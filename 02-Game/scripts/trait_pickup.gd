extends Area2D
## 特质光点（层级呈现版＋收集条件版）：
##   世界呈现＝专属图标 + 层级光环（逐级递进的体量／环饰／脉冲）——不用文字标签，
##   层级类型与介绍文本只在收集后的特质卡里揭示。
##   收集条件（req，按《五关开发计划》各关"获取语法"）：
##     ""        触碰即得（初响／末音／失语的记忆等位置型）
##     "detect"  共鸣探测显形——平时几乎隐形，探测波及才凝出实体数秒（众声／绕梁）
##     "silence" 静默等待——玩家持续不出声且站定才允许收集（止语：它在等你不说话）
##     "machine" 回声机音序应答解锁（频率梳）
##     "tune"    属性配平解锁（共振腔）

var trait_id := ""
var tier := "normal"
var visible_after_count := 0
var req := ""
var reveal_t := 0.0      # detect 显形剩余时间
var unlocked := false    # machine／tune 解锁标记
var hint_cd := 0.0
var _collected := false
var anim_t := 0.0

const TIER_SCALE := {"normal": 0.9, "key": 1.05, "core": 1.2, "edge": 1.2, "hidden": 1.45}
const TIER_PULSE := {"normal": 0.06, "key": 0.09, "core": 0.12, "edge": 0.12, "hidden": 0.16}
const HIDDEN_ALPHA := 0.10

var sprite: Sprite2D
var aura: Sprite2D
var ring: Sprite2D

func _ready() -> void:
	add_to_group("pickups")
	collision_layer = 0
	collision_mask = 1
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 16.0
	cs.shape = sh
	add_child(cs)

	tier = GameState.trait_tier(trait_id)
	var tcol: Color = GameState.TIER_COLOR[tier]
	var tier_scale: float = TIER_SCALE[tier]

	# 层级辉光（底层，按层级着色与放大）
	aura = Sprite2D.new()
	aura.texture = load("res://assets/sprites/glow.png")
	aura.modulate = Color(tcol.r, tcol.g, tcol.b, 0.55)
	aura.scale = Vector2(1.6, 1.6) * tier_scale
	add_child(aura)
	# 层级光环
	ring = Sprite2D.new()
	ring.texture = load("res://assets/sprites/ring_%s.png" % GameState.TIER_TAG[tier])
	ring.scale = Vector2(tier_scale, tier_scale)
	add_child(ring)
	# 专属图标
	sprite = Sprite2D.new()
	var icon_path := "res://assets/sprites/icon_%s.png" % trait_id
	sprite.texture = load(icon_path) if ResourceLoader.exists(icon_path) else load("res://assets/sprites/trait_dot.png")
	sprite.scale = Vector2(1.5, 1.5) * tier_scale
	add_child(sprite)

	if visible_after_count > 0:
		modulate.a = 0.15
	elif req == "detect":
		modulate.a = HIDDEN_ALPHA   # 未探测：几乎隐形
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	anim_t += delta
	hint_cd = maxf(hint_cd - delta, 0.0)
	# 解锁／显形可能发生在玩家已站进判定圈之后（body_entered 不会重发）——轮询兜底
	if _collectible_now():
		for b in get_overlapping_bodies():
			if b.is_in_group("player"):
				_do_collect()
				return
	# detect 显形倒计时
	if req == "detect" and reveal_t > 0.0:
		reveal_t -= delta
		modulate.a = 1.0 if reveal_t > 0.6 else maxf(reveal_t / 0.6, HIDDEN_ALPHA)
	# 呼吸脉冲：层级越高越明显
	var strength: float = TIER_PULSE[tier]
	var s := 1.0 + sin(anim_t * 2.4) * strength
	ring.scale = Vector2(s, s) * TIER_SCALE[tier]
	aura.modulate.a = 0.4 + 0.2 * sin(anim_t * 1.7)

## 共鸣探测：波及时凝出实体数秒
func reveal_by_detect() -> void:
	if req != "detect" or _collectible_now():
		return
	reveal_t = 4.0

## 回声机／空腔解锁
func set_unlocked() -> void:
	unlocked = true
	modulate.a = 1.0

func _collectible_now() -> bool:
	if visible_after_count > 0 and GameState.collected.size() < visible_after_count:
		return false
	match req:
		"detect":
			return reveal_t > 0.0
		"silence":
			var players := get_tree().get_nodes_in_group("player")
			if players.is_empty():
				return false
			var p = players[0]
			return p.quiet_t > 3.0 and absf(p.velocity.x) < 5.0 and p.is_on_floor()
		"machine", "tune":
			return unlocked
	return true

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if not _collectible_now():
		_hint()
		return
	_do_collect()

func _do_collect() -> void:
	if _collected:
		return
	_collected = true
	GameState.collect(trait_id)
	var n := clampi(GameState.collected.size(), 1, 5)
	AudioDirector.sfx_play("collect%d" % n)
	queue_free()

func _hint() -> void:
	if hint_cd > 0.0:
		return
	hint_cd = 4.0
	var m := get_tree().get_first_node_in_group("main")
	if m == null:
		return
	match req:
		"detect":
			m.call("hint", "杂音里什么也抓不住——用共鸣探测（F），从众声里把它听出来。")
		"silence":
			m.call("hint", "它不躲你。它只是在等你不说话——站定，安静。")
		"machine":
			m.call("hint", "回声机还没有认可你。先用它的音序回答它。")
		"tune":
			m.call("hint", "空腔还在等。它要的是和你声部槽里一模一样的组合。")
		_:
			if visible_after_count > 0:
				m.call("hint", "（它还没显形——也许在等另一个声音与它同时在场。）")
