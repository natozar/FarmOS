# PROMPT 02 — Redesign Completo AgrUAI

Cole este prompt no Claude Code DEPOIS de executar o Prompt 01:

---

```
## Redesign Completo: FarmOS → AgrUAI

O arquivo `index.html` é um protótipo de PWA de gestão rural que precisa ser totalmente rebrandado.
Use o arquivo `design-tokens.css` e a skill `agruai-design` como referência absoluta.

### MARCA

**Nome:** AgrUAI (pronuncia "a-gru-ái")
**Conceito:** SimFarm da vida real — plataforma de inteligência por satélite para proprietários de múltiplas fazendas
**Público:** Pecuaristas e agricultores ricos do eixo MG/SP/MS/MT/GO
**Tom:** Premium rural. Sofisticado sem ser urbano. Tecnológico sem ser frio.

### LOGO

Crie a logo SVG do AgrUAI com estas especificações:

1. **Tipografia:**
   - "Agr" em branco off-white (#F5F0E8), font-weight 600, Space Grotesk
   - "UAI" em ouro real (#C5A572), font-weight 700, Space Grotesk
   - Kerning apertado (letter-spacing: -0.02em)

2. **Ícone (opcional, ao lado esquerdo):**
   - Um símbolo minimalista que combine: ponto de satélite em órbita + contorno de terreno/campo
   - Traço fino (stroke: 1.5px), cor ouro (#C5A572)
   - Deve funcionar em 16x16 (favicon) até 512x512 (splash)
   - NÃO use: folha, espiga de trigo, vaca, trator (clichês de agro)

3. **Variações a gerar:**
   - Logo completa (ícone + AgrUAI) — para header e landing page
   - Logo compacta (só ícone) — para favicon e app icon
   - Logo branca — para uso em fundos coloridos
   - Logo ouro — para uso em fundos escuros

4. **Arquivos a gerar:**
   - `logo-full.svg` (logo completa)
   - `logo-icon.svg` (só ícone)
   - `favicon.svg` (ícone otimizado para 32x32)
   - Gere todos os PNGs para PWA: `icon-48x48.png` até `icon-512x512.png`
   - `favicon.ico` (multi-resolução: 16, 32, 48)
   - Atualize o `manifest.json` com os novos ícones

### CORES — SUBSTITUIÇÕES NO index.html

Faça as seguintes substituições GLOBAIS (não manuais, use replace):

| De (atual FarmOS)           | Para (AgrUAI)                          | Contexto |
|----------------------------|----------------------------------------|----------|
| `#0D1B2A`                  | `var(--agr-verde-900)` / `#0F1F0F`    | Fundo principal |
| `#1B2D45` ou similar       | `var(--agr-verde-800)` / `#1A2E1A`    | Fundo de cards |
| `#2D9B6F` ou verde acento  | `var(--agr-sucesso)` / `#4A8C5C`      | Status OK |
| `#C9A84C` ou gold          | `var(--agr-ouro-500)` / `#C5A572`     | Acentos ouro |
| `#E8A020` ou amber         | `var(--agr-alerta)` / `#D4A040`       | Alertas |
| `#E84040` ou red           | `var(--agr-perigo)` / `#C45A4A`       | Crítico |
| Qualquer azul `#1E90FF`, `#3498db`, etc. | `var(--agr-azul-500)` / `#4A90A4` | Dados, mapas, satélite |
| `#FFFFFF` texto             | `var(--agr-branco)` / `#F5F0E8`       | Texto principal |
| Qualquer cinza de texto    | Usar escala `--agr-cinza-*`            | Texto secundário |

### TIPOGRAFIA — SUBSTITUIÇÕES

| De (atual)          | Para (AgrUAI)                    |
|---------------------|----------------------------------|
| `Playfair Display`  | `Space Grotesk` (var --font-heading) |
| `DM Sans`           | `Inter` (var --font-body)        |

### COMPONENTES — REDESIGN

1. **Sidebar:**
   - Fundo: `--agr-verde-900` com borda direita `--agr-glass-border`
   - Ícones do menu: ouro (#C5A572) quando ativo, cinza quando inativo
   - Item ativo: fundo `--agr-verde-700` com borda esquerda ouro (3px)
   - Logo AgrUAI no topo com ícone de satélite

2. **Header/Topbar:**
   - Fundo: `--agr-verde-800` com efeito glass (`backdrop-filter: blur(12px)`)
   - Badge de conexão: azul água (#4A90A4) pulsando suavemente
   - Notificações: badge em ouro

3. **Cards (KPI, Propriedades, etc.):**
   - Fundo: `--agr-verde-800` com borda `--agr-glass-border`
   - Borda superior: gradiente de ouro (`--agr-ouro-700` → `--agr-ouro-400`)
   - Hover: borda ouro mais visível, sombra `--agr-sombra-md`
   - Border-radius: 12px
   - Números grandes: `--agr-branco-puro`, font-weight 700
   - Labels: `--agr-cinza-300`, font-weight 400, text-transform uppercase, font-size 0.75rem

4. **Mapa (Leaflet):**
   - Usar tile layer escuro: `https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png`
   - Markers: usar círculos com borda ouro e fill baseado no status
   - Popup: fundo `--agr-verde-800`, texto `--agr-branco`

5. **Gráficos (Chart.js):**
   - Background do canvas: transparente
   - Linha principal: gradiente ouro
   - Linha secundária: azul água (#4A90A4)
   - Grid: `--agr-verde-600` com opacidade 0.3
   - Labels dos eixos: `--agr-cinza-400`
   - Tooltip: fundo `--agr-verde-900`, borda ouro, texto branco

6. **Botões:**
   - Primário: fundo ouro (#C5A572), texto `--agr-verde-900`, hover escurece para #B8945A
   - Secundário: fundo transparente, borda ouro, texto ouro
   - Perigo: fundo `--agr-perigo`, texto branco
   - Border-radius: 8px
   - Padding: 12px 24px
   - Font-weight: 600
   - Transição suave (0.2s ease)

7. **Formulários (Modo Gestor):**
   - Input: fundo `--agr-verde-700`, borda `--agr-verde-600`, foco → borda ouro
   - Select/Dropdown: mesmo estilo
   - Labels: `--agr-cinza-300`, uppercase, 0.75rem

8. **Central ao Vivo (Timeline):**
   - Linha do tempo: vertical, cor `--agr-verde-600`
   - Pontos na timeline: ouro (check-in), azul água (info), vermelho terra (alerta)
   - Cards de evento: glass effect com borda lateral colorida por tipo

9. **Imagens de Satélite (NDVI):**
   - Manter a geração procedural mas ajustar a paleta:
     - Vegetação excelente: `--agr-sucesso`
     - Vegetação boa: verde mais claro
     - Degradada: `--agr-alerta`
     - Solo exposto: `--agr-perigo`
   - Borda do container: ouro sutil
   - Label "Sentinel-2" → "AgrUAI SAP" (Sistema de Acompanhamento por Satélite)

### TEXTOS A SUBSTITUIR

| De                              | Para                                    |
|--------------------------------|-----------------------------------------|
| "FarmOS"                       | "AgrUAI"                                |
| "Inteligência Operacional Rural" | "Inteligência Rural por Satélite"      |
| "Sistema" (genérico)           | "AgrUAI" onde fizer sentido             |
| Referências a "Sentinel-2/ESA" | "AgrUAI SAP — Monitoramento por Satélite" |

### MANIFEST.JSON

Atualize:
- `name`: "AgrUAI"
- `short_name`: "AgrUAI"
- `description`: "Inteligência Rural por Satélite"
- `theme_color`: "#0F1F0F"
- `background_color`: "#0F1F0F"
- Todos os caminhos de ícones

### SERVICE WORKER (sw.js)

Atualize:
- Nome do cache: `agruai-v1` (era `farmos-v10`)
- Demais caches: `agruai-fonts-v1`, `agruai-maps-v1`

### FILOSOFIA DE DESIGN — REGRAS ABSOLUTAS

1. **ZERO azul corporate** — o azul é de rio, de céu, de água. Sempre `--agr-azul-*`, nunca `#1E90FF` ou `#3498db`
2. **Ouro, NUNCA dourado** — `#C5A572` é o teto. Nunca `#FFD700` ou `#F1C40F`. Ouro é discreto.
3. **Verde é mata, não farmácia** — o verde é escuro, profundo, de cerrado à noite. Nunca `#00FF00` ou `#2ECC71`
4. **Branco é quente** — sempre off-white `#F5F0E8`. Branco puro `#FFFFFF` só em casos excepcionais de máximo contraste
5. **Espaçamento generoso** — padding mínimo de 16px em cards, 24px em seções. O luxo se expressa no espaço vazio.
6. **Animações sutis** — transições de 0.2-0.3s ease. Nada pulando ou brilhando. O ouro não precisa piscar para ser notado.
7. **Tipografia limpa** — Inter regular para corpo, Space Grotesk semibold para títulos. Sem itálico, sem bold excessivo.
8. **A bandeira está na paleta** — Verde (mata/campo), Ouro/Amarelo (riqueza mineral), Azul (rio/céu/satélite), Branco (paz/legibilidade). Mas nunca literal como bandeira — sempre sofisticado.

Execute todas as alterações no index.html, manifest.json e sw.js. Gere a logo e todos os ícones. Mostre o resultado final.
```

---
