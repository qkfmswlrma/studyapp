/*
 * 앱 아이콘과 시작 화면 그림을 만든다.
 *
 *   node scripts/make-icons.js
 *   -> assets/icon.png, assets/splash.png, assets/splash-dark.png
 *   그 다음 npx @capacitor/assets generate --ios 가 크기별로 잘라낸다.
 *
 * 사이트 아이콘(icon-512.png)은 모서리가 둥글고 그 바깥이 투명하다.
 * 애플 아이콘은 투명한 곳이 있으면 안 되고 모서리도 애플이 알아서 깎는다.
 * 그래서 둥근 모서리가 화면 밖으로 나가도록 안쪽을 잘라 쓴다.
 */
const fs = require("fs");
const path = require("path");
const sharp = require("sharp");

const ROOT = path.resolve(__dirname, "..");
const SITE = path.resolve(ROOT, process.env.SITE_DIR || "../수학");
const OUT = path.join(ROOT, "assets");
fs.mkdirSync(OUT, { recursive: true });

const SRC = path.join(SITE, "icon-512.png");
if (!fs.existsSync(SRC)) { console.error("[실패] 아이콘 원본이 없습니다: " + SRC); process.exit(1); }

const LIGHT = "#f2e6fb"; // 사이트 밝은 배경
const DARK = "#181a2b";  // 사이트 어두운 배경

(async () => {
  const meta = await sharp(SRC).metadata();
  // 둥근 모서리가 잘려 나가도록 각 변에서 안쪽으로 들어간다.
  // 모서리 반지름의 약 30% 만 들어가면 투명한 부분이 사라진다
  const inset = Math.round(meta.width * 0.085);
  const side = meta.width - inset * 2;

  await sharp(SRC)
    .extract({ left: inset, top: inset, width: side, height: side })
    .resize(1024, 1024, { kernel: "lanczos3" })
    .flatten({ background: "#b388ff" }) // 혹시라도 남은 투명한 곳을 메운다
    .png()
    .toFile(path.join(OUT, "icon.png"));

  // 시작 화면: 2732x2732 한가운데에 로고. 어느 기기에서든 가운데만 보인다
  const logo = await sharp(SRC).resize(560, 560, { kernel: "lanczos3" }).png().toBuffer();
  for (const [name, bg] of [["splash.png", LIGHT], ["splash-dark.png", DARK]]) {
    await sharp({ create: { width: 2732, height: 2732, channels: 4, background: bg } })
      .composite([{ input: logo, gravity: "centre" }])
      .png()
      .toFile(path.join(OUT, name));
  }

  // 투명한 곳이 남지 않았는지 확인한다. 남으면 애플이 업로드를 거절한다
  const st = await sharp(path.join(OUT, "icon.png")).stats();
  const alpha = st.channels[3];
  if (alpha && alpha.min < 255) {
    console.error("[실패] 아이콘에 투명한 부분이 남았습니다. inset 을 늘리세요.");
    process.exit(1);
  }
  console.log("아이콘 만들기 완료");
  console.log("  assets/icon.png          1024x1024 (투명 없음)");
  console.log("  assets/splash.png        2732x2732", LIGHT);
  console.log("  assets/splash-dark.png   2732x2732", DARK);
})().catch((e) => { console.error(e); process.exit(1); });
