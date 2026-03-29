---
name: leilao-caixa
description: Add real estate auction search command (/leilao) using Caixa Econômica Federal auctions via arrematadorcaixa.com.br API. Agents can search by city/state and get formatted results with price, discount, financing, and FGTS info. ~10x cheaper than browser search.
---

# Leilão Caixa Skill

Adds the `/leilao <cidade> <UF>` command to your NanoClaw agent. The agent queries the arrematadorcaixa.com.br internal API directly — no browser, no XLSX download — making searches ~10x cheaper (R$0.02 vs R$0.24).

## What it does

When the user sends `/leilao Valinhos SP` (or asks to search for auctions), the agent:
1. Sends an immediate acknowledgment via `send_message`
2. Queries the API with city + state filter
3. Returns up to 15 properties formatted with prices, discounts, financing/FGTS status, and direct Caixa links
4. Includes a comparative summary table highlighting best deals

## Installation

Run the following to apply this skill to a group's CLAUDE.md. Replace `<group>` with your group folder name (e.g. `telegram_main`):

```bash
cat .claude/skills/leilao-caixa/instructions.md >> groups/<group>/CLAUDE.md
```

Or manually copy the content of `instructions.md` into your group's `CLAUDE.md`.

> **Note:** Do NOT add to `groups/global/CLAUDE.md` — the warm container pool does not mount the global group workspace, so instructions there are not loaded by agents.

## API Details

- **Endpoint:** `https://arrematador.cxd.dev:3443/api/properties`
- **Header:** `app-id: 87e38dca71daffcedbcfbeea3a4815e3`
- **Key params:** `city=CITY&uf=UF&page=1&limit=50&orderBy=price&order=asc`
- `city` must be uppercase (e.g. `VALINHOS`, not `Valinhos`)
- `uf` is the 2-letter state code (e.g. `SP`)

### Response fields

| Field | Description |
|-------|-------------|
| `price` | Minimum bid (lance mínimo) |
| `evaluation_price` | Appraised value |
| `discount` | Discount % off appraised value |
| `accepts_financing` | 1 = yes, 0 = no (may lag actual CEF data) |
| `accepts_fgts` | 1 = yes, 0 = no |
| `mode` | Auction type (Leilão SFH, 1ª Praça, etc.) |
| `link` | Direct URL on arrematadorcaixa.com.br |

> ⚠️ `accepts_financing` may be outdated. Always include the property link so the user can verify on CEF's site.

## Files

- `SKILL.md` — this file (documentation)
- `instructions.md` — the CLAUDE.md snippet to paste into your group
