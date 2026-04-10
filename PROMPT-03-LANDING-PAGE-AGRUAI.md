# PROMPT 03 — Landing Page AgrUAI (Captura de Leads — Agrishow 2026)

Cole este prompt no Claude Code DEPOIS de executar os Prompts 01 e 02:

---

```
## Landing Page — AgrUAI — Programa de Acesso Antecipado

Crie o arquivo `landing.html` — uma landing page SINGLE-FILE (HTML + CSS + JS inline) para capturar leads na Agrishow 2026 (Ribeirão Preto, final de abril).

### CONTEXTO ESTRATÉGICO

- O QR code dos cartões de visita aponta para agruai.com — esta é a página que o visitante verá
- O público são pecuaristas e agricultores donos de MÚLTIPLAS fazendas no eixo MG/SP/MS/MT/GO
- São homens ricos, práticos, desconfiados de tecnologia brega. Respeitam solidez, não firula.
- A LP NÃO deve linkar para nenhum protótipo, app ou demo. Nada. Zero. A plataforma ainda não está disponível ao público.
- O objetivo ÚNICO é capturar dados de interesse para o Programa de Acesso Antecipado (20 vagas)
- Formulário envia para https://formsubmit.co/chatsagrado@gmail.com (serviço gratuito, sem backend)

### ESTRUTURA DA PÁGINA (single scroll, sem menu)

#### SEÇÃO 1 — HERO (100vh)

Fundo: gradiente verde escuro `#0F1F0F` → `#1A2E1A`, com textura sutil de topografia/terreno em SVG (opacidade 3-5%, cor ouro).

Centralizado vertical:
- Logo AgrUAI: "Agr" em `#F5F0E8` + "UAI" em `#C5A572`, Space Grotesk 700, tamanho responsivo (clamp(2.5rem, 5vw, 4rem))
- Abaixo da logo (margin-top: 1.5rem):
  - Tagline principal em H1: **"Você não administra fazendas. Administra um império."**
    - Font: Space Grotesk 600, `#F5F0E8`, clamp(1.2rem, 3vw, 2rem)
    - Sem aspas, sem itálico
- Abaixo do H1 (margin-top: 1rem):
  - Subtítulo em p: **"Inteligência por satélite para quem pensa em escala."**
    - Font: Inter 400, `#A89E90` (cinza quente), clamp(0.9rem, 1.5vw, 1.1rem)
- Abaixo (margin-top: 2.5rem):
  - Botão CTA: **"Quero acesso antecipado"**
    - Fundo `#C5A572`, texto `#0F1F0F`, font-weight 600, border-radius 8px
    - Padding: 16px 40px, font-size: 1rem
    - Hover: fundo `#B8945A`, transform scale(1.02), transition 0.2s ease
    - Scroll suave até a seção do formulário (anchor #reserva)
- Indicador de scroll no bottom: chevron sutil em ouro, animação bounce discreta (2s infinite)

#### SEÇÃO 2 — O PROBLEMA (padding: 80px 0)

Fundo: `#0F1F0F`

Título de seção: **"O dono de 5 fazendas não tem tempo para 5 planilhas."**
- Space Grotesk 600, `#F5F0E8`, max-width 700px, centralizado

Parágrafo abaixo (max-width 600px, centralizado):
**"Quem administra múltiplas propriedades precisa de visão de conjunto — não de dados espalhados em WhatsApp, cadernos e promessas de gestor. A decisão certa depende da informação certa, na hora certa, vista de cima."**
- Inter 400, `#D1C9BC`, line-height 1.8, font-size 1rem

Separador: linha horizontal, gradiente `transparent → rgba(197,165,114,0.2) → transparent`, margin 60px auto, max-width 200px

#### SEÇÃO 3 — O QUE É O AGRUAI (padding: 80px 0)

Fundo: `#1A2E1A` (contraste sutil)

Título: **"Seus olhos no céu. Suas decisões no chão."**
- Space Grotesk 600, `#F5F0E8`

3 blocos lado a lado (em mobile empilham), max-width 900px, gap 40px:

**Bloco 1 — SAP**
- Ícone: círculo com ponto orbital em SVG (azul água `#4A90A4`, stroke 1.5px)
- Título: "Monitoramento por Satélite"
- Texto: "Imagens reais das suas propriedades, atualizadas a cada 5 dias. Veja a saúde da pastagem, a evolução da cultura e áreas de risco sem sair do escritório."
- Cor do título: `#C5A572`, texto: `#D1C9BC`

**Bloco 2 — Multi-fazenda**
- Ícone: grid 2x2 com terrenos em SVG (ouro `#C5A572`, stroke 1.5px)
- Título: "Todas as fazendas. Uma tela."
- Texto: "Dashboard unificado para proprietários que pensam como gestores de portfólio. Compare propriedades, identifique problemas antes que virem prejuízo."
- Mesmas cores

**Bloco 3 — Inteligência**
- Ícone: lupa sobre gráfico em SVG (ouro, stroke 1.5px)
- Título: "I.A. que fala a língua do campo"
- Texto: "Alertas automáticos, análises preditivas e relatórios que traduzem dados de satélite em ação: 'mover gado', 'irrigar lote 3', 'investigar área norte'."
- Mesmas cores

Estilo dos blocos:
- Fundo: `rgba(15, 31, 15, 0.5)` com borda `rgba(197,165,114,0.1)`
- Border-radius: 12px, padding: 32px
- Ícone: 48x48, margin-bottom 16px
- Título bloco: Space Grotesk 600, 1.1rem
- Texto bloco: Inter 400, 0.95rem, line-height 1.7

#### SEÇÃO 4 — PROVA SOCIAL / CREDIBILIDADE (padding: 60px 0)

Fundo: `#0F1F0F`

**NÃO use depoimentos falsos.** Em vez disso, use dados concretos:

3 cards numéricos em linha (mobile empilha):

- **"Sentinel-2"** — subtexto: "Satélite da Agência Espacial Europeia. Dados abertos, resolução 10m." — cor número: `#4A90A4`
- **"5 dias"** — subtexto: "Frequência de revisita. Sua fazenda monitorada duas vezes por semana." — cor número: `#C5A572`
- **"20 vagas"** — subtexto: "Programa de Acesso Antecipado. Parceiros que ajudam a construir a ferramenta." — cor número: `#F5F0E8`

Estilo dos cards:
- Número grande: Space Grotesk 700, clamp(2rem, 4vw, 3rem)
- Subtexto: Inter 400, 0.85rem, `#A89E90`, max-width 220px
- Alinhamento: centralizado em cada card
- Fundo: transparente, sem borda (minimalismo)

#### SEÇÃO 5 — FORMULÁRIO DE RESERVA (padding: 80px 0)

id="reserva"
Fundo: `#1A2E1A`

Título: **"Programa de Acesso Antecipado"**
- Space Grotesk 600, `#F5F0E8`, centralizado

Subtítulo: **"20 proprietários vão ajudar a construir a plataforma definitiva de inteligência rural. Sem custo na fase pioneira."**
- Inter 400, `#D1C9BC`, max-width 550px, centralizado, margin-bottom 40px

Formulário centralizado (max-width 480px):

```html
<form action="https://formsubmit.co/chatsagrado@gmail.com" method="POST">
  <!-- FormSubmit configs -->
  <input type="hidden" name="_subject" value="🛰️ AgrUAI — Novo interesse Agrishow">
  <input type="hidden" name="_captcha" value="true">
  <input type="hidden" name="_template" value="table">
  <input type="hidden" name="_next" value="https://agruai.com/landing.html#obrigado">
  <input type="text" name="_honey" style="display:none">

  <!-- Campos visíveis -->
  <label>Nome completo</label>
  <input type="text" name="nome" required placeholder="Como prefere ser chamado">

  <label>WhatsApp ou telefone</label>
  <input type="tel" name="contato" required placeholder="(00) 00000-0000">

  <label>E-mail</label>
  <input type="email" name="email" placeholder="Opcional, mas recomendado">

  <label>Quantas propriedades rurais possui?</label>
  <select name="propriedades" required>
    <option value="" disabled selected>Selecione</option>
    <option value="2-3">2 a 3 propriedades</option>
    <option value="4-6">4 a 6 propriedades</option>
    <option value="7-10">7 a 10 propriedades</option>
    <option value="10+">Mais de 10 propriedades</option>
  </select>

  <label>Região principal das propriedades</label>
  <select name="regiao" required>
    <option value="" disabled selected>Selecione o estado</option>
    <option value="SP">São Paulo</option>
    <option value="MG">Minas Gerais</option>
    <option value="MS">Mato Grosso do Sul</option>
    <option value="MT">Mato Grosso</option>
    <option value="GO">Goiás</option>
    <option value="PR">Paraná</option>
    <option value="BA">Bahia</option>
    <option value="TO">Tocantins</option>
    <option value="outro">Outro estado</option>
  </select>

  <label>Atividade principal</label>
  <select name="atividade" required>
    <option value="" disabled selected>Selecione</option>
    <option value="pecuaria">Pecuária de corte</option>
    <option value="pecuaria-leite">Pecuária de leite</option>
    <option value="soja-milho">Soja / Milho</option>
    <option value="cana">Cana-de-açúcar</option>
    <option value="cafe">Café</option>
    <option value="misto">Misto (pecuária + lavoura)</option>
    <option value="outro">Outro</option>
  </select>

  <label>Área total aproximada (hectares)</label>
  <select name="area_total">
    <option value="" disabled selected>Selecione</option>
    <option value="500-2000">500 a 2.000 ha</option>
    <option value="2000-5000">2.000 a 5.000 ha</option>
    <option value="5000-10000">5.000 a 10.000 ha</option>
    <option value="10000+">Mais de 10.000 ha</option>
  </select>

  <label>Qual seu maior desafio hoje?</label>
  <textarea name="desafio" rows="3" placeholder="Ex: Não consigo acompanhar todas as fazendas à distância..."></textarea>

  <button type="submit">Garantir minha vaga</button>
</form>
```

Estilo dos campos:
- Background: `#0F1F0F`
- Borda: 1px solid `#2E4A2E` (--agr-verde-600)
- Foco: borda `#C5A572` com box-shadow `0 0 0 3px rgba(197,165,114,0.15)`
- Border-radius: 8px
- Padding: 14px 16px
- Font: Inter 400, `#F5F0E8`, 0.95rem
- Placeholder: `#7A7268`
- Labels: `#D1C9BC`, Inter 500, 0.8rem, text-transform uppercase, letter-spacing 0.5px, margin-bottom 6px
- Gap entre campos: 20px
- Textarea: mesma estilo, resize vertical only

Botão submit:
- Fundo: `#C5A572`, texto `#0F1F0F`, font-weight 700
- Largura 100%, padding 16px
- Border-radius: 8px
- Hover: `#B8945A`, cursor pointer
- Active: transform scale(0.98)
- Transição: 0.2s ease
- Texto: uppercase, letter-spacing 1px

Micro-copy abaixo do botão:
- "Seus dados são confidenciais. Entraremos em contato apenas para o programa."
- Inter 400, `#7A7268`, 0.75rem, text-align center, margin-top 12px

#### SEÇÃO 6 — CONFIRMAÇÃO (estado pós-envio)

id="obrigado" — mostrado via CSS quando URL contém #obrigado:

```css
#obrigado { display: none; }
#obrigado:target { display: flex; }
/* OU via JS: */
/* if (window.location.hash === '#obrigado') document.getElementById('obrigado').style.display = 'flex'; */
```

Usar JS para detectar `#obrigado` na URL e:
1. Esconder o formulário
2. Mostrar mensagem de confirmação:
   - Ícone: check circular em ouro, animação de draw-in (SVG stroke-dashoffset)
   - Título: **"Reserva registrada."** — Space Grotesk 600, `#C5A572`
   - Texto: **"Você está entre os primeiros. Entraremos em contato antes do lançamento."** — Inter 400, `#D1C9BC`
   - Botão secundário: **"Voltar ao início"** — borda ouro, scroll to top

#### SEÇÃO 7 — FOOTER (padding: 40px 0)

Fundo: `#0F1F0F`
- Logo AgrUAI pequena (font-size 1.2rem)
- Texto: "Ribeirão Preto, SP — Agrishow 2026" — `#7A7268`, 0.8rem
- Linha abaixo: "Inteligência Rural por Satélite" — `#A89E90`, 0.75rem
- Nenhum link de rede social (não temos ainda)
- Nenhum link para app/protótipo

### REGRAS TÉCNICAS

1. **SINGLE FILE** — todo HTML, CSS e JS no mesmo arquivo `landing.html`
2. **ZERO DEPENDÊNCIA EXTERNA** exceto:
   - Google Fonts: Space Grotesk (500, 600, 700) + Inter (300, 400, 500)
   - FormSubmit.co para envio do formulário
3. **RESPONSIVO** — mobile-first. Breakpoints:
   - Mobile: < 640px (tudo empilhado, padding lateral 24px)
   - Tablet: 640-1024px
   - Desktop: > 1024px (max-width 1100px centralizado)
4. **PERFORMANCE** — deve carregar em < 2s no 3G
   - Sem imagens bitmap, tudo SVG inline ou CSS
   - Font-display: swap
   - Minificar o que for possível sem perder legibilidade do código
5. **ACESSIBILIDADE** —
   - Labels associados a inputs (for/id)
   - Contraste mínimo WCAG AA
   - Focus-visible nos campos
   - Meta description e og:tags
6. **META TAGS** — no <head>:
   ```html
   <meta name="description" content="AgrUAI — Inteligência rural por satélite para proprietários de múltiplas fazendas. Programa de Acesso Antecipado.">
   <meta property="og:title" content="AgrUAI — Você não administra fazendas. Administra um império.">
   <meta property="og:description" content="Monitoramento por satélite com I.A. para quem pensa em escala. 20 vagas no Programa de Acesso Antecipado.">
   <meta property="og:type" content="website">
   <meta property="og:url" content="https://agruai.com">
   <meta property="og:image" content="https://agruai.com/og-image.png">
   <meta name="theme-color" content="#0F1F0F">
   ```
7. **FAVICON** — usar o favicon.svg gerado no Prompt 02 (referenciar com `<link rel="icon" type="image/svg+xml" href="favicon.svg">`)
8. **SMOOTH SCROLL** — `html { scroll-behavior: smooth; }`
9. **SEM ANIMAÇÕES PESADAS** — apenas:
   - Fade-in suave das seções ao scroll (IntersectionObserver, opacity 0→1, translateY 20px→0, 0.6s ease)
   - Chevron bounce no hero
   - Check draw-in na confirmação
   - Hover nos botões/campos
10. **ANTI-SPAM** — honeypot field `_honey` já incluído no form (display:none)

### O QUE NÃO INCLUIR

- ❌ Nenhum link para o protótipo/app/demo
- ❌ Nenhum screenshot da plataforma
- ❌ Nenhum depoimento falso ou inventado
- ❌ Nenhum preço, plano ou modelo de assinatura
- ❌ Nenhuma promessa de data de lançamento
- ❌ Nenhum link de rede social
- ❌ Nenhum chatbot ou widget de terceiros
- ❌ Nenhuma menção a "beta" (a palavra tem conotação negativa para este público)
- ❌ Nada de "em breve" genérico — o tom é exclusividade, não espera

### TOM DA COMUNICAÇÃO

- Direto, sem floreio. Este público não lê parágrafos longos.
- Premium sem ser arrogante. Confiança sem ser promessa.
- "Programa de Acesso Antecipado" soa melhor que "lista de espera" ou "pré-cadastro"
- "Parceiros pioneiros" soa melhor que "beta testers" ou "early adopters"
- O pecuarista precisa sentir que está SENDO SELECIONADO, não que está pedindo algo
- Escassez real: 20 vagas. Não é truque — é a capacidade real de atendimento inicial.

### PALETA (referência rápida, coerente com cartão e app)

| Token           | Hex       | Uso                              |
|-----------------|-----------|----------------------------------|
| verde-900       | #0F1F0F   | Fundo principal                  |
| verde-800       | #1A2E1A   | Fundo seções alternadas          |
| verde-600       | #2E4A2E   | Bordas de input                  |
| ouro-500        | #C5A572   | CTAs, títulos de bloco, acentos  |
| ouro-600        | #B8945A   | Hover em ouro                    |
| azul-500        | #4A90A4   | Dados satélite, ícone SAP        |
| branco          | #F5F0E8   | Texto principal                  |
| cinza-300       | #D1C9BC   | Texto corpo/secundário           |
| cinza-400       | #A89E90   | Subtítulos leves                 |
| cinza-500       | #7A7268   | Placeholders, micro-copy         |

### TESTE FINAL

Depois de criar o arquivo:
1. Abra `landing.html` no navegador e verifique:
   - Scroll suave do CTA até #reserva funciona
   - Formulário envia (primeiro envio no FormSubmit requer confirmação de email)
   - Layout responsivo em 375px, 768px e 1440px
   - Fade-in das seções funciona
   - Estado #obrigado aparece corretamente
2. Valide o HTML com `npx html-validate landing.html` ou manualmente
3. Confirme que NENHUM link aponta para index.html, demo, app, ou qualquer outra página
4. Confirme que o peso total do arquivo é < 50KB

Execute e me mostre o resultado.
```

---
