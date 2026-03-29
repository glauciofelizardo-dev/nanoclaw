/**
 * Warm Container Pool
 *
 * Keeps cron-task containers alive between executions to avoid
 * paying the MCP startup cost (~80k tokens) on every run.
 *
 * Flow:
 *   1st run  → runContainerAgent with keepWarm:true → resolves on session update
 *              → container stays alive, registered in pool
 *   Nth run  → pool.inject(groupFolder, prompt) → container picks up via IPC
 *              → pool.waitOutput(groupFolder, onOutput) → resolves on next session update
 *   Timeout  → pool auto-closes after WARM_IDLE_MS of inactivity
 */

import fs from 'fs';
import path from 'path';

import { logger } from './logger.js';
import { ContainerOutput, WarmHandle } from './container-runner.js';
import { resolveGroupIpcPath } from './group-folder.js';

// Keep containers warm for 5 hours (covers 4h cron gaps with buffer)
const WARM_IDLE_MS = 5 * 60 * 60 * 1000;

interface PoolEntry {
  handle: WarmHandle;
  groupFolder: string;
  idleTimer: ReturnType<typeof setTimeout>;
}

class WarmContainerPool {
  private pool = new Map<string, PoolEntry>();

  register(groupFolder: string, handle: WarmHandle): void {
    this.evict(groupFolder);

    const entry: PoolEntry = {
      handle,
      groupFolder,
      idleTimer: this.makeIdleTimer(groupFolder),
    };
    this.pool.set(groupFolder, entry);

    handle.emitter.once('close', () => {
      if (this.pool.get(groupFolder)?.handle === handle) {
        clearTimeout(entry.idleTimer);
        this.pool.delete(groupFolder);
        logger.info(
          { groupFolder },
          '[warm-pool] Container closed, evicted from pool',
        );
      }
    });

    logger.info({ groupFolder }, '[warm-pool] Container registered');
  }

  has(groupFolder: string): boolean {
    return this.pool.has(groupFolder);
  }

  inject(groupFolder: string, prompt: string): boolean {
    const entry = this.pool.get(groupFolder);
    if (!entry) return false;

    clearTimeout(entry.idleTimer);
    entry.idleTimer = this.makeIdleTimer(groupFolder);

    const ipcInputDir = path.join(resolveGroupIpcPath(groupFolder), 'input');
    try {
      fs.mkdirSync(ipcInputDir, { recursive: true });
      const filename = `${Date.now()}-warm-task.json`;
      const filepath = path.join(ipcInputDir, filename);
      const text = `[SCHEDULED TASK - The following message was sent automatically and is not coming directly from the user or group.]\n\n${prompt}`;
      fs.writeFileSync(
        `${filepath}.tmp`,
        JSON.stringify({ type: 'message', text }),
      );
      fs.renameSync(`${filepath}.tmp`, filepath);
      logger.info({ groupFolder }, '[warm-pool] Task injected via IPC');
      return true;
    } catch (err) {
      logger.error({ groupFolder, err }, '[warm-pool] Failed to inject task');
      this.evict(groupFolder);
      return false;
    }
  }

  /**
   * Wait for the next task's output from a warm container.
   * Calls onOutput for each streamed output until the session update marker
   * (isSessionUpdate:true) or an error. Resolves null if container closes.
   */
  waitOutput(
    groupFolder: string,
    onOutput: (output: ContainerOutput) => Promise<void>,
  ): Promise<ContainerOutput | null> {
    const entry = this.pool.get(groupFolder);
    if (!entry) return Promise.resolve(null);

    return new Promise((resolve) => {
      let outputChain = Promise.resolve();

      const onOutputEvent = (output: ContainerOutput) => {
        outputChain = outputChain.then(() => onOutput(output));

        if (output.isSessionUpdate || output.status === 'error') {
          cleanup();
          outputChain.then(() => resolve(output));
        }
      };

      const onClose = () => {
        cleanup();
        outputChain.then(() => resolve(null));
      };

      const cleanup = () => {
        entry.handle.emitter.removeListener('output', onOutputEvent);
        entry.handle.emitter.removeListener('close', onClose);
      };

      entry.handle.emitter.on('output', onOutputEvent);
      entry.handle.emitter.once('close', onClose);
    });
  }

  private evict(groupFolder: string): void {
    const existing = this.pool.get(groupFolder);
    if (existing) {
      clearTimeout(existing.idleTimer);
      this.pool.delete(groupFolder);
    }
  }

  private makeIdleTimer(groupFolder: string): ReturnType<typeof setTimeout> {
    return setTimeout(() => {
      logger.info(
        { groupFolder },
        '[warm-pool] Idle timeout, closing container',
      );
      this.pool.get(groupFolder)?.handle.close();
      this.evict(groupFolder);
    }, WARM_IDLE_MS);
  }
}

export const warmContainerPool = new WarmContainerPool();
