## Pesquisa de Leilões de Imóveis (Caixa)

Quando o usuário pedir para pesquisar, listar ou buscar imóveis em leilão (ex: "me lista imóveis em leilão em Valinhos SP", "tem apartamento com FGTS em Campinas?", "/leilao Valinhos SP"):

1. Avise com `mcp__nanoclaw__send_message`: "🔍 Buscando leilões em <cidade>/<estado>..."

2. Execute via bash:
```bash
python3 << 'EOF'
import urllib.request, json
city = "VALINHOS"  # cidade em uppercase — substituir
uf = "SP"          # estado — substituir
url = f"https://arrematador.cxd.dev:3443/api/properties?page=1&limit=50&city={city}&uf={uf}&orderBy=price&order=asc"
req = urllib.request.Request(url, headers={"app-id": "87e38dca71daffcedbcfbeea3a4815e3", "Accept": "application/json"})
with urllib.request.urlopen(req, timeout=15) as r:
    data = json.load(r)
items = data.get("data", [])
total = data.get("pagination", {}).get("total", 0)
print(f"Total: {total}")
for i, p in enumerate(items[:15], 1):
    print(f"{i}. {p.get('address','')} | {p.get('type','')} | R$ {p.get('price',0):,.0f} | Aval: R$ {p.get('evaluation_price',0):,.0f} | Desconto: {p.get('discount',0)}% | Fin: {'S' if p.get('accepts_financing') else 'N'} | FGTS: {'S' if p.get('accepts_fgts') else 'N'} | Mode: {p.get('mode','')} | {p.get('link','')}")
EOF
```

3. Formate e envie os resultados com `mcp__nanoclaw__send_message`. Máximo 15 por resposta.

⚠️ O campo `accepts_financing` da API pode estar desatualizado. Mostre o valor retornado, mas sempre inclua o link da CEF para o usuário verificar diretamente. Use este formato exato para cada imóvel:

*🏠 IMÓVEL 1 - [TIPO]*
Endereço: [endereço completo]
CEP: [cep]

*Valores:*
• 💰 R$ [preço formatado com vírgula]
• Avaliação: R$ [evaluation_price]
• Desconto: [discount]%
• Modalidade: [mode]

*Financiamento:*
• [✅ ou ❌] Financiamento: [SIM ou NÃO] | FGTS: [✅ ou ❌] [SIM ou NÃO]

Link: [link]

---

Ao final, adicione um resumo comparativo e análise:

*📊 RESUMO COMPARATIVO*

| # | Tipo | Preço | Fin. | FGTS | Destaque |
|---|------|-------|------|------|----------|
| 1 | Apto | R$ 196.800 | ❌ | ✅ | -40% desconto |
| 2 | Casa | R$ 698.275 | ❌ | ✅ | - |

*🏆 Melhores oportunidades:*
• Com financiamento: Imóvel X ([tipo] - R$ [preço])
• Sem financiamento / melhor desconto: Imóvel X ([tipo] - R$ [preço], [desconto]% off)
• Melhor custo-benefício: Imóvel X — avaliado em R$ [evaluation_price], lance mínimo R$ [price] ([desconto]% abaixo da avaliação)

Para a coluna "Destaque" use critérios como: desconto alto (>30%), 2º leilão, mais barato, melhor localização, aceita FGTS+financiamento, etc.
Considere "potencial" imóveis com desconto ≥ 30% ou 2º leilão (preço reduzido).
