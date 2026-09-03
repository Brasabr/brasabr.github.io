/*
 * verificar-download.mjs — roda o <script> real da página de download contra DOM e
 * fetch falsos e diz para onde o botão aponta em cada cenário.
 *
 *   node verificar-download.mjs <caminho/para/baixar.html>
 *
 * Ele não reimplementa nada: extrai o bloco <script> que contém ASSET_NAMES do
 * arquivo que você vai subir e o executa.
 */
import { readFileSync } from "node:fs";

const alvo = process.argv[2];
if (!alvo) {
  console.error("uso: node verificar-download.mjs <pagina.html>");
  process.exit(2);
}

const htmlTxt = readFileSync(alvo, "utf8");
const blocos = [...htmlTxt.matchAll(/<script>([\s\S]*?)<\/script>/g)]
  .map((m) => m[1])
  .filter((b) => b.includes("ASSET_NAMES"));
if (blocos.length !== 1) {
  console.error(`FALHOU: esperava 1 <script> com ASSET_NAMES em ${alvo}, achei ${blocos.length}`);
  process.exit(1);
}
const src = blocos[0];

const ADMOB = "https://github.com/Brasabr/brasabr.github.io/releases/latest/download/brasabr-1.16.5-admob.apk";
const RELEASE = "https://github.com/Brasabr/brasabr.github.io/releases/latest";

function rodar({ apiFalha = false, assets = null } = {}) {
  const estado = { href: null, status: "", version: "" };
  const el = (id) => ({
    set href(v) { if (id === "download") estado.href = v; },
    get href() { return estado.href; },
    set textContent(v) { if (id === "status") estado.status = v; if (id === "version") estado.version = v; },
    get textContent() { return id === "status" ? estado.status : estado.version; },
  });
  const doc = { getElementById: el };
  const fetch = async () => {
    if (apiFalha) return { ok: false, status: 429 };
    return { ok: true, json: async () => ({ tag_name: "v1.16.5", assets }) };
  };
  new Function("document", "fetch", src)(doc, fetch);
  return new Promise((r) => setTimeout(() => r(estado), 30));
}

let checks = 0, fails = 0;
const ok = (rotulo, cond) => {
  checks++;
  if (cond) console.log("ok      " + rotulo);
  else { fails++; console.log("FALHOU  " + rotulo); }
};

// o href estático: é o que o navegador usa antes do JS rodar (e o que o botão
// leva se o JavaScript estiver desligado)
const hrefEstatico = (htmlTxt.match(/id="download"\s+href="([^"]+)"/) || [])[1] || "";
ok("href estatico do botao existe no arquivo", hrefEstatico.length > 0);
ok("href estatico NAO aponta para nome de asset inexistente", !/foto-vai/.test(hrefEstatico));
ok("href estatico e o asset que esta na release", hrefEstatico === ADMOB);
ok("lista mantem os dois nomes (para o dia que voce renomear o asset)",
   /ASSET_NAMES\s*=\s*\[[^\]]*admob[^\]]*foto-vai[^\]]*\]/.test(src));
ok("o caminho de erro usa uma constante que existe", /const RELEASE_PAGE/.test(src));

let e = await rodar({ apiFalha: true });
ok("API do GitHub com rate limit: botao nao vira 404", !/foto-vai/.test(e.href || ""));
ok("API falhando: cai na pagina da release", e.href === RELEASE);
ok("API falhando: a frase explica, nao mente", /consegui falar com o GitHub/i.test(e.status));

e = await rodar({ assets: [{ name: "brasabr-1.16.5-admob.apk", browser_download_url: ADMOB }] });
ok("API ok: usa o asset que existe", e.href === ADMOB);
ok("API ok: mostra a versao", /v1\.16\.5/.test(e.version));

e = await rodar({ assets: [{ name: "brasabr-1.16.5-foto-vai.apk", browser_download_url: "X" }] });
ok("se o asset for renomeado amanha, o script acha sozinho", e.href === "X");

e = await rodar({ assets: [] });
ok("release sem asset: nao lanca erro e nao aponta para 404", typeof e.href === "string" && !/foto-vai/.test(e.href));

console.log(`\n${checks} verificacoes, ${fails} falhas  (${alvo})`);
process.exit(fails ? 1 : 0);
