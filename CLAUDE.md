# CLAUDE.md — AgrUAI
# Documento de Contexto Permanente
# Atualizar sempre que houver decisão relevante nova

---

## O QUE É O AGRUAI

AgrUAI (pronuncia "a-gru-ái") é uma plataforma PWA de inteligência
rural por satélite que conecta proprietários de múltiplas fazendas
aos seus gestores de campo em tempo real.

**Evolução da marca:** O projeto nasceu como "FarmOS" e foi
rebrandado para AgrUAI em abril de 2026 — nova identidade visual,
paleta, tipografia e posicionamento.

Posicionamento: "SimFarm da vida real"
Tagline: Inteligência Rural por Satélite.
Tom: Premium rural. Sofisticado sem ser urbano. Tecnológico sem ser frio.

O produto resolve três dores do multifazendeiro:
1. Dependência do gerente — dono não sabe o que acontece sem ligar
2. Impossibilidade de comparar fazendas — cada uma tem seu sistema
3. Ausência de alertas preventivos — problema chega tarde

---

## STACK TÉCNICA

- Frontend: HTML + CSS + JavaScript puro (sem framework)
- Mapas: Leaflet.js via CDN (tile: CartoDB Dark Matter)
- Gráficos: Chart.js via CDN
- Banco: Supabase (auth + realtime + storage)
- Landing page: Supabase para leads + RPC para contagem de vagas
- Satélite: Sentinel-2 via Copernicus API (gratuito)
- Satélite demo: Canvas HTML5 gerado programaticamente
- Deploy: GitHub Pages
- Fontes: Space Grotesk (títulos) + Inter (corpo) — local em /fonts/
- PWA: manifest.json + service worker (cache: agruai-v1)
- Design System: design-tokens.css + skill agruai-design

---

## PALETA DE CORES — DESIGN TOKENS

Inspirada na bandeira do Brasil, reinterpretada como paleta premium.

```css
/* === VERDE MUSGO ESCURO (Base/Fundo) === */
--agr-verde-900: #0F1F0F;    /* Fundo principal */
--agr-verde-800: #1A2E1A;    /* Cards e painéis */
--agr-verde-700: #243824;    /* Hover, sidebar */
--agr-verde-600: #2E4A2E;    /* Bordas sutis */
--agr-verde-500: #3D5E3D;    /* Texto secundário sobre escuro */

/* === OURO REAL (Acentos) === */
--agr-ouro-500: #C5A572;     /* Acento principal */
--agr-ouro-400: #D4B88A;     /* Hover ouro */
--agr-ouro-300: #E0CAA3;     /* Destaque suave */
--agr-ouro-600: #B8945A;     /* Bordas e ícones */
--agr-ouro-700: #9A7B45;     /* Ouro escuro */

/* === AZUL ÁGUA/CÉU/RIO (Secundário) === */
--agr-azul-500: #4A90A4;     /* Dados, mapas, satélite */
--agr-azul-400: #5DA8BE;     /* Hover, links */
--agr-azul-300: #7BBFD4;     /* Indicadores */
--agr-azul-600: #3A7A8E;     /* Bordas gráficos */
--agr-azul-700: #2B5F6E;     /* Badges de dados */

/* === BRANCO/NEUTROS === */
--agr-branco: #F5F0E8;       /* Texto principal (off-white quente) */
--agr-branco-puro: #FAFAF7;  /* Títulos máximo contraste */
--agr-cinza-300: #D1C9BC;    /* Texto secundário */
--agr-cinza-400: #A89E90;    /* Placeholders */
--agr-cinza-500: #7A7268;    /* Texto desabilitado */

/* === ESTADOS === */
--agr-sucesso: #4A8C5C;      /* OK */
--agr-alerta: #D4A040;       /* Atenção */
--agr-perigo: #C45A4A;       /* Crítico */
--agr-info: #4A90A4;         /* Informativo */
```

Dark mode exclusivo. Nunca light mode.
Referência completa: `design-tokens.css` e `.claude/skills/agruai-design/SKILL.md`

---

## LOGO

- "Agr" em `#F5F0E8` (branco quente) + "UAI" em `#C5A572` (ouro real)
- Fonte: Space Grotesk 700, letter-spacing -0.04em
- Ícone: satélite em órbita + contorno de terreno (stroke 1.5px, ouro)
- Arquivos: `logo-full.svg`, `logo-icon.svg`, `favicon.svg`
- Ícones PWA: todos os tamanhos em /icons/ (48 a 512, maskable, splash)

---

## DADOS DAS 9 FAZENDAS FICTÍCIAS (protótipo)

| ID | Nome | Município | Estado | Área (ha) | NDVI | Status |
|----|------|-----------|--------|-----------|------|--------|
| 1 | Fazenda Barreiro Grande | Matão | SP | 2.840 | 0.76 | ok |
| 2 | Fazenda Cerradão | Araraquara | SP | 3.200 | 0.81 | ok |
| 3 | Fazenda Laranjeiras | Motuca | SP | 1.920 | 0.69 | ok |
| 4 | Fazenda Carneirinho | Carneirinho | MG | 2.100 | 0.74 | alerta |
| 5 | Fazenda Boa Vista | Frutal | MG | 1.650 | 0.61 | critico |
| 6 | Fazenda Matão Sul | Matão | SP | 1.480 | 0.55 | critico |
| 7 | Fazenda Serra Verde | Uberaba | MG | 2.200 | 0.79 | ok |
| 8 | Fazenda Recanto Angus | Bebedouro | SP | 1.800 | 0.83 | ok |
| 9 | Fazenda Primavera | Prata | MG | 1.230 | 0.71 | ok |

Total: 18.420 hectares | 12.840 cabeças de gado | 9 propriedades
Culturas: Angus (pecuária), Coco, Citrus, Soja, Milho

---

## TELAS IMPLEMENTADAS (index.html)

1. **Mapa Geral** — Leaflet com 9 marcadores coloridos por status
2. **Dashboard** — KPIs, gráficos Chart.js, feed de eventos
3. **Propriedades** — cards expandíveis + modal de detalhes
4. **Rebanho** — tabela desktop / cards mobile
5. **Culturas** — breakdown por tipo de produção
6. **Relatórios** — preview de relatório executivo
7. **Modo Gestor** — formulário de check-in em 5 seções (wizard)
8. **Tempo Real** — feed de eventos + simulação de check-in ao vivo
9. **Central de Recados** — proprietário envia ordens/alertas aos gestores

### Feature de Satélite (Propriedades > Mais Detalhes)

* Botão "Ver Satélite" no mapa individual da fazenda
* Overlay gerado via Canvas HTML5 (sem API externa)
* Visual: zonas NDVI, grain, vinheta, metadados
* Label: "AgrUAI SAP — Monitoramento por Satélite"
* Cada fazenda tem visual único (seed por ID)

### Central de Recados (Proprietário → Gestores)

* FAB flutuante (📨) acima do bottom-nav
* Passo 1: Selecionar fazendas (múltipla seleção + "Todas")
* Passo 2: Categoria do recado (6 tipos):
  - Solicitar Relatório, Ordem de Serviço, Alerta ao Campo,
    Autorização, Agendar Visita, Recado Livre
* Passo 3: Compor mensagem com template por categoria
* Passo 4: Confirmação animada → evento no feed Ao Vivo

---

## PÁGINAS DO PROJETO

| Arquivo | Função |
|---------|--------|
| `index.html` | App principal (PWA) — todas as telas |
| `landing.html` | Landing page — captura de leads Agrishow 2026 |
| `cartao-agruai.html` | Cartão de visita (frente e verso) para impressão |

---

## LANDING PAGE (landing.html)

Página single-scroll para captura de leads na Agrishow 2026.

**Seções:** Hero → Problema → O que é → Prova social → Formulário → Confirmação → Footer

**Dados-chave:**
- Programa de Acesso Antecipado (10 vagas)
- Contador dinâmico de vagas via Supabase RPC
- Leads salvos diretamente no Supabase (não mais FormSubmit)
- Sem link para protótipo/app/demo (estratégico)
- Sem preço, sem data de lançamento
- Tom: exclusividade e seleção, não "lista de espera"

**Meta tags:** og:title, og:description, og:image configurados para agruai.com

---

## NAVEGAÇÃO

Desktop: sidebar fixa 240px (esquerda)
Mobile: bottom navigation 5 itens
Header: logo AgrUAI + badge de modo + botão "Modo Gestor" + 🔔

Modos de acesso:
* **Proprietário**: dashboard completo (padrão)
* **Gestor**: formulário de check-in de campo

Alternância via botão no header ou bottom nav — com toast de confirmação.
FAB Recados (📨) visível apenas no modo Proprietário.

---

## RESPONSIVO

Breakpoints:
* Mobile: < 768px
* Tablet: 768px – 1024px
* Desktop: > 1024px

Regras críticas mobile:
* Tabela de rebanho → cards empilhados com data-label
* KPIs → grid 2x2
* Sidebar → oculta, substituída por bottom nav
* Mapa → altura 55vh
* Padding bottom → calc(80px + env(safe-area-inset-bottom))
* Overflow-x → nunca ultrapassar 100vw

---

## PWA

manifest.json: name "AgrUAI", display standalone, theme #0F1F0F
Service Worker: cache agruai-v1, cache-first para assets, network-first para dados
iOS: apple-mobile-web-app-capable, safe areas com env(), splash screens
Android: beforeinstallprompt capturado, banner customizado
Offline: fallback com dados em cache
Ícones: completos de 48x48 a 512x512, maskable, apple-touch-icon

---

## SATÉLITE — ARQUITETURA REAL (produção futura)

Sentinel-2 via Copernicus Data Space Ecosystem:
* Gratuito: 10.000 PUs/mês
* Custo por foto (50km²): ~4 PUs → R$ 0
* Capacidade gratuita: ~62 clientes simultâneos
* Revisita: a cada 5 dias
* Resolução: 10m/px (suficiente para análise de pasto)
* NDVI: calculado com bandas B04 e B08

Endpoint: https://sh.dataspace.copernicus.eu/api/v1/process
Auth: OAuth2 client credentials

---

## CONTEXTO COMERCIAL

### Cliente-alvo

Proprietários de múltiplas fazendas (3+) com alto patrimônio.
Eixo prioritário: MG/SP/MS/MT/GO.
Brasil: ~5.000–8.000 multifazendeiros no público prioritário.
América Latina: ~80.000–120.000.

### Precificação (a definir — não mencionar na landing)

* Setup por fazenda: R$ 5.000–15.000 (único)
* Mensalidade por propriedade: R$ 800–2.000
* Módulo IA/Satélite: R$ 2.000–5.000/mês

### Dois públicos

1. **Proprietário 60+**: foco em controle e tranquilidade
2. **Herdeiro 25-35**: foco em modernização e tecnologia

### Estratégia de entrada

1. Agrishow 2026 (Ribeirão Preto, final de abril) — QR code no cartão → landing page
2. Balcão do Empório Família Rodrigues em Ribeirão Preto
3. Frase de 20 segundos → curiosidade → demo → piloto

### Parceiro estratégico em análise

Terral Agro / TBeef — Matão/SP:
* 9 fazendas, 18 mil hectares, 1.650 colaboradores
* SAP implementado (back-office industrial)
* Gap: sem camada de visibilidade executiva de campo
* AgrUAI complementa o SAP, não compete
* Proposta: piloto gratuito em 2 fazendas por 60 dias

---

## ARQUIVOS DO PROJETO

```
/
├── index.html              ← App principal (PWA)
├── landing.html            ← Landing page Agrishow 2026
├── cartao-agruai.html      ← Cartão de visita para impressão
├── cartao-agruai-frente.svg
├── cartao-agruai-verso.svg
├── design-tokens.css       ← Variáveis CSS do design system
├── fonts.css               ← @font-face local
├── logo-full.svg           ← Logo completa (ícone + AgrUAI)
├── logo-icon.svg           ← Logo compacta (só ícone)
├── favicon.svg             ← Favicon SVG
├── manifest.json           ← PWA manifest
├── sw.js                   ← Service Worker (agruai-v1)
├── fonts/
│   ├── inter/              ← Fonte Inter (local)
│   └── space-grotesk/      ← Fonte Space Grotesk (local)
├── icons/                  ← Ícones PWA (48-512, maskable, splash)
├── .claude/
│   └── skills/
│       └── agruai-design/  ← Skill do design system
│           └── SKILL.md
└── PROMPT_*.md             ← Prompts usados na construção
```

---

## PROMPTS GERADOS

| Arquivo | Conteúdo |
|---------|----------|
| PROMPT-01-INSTALAR-DESIGN-AGENT.md | Ferramentas de design + design-tokens + skill |
| PROMPT-02-REDESIGN-AGRUAI.md | Redesign completo FarmOS → AgrUAI |
| PROMPT-03-LANDING-PAGE-AGRUAI.md | Landing page Agrishow 2026 |
| PROMPT_ClaudeCode_FarmOS_CentralRecados.md | Central de Recados do proprietário |

---

## DECISÕES TÉCNICAS TOMADAS

| Decisão | Escolha | Motivo |
|---------|---------|--------|
| Framework | Nenhum (vanilla JS) | Deploy simples, sem build |
| Mapas | Leaflet + CartoDB Dark | Gratuito, dark theme nativo |
| Gráficos | Chart.js | Leve, responsivo, customizável |
| Satélite demo | Canvas HTML5 | Zero custo, zero API |
| Satélite produção | Sentinel-2 Copernicus | Gratuito até 62 clientes |
| Auth | Supabase | Já familiar ao desenvolvedor |
| Deploy | GitHub Pages | Zero custo, HTTPS nativo |
| Tile mapa | CartoDB Dark Matter | Visual premium sem API key |
| Marca | AgrUAI (rebrand de FarmOS) | Nome brasileiro, memorável, domínio disponível |
| Paleta | Verde musgo + ouro + azul água | Bandeira do Brasil reinterpretada premium |
| Fontes | Space Grotesk + Inter (local) | Moderna, limpa, sem dependência de CDN |
| Leads landing | Supabase direto | Controle total, sem FormSubmit intermediário |
| Vagas landing | RPC Supabase | Contador dinâmico real de vagas |

---

## REGRAS PARA O CLAUDE CODE

1. Nunca usar framework (React, Vue, etc.) — vanilla JS apenas
2. Nunca usar light mode — dark exclusivo
3. Nunca ultrapassar 100vw no mobile
4. Sempre box-sizing: border-box global
5. Sempre destruir mapa Leaflet antes de recriar (evitar memory leak)
6. Sempre font-size mínimo 16px em inputs (evitar zoom iOS)
7. Sempre env(safe-area-inset-*) para iOS
8. Sempre touch-action: manipulation para eliminar delay iOS
9. Dados fictícios devem ser matematicamente consistentes
10. Console deve estar limpo — zero erros, zero warnings
11. Ao adicionar feature nova: atualizar este CLAUDE.md
12. Usar tokens `--agr-*` do design-tokens.css, nunca cores hardcoded
13. Nunca usar branco puro #FFFFFF — usar --agr-branco (#F5F0E8)
14. Nunca usar dourado brega (#FFD700) — usar --agr-ouro-500 (#C5A572)
15. Nunca usar verde néon — usar --agr-verde-*
16. Nunca usar azul corporate — usar --agr-azul-*
17. Tipografia: Space Grotesk para títulos, Inter para corpo
18. Consultar skill `.claude/skills/agruai-design/SKILL.md` para componentes

---

## PRÓXIMOS PASSOS DO PROJETO

* [ ] Finalizar protótipo completo e testar em mobile real
* [ ] Deploy no GitHub Pages com domínio agruai.com
* [ ] Agrishow 2026 — distribuir cartões com QR code → landing
* [ ] Estruturar proposta de piloto para a Terral Agro
* [ ] Integrar Sentinel-2 real (substituir Canvas pela API)
* [ ] Implementar Supabase auth + realtime no app principal
* [ ] Criar CNPJ para formalizar o produto
* [ ] Registrar marca AgrUAI no INPI

---

## OWNER

Renato Cesar Rodrigues
Ribeirão Preto, SP, Brasil
Projetos ativos: AgrUAI, Escola Liberal, Empório Família Rodrigues, Craquei

---

Última atualização: Abril 2026
Atualizar este arquivo a cada sessão relevante de desenvolvimento.
