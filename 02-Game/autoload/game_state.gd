extends Node
## 全局状态（切片版）：失调、特质收集、声部槽、击碎记录、回响点。
## 完整设计见 01-Docs/复调_设计文档.md 第四节与第九节。

signal chaos_changed(value: float)
signal slots_changed
signal trait_collected(id: String)
signal blackout_started

const CHAOS_MAX := 100.0
# 切片：声部槽上限 3（断章塔核心后升为 4）
const SLOT_CAP := 3

# 切片特质集合（tier：normal普通=R／key关键=SR／core核心=SSR／edge边缘=UR／hidden隐藏=HR；
#               intro＝获得时展示的介绍文本）
const TRAITS := {
	"chuxiang":   {"name": "初响", "tier": "normal", "energy": "release", "structure": "mid",     "tempo": "fast",
		"intro": "全游戏捡起的第一个声音。它在你手里落定，像一直在那里等着。"},
	"zhongsheng": {"name": "众声", "tier": "normal", "energy": "release", "structure": "fragile", "tempo": "mid",
		"intro": "几百个声音挤在一起。你现在能从里面认出一个来了。"},
	"xieyin":     {"name": "谐音", "tier": "normal", "energy": "neutral", "structure": "mid",     "tempo": "fast",
		"intro": "两个声音叠在一起时，第三个声音出现了。"},
	"zhiyu":      {"name": "止语", "tier": "normal", "energy": "neutral", "structure": "tough",   "tempo": "slow",
		"intro": "它不响。它替你听着。"},
	"raoliang":   {"name": "绕梁", "tier": "normal", "energy": "absorb",  "structure": "tough",   "tempo": "slow",
		"intro": "声音不散。它绕着梁，一圈一圈，回到你身边。"},
	"pinlvshu":   {"name": "频率梳", "tier": "key", "energy": "release", "structure": "mid",  "tempo": "fast",
		"intro": "一把梳子，梳开噪声，露出藏着的音。"},
	"gongzhenqiang": {"name": "共振腔", "tier": "key", "energy": "release", "structure": "tough", "tempo": "mid",
		"intro": "它在等一个一模一样的声音。你配出来了。"},
	"moyin":      {"name": "末音", "tier": "edge", "energy": "neutral", "structure": "fragile", "tempo": "slow",
		"intro": "整个废墟最后一个还在响的音。你从喧啸里把它摘了下来。"},
	"shiyu":      {"name": "失语的记忆", "tier": "hidden", "energy": "release", "structure": "mid", "tempo": "slow",
		"intro": "一句没能说出口的话。它现在跟着你。"},
	"yuansheng":  {"name": "原声", "tier": "core", "energy": "release", "structure": "tough", "tempo": "mid",
		"intro": "所有声音的源头。你把它捡了起来——像捡起自己。"},
}

# 层级呈现：R／SR／SSR／UR／HR（世界呈现与标签用；品质“稳定性／组合宽度”仍正交）
const TIER_TAG := {"normal": "R", "key": "SR", "core": "SSR", "edge": "UR", "hidden": "HR"}
const TIER_NAME := {"normal": "普通", "key": "关键", "core": "核心", "edge": "边缘", "hidden": "隐藏"}
const TIER_COLOR := {
	"normal": Color(0.55, 0.78, 0.88),
	"key": Color(0.45, 0.68, 1.0),
	"core": Color(0.82, 0.6, 1.0),
	"edge": Color(1.0, 0.66, 0.35),
	"hidden": Color(0.92, 0.88, 1.0),
}

func trait_tier(id: String) -> String:
	return String(TRAITS[id]["tier"]) if TRAITS.has(id) else "normal"

var chaos := 0.0
var chaos_base := 0.0
var collected: Array[String] = []
var slots: Array[String] = ["chuxiang", "", ""]
var respawn_point := Vector2(100, 890)
var tune_ok_count := 0
var purify_count := 0
var shatter_count := 0
var lib_open := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # 暂停时仍服务（库面板等）
	_setup_input()

# ---------- 输入（代码注册，避免 project.godot 序列化兼容问题） ----------
func _setup_input() -> void:
	_add_action("move_left",   [KEY_A, KEY_LEFT])
	_add_action("move_right",  [KEY_D, KEY_RIGHT])
	_add_action("move_up",     [KEY_W, KEY_UP])
	_add_action("move_down",   [KEY_S, KEY_DOWN])
	_add_action("jump",        [KEY_SPACE])
	_add_action("detect",      [KEY_F])
	_add_action("interact",    [KEY_E])
	_add_action("tune_beat",   [KEY_ENTER, KEY_E])
	_add_action("library",     [KEY_TAB])
	_add_action("drop",        [KEY_Q])
	# Xbox 手柄（布局以 XBOX 手柄为准）
	_add_joy("move_left",   [JOY_BUTTON_DPAD_LEFT],  [[JOY_AXIS_LEFT_X, -1.0]])
	_add_joy("move_right",  [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]])
	_add_joy("move_up",     [JOY_BUTTON_DPAD_UP],    [[JOY_AXIS_LEFT_Y, -1.0]])
	_add_joy("move_down",   [JOY_BUTTON_DPAD_DOWN],  [[JOY_AXIS_LEFT_Y, 1.0]])
	_add_joy("jump",        [JOY_BUTTON_A], [])
	_add_joy("voice_1",     [JOY_BUTTON_X], [])
	_add_joy("voice_2",     [JOY_BUTTON_B], [])
	_add_joy("voice_3",     [JOY_BUTTON_Y], [])
	_add_joy("tune_beat",   [JOY_BUTTON_RIGHT_SHOULDER], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]])
	_add_joy("detect",      [JOY_BUTTON_LEFT_SHOULDER],  [[JOY_AXIS_TRIGGER_LEFT, 1.0]])
	_add_joy("library",     [JOY_BUTTON_START], [])

func _add_joy(action: String, buttons: Array, axes: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for b in buttons:
		var ev := InputEventJoypadButton.new()
		ev.button_index = b
		InputMap.action_add_event(action, ev)
	for a in axes:
		var ev2 := InputEventJoypadMotion.new()
		ev2.axis = a[0]
		ev2.axis_value = a[1]
		InputMap.action_add_event(action, ev2)
	_add_action("voice_1",     [KEY_J])
	_add_action("voice_2",     [KEY_K])
	_add_action("voice_3",     [KEY_L])

func _add_action(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)

# ---------- 收集 ----------
func collect(id: String) -> void:
	if id in collected:
		return
	collected.append(id)
	for i in range(slots.size()):
		if slots[i] == "":
			slots[i] = id
			break
	recalc_base()
	trait_collected.emit(id)
	slots_changed.emit()

func has_trait(id: String) -> bool:
	return id in collected

func trait_name(id: String) -> String:
	return String(TRAITS[id]["name"]) if TRAITS.has(id) else id

func trait_intro(id: String) -> String:
	return String(TRAITS[id]["intro"]) if TRAITS.has(id) else ""

func trait_attr(id: String, dim: String) -> String:
	return String(TRAITS[id][dim]) if TRAITS.has(id) else "mid"

# ---------- 声部槽 ----------
func slot_trait(i: int) -> String:
	return slots[i] if i < slots.size() else ""

## 将库中选中的特质装进指定声部槽（Tab 库面板使用）
func equip(slot: int, id: String) -> void:
	if slot < 0 or slot >= slots.size() or not (id in collected):
		return
	slots[slot] = id
	recalc_base()
	slots_changed.emit()

## 卸下指定声部槽（空位类挑战需要）
func clear_slot(slot: int) -> void:
	if slot < 0 or slot >= slots.size():
		return
	slots[slot] = ""
	recalc_base()
	slots_changed.emit()

func equipped_ids() -> Array:
	var out := []
	for s in slots:
		if s != "":
			out.append(s)
	return out

# ---------- 失调 ----------
## 基底：每对同向属性 +8（中性豁免）。维度：energy / structure / tempo。
func recalc_base() -> void:
	var base := 0.0
	for dim in ["energy", "structure", "tempo"]:
		var counts := {}
		for id in equipped_ids():
			var v := trait_attr(id, dim)
			if v == "neutral":
				continue
			counts[v] = counts.get(v, 0) + 1
		for v in counts:
			var c: int = counts[v]
			base += 8.0 * float(c * (c - 1) / 2)
	chaos_base = base

func base_value() -> float:
	return chaos_base

func add_chaos(amount: float) -> void:
	chaos = clampf(chaos + amount, 0.0, CHAOS_MAX)
	chaos_changed.emit(chaos)
	if chaos >= CHAOS_MAX:
		blackout_started.emit()

func vent() -> void:
	add_chaos(-12.0)

## 实际可用声部数：40→失一声 60→失两声 80→只剩一声
func available_slots() -> int:
	if chaos >= 80.0:
		return 1
	elif chaos >= 60.0:
		return 1 if SLOT_CAP <= 2 else SLOT_CAP - 2
	elif chaos >= 40.0:
		return SLOT_CAP - 1
	return SLOT_CAP

# ---------- 失声重置（无死亡） ----------
func do_blackout_reset() -> void:
	chaos = 30.0
	chaos_changed.emit(chaos)
