---
tags: [qa, testing, pwa]
---
# QA Script Final — Teste Manual do AgrUAI PWA

## Passo 1: Instalação e Login (2 min)

1. Abra `agruai.com/painel.html` no Chrome (Android) ou Safari (iOS)
2. Faça login: `fazendeiro.teste@agruai.com` / `AgrUAI2026!`
3. Deve aparecer o popup de "Instalar AgrUAI"
   - **Android**: clique "Instalar agora" — o app deve aparecer na home
   - **iOS**: siga os 3 passos do Safari (Compartilhar > Tela Início > Adicionar)
4. Abra o app pela home screen — deve abrir em tela cheia (sem barra do browser)
5. **PASS se**: login funciona, app instala, abre standalone

## Passo 2: Navegação e Dados (2 min)

1. Na tela de Propriedades, verifique se os cards carregam com NDVI e badges
2. Toque em uma propriedade — deve abrir o Detalhe com abas: Satélite | Diário | Insumos | Equipe
3. Na aba Satélite: métricas, gráfico NDVI e alertas devem renderizar
4. Na aba Insumos: lista de estoque ou mensagem de "nenhum insumo"
5. Clique no botão "Emitir Laudo do Banco (ESG)" — um PDF deve baixar
6. Abra o Mapa (bottom nav) — polígonos devem aparecer sobre o satélite
7. **PASS se**: todas as abas carregam, PDF baixa, mapa renderiza

## Passo 3: Diário de Campo + Voz (2 min)

1. Vá na aba Diário de uma propriedade
2. Selecione um setor (ex: Agronomia)
3. Digite "Teste QA" e clique Enviar — deve aparecer na timeline
4. Se o aparelho for **Android/Chrome**: clique no 🎙️ microfone
   - Autorize o microfone quando o browser pedir
   - Fale "teste de voz" — o texto deve aparecer ao vivo no textarea
   - Clique Enviar
5. Se for **iOS/Safari**: o botão de mic **NÃO deve aparecer** (correto, API não suportada)
6. **PASS se**: texto salva, voz funciona (Android), mic não aparece (iOS)

## Passo 4: Modo Offline (3 min)

1. Ative o **Modo Avião** no celular
2. A barra vermelha "Sem conexão" deve aparecer no topo
3. Vá ao Diário e escreva "Log offline teste" — clique Enviar
4. Deve aparecer na timeline com badge cinza "Aguardando conexão"
5. **Desative o Modo Avião**
6. A barra vermelha deve desaparecer
7. O badge deve mudar para verde "Sincronizado" (pode levar ~2s)
8. Recarregue a página — o log deve estar lá (veio do banco)
9. **PASS se**: log salva offline, sincroniza ao reconectar, persiste

## Passo 5: Idioma e Responsivo (1 min)

1. Abra o menu do usuário (toque no nome no canto superior)
2. No dropdown 🌐, troque para "English"
3. Os textos devem mudar (Propriedades → Properties, Hectares → Acres)
4. Troque para "Español" — textos em espanhol
5. Volte para "Português"
6. Gire o celular para paisagem — layout não deve quebrar
7. **PASS se**: 3 idiomas funcionam, layout responsivo ok

---

## Checklist de Resultado

| Teste | Android Chrome | iOS Safari |
|-------|:-:|:-:|
| Login + Instalação PWA | [ ] | [ ] |
| Propriedades + Detalhe + PDF | [ ] | [ ] |
| Diário texto + Voz | [ ] | [ ] mic oculto |
| Offline → Sync | [ ] | [ ] |
| Idiomas + Responsivo | [ ] | [ ] |

**Todos [ ] marcados = GO TO MARKET aprovado.**
