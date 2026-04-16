# Prompt para Claude Extensão do Navegador — Migrar para Vercel

> Cole este prompt no Claude com o Vercel Dashboard aberto.

---

Preciso migrar o domínio agruai.com de GitHub Pages para Vercel. O repositório é github.com/natozar/FarmOS e o CNAME já foi removido do repo.

## PASSO 1: Conectar repositório ao Vercel

1. Vá em https://vercel.com/new
2. Importe o repositório **natozar/FarmOS** do GitHub
3. Na configuração do projeto:
   - **Framework Preset**: Other
   - **Root Directory**: `.` (raiz)
   - **Build Command**: deixe vazio (é site estático)
   - **Output Directory**: deixe vazio (`.`)
4. Clique **Deploy**

Se o projeto já existir no Vercel, pule para o passo 2.

## PASSO 2: Adicionar domínio customizado

1. Vá no projeto > **Settings** > **Domains**
2. Adicione: `agruai.com`
3. Adicione também: `www.agruai.com` (redireciona para agruai.com)
4. O Vercel vai mostrar os DNS records necessários

## PASSO 3: Configurar DNS

Onde quer que o DNS do agruai.com esteja configurado (provavelmente no registrador do domínio), preciso:

**Para `agruai.com` (apex/root domain):**
- Tipo: **A**
- Nome: `@`
- Valor: `76.76.21.21`

**Para `www.agruai.com`:**
- Tipo: **CNAME**
- Nome: `www`
- Valor: `cname.vercel-dns.com`

**Remover** os registros antigos do GitHub Pages:
- Remover A records para `185.199.108.153`, `185.199.109.153`, `185.199.110.153`, `185.199.111.153`

## PASSO 4: Desativar GitHub Pages

1. Vá em https://github.com/natozar/FarmOS/settings/pages
2. Em **Source**, selecione **None** (desabilita o GitHub Pages)
3. Confirme

## PASSO 5: Verificar

Após a propagação do DNS (pode levar até 48h, geralmente <10min):

1. Acesse https://agruai.com — deve mostrar a landing page
2. Acesse https://agruai.com/blog — deve mostrar a listagem de artigos
3. Acesse https://agruai.com/blog/cotacao-da-soja-recua-enquanto-safra-de-graos-pode-bater-recorde-2026-04-16 — deve mostrar o artigo com preview correto
4. Acesse https://agruai.com/sitemap.xml — deve mostrar o sitemap dinâmico
5. Compartilhe um link de artigo no WhatsApp — deve mostrar miniatura com foto e texto

## PASSO 6: Verificar SSL

O Vercel configura SSL automaticamente. Confirme que:
- https://agruai.com tem certificado válido
- http://agruai.com redireciona para https

## RESUMO

Quando terminar, me diga:
1. Projeto criado/conectado no Vercel?
2. Domínio adicionado?
3. DNS atualizado?
4. GitHub Pages desativado?
5. Site acessível via https://agruai.com?
6. /blog/:slug funcionando?
