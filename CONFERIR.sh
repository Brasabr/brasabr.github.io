#!/usr/bin/env bash
# Confere o fix-site antes de voce subir: sintaxe, comportamento do botao, e cada
# link das paginas corrigidas (resolvido contra o site no ar).
set -uo pipefail
cd "$(dirname "$0")"
F=0
passa() { echo "ok      $1"; }
falha() { echo "FALHOU  $1"; F=$((F+1)); }

echo "== 1. node --check no <script> extraido de cada pagina =="
for f in baixar.html baixar-hash-buildlog.html; do
  python3 - "$f" <<'PY'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
b = [m.group(1) for m in re.finditer(r"<script>([\s\S]*?)</script>", s) if "ASSET_NAMES" in m.group(1)]
sys.exit(0 if len(b) == 1 else 1)
PY
  python3 - "$f" > /tmp/extrado-$$.js <<'PY'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
b = [m.group(1) for m in re.finditer(r"<script>([\s\S]*?)</script>", s) if "ASSET_NAMES" in m.group(1)]
sys.stdout.write(b[0])
PY
  if node --check /tmp/extrado-$$.js >/dev/null 2>&1; then passa "$f: script valida"; else falha "$f: node --check"; fi
done

echo
echo "== 2. comportamento do botao (cenario real, fetch falso) =="
for f in baixar.html baixar-hash-buildlog.html; do
  if out=$(node verificar-download.mjs "$f" 2>&1); then
    passa "$f: $(echo "$out" | tail -1)"
  else
    echo "$out" | tail -6; falha "$f: verificar-download.mjs"
  fi
done

echo
echo "== 3. todo link das paginas corrigidas responde 200 =="
python3 - <<'PY' || F=$((F+1))
import re, html, sys, urllib.parse, urllib.request, urllib.error, os
BASE = "https://brasabr.github.io/"
def get(u, method="GET"):
    try:
        req = urllib.request.Request(u, method=method, headers={"User-Agent": "conferir"})
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status
    except urllib.error.HTTPError as e:
        return e.code
    except Exception:
        return "ERR"
ruins = 0
avisos = []
for nome in ("baixar.html", "baixar-hash-buildlog.html"):
    s = open(nome, encoding="utf-8").read()
    alvos = set(re.findall(r'(?:href|src)="([^"#{}]+)"', html.unescape(s)))
    alvos |= set(re.findall(r"https?://[^\s\"'<>\\]+\.apk", html.unescape(s)))
    alvos |= set(re.findall(r"(?:location\.href|RELEASE_PAGE)\s*=\s*['\"]([^'\"]+)", s))
    alvos = {a.strip() for a in alvos if a.strip() and not a.startswith(("mailto:", "tel:", "data:", "javascript:"))}
    for a in sorted(alvos):
        if "cdn-cgi/" in a:
            continue
        url = a if a.startswith("http") else BASE + urllib.parse.quote(a)
        st = get(url)
        interno = url.startswith(BASE)
        if st == 200:
            print("  [200] %s" % url[:100])
        elif st in (403, 429) and not interno:
            # site de terceiros bloqueando o nosso robby: NAO e link quebrado, mas
            # também nao digo que esta ok - fica como AVISO para voce abrir no navegador.
            avisos.append((st, url, nome))
        else:
            print("  [http %s] %s   <- em %s" % (st, url, nome)); ruins += 1
for st, url, nome in avisos:
    print("  [AVISO http %s] %s  (site de terceiros limitando robott; confira no navegador)" % (st, url))
if ruins:
    print("FALHOU: %d link(s) sem 200" % ruins); sys.exit(1)
print("todos os links do proprio site dao 200 (%d aviso(s) de terceiros)" % len(avisos))
PY

echo
echo "== 4. o APK que o botao entrega e o original, bit a bit =="
DIGEST=$(curl -s --max-time 30 "https://api.github.com/repos/Brasabr/brasabr.github.io/releases/371198906/assets" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)[0].get('digest',''))" 2>/dev/null)
LOCAL=$(sha256sum ../apk/brasabr-1.16.5-foto-vai.apk | cut -d' ' -f1)
echo "  digest no GitHub : $DIGEST"
echo "  sha256 local     : sha256:$LOCAL"
if [ -n "$DIGEST" ] && [ "$DIGEST" = "sha256:$LOCAL" ]; then
  passa "o asset da release e exatamente o APK original (nao precisa reenviar 28 MB)"
else
  falha "digest nao confere (ou a API respondeu vazia) - confira voce mesmo"
fi

echo
if [ "$F" = "0" ]; then echo "fix-site pronto para publicar."; else echo "$F falha(s)"; fi
exit $([ "$F" = "0" ] && echo 0 || echo 1)
