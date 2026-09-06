// 《复调》鸣响墟 —— 像素资产生成器（Node.js，仅标准库：zlib 手写 PNG 编码）。
// 产出：主角／失调体／Boss／特质光点／地形瓦片／装饰／视差背景／涟漪／渐盲晕影。
// 用法：node gen_art.js   （输出到 ../assets/sprites/ 与 ../assets/bg/）
// 正式美术可逐张替换同名 PNG，无需改代码（尺寸一致即可）。
"use strict";
const fs = require("fs");
const path = require("path");
const zlib = require("zlib");

const OUT = path.join(__dirname, "..", "assets");
const SPR = path.join(OUT, "sprites");
const BG = path.join(OUT, "bg");

// ---------- PNG 编码 ----------
const CRC_TABLE = (() => {
  const t = new Int32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c;
  }
  return t;
})();
function crc32(buf) {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(td));
  return Buffer.concat([len, td, crc]);
}
function savePNG(file, w, h, rgba) {
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) {
    raw[y * (w * 4 + 1)] = 0; // filter none
    for (let x = 0; x < w; x++) {
      const s = (y * w + x) * 4, d = y * (w * 4 + 1) + 1 + x * 4;
      raw[d] = rgba[s]; raw[d + 1] = rgba[s + 1]; raw[d + 2] = rgba[s + 2]; raw[d + 3] = rgba[s + 3];
    }
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8; ihdr[9] = 6; // 8bit RGBA
  const png = Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk("IHDR", ihdr), chunk("IDAT", zlib.deflateSync(raw, { level: 9 })), chunk("IEND", Buffer.alloc(0)),
  ]);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, png);
  console.log("  wrote", file, `${w}x${h}`);
}

// ---------- 画布与绘制 ----------
function canvas(w, h) { return { w, h, d: new Float32Array(w * h * 4) }; }
function px(c, x, y, col) {
  x |= 0; y |= 0;
  if (x < 0 || y < 0 || x >= c.w || y >= c.h) return;
  const i = (y * c.w + x) * 4, a = col[3] === undefined ? 255 : col[3];
  if (a >= 255) { c.d[i] = col[0]; c.d[i + 1] = col[1]; c.d[i + 2] = col[2]; c.d[i + 3] = 255; }
  else { // alpha blend
    const da = c.d[i + 3] / 255, sa = a / 255, oa = sa + da * (1 - sa);
    if (oa <= 0) return;
    c.d[i] = (col[0] * sa + c.d[i] * da * (1 - sa)) / oa;
    c.d[i + 1] = (col[1] * sa + c.d[i + 1] * da * (1 - sa)) / oa;
    c.d[i + 2] = (col[2] * sa + c.d[i + 2] * da * (1 - sa)) / oa;
    c.d[i + 3] = oa * 255;
  }
}
function rect(c, x, y, w, h, col) { for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) px(c, x + i, y + j, col); }
function ellipse(c, cx, cy, rx, ry, col) {
  for (let y = Math.floor(cy - ry); y <= Math.ceil(cy + ry); y++)
    for (let x = Math.floor(cx - rx); x <= Math.ceil(cx + rx); x++) {
      const dx = (x - cx) / rx, dy = (y - cy) / ry;
      if (dx * dx + dy * dy <= 1) px(c, x, y, col);
    }
}
function outline(c, col) {
  const src = c.d.slice();
  const A = (x, y) => (x < 0 || y < 0 || x >= c.w || y >= c.h ? 0 : src[(y * c.w + x) * 4 + 3]);
  for (let y = 0; y < c.h; y++) for (let x = 0; x < c.w; x++) {
    const i = (y * c.w + x) * 4;
    if (src[i + 3] < 8) {
      if (A(x - 1, y) > 128 || A(x + 1, y) > 128 || A(x, y - 1) > 128 || A(x, y + 1) > 128)
        { c.d[i] = col[0]; c.d[i + 1] = col[1]; c.d[i + 2] = col[2]; c.d[i + 3] = 255; }
    }
  }
}
function save(c, file) {
  const rgba = Buffer.alloc(c.w * c.h * 4);
  for (let i = 0; i < c.d.length; i++) rgba[i] = Math.max(0, Math.min(255, Math.round(c.d[i])));
  savePNG(file, c.w, c.h, rgba);
}

// ---------- 调色板（鸣响墟：冷蓝／青） ----------
const P = {
  outline: [11, 19, 29],
  body: [28, 42, 58], bodyMid: [44, 66, 88],
  hood: [216, 236, 244], eye: [174, 242, 255],
  scarf: [86, 200, 216], scarfD: [46, 138, 154],
  enemy: [74, 26, 38], enemy2: [110, 30, 42], spike: [160, 48, 64], eeye: [255, 106, 106],
  stone: [22, 48, 63], stoneHi: [61, 107, 130], stoneLine: [111, 179, 201], stoneDk: [14, 30, 42],
  trait: [232, 251, 255], traitMid: [127, 216, 232], traitEdge: [42, 122, 149],
  trail: [74, 138, 160], lamp: [255, 216, 138], wave: [53, 86, 110],
};

// ---------- 主角（倾听者，16×24，兜帽＋围巾） ----------
function playerFrame(leg, armUp) {
  const c = canvas(16, 24);
  // 兜帽
  ellipse(c, 7.5, 4.5, 4.5, 4.5, P.hood);
  rect(c, 5, 6, 5, 3, [20, 30, 42]);            // 面部阴影
  px(c, 9, 7, P.eye);                            // 发光的眼睛（朝右）
  // 围巾
  rect(c, 4, 9, 9, 2, P.scarf);
  rect(c, 5, 11, 7, 1, P.scarfD);
  if (armUp) rect(c, 11, 8, 3, 2, P.scarfD);     // 发音时抬起的手
  // 斗篷身躯（上宽下窄）
  for (let y = 12; y <= 17; y++) {
    const w = y < 15 ? 9 - Math.floor((y - 12) / 2) : 7 - Math.floor((y - 12) / 2);
    rect(c, 8 - Math.floor(w / 2), y, w, 1, P.body);
    rect(c, 8 - Math.floor(w / 2) + 1, y, 1, 1, P.bodyMid);
  }
  // 腿（leg: 0 站立 1 走A 2 走B 3 跳）
  const L = (x, h) => rect(c, x, 24 - h, 2, h, P.body);
  if (leg === 0) { L(6, 6); L(9, 6); }
  else if (leg === 1) { L(5, 5); rect(c, 5, 22, 2, 1, P.body); L(10, 6); }
  else if (leg === 2) { L(6, 6); L(9, 5); rect(c, 9, 22, 2, 1, P.body); }
  else { L(5, 4); L(9, 4); rect(c, 5, 19, 2, 1, P.bodyMid); rect(c, 9, 19, 2, 1, P.bodyMid); }
  outline(c, P.outline);
  return c;
}

// ---------- 过载型失调体（16×18，锯齿声团） ----------
function enemyFrame(shift, bright) {
  const c = canvas(16, 18);
  const bodyC = bright ? [150, 60, 40] : P.enemy;
  ellipse(c, 8, 10, 5.5, 6.5, bodyC);
  ellipse(c, 8, 12, 4.5, 4, P.enemy2);
  // 锯齿声波刺（绕体一周，帧间位移）
  for (let a = 0; a < 10; a++) {
    const ang = (a / 10) * Math.PI * 2 + shift * 0.35;
    const sx = 8 + Math.cos(ang) * 6.5, sy = 10 + Math.sin(ang) * 7.5;
    const tipx = 8 + Math.cos(ang) * (9 + (a % 2)), tipy = 10 + Math.sin(ang) * (10 + (a % 2));
    for (let t = 0; t <= 1; t += 0.2)
      px(c, sx + (tipx - sx) * t, sy + (tipy - sy) * t, P.spike);
  }
  // 双眼
  px(c, 5, 9, P.eeye); px(c, 10, 9, P.eeye);
  outline(c, P.outline);
  return c;
}

// ---------- Boss 原声（32×40，声骸之海的巨骸） ----------
function bossFrame() {
  const c = canvas(32, 40);
  ellipse(c, 16, 20, 12, 16, P.enemy);
  ellipse(c, 16, 24, 9, 11, P.enemy2);
  ellipse(c, 16, 16, 8, 6, [26, 12, 20]);
  // 多环声波刺
  for (let ring = 0; ring < 3; ring++) {
    const n = 12 + ring * 4;
    for (let a = 0; a < n; a++) {
      const ang = (a / n) * Math.PI * 2 + ring * 0.4;
      const r0 = 11 + ring * 3.2, r1 = r0 + 3 + (a % 2) * 2;
      for (let t = 0; t <= 1; t += 0.15)
        px(c, 16 + Math.cos(ang) * r0 * (1 - t) + Math.cos(ang) * r1 * t,
             20 + Math.sin(ang) * (r0 * (1 - t) + r1 * t) * 1.25, P.spike);
    }
  }
  // 巨核之眼
  ellipse(c, 16, 19, 3.5, 2.5, [10, 6, 10]);
  px(c, 16, 19, [255, 120, 120]); px(c, 15, 19, [255, 160, 160]);
  outline(c, P.outline);
  return c;
}

// ---------- 特质光点（8×8 两帧脉冲） ----------
function traitDot(frame) {
  const c = canvas(8, 8);
  const r = frame === 0 ? 2.2 : 3.0;
  ellipse(c, 4, 4, r, r, P.traitMid);
  ellipse(c, 4, 4, 1.2, 1.2, P.trait);
  px(c, 4, 0, [127, 216, 232, 140]); px(c, 4, 7, [127, 216, 232, 140]);
  return c;
}

// ---------- 地形瓦片（16×16） ----------
let seed = 9;
function rnd() { seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648; }
function tileGroundTop() {
  const c = canvas(16, 16);
  rect(c, 0, 0, 16, 16, P.stone);
  rect(c, 0, 0, 16, 1, P.stoneLine);
  rect(c, 0, 1, 16, 1, P.stoneHi);
  for (let i = 0; i < 26; i++) px(c, Math.floor(rnd() * 16), 2 + Math.floor(rnd() * 14), P.stoneDk);
  for (let i = 0; i < 4; i++) rect(c, Math.floor(rnd() * 13), 4 + Math.floor(rnd() * 10), 2, 1, P.stoneDk);
  return c;
}
function tileGroundFill() {
  const c = canvas(16, 16);
  rect(c, 0, 0, 16, 16, [13, 27, 38]);
  for (let i = 0; i < 18; i++) px(c, Math.floor(rnd() * 16), Math.floor(rnd() * 16), P.stoneDk);
  for (let i = 0; i < 3; i++) rect(c, Math.floor(rnd() * 14), Math.floor(rnd() * 14), 3, 1, [10, 22, 32]);
  return c;
}
function tilePlatform() {
  const c = canvas(16, 10);
  rect(c, 0, 0, 16, 10, P.stone);
  rect(c, 0, 0, 16, 1, P.stoneLine);
  rect(c, 0, 1, 16, 1, P.stoneHi);
  for (let i = 0; i < 8; i++) px(c, Math.floor(rnd() * 16), 3 + Math.floor(rnd() * 6), P.stoneDk);
  return c;
}
function tileTrail() {
  const c = canvas(16, 16);
  // 痕迹：三段浅色短划（拖拽感）
  rect(c, 2, 11, 5, 1, [P.trail[0], P.trail[1], P.trail[2], 150]);
  rect(c, 9, 12, 4, 1, [P.trail[0], P.trail[1], P.trail[2], 100]);
  px(c, 1, 12, [P.trail[0], P.trail[1], P.trail[2], 80]);
  return c;
}

// ---------- 装饰 ----------
function decoPillar() {
  const c = canvas(12, 44);
  rect(c, 2, 4, 8, 38, [30, 52, 66]);
  rect(c, 2, 4, 2, 38, [44, 76, 94]);
  rect(c, 0, 0, 12, 5, [38, 64, 80]);
  rect(c, 0, 40, 12, 4, [26, 44, 58]);
  for (let i = 0; i < 6; i++) rect(c, 3 + Math.floor(rnd() * 7), 8 + Math.floor(rnd() * 30), 1, 2, [20, 36, 48]);
  outline(c, P.outline);
  return c;
}
function decoWave(variant) {
  const c = canvas(26, 14);
  // 冻结的声纹弧线
  for (let arc = 0; arc < 3; arc++) {
    const r = 3 + arc * 3.2 + variant;
    for (let t = -1; t <= 1; t += 0.05) {
      const x = 4 + Math.cos(t * 1.2) * r * 0.9;
      const y = 12 - Math.abs(Math.sin(t * 1.2)) * r;
      if (x >= 0 && x < 26 && y >= 0) px(c, x, y, [P.wave[0], P.wave[1], P.wave[2], 190 - arc * 40]);
    }
  }
  return c;
}
function decoContainer() {
  const c = canvas(12, 18);
  rect(c, 1, 3, 10, 14, [32, 48, 62]);
  rect(c, 1, 3, 10, 2, [50, 74, 92]);
  rect(c, 4, 0, 4, 3, [40, 60, 76]);
  rect(c, 2, 8, 8, 1, [16, 30, 40]);
  outline(c, P.outline);
  return c;
}
function respawnLamp() {
  const c = canvas(10, 34);
  rect(c, 4, 6, 2, 28, [128, 138, 148]);
  ellipse(c, 5, 4, 3.5, 4, P.lamp);
  ellipse(c, 5, 4, 1.5, 2, [255, 245, 210]);
  outline(c, P.outline);
  return c;
}
function ripple() {
  const c = canvas(48, 48);
  for (let a = 0; a < 360; a += 0.5) {
    const x = 24 + Math.cos(a * Math.PI / 180) * 21, y = 24 + Math.sin(a * Math.PI / 180) * 21;
    px(c, x, y, [127, 216, 232, 170]); px(c, x + 1, y, [127, 216, 232, 90]);
  }
  return c;
}
function waveShot() {
  const c = canvas(10, 5);
  rect(c, 0, 1, 10, 3, [127, 216, 232, 210]);
  rect(c, 2, 0, 6, 1, [200, 240, 255, 220]);
  rect(c, 2, 4, 6, 1, [127, 216, 232, 140]);
  return c;
}
function particle() {
  const c = canvas(3, 3);
  px(c, 1, 1, [174, 242, 255, 220]);
  px(c, 0, 1, [174, 242, 255, 90]); px(c, 2, 1, [174, 242, 255, 90]);
  px(c, 1, 0, [174, 242, 255, 90]); px(c, 1, 2, [174, 242, 255, 90]);
  return c;
}
function vignette() {
  const c = canvas(320, 180);
  for (let y = 0; y < 180; y++) for (let x = 0; x < 320; x++) {
    const dx = (x - 160) / 160, dy = (y - 90) / 90;
    const d = Math.sqrt(dx * dx + dy * dy);
    const a = Math.max(0, Math.min(0.85, (d - 0.55) / 0.65)) * 255;
    const i = (y * 320 + x) * 4;
    c.d[i] = 4; c.d[i + 1] = 8; c.d[i + 2] = 14; c.d[i + 3] = a;
  }
  return c;
}

// ---------- 背景（视差层） ----------
function bgSky() {
  const c = canvas(8, 360);
  for (let y = 0; y < 360; y++) {
    const t = y / 360;
    const r = Math.round(10 + t * 14), g = Math.round(16 + t * 24), b = Math.round(24 + t * 38);
    for (let x = 0; x < 8; x++) px(c, x, y, [r, g, b]);
  }
  return c;
}
function bgFar() {
  const c = canvas(640, 150);
  // 远景：残塔剪影（一眼即可复制的重复节构）
  const towers = [[20, 60, 26], [70, 110, 18], [130, 40, 30], [190, 90, 22], [260, 130, 16],
    [330, 70, 28], [400, 120, 20], [470, 50, 26], [540, 100, 24], [600, 60, 30]];
  for (const [x, h, w] of towers) {
    rect(c, x, 150 - h, w, h, [14, 24, 38]);
    rect(c, x + Math.floor(w / 2), 150 - h - 12, 2, 12, [14, 24, 38]);   // 天线
  }
  for (let i = 0; i < 40; i++) px(c, Math.floor(rnd() * 640), 150 - Math.floor(rnd() * 40), [20, 32, 50]);
  return c;
}
function bgMid() {
  const c = canvas(640, 120);
  // 中景：冻结的巨大声纹弧
  for (let k = 0; k < 5; k++) {
    const cx = 60 + k * 130, r = 26 + (k % 3) * 10;
    for (let a = 0; a < 180; a += 0.4) {
      const rad = a * Math.PI / 180;
      const x = cx + Math.cos(rad) * r, y = 118 - Math.sin(rad) * r * 0.8;
      if (x >= 0 && x < 640 && y >= 0) px(c, x, y, [28, 48, 72]);
    }
  }
  for (let i = 0; i < 60; i++) px(c, Math.floor(rnd() * 640), Math.floor(rnd() * 120), [24, 40, 62]);
  return c;
}

// ---------- 特质图标（12×12，按各特质特征绘制） ----------
function ring(c, cx, cy, r, col) {
  for (let a = 0; a < 360; a += 2) {
    const rad = a * Math.PI / 180;
    px(c, cx + Math.cos(rad) * r, cy + Math.sin(rad) * r, col);
  }
}
function traitIcon(id) {
  const c = canvas(12, 12);
  const T1 = P.traitMid, T2 = P.trait, TE = P.traitEdge;
  switch (id) {
    case "chuxiang":   // 初响：一滴声＋一圈余韵
      ellipse(c, 6, 6, 1.6, 1.6, T2); ring(c, 6, 6, 3.2, T1); px(c, 6, 1, [174, 242, 255, 180]);
      break;
    case "yingsheng":  // 应声：一声与它的回答
      ellipse(c, 4, 6, 1.5, 1.5, T2);
      ring(c, 8, 6, 2.2, [T1[0], T1[1], T1[2], 160]);
      ring(c, 8, 6, 3.8, [TE[0], TE[1], TE[2], 100]);
      break;
    case "zhongsheng": // 众声：三段重叠的声弧
      for (let k = 0; k < 3; k++) ring(c, 4 + k * 2, 6, 2.5 + k, [T1[0] - k * 20, T1[1], T1[2], 200 - k * 50]);
      break;
    case "xieyin":     // 谐音：两个交叠的音环
      ring(c, 4.5, 6, 3, T2); ring(c, 7.5, 6, 3, [T1[0], T1[1], T1[2], 170]);
      px(c, 6, 6, [232, 251, 255]);
      break;
    case "zhiyu":      // 止语：被封住的音（横杠封口）
      ellipse(c, 6, 6, 2.2, 2.2, T1);
      rect(c, 1, 5, 10, 2, TE);
      break;
    case "raoliang":   // 绕梁：绕梁不散的回声螺旋
      for (let a = 0; a < 720; a += 3) {
        const rad = a * Math.PI / 180, r = 0.5 + a / 720 * 4.5;
        px(c, 6 + Math.cos(rad) * r, 6 + Math.sin(rad) * r, T1);
      }
      break;
    case "shiyu":      // 失语的记忆：断裂的声纹＋悬着的半句
      for (let i = 0; i < 4; i++) px(c, 2 + i, 6 - (i % 2), T2);
      for (let i = 0; i < 3; i++) px(c, 8 + i, 6 + (i % 2), [T1[0], T1[1], T1[2], 140]);
      px(c, 6, 6, [232, 251, 255, 160]);
      break;
    case "yuansheng":  // 原声：源头之光（核心＋四射）
      ellipse(c, 6, 6, 2.4, 2.4, T2); ellipse(c, 6, 6, 1.2, 1.2, [255, 255, 255]);
      for (let a = 0; a < 4; a++) {
        const rad = a * Math.PI / 2 + Math.PI / 4;
        for (let t = 3.2; t <= 5; t += 0.5) px(c, 6 + Math.cos(rad) * t, 6 + Math.sin(rad) * t, T1);
      }
      break;
    case "pinlvshu":   // 频率梳：五根梳齿
      for (let i = 0; i < 5; i++) {
        const h = [4, 7, 9, 6, 3][i];
        rect(c, 1 + i * 2, 6 - Math.floor(h / 2), 1, h, i % 2 ? T1 : T2);
      }
      break;
    case "gongzhenqiang": // 共振腔：中空的同心腔体
      ring(c, 6, 6, 4.2, T2); ring(c, 6, 6, 2.4, T1);
      px(c, 6, 6, [232, 251, 255, 120]);
      break;
    case "moyin":      // 末音：渐弱的最后一个音
      px(c, 9, 6, [232, 251, 255, 230]);
      ellipse(c, 7, 6, 1.4, 1.4, T2);
      for (let i = 0; i < 4; i++) px(c, 5 - i, 6, [T1[0], T1[1], T1[2], 180 - i * 45]);
      break;
  }
  outline(c, P.outline);
  return c;
}

// ---------- 层级光环（R／SR／SSR／UR／HR）＋ 通用辉光 ----------
function tierRing(tier) {
  const c = canvas(28, 28);
  const C = { r: [150, 190, 205], sr: [110, 160, 255], ssr: [190, 130, 255],
    ur: [255, 150, 80], hr: [240, 240, 255] }[tier];
  ring(c, 14, 14, 11, C);
  if (tier !== "r") ring(c, 14, 14, 8.5, [C[0], C[1], C[2], 120]);          // SR 起：内环
  if (tier === "ssr" || tier === "ur" || tier === "hr") {                    // SSR 起：四枚辉点
    for (let a = 0; a < 4; a++) {
      const rad = a * Math.PI / 2 + Math.PI / 4;
      px(c, 14 + Math.cos(rad) * 11, 14 + Math.sin(rad) * 11, [255, 220, 140]);
    }
  }
  if (tier === "ur" || tier === "hr") {                                      // UR 起：轨道点
    for (let a = 0; a < 6; a++) {
      const rad = a / 6 * Math.PI * 2;
      px(c, 14 + Math.cos(rad) * 9.5, 14 + Math.sin(rad) * 9.5, [C[0], C[1], C[2]]);
    }
  }
  if (tier === "hr") {                                                       // HR：外射线
    for (let a = 0; a < 12; a++) {
      const rad = a / 12 * Math.PI * 2;
      for (let t = 12; t <= 13.8; t += 0.4)
        px(c, 14 + Math.cos(rad) * t, 14 + Math.sin(rad) * t, [C[0], C[1], C[2], 160]);
    }
  }
  return c;
}
function glow() {
  const c = canvas(24, 24);
  for (let y = 0; y < 24; y++) for (let x = 0; x < 24; x++) {
    const dx = (x - 12) / 12, dy = (y - 12) / 12;
    const d = Math.sqrt(dx * dx + dy * dy);
    px(c, x, y, [255, 255, 255, Math.max(0, 255 * (1 - d))]);
  }
  return c;
}

// ---------- 输出 ----------
if (require.main === module) {
  console.log("生成鸣响墟像素资产……");
  save(playerFrame(0, false), path.join(SPR, "player_idle.png"));
  save(playerFrame(1, false), path.join(SPR, "player_walk1.png"));
  save(playerFrame(2, false), path.join(SPR, "player_walk2.png"));
  save(playerFrame(3, false), path.join(SPR, "player_jump.png"));
  save(playerFrame(0, true), path.join(SPR, "player_voice.png"));
  save(enemyFrame(0, false), path.join(SPR, "enemy1.png"));
  save(enemyFrame(1, false), path.join(SPR, "enemy2.png"));
  save(enemyFrame(0, true), path.join(SPR, "enemy_charge.png"));
  save(bossFrame(), path.join(SPR, "boss_yuansheng.png"));
  save(traitDot(0), path.join(SPR, "trait_dot.png"));
  save(traitDot(1), path.join(SPR, "trait_dot2.png"));
  save(tileGroundTop(), path.join(SPR, "tile_ground_top.png"));
  save(tileGroundFill(), path.join(SPR, "tile_ground_fill.png"));
  save(tilePlatform(), path.join(SPR, "tile_platform.png"));
  save(tileTrail(), path.join(SPR, "tile_trail.png"));
  save(decoPillar(), path.join(SPR, "deco_pillar.png"));
  save(decoWave(0), path.join(SPR, "deco_wave1.png"));
  save(decoWave(1), path.join(SPR, "deco_wave2.png"));
  save(decoContainer(), path.join(SPR, "deco_container.png"));
  save(respawnLamp(), path.join(SPR, "lamp.png"));
  save(ripple(), path.join(SPR, "ripple.png"));
  save(waveShot(), path.join(SPR, "wave_shot.png"));
  save(particle(), path.join(SPR, "particle.png"));
  save(vignette(), path.join(BG, "vignette.png"));
  save(bgSky(), path.join(BG, "sky.png"));
  save(bgFar(), path.join(BG, "far.png"));
  save(bgMid(), path.join(BG, "mid.png"));
  console.log("  —— 特质图标（鸣响墟 11 枚）——");
  for (const id of ["chuxiang", "yingsheng", "zhongsheng", "xieyin", "zhiyu", "raoliang",
      "shiyu", "yuansheng", "pinlvshu", "gongzhenqiang", "moyin"]) {
    save(traitIcon(id), path.join(SPR, "icon_%s.png".replace("%s", id)));
  }
  console.log("  —— 层级光环（R／SR／SSR／UR／HR）——");
  for (const t of ["r", "sr", "ssr", "ur", "hr"]) {
    save(tierRing(t), path.join(SPR, "ring_%s.png".replace("%s", t)));
  }
  save(glow(), path.join(SPR, "glow.png"));
  console.log("完成。");
}
module.exports = { save, canvas, rect, ellipse, outline };
