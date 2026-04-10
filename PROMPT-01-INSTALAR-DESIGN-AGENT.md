# PROMPT 01 — Instalar Agente de Design Gráfico

Cole este prompt no Claude Code:

---

```
Preciso que você instale e configure ferramentas de design gráfico para trabalhar com:

## Ferramentas Necessárias

### 1. Geração de SVG/Logo
- Instale as dependências para gerar SVGs programaticamente
- `npm install -g sharp svgo` (otimização de imagens e SVG)
- `pip install cairosvg Pillow --break-system-packages` (renderização SVG para PNG)

### 2. Geração de Ícones e Favicons
- `npm install -g sharp-cli` (redimensionamento de imagens)
- `npm install -g png-to-ico` (geração de favicon.ico)
- Preciso gerar ícones PWA em todos os tamanhos: 48, 72, 96, 128, 144, 152, 192, 384, 512

### 3. Fontes
- Baixe as fontes Google Fonts para uso local:
  - **Inter** (pesos 300, 400, 500, 600, 700) — corpo de texto
  - **Satoshi** ou **Space Grotesk** (pesos 500, 600, 700) — títulos e destaques
- Gere os @font-face CSS para carregamento local

### 4. Paleta de Cores — Sistema de Design AgrUAI
Crie um arquivo `design-tokens.css` com as variáveis CSS:

```css
:root {
  /* === VERDE MUSGO ESCURO (Base/Fundo) === */
  --agr-verde-900: #0F1F0F;    /* Fundo principal, mais profundo */
  --agr-verde-800: #1A2E1A;    /* Fundo de cards, painéis */
  --agr-verde-700: #243824;    /* Fundo hover, sidebar */
  --agr-verde-600: #2E4A2E;    /* Bordas sutis, separadores */
  --agr-verde-500: #3D5E3D;    /* Texto secundário sobre fundo escuro */

  /* === OURO REAL (Acentos — NÃO dourado brega) === */
  --agr-ouro-500: #C5A572;     /* Acento principal */
  --agr-ouro-400: #D4B88A;     /* Hover em elementos ouro */
  --agr-ouro-300: #E0CAA3;     /* Texto destaque suave */
  --agr-ouro-600: #B8945A;     /* Bordas e ícones */
  --agr-ouro-700: #9A7B45;     /* Ouro mais escuro, sombras */

  /* === AZUL ÁGUA/CÉU/RIO (Secundário — dados, mapas, satélite) === */
  --agr-azul-500: #4A90A4;     /* Azul água — sereno, não corporate */
  --agr-azul-400: #5DA8BE;     /* Hover, links */
  --agr-azul-300: #7BBFD4;     /* Indicadores de satélite/mapa */
  --agr-azul-600: #3A7A8E;     /* Bordas de gráficos */
  --agr-azul-700: #2B5F6E;     /* Fundo de badges de dados */

  /* === BRANCO/NEUTROS (Texto e paz) === */
  --agr-branco: #F5F0E8;       /* Off-white quente — texto principal */
  --agr-branco-puro: #FAFAF7;  /* Títulos de máximo contraste */
  --agr-cinza-300: #D1C9BC;    /* Texto secundário */
  --agr-cinza-400: #A89E90;    /* Texto terciário, placeholders */
  --agr-cinza-500: #7A7268;    /* Texto desabilitado */

  /* === ESTADOS (Alertas e Status) === */
  --agr-sucesso: #4A8C5C;      /* Verde vivo — check-in ok */
  --agr-alerta: #D4A040;       /* Âmbar ouro — atenção */
  --agr-perigo: #C45A4A;       /* Vermelho terra — crítico */
  --agr-info: #4A90A4;         /* Azul água — informativo */

  /* === SOMBRAS E GLASSMORPHISM === */
  --agr-sombra-sm: 0 2px 8px rgba(15, 31, 15, 0.3);
  --agr-sombra-md: 0 4px 16px rgba(15, 31, 15, 0.4);
  --agr-sombra-lg: 0 8px 32px rgba(15, 31, 15, 0.5);
  --agr-glass: rgba(26, 46, 26, 0.7);
  --agr-glass-border: rgba(197, 165, 114, 0.15);

  /* === TIPOGRAFIA === */
  --font-heading: 'Space Grotesk', 'Inter', sans-serif;
  --font-body: 'Inter', -apple-system, sans-serif;
  --font-mono: 'JetBrains Mono', monospace;

  /* === BANDEIRA DO BRASIL — Referência semântica === */
  /* Verde = mata, floresta, campo → --agr-verde-* */
  /* Amarelo = ouro, minério, riqueza → --agr-ouro-* */
  /* Azul = rio, água, céu, satélite → --agr-azul-* */
  /* Branco = paz, clareza, legibilidade → --agr-branco* */
}
```

### 5. Skill de Design (criar em .claude/skills/)
Crie uma skill chamada `agruai-design` em `.claude/skills/agruai-design/SKILL.md` com:
- As regras de uso das cores acima
- Regras de tipografia (Inter para corpo, Space Grotesk para títulos)
- Regras de espaçamento (8px grid system)
- Regras de componentes (cards com glass effect, bordas em ouro sutil, cantos arredondados 12px)
- Regras de ícones (linha fina, stroke 1.5px, cor ouro ou branco)
- A filosofia: "Premium rural — sofisticação do campo, não da cidade. Ouro real, não dourado de bijuteria. Verde da mata, não verde de farmácia. Azul do rio e do céu, não azul corporate."

Confirme cada instalação e me mostre o design-tokens.css final.
```

---
