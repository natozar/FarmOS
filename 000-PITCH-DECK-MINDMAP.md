---
status: Ativo
data: 2026-04-12
tags: [estrategia, pitch, investidores, vendas, gtm]
---

# A Bíblia Fundamental do AgrUAI

> Documento central de estratégia para investidores, novos colaboradores e alinhamento de vendas.
> Classificação: Confidencial — Uso Interno e Apresentações Controladas.

---

## I. O INIMIGO MAPEADO

### 1.1 O Caos do WhatsApp

O agronegócio brasileiro movimenta R$ 2,6 trilhões por ano. A gestão operacional de 80% das fazendas com mais de 1.000 hectares depende de grupos de WhatsApp.

O fazendeiro com 3 propriedades em estados diferentes acorda e abre 7 grupos. Áudios de 3 minutos do tratorista. Foto desfocada de uma cerca caída. Texto do veterinário sem contexto. Nenhuma dessas informações está georreferenciada, nenhuma tem timestamp confiável, nenhuma cruza com dados de satélite.

**O resultado:** decisões de milhões tomadas no achismo. O fazendeiro paga 2 a 3 funcionários apenas para ler mensagens e transformar em planilhas. O gestor de campo omite informações porque sabe que ninguém vai verificar. O peão não registra nada porque não sabe digitar.

### 1.2 A Gestão por Intuição (Sem Satélite)

O produtor brasileiro médio descobre que perdeu uma safra quando a colheitadeira entra no talhão e o rendimento vem 40% abaixo. A degradação do pasto é percebida quando o gado começa a emagrecer. O estresse hídrico é notado quando o pivô já parou há 3 dias.

Todos esses sinais são visíveis do espaço — 5 dias antes — via índice NDVI do Sentinel-2 (Agência Espacial Europeia, gratuito). Ninguém traduz isso para o fazendeiro porque as ferramentas existentes exigem formação técnica em sensoriamento remoto.

### 1.3 A Miopia do Campo Offline

O Brasil tem 8,5 milhões de km². A cobertura 4G atinge menos de 30% da área rural. O peão no meio do pasto não tem internet. Se o sistema depende de conexão para funcionar, ele é inútil onde mais importa.

O tratorista que encontra a bomba d'água quebrada às 14h de uma terça-feira no retiro a 80km da sede não vai esperar chegar no Wi-Fi para registrar. Ele manda um áudio no WhatsApp pessoal e a informação se perde na entropia dos grupos.

---

## II. O ARSENAL TECNOLÓGICO (A Barreira B2B)

### 2.1 Stack de Custo Zero Operacional

| Componente | Tecnologia | Custo Mensal |
|---|---|---|
| Frontend | HTML/CSS/JS vanilla (PWA) | R$ 0 |
| Backend | Supabase Pro (PostgreSQL + PostGIS) | R$ 175 |
| Hosting | Vercel (Edge Network Global) | R$ 0 |
| Satélite | Sentinel-2 / Copernicus (ESA) | R$ 0 |
| Câmbio | AwesomeAPI (USD/BRL ao vivo) | R$ 0 |
| Mapas | Mapbox GL (50k loads/mês free) | R$ 0 |
| Voice-to-Text | Web Speech API (nativa do device) | R$ 0 |
| PDF Reports | jsPDF (client-side) | R$ 0 |
| QR Scanner | html5-qrcode (client-side) | R$ 0 |
| Push | Notification API (nativa) | R$ 0 |
| **Total operacional** | | **~R$ 175/mês** |

**Margem de contribuição por cliente:** se cada fazendeiro paga R$ 500/mês (conservador para multi-propriedade), o custo marginal por usuário é próximo de zero. A infraestrutura escala para 100 clientes no mesmo Supabase Pro sem upgrade.

### 2.2 As 10 Barreiras Técnicas Anti-Cópia

1. **Offline-First com IndexedDB** — Diário de campo funciona sem internet. Logs sincronizam ao reconectar. Competidores que tentarem copiar vão gastar meses depurando bugs de cache no Safari.

2. **Voice-to-Text Nativo** — Web Speech API converte sotaque caipira em texto sem API paga. O peão fala em vez de digitar. Zero custo por minuto de áudio.

3. **GPS Blindado em Cada Log** — Cada ocorrência registra latitude/longitude de alta precisão via `navigator.geolocation`. Insumos escaneados por QR carimbam onde fisicamente a tampa foi aberta.

4. **Compressão de Imagem Client-Side** — Fotos de 48MP são redimensionadas para 800px via Canvas antes de tocar o IndexedDB. Previne crash em dispositivos com pouca memória.

5. **Bloomberg Ticker Agrícola** — Cotação USD/BRL ao vivo da AwesomeAPI com cache em localStorage para offline. Risco financeiro calculado com preço do dólar daquele segundo.

6. **Motor de Pseudo-IA por Keywords** — 6 regras de NLP local detectam emergências (fogo, gado doente, cerca quebrada) e sugerem 3 ações prescritivas. Zero API, zero latência.

7. **Créditos de Carbono Calculados** — Área verde (NDVI ≥ 0.6) × 4 tCO2/ha × US$ 15/ton = valor oculto que o fazendeiro nunca soube que tinha. Isca para upgrade Premium.

8. **Timelapse NDVI no Mapa** — Slider de 12 meses muda cor dos polígonos em 60fps via `setPaintProperty` do Mapbox. Impacto visual devastador em apresentações.

9. **Heatmap de Frota** — Background tracking a cada 10 min gera mapa de calor mostrando onde os funcionários transitaram. Prova de presença sem câmera.

10. **Laudo ESG em PDF** — jsPDF gera documento A4 com gráfico NDVI, métricas, conformidade ambiental. O fazendeiro imprime e leva ao banco. Funciona offline.

### 2.3 Arquitetura de Dados

```
Peão no campo (offline)
    ↓ Voz / Foto / QR
IndexedDB (device local)
    ↓ Wi-Fi na sede
Supabase (PostgreSQL + PostGIS)
    ↓ pg_cron (diário + semanal)
Edge Functions (Sentinel-2 NDVI)
    ↓ Classificação automática
Painel do Fazendeiro (PWA)
    ↓ Risco R$ × Câmbio ao vivo
Alerta Push + PDF + Relatório Semanal
```

---

## III. O ESCUDO JURÍDICO INQUEBRÁVEL

### 3.1 BYOD Trabalhista (O Checkbox Nuclear)

O AgrUAI rastreia GPS dos dispositivos dos funcionários. Isso é um campo minado trabalhista se feito errado.

**Nossa blindagem:** antes de cadastrar, o fazendeiro OBRIGATORIAMENTE marca o checkbox EULA declarando sob as penas da lei que possui concordância trabalhista explícita dos colaboradores para rastreio GPS.

Traduzido: se o peão processar a fazenda por rastreamento indevido, a responsabilidade é do empregador que assinou o termo — não do AgrUAI. Nós somos ferramenta, não empregador.

### 3.2 Disclaimers Cirúrgicos

| Local | Texto | Proteção |
|---|---|---|
| Sugestões da IA | "Não substitui laudo Zootécnico/Agronômico/Veterinário (Lei 5.194/66)" | CREA/CRMV |
| Bloomberg Ticker | "Projeção matemática referencial. Não constitui recomendação financeira" | CVM |
| Créditos de Carbono | Mesmo disclaimer CVM | Regulação de ativos |
| Laudo ESG (PDF) | "Não substitui laudo técnico assinado por profissional habilitado" | CREA/CRBio |
| LGPD (Form) | "Coordenadas criptografadas sob sigilo LGPD e jamais compartilhadas" | ANPD |

### 3.3 O Dossiê Bancário (Plano Safra)

O fazendeiro precisa de documentação para acessar crédito rural (Plano Safra, BNDES, CPR). Os bancos exigem comprovação de atividade produtiva e conformidade ambiental.

**O AgrUAI gera automaticamente um laudo ESG** cruzando:
- Histórico NDVI de 12 meses (prova de produtividade)
- Coordenadas PostGIS do polígono (prova de georreferenciamento)
- Código CAR da propriedade (conformidade ambiental)
- Classificação de vegetação (prova de não-desmatamento)

O banco recebe um PDF de uma página com gráfico e atestado. O fazendeiro não pagou consultor. Nós não assinamos o laudo (isenção técnica). Todos ganham.

---

## IV. O CAVALO DE TROIA (Tração GTM)

### 4.1 A Isca: Açougues de Elite do Interior

O funil de vendas do AgrUAI não começa no LinkedIn ou em conferências de agritech. Começa nos açougues premium, cooperativas e eventos de leilão das cidades-polo do agronegócio (Ribeirão Preto, Uberaba, Sorriso, Luís Eduardo Magalhães, Sinop).

O CEO vai fisicamente a esses locais. No balcão, na fila do caixa, na mesa do restaurante. A conversa começa: "O senhor tem fazenda? Quantas propriedades? Usa WhatsApp pra gestão?"

A resposta é sempre sim. A dor é universal.

### 4.2 As 10 Chaves Alpha

O programa piloto tem exatamente 10 vagas. Não é escassez artificial — é capacidade real de suporte manual no MVP. Cada vaga é uma "Chave Alpha" entregue pessoalmente com o script:

> "Senhor, liberei seu acesso. O senhor é um dos 10 produtores selecionados. Sem custo nenhum."

O fazendeiro entra. Cadastra a fazenda em 2 minutos. Em 5 dias o satélite faz a primeira leitura. O sistema começa a gerar valor sozinho.

### 4.3 O Ciclo de Conversão (15 dias)

| Dia | Ação | Canal |
|---|---|---|
| D+0 | Encontro presencial + Chave Alpha | Balcão |
| D+0 (1h) | Script 1: URL + instruções de cadastro | WhatsApp |
| D+2 | Script 2: indução de voz + IA prescritiva | WhatsApp |
| D+5 | Primeira leitura de satélite aparece no painel | Automático |
| D+7 | Relatório semanal automático (sexta 15h) | Email + Link |
| D+15 | Script 3: fechamento B2B + agendamento Zoom | WhatsApp |
| D+16 | Zoom de proposta com dados reais da fazenda dele | Zoom |

### 4.4 A Retenção Vitalícia

Uma vez que o fazendeiro tem 3 meses de dados NDVI, 50 logs de campo, fotos georreferenciadas e um laudo ESG gerado — ele não sai. O custo de troca é psicológico antes de financeiro.

O Laudo ESG é a âncora final: mesmo que ele cancele a assinatura, o documento que ele levou ao banco foi gerado pela plataforma. Quando o banco pedir atualização, ele precisa voltar.

### 4.5 O Mapa de Expansão

```
Fase 1 (Atual): 10 fazendeiros Alpha em MT/GO/SP
Fase 2 (Q3 2026): 50 clientes via indicação + cooperativas
Fase 3 (Q4 2026): Landing em EN/ES para LATAM (Paraguai, Argentina, Uruguai)
Fase 4 (2027): Integração com ERP agrícola (Aegro, Agrimanager)
Fase 5 (2027+): Modelo SaaS white-label para cooperativas
```

---

## MÉTRICAS DE NORTE VERDADEIRO

| Métrica | Target MVP | Target 12 meses |
|---|---|---|
| Fazendeiros ativos | 10 | 100 |
| Propriedades monitoradas | 30 | 500 |
| Hectares sob vigilância | 50.000 | 2.000.000 |
| MRR (Monthly Recurring Revenue) | R$ 0 (piloto) | R$ 50.000 |
| Churn mensal | 0% (grátis) | < 5% |
| CAC (Custo de Aquisição) | R$ 0 (presencial) | < R$ 200 |
| LTV estimado (24 meses) | — | R$ 12.000/cliente |

---

## ASSINATURA

Este documento representa a tese estratégica consolidada do AgrUAI na data de sua geração. Todas as métricas financeiras são projeções baseadas em modelos internos e não constituem garantia de resultados.

**AgrUAI — Inteligência Rural por Satélite**
agruai.com | Confidencial
