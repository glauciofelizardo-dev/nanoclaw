#!/bin/bash
# Renova o token OAuth do Claude Code forçando uso do refresh token

LOG="/home/glaucio/nanoclaw/logs/token-refresh.log"
CREDENTIALS="/home/glaucio/.claude/.credentials.json"
BACKUP="${CREDENTIALS}.bak"
ENV_FILE="/home/glaucio/nanoclaw/.env"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

# Faz backup do credentials atual
cp "$CREDENTIALS" "$BACKUP" || { log "ERRO: não conseguiu fazer backup"; exit 1; }

# Zera o expiresAt para forçar Claude a usar o refresh token
python3 -c "
import json
d = json.load(open('$CREDENTIALS'))
d['claudeAiOauth']['expiresAt'] = 0
with open('$CREDENTIALS', 'w') as f:
    json.dump(d, f, indent=2)
" 2>/dev/null || { log "ERRO: não conseguiu modificar credentials"; cp "$BACKUP" "$CREDENTIALS"; exit 1; }

log "Forçando refresh do token OAuth..."

# Roda claude — agora ele vai usar o refresh token para obter novo access token
RESULT=$(echo "ping" | /home/glaucio/.local/bin/claude --print 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    # Verifica se o token foi realmente renovado
    NEW_EXPIRES=$(python3 -c "
import json, datetime
d = json.load(open('$CREDENTIALS'))
exp = d['claudeAiOauth']['expiresAt']
print(datetime.datetime.fromtimestamp(exp/1000).strftime('%Y-%m-%d %H:%M'))
" 2>/dev/null)
    log "Token renovado com sucesso — expira em: $NEW_EXPIRES"
    rm -f "$BACKUP"

    # Atualiza o token no .env
    NEW_TOKEN=$(python3 -c "
import json
d = json.load(open('$CREDENTIALS'))
print(d['claudeAiOauth']['accessToken'])
" 2>/dev/null)
    if [ -n "$NEW_TOKEN" ] && [ -f "$ENV_FILE" ]; then
        sed -i "s|^CLAUDE_CODE_OAUTH_TOKEN=.*|CLAUDE_CODE_OAUTH_TOKEN=$NEW_TOKEN|" "$ENV_FILE"
        log "Token atualizado no .env"
        systemctl --user restart nanoclaw 2>/dev/null && log "NanoClaw reiniciado"
    fi
else
    log "ERRO ao renovar token: $RESULT"
    log "Restaurando backup..."
    cp "$BACKUP" "$CREDENTIALS"
fi
