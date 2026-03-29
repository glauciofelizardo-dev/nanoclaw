#!/bin/bash
# Renova o token OAuth do Claude Code automaticamente.
# O credential-proxy lê o token direto do credentials.json a cada request,
# então não é necessário reiniciar o nanoclaw após a renovação.

LOG="/home/glaucio/nanoclaw/logs/token-refresh.log"
CREDENTIALS="/home/glaucio/.claude/.credentials.json"
BACKUP="${CREDENTIALS}.bak"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

# Verifica tempo restante — só renova se faltar menos de 30 minutos
REMAINING=$(python3 -c "
import json, time
try:
    d = json.load(open('$CREDENTIALS'))
    exp = d['claudeAiOauth']['expiresAt'] / 1000
    print(int(exp - time.time()))
except:
    print(-1)
" 2>/dev/null)

if [ "$REMAINING" -gt 1800 ] 2>/dev/null; then
    log "Token ainda válido por ${REMAINING}s, renovação não necessária"
    exit 0
fi

log "Token expira em ${REMAINING}s — iniciando renovação..."

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

# Roda claude — vai usar o refresh token para obter novo access token
RESULT=$(echo "ping" | /home/glaucio/.local/bin/claude --print 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    NEW_EXPIRES=$(python3 -c "
import json, datetime
d = json.load(open('$CREDENTIALS'))
exp = d['claudeAiOauth']['expiresAt']
print(datetime.datetime.fromtimestamp(exp/1000).strftime('%Y-%m-%d %H:%M'))
" 2>/dev/null)
    log "Token renovado com sucesso — expira em: $NEW_EXPIRES (sem restart necessário)"
    rm -f "$BACKUP"
else
    log "ERRO ao renovar token: $RESULT"
    log "Restaurando backup..."
    cp "$BACKUP" "$CREDENTIALS"
    exit 1
fi
