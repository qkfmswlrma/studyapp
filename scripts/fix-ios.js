/*
 * npx cap sync 뒤에 항상 돌린다.
 *
 *  1) Package.swift 경로 고치기
 *     윈도우에서 cap sync 를 돌리면 경로를 역슬래시로 적는다.
 *       .package(name: "CapacitorApp", path: "..\..\..\node_modules\@capacitor\app")
 *     스위프트에서 역슬래시는 특수문자라 맥에서 빌드가 통째로 깨진다. 슬래시로 바꾼다.
 *
 *  2) 앱 버전을 사이트 버전에 맞추기
 *     사이트 _source.html 의 APP_VERSION 을 그대로 앱 버전으로 쓴다.
 *     두 곳이 어긋나면 어느 게 최신인지 알 수 없게 된다.
 */
const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");
const SITE = path.resolve(ROOT, process.env.SITE_DIR || "../수학");

/* ---------- 1) Package.swift ---------- */
const pkg = path.join(ROOT, "ios/App/CapApp-SPM/Package.swift");
if (fs.existsSync(pkg)) {
  const before = fs.readFileSync(pkg, "utf8");
  const after = before.replace(/path:\s*"([^"]*)"/g, (m, p) => `path: "${p.replace(/\\/g, "/")}"`);
  if (after !== before) {
    fs.writeFileSync(pkg, after);
    console.log("Package.swift  : 역슬래시 경로를 고쳤습니다");
  } else {
    console.log("Package.swift  : 고칠 것 없음");
  }
  const bad = after.match(/path:\s*"[^"]*\\[^"]*"/);
  if (bad) { console.error("[실패] 아직 역슬래시가 남아 있습니다: " + bad[0]); process.exit(1); }
}

/* ---------- 2) 버전 맞추기 ---------- */
const src = path.join(SITE, "_source.html");
if (!fs.existsSync(src)) {
  console.log("버전           : 사이트 원본이 없어 건너뜁니다 (" + src + ")");
} else {
  const m = fs.readFileSync(src, "utf8").match(/const APP_VERSION\s*=\s*"([\d.]+)"/);
  if (!m) { console.error("[실패] _source.html 에서 APP_VERSION 을 찾지 못했습니다."); process.exit(1); }
  const version = m[1];

  const pbx = path.join(ROOT, "ios/App/App.xcodeproj/project.pbxproj");
  let txt = fs.readFileSync(pbx, "utf8");

  // 빌드 번호는 2.16.1 -> 21601 처럼 올라가기만 하는 정수로 만든다.
  // 애플은 같은 버전에 같은 빌드 번호를 두 번 못 올린다
  const [a, b, c] = version.split(".").map(Number);
  const build = a * 10000 + b * 100 + c;

  txt = txt.replace(/MARKETING_VERSION = [^;]+;/g, `MARKETING_VERSION = ${version};`);
  txt = txt.replace(/CURRENT_PROJECT_VERSION = [^;]+;/g, `CURRENT_PROJECT_VERSION = ${build};`);
  fs.writeFileSync(pbx, txt);
  console.log(`버전           : ${version} (빌드 ${build})`);
}
