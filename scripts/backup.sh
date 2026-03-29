#!/bin/bash
# NanoClaw Backup Script
# Configure BACKUP_DIR in .env or set default below

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NANOCLAW_DIR="$(dirname "$SCRIPT_DIR")"

# Load .env if present
[ -f "$NANOCLAW_DIR/.env" ] && set -a && source "$NANOCLAW_DIR/.env" && set +a

# BACKUP_DIR can be set in .env — fallback to ~/nanoclaw-backups
BACKUP_DIR="${BACKUP_DIR:-$HOME/nanoclaw-backups}"
GMAIL_MCP_DIR="${GMAIL_MCP_DIR:-$HOME/.gmail-mcp}"
KEEP_DAYS="${BACKUP_KEEP_DAYS:-14}"

DATE=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_FILE="$BACKUP_DIR/nanoclaw-$DATE.tar.gz"
TEMP_DIR=$(mktemp -d)

log() { echo "[$(date '+%H:%M:%S')] $*"; }

log "Iniciando backup: $BACKUP_FILE"
mkdir -p "$BACKUP_DIR"

# Monta estrutura temporária com tudo que precisa ser salvo
mkdir -p "$TEMP_DIR/nanoclaw"

# Dados e configuração
cp -r "$NANOCLAW_DIR/data"         "$TEMP_DIR/nanoclaw/"
cp -r "$NANOCLAW_DIR/store"         "$TEMP_DIR/nanoclaw/"
cp -r "$NANOCLAW_DIR/groups"        "$TEMP_DIR/nanoclaw/"
cp    "$NANOCLAW_DIR/.env"          "$TEMP_DIR/nanoclaw/"
cp    "$NANOCLAW_DIR/.mcp.json"     "$TEMP_DIR/nanoclaw/"
cp -r "$NANOCLAW_DIR/.claude"       "$TEMP_DIR/nanoclaw/"

# Credenciais Gmail
if [ -d "$GMAIL_MCP_DIR" ]; then
    cp -r "$GMAIL_MCP_DIR" "$TEMP_DIR/"
fi

# Compacta
tar -czf "$BACKUP_FILE" -C "$TEMP_DIR" .
rm -rf "$TEMP_DIR"

SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
log "Backup criado: $BACKUP_FILE ($SIZE)"

# Remove backups antigos (mais de KEEP_DAYS dias)
REMOVED=$(find "$BACKUP_DIR" -name "nanoclaw-*.tar.gz" -mtime +$KEEP_DAYS -print -delete | wc -l)
[ "$REMOVED" -gt 0 ] && log "Removidos $REMOVED backup(s) antigo(s)"

log "Backup concluído."
