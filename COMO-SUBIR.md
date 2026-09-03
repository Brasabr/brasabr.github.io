# O que a página de download fazia (e por que isso virou "Página não encontrada")

`baixar.html` tinha um mecanismo de sorteio com três níveis, e o último deles era
um beco sem saída:

1. `button.href` começa fixo em `.../releases/latest/download/brasabr-1.16.5-foto-vai.apk` —
   **esse nome de asset não existe** na release `v1.16.5` (lá só está
   `brasabr-1.16.5-admob.apk`). GitHub responde `404` e, no seu site, 404 é a página
   "Página não encontrada" que você viu no celular.
2. Aí roda o `fetch` na API do GitHub para achar o asset certo. Se ele succeeds, o href é
   corrigido. Se ele **falha** (rate limit — 60 req/h por IP sem token, e o seu site faz isso
   em *todo* carregamento de página; rede de celular compartilhando NAT ajuda), o `catch` fazia:
   `button.href = STABLE_URL` → devolvia o botão para o nome inexistente. Ou seja: quanto pior a
   rede, mais provável o 404.
3. `ASSET_NAMES` já continha `'brasabr-1.16.5-admob.apk'`, mas o `EXACT_NAME` fixo em `[0]`
   era o nome errado.

## Correção (4 mudanças por arquivo, nada de re-upload de 28 MB)

| # | Antes | Depois |
|---|-------|--------|
| 1 | `href="…/download/brasabr-1.16.5-foto-vai.apk"` | `href="…/download/brasabr-1.16.5-admob.apk"` (o que existe) |
| 2 | `ASSET_NAMES = ['…foto-vai…', '…admob…']` | ordem trocada: o nome real vem primeiro; os dois continuam na lista, então se você renomear o asset amanhã o script acha sozinho |
| 3 | `catch → button.href = STABLE_URL` (o nome morto) | `catch → button.href = RELEASE_PAGE` (`…/releases/latest`, 200), que sempre tem o APK |
| 4 | status "Download oficial disponível pelo botão acima." (mentira se o link quebra) | status explicando que a API falhou e que o botão abre a página da release |

O `STABLE_URL` continua no arquivo (derivado de `EXACT_NAME`, agora um nome válido) e a
página passa a funcionar **sem JavaScript também**, porque o href estático já é o asset certo.

## Arquivos

```
baixar.html                  <- substitui o de mesmo nome no repo
baixar-hash-buildlog.html    <- substitui o de mesmo nome no repo
app-ads.txt                  <- NOVO (o AdMob ainda 404 para ele)
verificar-download.mjs       <- roda o <script> real contra fetch/DOM falsos (12 checagens)
CONFERIR.sh                  <- node --check + verificar-download.mjs + laço de links
COMO-SUBIR.md                <- como publicar
```

## Conferir local antes de subir

```bash
cd fix-site && ./CONFERIR.sh          # precisa de node
```

## Publicar (do jeito que você já publica)

1. `github.com/Brasabr/brasabr.github.io` → **Add file → Upload files**
2. arraste os **três** arquivos: `baixar.html`, `baixar-hash-buildlog.html`, `app-ads.txt`
   (os dois `.html` substituem os existentes; `app-ads.txt` é novo)
3. **Commit directly to `main`** → Commit. Pages publica o resto em ~30 s.

Com `gh` é um comando:

```bash
gh api -X PUT repos/Brasabr/brasabr.github.io/contents/baixar.html \
  -f message="baixar.html: apontar para o asset que existe" \
  -f branch=main -f content="$(base64 -w0 baixar.html)" \
  -f sha="$(gh api repos/Brasabr/brasabr.github.io/contents/baixar.html --jq .sha)"
```

Depois de publicar, confira:

```bash
curl -o /dev/null -w "%{http_code}\n" https://brasabr.github.io/baixar.html      # 200
curl -o /dev/null -w "%{http_code}\n" https://brasabr.github.io/app-ads.txt      # 200
```
