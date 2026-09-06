// 《复调》鸣响墟垂直切片 —— 占位音频生成器（Node.js，仅标准库）。
// 生成：商调式 BGM（72BPM、8 小节、每 2 小节句末留换气口）＋ 音效表 WAV。
// 用法：node gen_audio.js   （输出到 ../assets/audio/）
// 正式主旋律将由 AI 依据背景与剧情创作后替换，保持 BPM 与换气点结构不变。
"use strict";
const fs = require("fs");
const path = require("path");

const RATE = 44100;
const OUT = path.join(__dirname, "..", "assets", "audio");

const N = {
  D3: 146.83, G3: 196.0, A3: 220.0,
  D4: 293.66, E4: 329.63, Fs4: 369.99, A4: 440.0, B4: 493.88,
  D5: 587.33, E5: 659.26, A5: 880.0,
};

function writeWav(file, samples) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const n = samples.length;
  const data = Buffer.alloc(44 + n * 2);
  data.write("RIFF", 0);
  data.writeUInt32LE(36 + n * 2, 4);
  data.write("WAVEfmt ", 8);
  data.writeUInt32LE(16, 16);
  data.writeUInt16LE(1, 20);        // PCM
  data.writeUInt16LE(1, 22);        // mono
  data.writeUInt32LE(RATE, 24);
  data.writeUInt32LE(RATE * 2, 28); // byte rate
  data.writeUInt16LE(2, 32);
  data.writeUInt16LE(16, 34);
  data.write("data", 36);
  data.writeUInt32LE(n * 2, 40);
  for (let i = 0; i < n; i++) {
    const s = Math.max(-1, Math.min(1, samples[i]));
    data.writeInt16LE(Math.round(s * 32767), 44 + i * 2);
  }
  fs.writeFileSync(file, data);
  console.log("  wrote", file, (n / RATE).toFixed(2), "s");
}

function silence(dur) { return new Array(Math.round(RATE * dur)).fill(0); }

function tone(freq, dur, vol = 0.5, kind = "sine", attack = 0.01, release = 0.15) {
  const n = Math.round(RATE * dur), out = [];
  for (let i = 0; i < n; i++) {
    const t = i / RATE;
    let e = 1.0;
    if (t < attack) e = t / attack;
    if (dur - t < release) e = Math.min(e, (dur - t) / release);
    let s = Math.sin(2 * Math.PI * freq * t);
    if (kind === "tri") s = (2 / Math.PI) * Math.asin(s);
    else if (kind === "soft") s = (s + 0.35 * Math.sin(2 * Math.PI * freq * 2 * t)) * 0.75;
    out.push(s * vol * e);
  }
  return out;
}

function noise(dur, vol = 0.4, decay = 6.0) {
  const n = Math.round(RATE * dur), out = [];
  for (let i = 0; i < n; i++) out.push((Math.random() * 2 - 1) * vol * Math.exp(-decay * i / RATE));
  return out;
}

function mix(dest, src, at) {
  for (let i = 0; i < src.length; i++) {
    const j = at + i;
    if (0 <= j && j < dest.length) dest[j] += src[i];
  }
  return dest;
}

function cat(parts) { const out = []; for (const p of parts) out.push(...p); return out; }

// ---------- BGM：鸣响墟（商调式碎片化变奏，72BPM，8 小节） ----------
function genBgm() {
  const beat = 60 / 72, bar = beat * 4;
  const total = Math.round(RATE * bar * 8);
  const buf = new Array(total).fill(0);
  mix(buf, tone(N.D3, bar * 8, 0.10, "sine", 0.5, 1.0), 0);   // 低音持续音
  const melody = [
    "D4", "E4", "Fs4", 0, 0, 0, 0, 0,
    "A4", "B4", "A4", 0, 0, 0, 0, 0,
    "D5", "B4", "A4", 0, 0, 0, 0, 0,
    "Fs4", "E4", "D4", 0, 0, 0, 0, 0];
  const step = beat / 2;
  melody.forEach((name, i) => {
    if (name === 0) return;
    mix(buf, tone(N[name], step * 1.6, 0.30, "soft", 0.01, 0.10), Math.round(RATE * step * i));
  });
  for (let b = 0; b < 32; b++) {
    if (b % 2 === 0) mix(buf, noise(0.05, 0.08, 40), Math.round(RATE * beat * b));
  }
  const d = Math.round(RATE * 0.28), echo = buf.slice();
  for (let i = 0; i < buf.length; i++) if (i + d < echo.length) echo[i + d] += buf[i] * 0.25;
  writeWav(path.join(OUT, "bgm_mingxiangxu.wav"), echo);
}

// ---------- 音效表 ----------
function genSfx() {
  const dir = path.join(OUT, "sfx");
  const collects = ["D5", "E5", "Fs4", "A4", "B4"];
  collects.forEach((name, i) => {
    const f = N[name] || N.D5;
    writeWav(path.join(dir, `collect${i + 1}.wav`), tone(f, 0.35, 0.45, "soft", 0.005, 0.25));
  });
  const n = Math.round(RATE * 0.25);
  const rel = [];
  for (let i = 0; i < n; i++) { const t = i / RATE, f = 520 - 260 * (i / n); rel.push(Math.sin(2 * Math.PI * f * t) * 0.4 * (1 - i / n)); }
  writeWav(path.join(dir, "voice_release.wav"), rel);
  const abs = [];
  for (let i = 0; i < n; i++) { const t = i / RATE, f = 260 + 260 * (i / n); abs.push(Math.sin(2 * Math.PI * f * t) * 0.35 * (i / n)); }
  writeWav(path.join(dir, "voice_absorb.wav"), abs);
  writeWav(path.join(dir, "voice_tough.wav"), tone(N.D3, 0.22, 0.5, "tri", 0.005, 0.12));
  let chord = new Array(Math.round(RATE * 0.6)).fill(0);
  for (const [f, v] of [[N.D4, 0.3], [N.A4, 0.22], [N.D5, 0.18]]) mix(chord, tone(f, 0.6, v, "soft", 0.01, 0.35), 0);
  writeWav(path.join(dir, "tune_ok.wav"), chord);
  writeWav(path.join(dir, "shatter.wav"), noise(0.45, 0.5, 9));
  let dis = new Array(Math.round(RATE * 0.15)).fill(0);
  mix(dis, tone(233.08, 0.15, 0.35, "sine", 0.005, 0.08), 0);
  mix(dis, tone(246.94, 0.15, 0.35, "sine", 0.005, 0.08), 0);
  writeWav(path.join(dir, "hurt.wav"), dis);
  let rs = new Array(Math.round(RATE * 0.7)).fill(0);
  mix(rs, tone(N.D4, 0.7, 0.28, "soft", 0.01, 0.4), 0);
  mix(rs, tone(N.D5, 0.7, 0.2, "soft", 0.01, 0.4), 0);
  writeWav(path.join(dir, "respawn.wav"), rs);
}

if (require.main === module) {
  console.log("生成占位音频（正式主旋律将由 AI 依据背景与剧情创作后替换）……");
  genBgm();
  genSfx();
  console.log("完成。");
}
module.exports = { genBgm, genSfx };
