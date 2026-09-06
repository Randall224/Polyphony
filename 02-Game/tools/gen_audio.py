# -*- coding: utf-8 -*-
"""《复调》鸣响墟垂直切片 —— 占位音频生成器（仅标准库）。
生成：商调式 BGM（72BPM、8 小节、每 2 小节句末留换气口）＋ 音效表 WAV。
用法：python gen_audio.py   （输出到 ../assets/audio/）
正式主旋律将由 AI 依据背景与剧情创作后替换，保持 BPM 与换气点结构不变。
"""
import wave, struct, math, random, os

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")

# D 宫商调式音高（商为中心 → 商调式：以 D 为宫音阶的第二音，此处取 D 五声集合便于听感）
N = {
    "D3": 146.83, "G3": 196.00, "A3": 220.00,
    "D4": 293.66, "E4": 329.63, "Fs4": 369.99, "A4": 440.00, "B4": 493.88,
    "D5": 587.33, "E5": 659.26, "A5": 880.00,
}

def write_wav(path, samples):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = b"".join(struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in samples)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)
    print("  wrote", path, len(samples) / RATE, "s")

def silence(dur):
    return [0.0] * int(RATE * dur)

def tone(freq, dur, vol=0.5, kind="sine", attack=0.01, release=0.15):
    n = int(RATE * dur)
    out = []
    for i in range(n):
        t = i / RATE
        e = 1.0
        if t < attack:
            e = t / attack
        if dur - t < release:
            e = min(e, (dur - t) / release)
        s = math.sin(2 * math.pi * freq * t)
        if kind == "tri":
            s = 2 / math.pi * math.asin(s)
        elif kind == "soft":
            s = (s + 0.35 * math.sin(2 * math.pi * freq * 2 * t)) * 0.75
        out.append(s * vol * e)
    return out

def mix(dest, src, at):
    for i, s in enumerate(src):
        j = at + i
        if 0 <= j < len(dest):
            dest[j] += s

def cat(parts):
    out = []
    for p in parts:
        out.extend(p)
    return out

def noise(dur, vol=0.4, decay=6.0):
    n = int(RATE * dur)
    return [random.uniform(-1, 1) * vol * math.exp(-decay * i / RATE) for i in range(n)]

# ---------- BGM：鸣响墟（商调式碎片化变奏，72BPM，8 小节） ----------
def gen_bgm():
    beat = 60.0 / 72.0                      # 0.8333s
    bar = beat * 4
    total = int(RATE * bar * 8)
    buf = [0.0] * total
    # 低音持续音（D2 邻近的 D3）——极简铺垫
    mix(buf, tone(N["D3"], bar * 8, 0.10, "sine", 0.5, 1.0), 0)
    # 动机碎片（每个乐句只出现动机前三个音：D E Fs），句末留一个休止＝换气口
    melody = ["D4", "E4", "Fs4", 0,  0, 0, 0, 0,
              "A4", "B4", "A4", 0,  0, 0, 0, 0,
              "D5", "B4", "A4", 0,  0, 0, 0, 0,
              "Fs4", "E4", "D4", 0,  0, 0, 0, 0]
    step = beat / 2                          # 半拍一格
    for i, name in enumerate(melody):
        if name == 0:
            continue
        mix(buf, tone(N[name], step * 1.6, 0.30, "soft", 0.01, 0.10), int(RATE * step * i))
    # 节拍点：编钟感的轻击
    for b in range(32):
        if b % 2 == 0:
            mix(buf, noise(0.05, 0.08, 40.0), int(RATE * beat * b))
    # 混响感：把整体做一个简单延迟叠加
    echo = buf[:]
    d = int(RATE * 0.28)
    for i, s in enumerate(buf):
        if i + d < len(echo):
            echo[i + d] += s * 0.25
    write_wav(os.path.join(OUT, "bgm_mingxiangxu.wav"), echo)

# ---------- 音效表 ----------
def gen_sfx():
    sfx_dir = os.path.join(OUT, "sfx")
    # 收集：D 商五声音阶上行（D E Fs A B）
    for i, name in enumerate(["D5", "E5", "Fs4", "A4", "B4"]):
        key = "collect%d" % (i + 1)
        f = N[name] if name in N else 587.33
        write_wav(os.path.join(sfx_dir, key + ".wav"), tone(f, 0.35, 0.45, "soft", 0.005, 0.25))
    # 发音：释放（下行扫描波）
    n = int(RATE * 0.25)
    rel = []
    for i in range(n):
        t = i / RATE
        f = 520 - 260 * (i / n)
        rel.append(math.sin(2 * math.pi * f * t) * 0.4 * (1 - i / n))
    write_wav(os.path.join(sfx_dir, "voice_release.wav"), rel)
    # 吸收（上行扫描）
    abs_ = []
    for i in range(n):
        t = i / RATE
        f = 260 + 260 * (i / n)
        abs_.append(math.sin(2 * math.pi * f * t) * 0.35 * (i / n))
    write_wav(os.path.join(sfx_dir, "voice_absorb.wav"), abs_)
    # 坚韧（低沉顿音）
    write_wav(os.path.join(sfx_dir, "voice_tough.wav"), tone(N["D3"], 0.22, 0.5, "tri", 0.005, 0.12))
    # 调音/调声成功：干净正拍主和弦（D + A + D5）
    chord = [0.0] * int(RATE * 0.6)
    for f, v in [(N["D4"], 0.3), (N["A4"], 0.22), (N["D5"], 0.18)]:
        mix(chord, tone(f, 0.6, v, "soft", 0.01, 0.35), 0)
    write_wav(os.path.join(sfx_dir, "tune_ok.wav"), chord)
    # 击碎/爆发：白噪声爆裂
    write_wav(os.path.join(sfx_dir, "shatter.wav"), noise(0.45, 0.5, 9.0))
    # 受击：不协和短音
    dis = [0.0] * int(RATE * 0.15)
    mix(dis, tone(233.08, 0.15, 0.35, "sine", 0.005, 0.08), 0)
    mix(dis, tone(246.94, 0.15, 0.35, "sine", 0.005, 0.08), 0)
    write_wav(os.path.join(sfx_dir, "hurt.wav"), dis)
    # 回响点激活：D4 + D5 轻和音
    rs = [0.0] * int(RATE * 0.7)
    mix(rs, tone(N["D4"], 0.7, 0.28, "soft", 0.01, 0.4), 0)
    mix(rs, tone(N["D5"], 0.7, 0.2, "soft", 0.01, 0.4), 0)
    write_wav(os.path.join(sfx_dir, "respawn.wav"), rs)

if __name__ == "__main__":
    random.seed(7)
    print("生成占位音频（正式主旋律将由 AI 依据背景与剧情创作后替换）……")
    gen_bgm()
    gen_sfx()
    print("完成。")
