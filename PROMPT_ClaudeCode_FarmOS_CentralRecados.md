# PROMPT — Central de Recados do Proprietário
# Colar integralmente no Claude Code e executar
# Pré-requisito: CLAUDE.md lido no início da sessão

---

## CONTEXTO

O FarmOS já tem o fluxo GESTOR → PROPRIETÁRIO funcionando:
check-ins de campo em 5 passos, eventos no feed "Ao Vivo",
notificações no sino. O que falta é o fluxo inverso:
**PROPRIETÁRIO → GESTOR(ES)**.

Este prompt implementa a **Central de Recados** — a ferramenta
que permite ao proprietário enviar ordens, solicitações e alertas
diretamente para os gestores de uma ou mais fazendas.

O protótipo é de demonstração: não há backend real.
Toda comunicação é simulada localmente com feedback visual.

---

## REGRA ZERO

Ler o CLAUDE.md antes de qualquer alteração.
Respeitar 100% a paleta, o dark mode, as regras de responsivo
e o padrão vanilla JS sem framework.

---

## O QUE CONSTRUIR

### 1. Botão Flutuante "Central de Recados"

**Posição:**
- Mobile: canto inferior direito, ACIMA do bottom-nav
  - `bottom: calc(80px + env(safe-area-inset-bottom) + 16px)`
  - `right: 16px`
  - `z-index: 250` (abaixo do gestor overlay 300)
- Desktop: canto inferior direito do main-content
  - `bottom: 24px; right: 24px`

**Visual:**
- Círculo 56px, background `var(--gold)` (#C9A84C)
- Ícone: `📨` (emoji) centralizado, font-size 24px
- Box-shadow: `0 4px 16px rgba(201,168,76,.4)`
- Hover: scale(1.08), shadow mais forte
- Active: scale(0.95)
- Pulse animation sutil a cada 8 segundos (chamar atenção no demo)

**Comportamento:**
- `onclick="abrirCentralRecados()"`
- NÃO exibir quando o Modo Gestor estiver ativo
  (verificar: `gestorOverlay.classList.contains('aberto')`)

**HTML — inserir ANTES do `</main>`:**
```html
<button class="fab-recados" id="fabRecados" onclick="abrirCentralRecados()" title="Enviar recado às fazendas">
  📨
</button>
```

---

### 2. Overlay da Central de Recados

**Estrutura:** overlay full-screen igual ao padrão do gestor overlay.

```html
<div class="recados-overlay" id="recadosOverlay">
  <div class="recados-container" id="recadosConteudo">
    <!-- Renderizado dinamicamente por JS -->
  </div>
</div>
```

**CSS do overlay:**
```css
.recados-overlay {
  position: fixed;
  inset: 0;
  background: var(--dark);
  z-index: 280;
  display: none;
  overflow-y: auto;
}
.recados-overlay.aberto {
  display: block;
  animation: fadeSlideIn .3s ease forwards;
}
.recados-container {
  max-width: 600px;
  margin: 0 auto;
  padding: 20px 20px 100px;
}
```

---

### 3. Passo 1 — Selecionar Fazendas

**Header do overlay:**
```
← Voltar                    Central de Recados
```
O botão "← Voltar" chama `fecharCentralRecados()`.

**Conteúdo:**

Título: **"Para quais fazendas?"**
Subtítulo (muted): "Selecione uma ou mais propriedades"

**Botão "Todas as Fazendas":**
- Full-width, border `var(--gold)`, fundo transparente
- Ao clicar: seleciona/deseleciona todas
- Quando ativo: fundo `rgba(201,168,76,.15)`, texto gold

**Grid de fazendas:** 1 coluna mobile, 2 colunas desktop
Cada card:
```
┌─────────────────────────────┐
│ [checkbox]  Fazenda Barreiro Grande    │
│             Matão/SP · 2.840 ha        │
│             👷 João Pedro              │
│             ● ok                       │
└─────────────────────────────┘
```

- Checkbox visual customizado (círculo 22px, borda `var(--border)`)
- Quando selecionado: preenchido com `var(--gold)`, ícone ✓
- Status dot: verde (ok), amber (alerta), vermelho (critico)
- Card: fundo `var(--surface)`, border `var(--border)`, radius 12px
- Card selecionado: border muda para `var(--gold)`

**Botão inferior fixo:**
```
[  Continuar (3 fazendas selecionadas)  ]
```
- Background `var(--gold)`, texto `var(--dark)`, font-weight 700
- Desabilitado (opacity 0.4) se nenhuma fazenda selecionada
- Sticky no bottom com padding safe-area

**Estado JS:**
```javascript
// Adicionar ao AppState ou criar objeto separado
let recadosState = {
  passo: 1,
  fazendasSelecionadas: [],  // array de IDs
  categoria: null,
  mensagem: '',
  prioridade: 'normal'       // 'normal' ou 'urgente'
};
```

---

### 4. Passo 2 — Tipo de Recado

**Header:** mesma estrutura, com breadcrumb ou indicador de passo

**Título:** "Que tipo de recado?"

**Grid de categorias:** 2 colunas, 3 linhas

```
┌──────────────────┐  ┌──────────────────┐
│  📋               │  │  🔧               │
│  Solicitar        │  │  Ordem de         │
│  Relatório        │  │  Serviço          │
│                   │  │                   │
│  Pedir informação │  │  Delegar tarefa   │
│  atualizada       │  │  ao gestor        │
└──────────────────┘  └──────────────────┘

┌──────────────────┐  ┌──────────────────┐
│  ⚠️               │  │  ✅               │
│  Alerta ao        │  │  Autorização      │
│  Campo            │  │                   │
│                   │  │  Aprovar compra   │
│  Aviso urgente    │  │  ou ação          │
│  para o gestor    │  │                   │
└──────────────────┘  └──────────────────┘

┌──────────────────┐  ┌──────────────────┐
│  📅               │  │  💬               │
│  Agendar          │  │  Recado           │
│  Visita           │  │  Livre            │
│                   │  │                   │
│  Informar ida ao  │  │  Mensagem aberta  │
│  campo            │  │  ao gestor        │
└──────────────────┘  └──────────────────┘
```

**Cada card:**
- Fundo `var(--surface)`, border `var(--border)`, radius 12px
- Emoji grande: font-size 28px
- Título: font-weight 700, `var(--text)`
- Descrição: font-size 0.82rem, `var(--muted)`
- Hover: border `var(--gold)`, background `rgba(201,168,76,.06)`
- Ao clicar: seleciona e avança automaticamente para passo 3

**Importante:** "Alerta ao Campo" deve ter um indicador visual
diferenciado (borda left amber 3px) para sugerir urgência.

---

### 5. Passo 3 — Compor Mensagem

**Header:** categoria selecionada como badge (ex: "🔧 Ordem de Serviço")

**Destinatários resumidos:**
```
Para: Faz. Barreiro Grande, Faz. Cerradão e +1 outra
```

**Template por categoria** (pré-preenchido no textarea):

| Categoria | Placeholder do textarea |
|-----------|------------------------|
| Solicitar Relatório | "Preciso do relatório atualizado de..." |
| Ordem de Serviço | "Executar a seguinte tarefa: ..." |
| Alerta ao Campo | "ATENÇÃO: ..." |
| Autorização | "Autorizo a seguinte ação/compra: ..." |
| Agendar Visita | "Visita programada para [data]: ..." |
| Recado Livre | "..." |

**Textarea:**
- Fundo `var(--surface)`, border `var(--border)`
- Min-height: 120px, resize vertical
- Font-size: 16px (regra iOS!)
- Border-radius: 12px
- Focus: border `var(--gold)`

**Toggle de Prioridade:**
```
Prioridade:  [ Normal ]  [ 🔴 Urgente ]
```
- Dois botões tipo segmented control
- Normal: fundo transparente, texto muted
- Urgente: fundo `rgba(232,64,64,.15)`, texto `var(--red)`, borda red
- Se categoria for "Alerta ao Campo": urgente pré-selecionado

**Botão de envio:**
```
[  📨 Enviar Recado  ]
```
- Background `var(--gold)`, texto `var(--dark)`
- Desabilitado se textarea vazio
- Sticky bottom com safe-area

---

### 6. Passo 4 — Confirmação Animada

Após clicar "Enviar Recado", exibir overlay de confirmação
(mesmo padrão visual do envio de check-in do gestor):

**Sequência de animação (2.5 segundos total):**

1. (0.0s) Overlay aparece, fundo escuro 97% opacidade
2. (0.3s) Ícone `📨` grande (60px) com scale animation
3. (0.6s) Texto: "Enviando recado..."
4. (1.0s) Barra de progresso animada (gold)
5. (1.8s) Ícone muda para `✅`, texto: "Recado enviado!"
6. (2.0s) Texto secundário: "3 gestores notificados"
7. (2.5s) Auto-fecha e volta ao app

**Após confirmação:**

A. Adicionar evento ao feed da Central (Ao Vivo):
```javascript
adicionarEventoCentral(
  'recado',                           // novo tipo
  fazendaNome,                         // ou "3 fazendas"
  'Proprietário',                      // quem mandou
  `${categoriaEmoji} ${categoriaNome}: ${mensagemTruncada}`,
  true                                 // é novo
);
```

B. Incrementar notificação no sino

C. Mostrar toast: "Recado enviado para X fazenda(s)"

D. Fechar overlay e navegar para a tela "Ao Vivo"
   para que o demo mostre o recado aparecendo no feed

---

### 7. Novo tipo de evento no Feed "Ao Vivo"

Adicionar ao sistema de eventos o tipo `recado`:

**CSS:**
```css
.evento-tipo.recado {
  color: var(--gold);
}
```

**Ícone do evento:** `📨`
**Dot color:** `var(--gold)`

**Template no feed:**
```
📨  Recado do Proprietário          · agora
    🔧 Ordem de Serviço
    Faz. Barreiro Grande · Para: João Pedro
    "Executar vacinação do lote 3 até sexta-feira"
```

---

### 8. Ajuste no Botão Gestor do Header

O botão "👷 Modo Gestor" no top-bar JÁ EXISTE e JÁ FUNCIONA.
**Não alterar o comportamento.** Apenas garantir que:

1. Ele continua visível e acessível no header em todas as telas
2. O texto alterna entre "👷 Modo Gestor" e "👔 Voltar ao Painel"
3. O badge alterna entre "👔 Proprietário" e "👷 Gestor de Campo"

Se o botão estiver sumindo em alguma tela ou breakpoint,
corrigir o CSS para mantê-lo sempre visível no top-bar.

---

### 9. Interação entre os dois modos no Demo

Para a demonstração funcionar bem:

- Quando o Modo Gestor está ABERTO: esconder `#fabRecados`
- Quando a Central de Recados está ABERTA: esconder `#fabRecados`
- O botão Gestor no header continua acessível mesmo com a Central aberta
  (permite demonstrar: "enquanto o dono manda recado, o gestor checa in")

---

### 10. CSS Responsivo

**Mobile (< 768px):**
- Grid de fazendas: 1 coluna
- Grid de categorias: 1 coluna (cards maiores, mais touch-friendly)
- FAB recados: acima do bottom-nav
- Botão "Continuar" e "Enviar": full-width sticky bottom
- Textarea: min-height 100px

**Tablet (768px – 1024px):**
- Grid de fazendas: 2 colunas
- Grid de categorias: 2 colunas

**Desktop (> 1024px):**
- Grid de fazendas: 2 colunas
- Grid de categorias: 3 colunas (2x3 fica mais elegante)
- FAB recados: posição fixed no canto do main-content
  (respeitar margem da sidebar 240px)

---

### 11. Dados simulados para o demo

Ao carregar a página, incluir 2 recados pré-existentes
no feed da Central para que o demo já mostre histórico:

```javascript
// Inserir em carregarEventosIniciais() ou equivalente
adicionarEventoCentral('recado', 'Faz. Carneirinho',
  'Proprietário',
  '📋 Solicitar Relatório: Preciso do status da vacinação até amanhã',
  false);

adicionarEventoCentral('recado', 'Todas as fazendas',
  'Proprietário',
  '⚠️ Alerta ao Campo: Previsão de geada para sábado — proteger bezerros',
  false);
```

---

## CHECKLIST DE VALIDAÇÃO

Após implementar, verificar:

- [ ] FAB `📨` aparece em todas as telas do proprietário
- [ ] FAB desaparece quando Modo Gestor ou Central está aberta
- [ ] Passo 1: seleção múltipla funciona, "Todas" funciona
- [ ] Passo 2: clique na categoria avança para passo 3
- [ ] Passo 3: textarea tem placeholder por categoria
- [ ] Passo 3: "Alerta ao Campo" pré-seleciona prioridade urgente
- [ ] Passo 4: animação completa roda sem travar
- [ ] Recado aparece no feed "Ao Vivo" após envio
- [ ] Notificação incrementada no sino
- [ ] Botão Gestor no header continua funcionando em todas as telas
- [ ] Mobile: nenhum overflow-x, FAB acima do bottom-nav
- [ ] Desktop: FAB respeita sidebar, overlay centralizado
- [ ] Console limpo: zero erros, zero warnings
- [ ] Font-size do textarea ≥ 16px (iOS)
- [ ] Touch-action: manipulation no FAB e botões

---

## ORDEM DE IMPLEMENTAÇÃO SUGERIDA

1. CSS: FAB + overlay + cards + responsivo
2. HTML: FAB button + overlay container (inserir no index.html)
3. JS: Estado (recadosState) + funções de navegação entre passos
4. JS: renderizarRecadosPasso1() — grid de fazendas
5. JS: renderizarRecadosPasso2() — grid de categorias
6. JS: renderizarRecadosPasso3() — compositor de mensagem
7. JS: enviarRecadoAnimado() — animação de confirmação
8. JS: integração com adicionarEventoCentral()
9. Teste mobile: verificar FAB, overflow, safe-areas
10. Teste desktop: verificar sidebar, posicionamento

---

## NÃO FAZER

- NÃO criar arquivos separados — tudo no index.html existente
- NÃO usar framework ou lib externa nova
- NÃO implementar backend real (é protótipo)
- NÃO criar histórico de mensagens ou inbox (overengineering)
- NÃO alterar o fluxo do Modo Gestor que já funciona
- NÃO usar light mode em nenhum elemento
- NÃO usar font-size menor que 16px em inputs/textareas

---

*Prompt gerado em Abril 2026*
*Atualizar CLAUDE.md após implementação com a seção "Central de Recados"*
