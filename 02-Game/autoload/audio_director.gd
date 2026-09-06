extends Node
## 音频总监：总线（失声＝低通下沉）、BGM 时钟（拍／换气点信号）、音效播放。
## 切片阶段使用脚本生成的占位 WAV；正式主旋律由 AI 创作后同路径替换。

signal beat(index: int)
signal breath(index: int)

const BPM := 72.0
const BEATS_PER_BAR := 4
const BREATH_EVERY_BEATS := 8   # 每 2 小节一个换气点（调声输入窗口）

var music_player: AudioStreamPlayer
var sfx: Dictionary = {}
var _time := 0.0
var _last_beat := -1
var _lowpass: AudioEffectLowPassFilter

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # 暂停时音乐与音频时钟继续（长椅式喘息）
	_setup_buses()
	_load_sfx()
	_start_bgm()
	GameState.chaos_changed.connect(_on_chaos_changed)

func _setup_buses() -> void:
	# Music / SFX 总线；Master 挂低通（失声＝世界对你静音）
	var i := AudioServer.bus_count
	AudioServer.add_bus(i)
	AudioServer.set_bus_name(i, "Music")
	i = AudioServer.bus_count
	AudioServer.add_bus(i)
	AudioServer.set_bus_name(i, "SFX")
	_lowpass = AudioEffectLowPassFilter.new()
	_lowpass.cutoff_hz = 15000.0
	AudioServer.add_bus_effect(0, _lowpass)   # bus 0 = Master

func set_deafness(x: float) -> void:
	if _lowpass:
		_lowpass.cutoff_hz = lerpf(15000.0, 320.0, clampf(x, 0.0, 1.0))

func _on_chaos_changed(v: float) -> void:
	set_deafness(v / GameState.CHAOS_MAX)

func set_music_duck(on: bool) -> void:
	if music_player:
		music_player.volume_db = -14.0 if on else 0.0

func _load_sfx() -> void:
	var names := [
		"collect1", "collect2", "collect3", "collect4", "collect5",
		"voice_release", "voice_absorb", "voice_tough",
		"tune_ok", "shatter", "hurt", "respawn",
	]
	for n in names:
		var p := "res://assets/audio/sfx/%s.wav" % n
		if ResourceLoader.exists(p):
			sfx[n] = load(p)

func _start_bgm() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	var p := "res://assets/audio/bgm_mingxiangxu.wav"
	if ResourceLoader.exists(p):
		var stream: AudioStreamWAV = load(p)
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / 2   # 16-bit mono：2 字节一帧
		music_player.stream = stream
	add_child(music_player)
	music_player.play()

func _process(_delta: float) -> void:
	if music_player == null or music_player.stream == null or not music_player.playing:
		return
	_time = music_player.get_playback_position() + AudioServer.get_time_since_last_mix()
	var beat_len := 60.0 / BPM
	var b := int(_time / beat_len)
	if b != _last_beat:
		_last_beat = b
		beat.emit(b)
		if b % BREATH_EVERY_BEATS == 0:
			breath.emit(b / BREATH_EVERY_BEATS)

## 换气点窗口：距换气点 ±0.4s 内可调声（站立限制在玩家侧判断）
func breath_window_open() -> bool:
	if music_player == null or music_player.stream == null:
		return false
	var beat_len := 60.0 / BPM
	var period := beat_len * BREATH_EVERY_BEATS
	var phase := fmod(_time, period)
	return phase < 0.4 or phase > period - 0.4

func sfx_play(name: String) -> void:
	if not sfx.has(name):
		return
	var p := AudioStreamPlayer.new()
	p.bus = "SFX"
	p.stream = sfx[name]
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
