# Skill: AgrUAI Design System

## Filosofia

> **"Premium rural — sofisticação do campo, não da cidade. Ouro real, não dourado de bijuteria. Verde da mata, não verde de farmácia. Azul do rio e do céu, não azul corporate."**

O sistema visual do AgrUAI é inspirado na bandeira do Brasil, reinterpretada como paleta premium para agronegócio de alta tecnologia. Cada cor tem raiz na paisagem rural brasileira.

---

## Paleta de Cores

Arquivo de referência: `design-tokens.css`

### Uso correto das cores

| Contexto | Token | Exemplo |
|----------|-------|---------|
| Fundo da aplicação | `--agr-verde-900` | `background: var(--agr-verde-900)` |
| Fundo de cards/painéis | `--agr-verde-800` | Cards, modais, sidebar |
| Hover sobre fundo | `--agr-verde-700` | Estados hover de containers |
| Bordas sutis | `--agr-verde-600` | Separadores, divisórias |
| Acento principal | `--agr-ouro-500` | Botões primários, badges, ícones ativos |
| Hover em ouro | `--agr-ouro-400` | Estado hover de botões ouro |
| Texto destaque | `--agr-ouro-300` | Números grandes, KPIs |
| Bordas de ícones | `--agr-ouro-600` | Contorno de ícones, stroke |
| Links e dados | `--agr-azul-500` | Links, indicadores de mapa |
| Texto principal | `--agr-branco` | Corpo de texto (#F5F0E8 off-white quente) |
| Títulos alto contraste | `--agr-branco-puro` | H1, H2 (#FAFAF7) |
| Texto secundário | `--agr-cinza-300` | Legendas, subtítulos |
| Placeholders | `--agr-cinza-400` | Inputs vazios |

### Regras de cor

- **NUNCA** usar amarelo puro (#FFD700) — usar apenas os tokens `--agr-ouro-*`
- **NUNCA** usar verde limão ou verde néon — apenas `--agr-verde-*`
- **NUNCA** usar azul royal ou azul corporate — apenas `--agr-azul-*`
- **NUNCA** usar branco puro (#FFFFFF) para texto — usar `--agr-branco` (off-white quente)
- Fundo sempre escuro (verde musgo), nunca fundo branco/claro

---

## Tipografia

### Fontes
- **Títulos e destaques:** `var(--font-heading)` → Space Grotesk (500, 600, 700)
- **Corpo de texto:** `var(--font-body)` → Inter (300, 400, 500, 600, 700)
- **Código/dados:** `var(--font-mono)` → JetBrains Mono

### Escala tipográfica
| Elemento | Tamanho | Peso | Fonte |
|----------|---------|------|-------|
| H1 | 2rem (32px) | 700 | Space Grotesk |
| H2 | 1.5rem (24px) | 600 | Space Grotesk |
| H3 | 1.25rem (20px) | 600 | Space Grotesk |
| Body | 1rem (16px) | 400 | Inter |
| Body Small | 0.875rem (14px) | 400 | Inter |
| Caption | 0.75rem (12px) | 500 | Inter |
| KPI Number | 2.5rem (40px) | 700 | Space Grotesk |

### Regras de tipografia
- Line-height para corpo: 1.6
- Line-height para títulos: 1.2
- Letter-spacing em títulos: -0.02em
- Letter-spacing em captions: 0.04em (uppercase)

---

## Espaçamento (8px Grid System)

| Token | Valor | Uso |
|-------|-------|-----|
| `--space-1` | 4px | Micro gaps |
| `--space-2` | 8px | Padding interno mínimo |
| `--space-3` | 12px | Gap entre ícone e texto |
| `--space-4` | 16px | Padding padrão de cards |
| `--space-5` | 24px | Gap entre seções internas |
| `--space-6` | 32px | Margin entre cards |
| `--space-8` | 48px | Margin entre seções |
| `--space-10` | 64px | Margin de seção principal |

**Regra:** Todo espaçamento deve ser múltiplo de 4px. Preferir múltiplos de 8px.

---

## Componentes

### Cards
```css
.card {
  background: var(--agr-verde-800);
  border: 1px solid var(--agr-glass-border);
  border-radius: 12px;
  padding: 16px;
  box-shadow: var(--agr-sombra-sm);
  backdrop-filter: blur(12px);
}

.card:hover {
  background: var(--agr-verde-700);
  border-color: var(--agr-ouro-600);
  box-shadow: var(--agr-sombra-md);
}
```

### Glass Effect (Glassmorphism)
```css
.glass {
  background: var(--agr-glass);
  backdrop-filter: blur(16px);
  -webkit-backdrop-filter: blur(16px);
  border: 1px solid var(--agr-glass-border);
  border-radius: 12px;
}
```

### Botões
```css
/* Primário — Ouro */
.btn-primary {
  background: var(--agr-ouro-500);
  color: var(--agr-verde-900);
  font-family: var(--font-heading);
  font-weight: 600;
  border: none;
  border-radius: 8px;
  padding: 12px 24px;
}

.btn-primary:hover {
  background: var(--agr-ouro-400);
}

/* Secundário — Outline ouro */
.btn-secondary {
  background: transparent;
  color: var(--agr-ouro-500);
  border: 1px solid var(--agr-ouro-600);
  border-radius: 8px;
  padding: 12px 24px;
}

/* Ghost — Sobre fundo escuro */
.btn-ghost {
  background: transparent;
  color: var(--agr-branco);
  border: 1px solid var(--agr-verde-600);
  border-radius: 8px;
  padding: 12px 24px;
}
```

### Regras de componentes
- **Border-radius:** 12px para cards/modais, 8px para botões/inputs, 50% para avatares
- **Bordas:** Sempre sutis — usar `--agr-glass-border` ou `--agr-ouro-600` com opacidade
- **Sombras:** Usar tokens `--agr-sombra-*`, nunca sombras com cor azul/preta pura
- **Transições:** `transition: all 0.2s ease` para hovers
- **Cantos:** Nunca usar cantos retos (border-radius: 0) em elementos interativos

---

## Ícones

### Regras
- **Estilo:** Linha fina (outline), nunca preenchido (filled)
- **Stroke:** 1.5px
- **Cor padrão:** `var(--agr-ouro-500)` ou `var(--agr-branco)`
- **Cor ativo/selecionado:** `var(--agr-ouro-400)`
- **Tamanho padrão:** 24px (desktop), 20px (mobile)
- **Tamanho em navegação:** 28px

### Biblioteca preferida
- Lucide Icons (consistente com stroke 1.5px)
- Feather Icons como alternativa

---

## Acessibilidade

- Contraste mínimo: 4.5:1 para texto, 3:1 para elementos grandes
- `--agr-branco` sobre `--agr-verde-900` = ratio ~12:1 (excelente)
- `--agr-ouro-500` sobre `--agr-verde-900` = ratio ~7:1 (bom)
- Sempre testar contraste ao combinar tokens
