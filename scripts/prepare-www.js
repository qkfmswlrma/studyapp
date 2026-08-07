/*
 * 수학질문방 웹사이트(index.html)를 iOS 앱에 넣을 www/ 로 바꾼다.
 *
 *   node scripts/prepare-www.js [사이트폴더]
 *   기본 사이트폴더: ../수학  (환경변수 SITE_DIR 로도 지정)
 *
 * 하는 일
 *  1) index.html 과 아이콘, manifest 를 www/ 로 복사
 *  2) CDN 에서 받던 React, Supabase, KaTeX, MathLive, 글꼴을 앱 안에 넣고 주소를 바꾼다
 *     (앱은 껍데기만 받고 알맹이를 인터넷에서 받아오면 안 된다. 첫 실행이 느리고,
 *      CDN 이 죽으면 앱도 같이 죽는다)
 *  3) 아이폰 노치와 홈 표시줄을 피하도록 화면 여백을 보정하는 css 를 덧붙인다
 *  4) 상태 표시줄 색과 시작 화면을 다루는 app-native.js 를 끼워 넣는다
 *
 * 원본 사이트 파일은 절대 건드리지 않는다. 읽기만 한다.
 */
const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");
const SITE = path.resolve(ROOT, process.argv[2] || process.env.SITE_DIR || "../수학");
const WWW = path.join(ROOT, "www");
const NM = path.join(ROOT, "node_modules");

const log = (...a) => console.log(...a);

/* ---------- 파일 도우미 ---------- */
function copyFile(from, to) {
  fs.mkdirSync(path.dirname(to), { recursive: true });
  fs.copyFileSync(from, to);
}
function copyDir(from, to, filter) {
  fs.mkdirSync(to, { recursive: true });
  for (const name of fs.readdirSync(from)) {
    const src = path.join(from, name);
    const dst = path.join(to, name);
    const st = fs.statSync(src);
    if (st.isDirectory()) copyDir(src, dst, filter);
    else if (!filter || filter(name)) fs.copyFileSync(src, dst);
  }
}
function need(p, what) {
  if (!fs.existsSync(p)) {
    console.error(`[실패] ${what} 를 찾지 못했습니다: ${p}`);
    process.exit(1);
  }
  return p;
}

/* ---------- 0) www 비우고 시작 ---------- */
fs.rmSync(WWW, { recursive: true, force: true });
fs.mkdirSync(WWW, { recursive: true });

/* ---------- 1) 사이트 파일 복사 ---------- */
need(path.join(SITE, "index.html"), "사이트의 index.html");
let html = fs.readFileSync(path.join(SITE, "index.html"), "utf8");

for (const name of ["icon-180.png", "icon-192.png", "icon-512.png", "manifest.json", "og-image.png"]) {
  const src = path.join(SITE, name);
  if (fs.existsSync(src)) copyFile(src, path.join(WWW, name));
}

/* ---------- 2) CDN 을 앱 안으로 ---------- */
const V = path.join(WWW, "vendor");

// React
copyFile(need(path.join(NM, "react/umd/react.production.min.js"), "react UMD"), path.join(V, "react.production.min.js"));
copyFile(need(path.join(NM, "react-dom/umd/react-dom.production.min.js"), "react-dom UMD"), path.join(V, "react-dom.production.min.js"));

// Supabase (window.supabase 를 만드는 UMD 빌드)
copyFile(need(path.join(NM, "@supabase/supabase-js/dist/umd/supabase.js"), "supabase-js UMD"), path.join(V, "supabase.js"));

// KaTeX: css 가 fonts/ 를 상대경로로 찾으므로 폴더째 옮긴다
copyFile(need(path.join(NM, "katex/dist/katex.min.css"), "katex css"), path.join(V, "katex/katex.min.css"));
copyFile(need(path.join(NM, "katex/dist/katex.min.js"), "katex js"), path.join(V, "katex/katex.min.js"));
copyDir(need(path.join(NM, "katex/dist/fonts"), "katex 글꼴"), path.join(V, "katex/fonts"), (n) => n.endsWith(".woff2"));

// MathLive: 스크립트가 자기 위치를 기준으로 fonts/ 와 sounds/ 를 찾는다. 형제로 둔다
copyFile(need(path.join(NM, "mathlive/mathlive.min.js"), "mathlive"), path.join(V, "mathlive/mathlive.min.js"));
copyDir(need(path.join(NM, "mathlive/fonts"), "mathlive 글꼴"), path.join(V, "mathlive/fonts"));
if (fs.existsSync(path.join(NM, "mathlive/sounds"))) copyDir(path.join(NM, "mathlive/sounds"), path.join(V, "mathlive/sounds"));

// Plus Jakarta Sans: 구글 글꼴 대신 앱에 넣는다
const FS_PKG = need(path.join(NM, "@fontsource/plus-jakarta-sans"), "Plus Jakarta Sans");
const weights = ["400", "500", "600", "700", "800"];
let fontCss = "/* Plus Jakarta Sans (앱 내장) */\n";
fs.mkdirSync(path.join(V, "fonts/files"), { recursive: true });
for (const w of weights) {
  const cssPath = path.join(FS_PKG, `${w}.css`);
  if (!fs.existsSync(cssPath)) continue;
  let css = fs.readFileSync(cssPath, "utf8");
  // latin 계열만 남긴다. 한글은 애플 기본 글꼴이 그린다
  css = css.replace(/url\(\.\/files\/([^)]+)\)/g, (m, f) => {
    const src = path.join(FS_PKG, "files", f);
    if (fs.existsSync(src)) copyFile(src, path.join(V, "fonts/files", f));
    return `url(./files/${f})`;
  });
  fontCss += css + "\n";
}
fs.writeFileSync(path.join(V, "fonts/plus-jakarta-sans.css"), fontCss);

/* ---------- 3) index.html 주소 바꾸기 ---------- */
const before = html;
const swaps = [
  // React / Supabase / KaTeX
  [/https:\/\/unpkg\.com\/react@18\/umd\/react\.production\.min\.js/g, "/vendor/react.production.min.js"],
  [/https:\/\/unpkg\.com\/react-dom@18\/umd\/react-dom\.production\.min\.js/g, "/vendor/react-dom.production.min.js"],
  [/https:\/\/cdn\.jsdelivr\.net\/npm\/@supabase\/supabase-js@2/g, "/vendor/supabase.js"],
  [/https:\/\/cdn\.jsdelivr\.net\/npm\/katex@[\d.]+\/dist\/katex\.min\.css/g, "/vendor/katex/katex.min.css"],
  [/https:\/\/cdn\.jsdelivr\.net\/npm\/katex@[\d.]+\/dist\/katex\.min\.js/g, "/vendor/katex/katex.min.js"],
  // MathLive 는 화면 안에서 나중에 불러온다. 상대경로면 /column/110001 같은 주소에서 깨지므로 절대경로로
  [/https:\/\/cdn\.jsdelivr\.net\/npm\/mathlive@[\d.]+/g, "/vendor/mathlive/mathlive.min.js"],
  // 구글 글꼴
  [/\s*<link rel="preconnect" href="https:\/\/fonts\.googleapis\.com"[^>]*>/g, ""],
  [/\s*<link rel="preconnect" href="https:\/\/fonts\.gstatic\.com"[^>]*>/g, ""],
  [/<link href="https:\/\/fonts\.googleapis\.com\/css2[^"]*" rel="stylesheet"\s*\/?>/g,
   '<link rel="stylesheet" href="/vendor/fonts/plus-jakarta-sans.css" />'],
  // 노치까지 화면을 쓰고, 여백은 css 가 env(safe-area-inset-*) 로 잡는다
  [/(<meta name="viewport" content="[^"]*?)(" \/>)/, '$1, viewport-fit=cover$2'],
];
for (const [re, to] of swaps) html = html.replace(re, to);

// 앱 전용 css 와 js 를 끼워 넣는다
html = html.replace(
  "</head>",
  '<link rel="stylesheet" href="/app-native.css" />\n<script defer src="/app-native.js"></script>\n</head>'
);

if (html === before) {
  console.error("[실패] index.html 에서 바꾼 게 하나도 없습니다. 사이트 쪽이 달라졌는지 확인하세요.");
  process.exit(1);
}

/* ---------- 4) 남은 인터넷 주소 확인 ---------- */
const leftover = [...html.matchAll(/(?:src|href)="(https?:\/\/[^"]+)"/g)]
  .map((m) => m[1])
  .filter((u) => !/suhakjilmoon\.pages\.dev/.test(u)); // og 미리보기 주소는 앱에서 안 쓴다
if (leftover.length) {
  console.error("[실패] 아직 CDN 에서 받아오는 파일이 있습니다:");
  leftover.forEach((u) => console.error("   " + u));
  process.exit(1);
}

fs.writeFileSync(path.join(WWW, "index.html"), html);
copyFile(path.join(__dirname, "app-native.css"), path.join(WWW, "app-native.css"));
copyFile(path.join(__dirname, "app-native.js"), path.join(WWW, "app-native.js"));

/* ---------- 5) 결과 ---------- */
function dirSize(p) {
  let n = 0;
  for (const f of fs.readdirSync(p)) {
    const s = fs.statSync(path.join(p, f));
    n += s.isDirectory() ? dirSize(path.join(p, f)) : s.size;
  }
  return n;
}
log("www 준비 완료");
log("  사이트   ", SITE);
log("  index    ", Math.round(Buffer.byteLength(html) / 1024), "KB");
log("  전체     ", Math.round(dirSize(WWW) / 1024), "KB");
log("  CDN 의존 ", "없음");
