extends Node2D
## 鸣响墟垂直切片（横版·有重力）：左→右的剖面长卷，落差用平台／竖井／桥断口表达。
## 剖面：苏醒谷地 → 教学战 → 噪声区碎石上行 → 谐音桥（断口下是深谷，坠而不死）
##   → 止语凹地（低伏盆地）→ 回声环（竖井下探·绕梁在井底）→ 共鸣厅（高台）
##   → 轰鸣带（更高的喧啸脊地·末音在台上）→ 幻声林地（裂谷双梯）→ 声骸之海（洼地 Boss）→ 断章塔阶（上行出口）。
## 特质×10（9 颗 Pickup＋原声 Boss 掉落）；资产由 tools/gen_art.js 生成。

const WORLD_W := 4800.0
const WORLD_H := 1400.0

var player: CharacterBody2D
var hud: CanvasLayer
var blackout: ColorRect
var boss: CharacterBody2D
var boss_phase := 0
var ended := false
var T := {}
var cam: Camera2D
var shake_amount := 0.0
var hit_stop_id := 0

func _ready() -> void:
	add_to_group("main")
	for p in ["tile_ground_top", "tile_ground_fill", "tile_platform", "tile_trail",
			"deco_pillar", "deco_wave1", "deco_wave2", "deco_container", "lamp",
			"ripple", "wave_shot", "particle", "trait_dot", "trait_dot2",
			"icon_chuxiang", "icon_zhongsheng", "icon_xieyin",
			"icon_zhiyu", "icon_raoliang", "icon_shiyu", "icon_yuansheng",
			"icon_pinlvshu", "icon_gongzhenqiang", "icon_moyin"]:
		T[p] = load("res://assets/sprites/%s.png" % p)
	_build_background()
	_build_world()
	_spawn_player()
	_build_hud()
	_show_intro()
	GameState.blackout_started.connect(_on_blackout)
	GameState.trait_collected.connect(_on_trait_collected)

# ---------- 背景 ----------
func _build_background() -> void:
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -10
	var sky := TextureRect.new()
	sky.texture = load("res://assets/bg/sky.png")
	sky.size = Vector2(640, 360)
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky_layer.add_child(sky)
	add_child(sky_layer)

	var par := ParallaxBackground.new()
	var far_layer := ParallaxLayer.new()
	far_layer.motion_scale = Vector2(0.25, 0.25)
	far_layer.motion_mirroring = Vector2(640, 0)
	var far := Sprite2D.new()
	far.texture = load("res://assets/bg/far.png")
	far.centered = false
	far.position = Vector2(0, 420)
	far_layer.add_child(far)
	par.add_child(far_layer)
	add_child(par)

	# 渐盲晕影
	var vig_layer := CanvasLayer.new()
	vig_layer.layer = 7
	var vig := TextureRect.new()
	vig.texture = load("res://assets/bg/vignette.png")
	vig.size = Vector2(640, 360)
	vig_layer.add_child(vig)
	add_child(vig_layer)

	# 氛围粒子（声尘）——止语凹地不放（那里连尘埃都静了）
	for c in [[300, 700], [1000, 700], [2800, 600], [4100, 700]]:
		var p := CPUParticles2D.new()
		p.texture = T["particle"]
		p.amount = 26
		p.lifetime = 8.0
		p.preprocess = 8.0
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(420, 280)
		p.position = Vector2(c[0], c[1])
		p.gravity = Vector2(0, -4)
		p.initial_velocity_min = 3.0
		p.initial_velocity_max = 10.0
		p.color = Color(0.6, 0.85, 0.95, 0.3)
		add_child(p)

# ---------- 关卡构建（横版剖面） ----------
func _build_world() -> void:
	# ---- 外边界 ----
	_slab(-40, -40, WORLD_W + 80, 100, Color(0.13, 0.18, 0.27))       # 顶
	_slab(-40, 1340, WORLD_W + 80, 100, Color(0.13, 0.18, 0.27))      # 底（安全底线）
	_slab(-40, -40, 100, WORLD_H + 80, Color(0.13, 0.18, 0.27))       # 左
	_slab(4740, -40, 100, WORLD_H + 80, Color(0.13, 0.18, 0.27))      # 右

	# ---- 地形（实心地块，顶面即地表）----
	var ground := Color(0.10, 0.14, 0.20)
	_slab(-40, 940, 1600, 460, ground)        # 苏醒谷地＋教学＋噪声区基岩（x 至 1560）
	_slab(1560, 880, 180, 320, ground)        # 谐音桥西段（桥墩落地）
	_slab(1560, 1200, 350, 200, Color(0.06, 0.09, 0.14))   # 桥下深谷底（坠落缓冲，东行可爬回）
	_slab(1830, 880, 80, 40, ground)          # 谐音桥东段（断口东侧悬段）
	_slab(1910, 1000, 340, 400, ground)       # 止语凹地（低伏盆地）
	_slab(2250, 940, 130, 460, ground)        # 回声环井沿
	_slab(2380, 1280, 260, 120, Color(0.05, 0.08, 0.12))   # 井底
	_slab(2640, 900, 410, 500, ground)        # 共鸣厅地面
	_slab(3050, 800, 400, 600, ground)        # 轰鸣带脊地
	_slab(3210, 700, 170, 100, ground)        # 轰鸣带高台（末音悬于其上）
	_slab(3450, 940, 170, 460, ground)        # 幻声林地地面
	_slab(3620, 1240, 180, 160, Color(0.05, 0.08, 0.12))   # 裂谷底
	_slab(3800, 980, 600, 420, ground)        # 声骸之海洼地
	_slab(4400, 920, 100, 480, ground)        # 塔阶一
	_slab(4500, 860, 100, 540, ground)        # 塔阶二
	_slab(4600, 800, 200, 600, ground)        # 塔阶三（出口）

	# ---- 平台（碎石／井梯／踏步，全部单向——可从下方跳穿，消除"跳不上去"）----
	var plat := Color(0.16, 0.21, 0.30)
	# 噪声区碎石上行
	_slab(1130, 880, 110, 26, plat, true)
	_slab(1290, 820, 110, 26, plat, true)
	_slab(1400, 760, 110, 26, plat, true)
	# 桥下深谷回程梯（坠落者的路）
	_slab(1835, 1140, 75, 26, plat, true)
	_slab(1845, 1080, 60, 26, plat, true)
	_slab(1855, 1020, 50, 26, plat, true)
	# 盆地→桥东段回程踏步
	_slab(1900, 940, 50, 26, plat, true)
	# 井梯（下探＋东壁爬出）
	_slab(2400, 1060, 100, 26, plat, true)
	_slab(2540, 1120, 100, 26, plat, true)
	_slab(2420, 1180, 100, 26, plat, true)
	_slab(2520, 1240, 100, 26, plat, true)
	_slab(2570, 1060, 70, 26, plat, true)
	_slab(2570, 1000, 70, 26, plat, true)
	_slab(2570, 950, 70, 26, plat, true)
	# 轰鸣带踏步（厅→脊→台）
	_slab(2980, 840, 80, 26, plat, true)
	_slab(3130, 740, 80, 26, plat, true)
	# 脊地东壁回程踏步（幻声林地返回轰鸣带）
	_slab(3390, 900, 60, 26, plat, true)
	_slab(3390, 840, 60, 26, plat, true)
	# 裂谷双梯（西壁回地面／东壁上海洼）
	_slab(3625, 1180, 90, 26, plat, true)
	_slab(3625, 1120, 60, 26, plat, true)
	_slab(3625, 1060, 60, 26, plat, true)
	_slab(3625, 1000, 55, 26, plat, true)
	_slab(3740, 1180, 60, 26, plat, true)
	_slab(3740, 1120, 60, 26, plat, true)
	_slab(3740, 1060, 60, 26, plat, true)
	_slab(3745, 1010, 55, 26, plat, true)

	# ---- 分区色调罩染（气氛层）----
	_tint(1910, 780, 340, 240, Color(0.0, 0.0, 0.02, 0.55))     # 止语凹地：压暗
	_tint(3050, 700, 400, 260, Color(0.20, 0.04, 0.04, 0.25))   # 轰鸣带：暗红
	_tint(3450, 700, 350, 260, Color(0.10, 0.05, 0.22, 0.30))   # 幻声林地：蓝紫
	_tint(3800, 700, 600, 300, Color(0.55, 0.62, 0.70, 0.14))   # 声骸之海：尸白
	_tint(4400, 700, 400, 260, Color(0.85, 0.90, 0.95, 0.10))   # 塔阶：渐亮

	# ---- 回响点 ----
	_respawn(100, 915)      # R1·苏醒谷地
	_respawn(3900, 955)     # R2·声骸之海（Boss 前）

	# ---- 特质全量分布（9 颗收集＋原声 Boss 掉落）——收集方式按特质表"获取语法"----
	_pickup("chuxiang", 560, 900)                       # ①初响：触碰即得（教走与触碰）
	_pickup("zhongsheng", 1450, 715, 0, "detect")       # ②众声：碎石顶——共鸣探测才凝出实体
	_pickup("xieyin", 1785, 830, 2)                     # ③谐音：断口上方——集齐两特质才显形
	_pickup("zhiyu", 2100, 960, 0, "silence")           # ④止语：站定不出声它才接受你
	_pickup("raoliang", 2460, 1245, 0, "detect")        # ⑤绕梁：井底——用探测听出自己的回声
	_pickup("pinlvshu", 3080, 755, 0, "machine")        # ⑥频率梳：回声机音序应答
	_pickup("gongzhenqiang", 2900, 860, 0, "tune")      # ⑦共振腔：配出空腔要的属性组合
	_pickup("moyin", 3340, 650)                         # ⑧末音：高台之上（E3 把守）
	_pickup("shiyu", 3685, 1200)                        # ⑨失语的记忆：相信幻声，跳进裂谷
	# ★原声：声骸之海 Boss 净化后掉落（见 _on_boss_purified）

	# ---- 回声机（频率梳挑战：音序应答）----
	_machine_zone(3130, 780)

	# ---- 空腔（共振腔挑战：属性配平）----
	_tune_zone(2950, 860)

	# ---- 失调体（韧性逐段递增）----
	_enemy(760, 915, false, 80.0, 24.0)      # E1·教学战（谷地东口）
	_enemy(1650, 850, false, 60.0, 32.0)     # 和声战（桥西段巡逻）
	_enemy(3180, 770, false, 80.0, 40.0)     # E2·轰鸣带脊地
	_enemy(3300, 675, false, 40.0, 40.0)     # E3·高台守末音

	# ---- 原声 Boss（声骸之海）----
	boss = _enemy(4150, 940, true, 80.0, 70.0)

	# ---- 幻声三连 ----
	_phantom(350, 880, "（你的脚步被送了回来——比落下去的时候慢半拍。）")
	_phantom(2020, 950, "（安静里，废墟深处有什么轻轻应了一声——是你自己哼过的那段旋律。）")
	_phantom(3520, 880, "你终于又听见了。")

	# ---- 分幕叙事（每幕一句，其余文本都为它服务）----
	_phantom(640, 900, "废墟渐渐有了声音。冻在半空的声纹，像被凝固的呼喊。")
	_phantom(1090, 900, "（前面挤满了声音——几百个字、几百段旋律，谁也听不清谁。）")
	_phantom(1520, 900, "（桥的中段空了。也许有什么东西，一直在替你搭桥。）")
	_phantom(2310, 910, "（一口井。你沿着井壁走下去，然后听见——你的脚步声，正从井的另一侧走回来。）")
	_phantom(2760, 880, "（厅堂尽头立着一只空腔。它在等一个和它一模一样的声音。）")
	_phantom(3200, 780, "（越靠近，世界越吵。而最高处，有什么还在响。）")
	_phantom(3860, 950, "（满地都是声骸——哑掉的容器、断掉的声纹。所有你见过的幻声，在这里拧成了一团。）")
	_phantom(4440, 900, "废墟在这里开始上坡。声音越来越规整，回声一步步变成节拍。")

	# ---- 止语凹地：静默区（音乐低伏）----
	_silence_zone(2080, 900, 340, 220)

	# ---- 切片结束区（塔阶顶）----
	_end_zone(4650, 730)

	# ---- 分区布景 ----
	_decos([[250, 926, "deco_pillar"], [430, 926, "deco_wave1"], [540, 926, "deco_pillar"],
		[90, 926, "deco_wave2"], [650, 926, "deco_wave2"], [940, 926, "deco_pillar"]])
	_decos([[1120, 926, "deco_wave1"], [1210, 926, "deco_wave2"], [1330, 926, "deco_wave1"],
		[1175, 866, "deco_wave1"], [1345, 806, "deco_wave2"], [1445, 746, "deco_wave1"],
		[1490, 926, "deco_wave2"]])
	_decos([[1580, 866, "deco_pillar"], [1720, 866, "deco_pillar"], [1850, 866, "deco_pillar"]])
	_decos([[1950, 986, "deco_pillar"]])
	_decos([[2280, 926, "deco_pillar"], [2350, 926, "deco_pillar"]])
	_decos([[2420, 1266, "deco_wave1"], [2590, 1266, "deco_wave2"]])
	_decos([[2700, 886, "deco_container"], [2770, 886, "deco_container"], [2840, 886, "deco_pillar"],
		[2990, 886, "deco_container"], [3030, 886, "deco_wave1"]])
	_decos([[3140, 786, "deco_container"], [3400, 786, "deco_container"], [3300, 686, "deco_container"]])
	_decos([[3480, 926, "deco_wave1"], [3570, 926, "deco_wave2"], [3440, 926, "deco_pillar"]])
	_decos([[3860, 966, "deco_container"], [3960, 966, "deco_wave1"], [4060, 966, "deco_container"],
		[4260, 966, "deco_wave2"], [4360, 966, "deco_container"], [4000, 966, "deco_wave1"]])
	_decos([[4460, 906, "deco_pillar"], [4560, 846, "deco_pillar"], [4660, 786, "deco_pillar"]])

	# ---- 痕迹（拖拽痕：从苏醒处铺向废墟深处，另一半通向塔阶）----
	for t in [[130, 928, 280, 12], [480, 928, 180, 12], [1080, 928, 280, 12],
			[1600, 868, 120, 12], [2260, 928, 110, 12], [3900, 968, 320, 12], [4420, 908, 60, 12]]:
		var tr := Sprite2D.new()
		tr.texture = T["tile_trail"]
		tr.centered = false
		tr.region_enabled = true
		tr.region_rect = Rect2(0, 0, t[2], t[3])
		tr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		tr.position = Vector2(t[0], t[1])
		add_child(tr)

	# ---- 碑文×3 ----
	_tablet(1100, 928, "碑①——字迹几乎磨平了，只剩一个词还认得出：听。")
	_tablet(2300, 928, "碑②——回声不辨新旧。")
	_tablet(4440, 966, "碑③——路。")

# ---------- 构建工具 ----------
func _slab(x: float, y: float, w: float, h: float, col: Color, one_way := false) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 4
	body.position = Vector2(x + w / 2.0, y + h / 2.0)
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(w, h)
	cs.shape = sh
	cs.one_way_collision = one_way
	cs.one_way_collision_margin = 8.0
	body.add_child(cs)
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-w / 2.0, -h / 2.0), Vector2(w / 2.0, -h / 2.0),
		Vector2(w / 2.0, h / 2.0), Vector2(-w / 2.0, h / 2.0)])
	poly.color = col
	body.add_child(poly)
	var edge := ColorRect.new()
	edge.color = Color(0.24, 0.34, 0.45, 0.9)
	edge.position = Vector2(-w / 2.0, -h / 2.0)
	edge.size = Vector2(w, 2)
	body.add_child(edge)
	add_child(body)

func _tint(x: float, y: float, w: float, h: float, col: Color) -> void:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])
	poly.color = col
	add_child(poly)

func _decos(list: Array) -> void:
	for d in list:
		var s := Sprite2D.new()
		s.texture = T[d[2]]
		s.position = Vector2(d[0], d[1])
		add_child(s)

func _silence_zone(x: float, y: float, w: float, h: float) -> void:
	var area := Area2D.new()
	area.position = Vector2(x, y)
	area.collision_layer = 0
	area.collision_mask = 1
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(w, h)
	cs.shape = sh
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(func(body):
		if body.is_in_group("player"):
			AudioDirector.set_music_duck(true)
			hud.show_phantom("安静——这里在替你听。"))
	area.body_exited.connect(func(body):
		if body.is_in_group("player"):
			AudioDirector.set_music_duck(false))

func _pickup(id: String, x: float, y: float, need := 0, req := "") -> void:
	var area := Area2D.new()
	area.set_script(load("res://scripts/trait_pickup.gd"))
	area.trait_id = id
	area.visible_after_count = need
	area.req = req
	area.position = Vector2(x, y)
	add_child(area)

# ---------- 回声机（频率梳：音序应答） ----------
var machine_seq: Array = []
var machine_input: Array = []
var machine_in := false
var machine_solved := false
var machine_busy := false

func _machine_zone(x: float, y: float) -> void:
	var area := Area2D.new()
	area.position = Vector2(x, y)
	area.collision_layer = 0
	area.collision_mask = 1
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 80.0
	cs.shape = sh
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(func(body):
		if body.is_in_group("player"):
			machine_in = true
			if not machine_solved:
				if machine_seq.is_empty():
					_machine_new_seq()
				hint("回声机卡住了。它哼了一串音——用同样的音序回答它。（J／K／L）")
				_machine_hum())
	area.body_exited.connect(func(body):
		if body.is_in_group("player"):
			machine_in = false)

## 每次挑战生成 4 音序列（三音阶随机）
func _machine_new_seq() -> void:
	machine_seq = []
	for i in range(4):
		machine_seq.append(randi_range(1, 3))

func _machine_hum() -> void:
	if machine_busy or machine_solved:
		return
	machine_busy = true
	machine_input = []
	for i in range(machine_seq.size()):
		var note: int = machine_seq[i]
		var t := get_tree().create_timer(0.7 * i + 0.4)
		t.timeout.connect(func():
			AudioDirector.sfx_play("collect%d" % note)
			_machine_noteVisual(note))
	var end := get_tree().create_timer(0.7 * machine_seq.size() + 0.6)
	end.timeout.connect(func(): machine_busy = false)

func _machine_noteVisual(note: int) -> void:
	var s := Sprite2D.new()
	s.texture = T["trait_dot"] if note == 1 else (T["trait_dot2"] if note == 2 else T["glow"])
	s.position = Vector2(3130, 740)
	s.scale = Vector2(1.6, 1.6)
	add_child(s)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "position:y", s.position.y - 26.0, 0.5)
	tw.tween_property(s, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(s.queue_free)

func _machine_press(note: int) -> void:
	if not machine_in or machine_solved or machine_busy:
		return
	machine_input.append(note)
	_machine_noteVisual(note)
	if machine_input.size() < machine_seq.size():
		return
	if machine_input == machine_seq:
		machine_solved = true
		AudioDirector.sfx_play("tune_ok")
		for p in get_tree().get_nodes_in_group("pickups"):
			if p.get("trait_id") == "pinlvshu":
				p.call("set_unlocked")
		hint("回声机松开了——梳子从卡住的齿轮间落了下来。")
	else:
		hint("不对。它把那串音重新哼了一遍——再听。")
		_machine_hum()

# ---------- 空腔（共振腔：属性配平） ----------
var tune_in := false
var tune_solved := false
var tune_target: Array = []      # 目标属性组合（三条 [energy, structure, tempo]）
var tune_hint_cd := 0.0

const ENERGY_CN := {"release": "放", "absorb": "收", "neutral": "静"}
const STRUCT_CN := {"mid": "稳", "fragile": "脆", "tough": "韧"}
const TEMPO_CN := {"fast": "急", "mid": "平", "slow": "缓"}

func _tune_zone(x: float, y: float) -> void:
	var area := Area2D.new()
	area.position = Vector2(x, y)
	area.collision_layer = 0
	area.collision_mask = 1
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 90.0
	cs.shape = sh
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(func(body):
		if body.is_in_group("player"):
			tune_in = true
			if not tune_solved:
				if GameState.collected.size() < 3:
					hint("空腔沉睡着。它要等你手里攒够三个声音，才肯开口。")
				else:
					_tune_make_target())
	area.body_exited.connect(func(body):
		if body.is_in_group("player"):
			tune_in = false)

func _tune_make_target() -> void:
	if not tune_target.is_empty() or GameState.collected.size() < 3:
		return
	tune_target = []
	for i in range(3):
		var id: String = GameState.collected[i]
		tune_target.append([GameState.trait_attr(id, "energy"),
			GameState.trait_attr(id, "structure"), GameState.trait_attr(id, "tempo")])

func _tune_key(attrs: Array) -> String:
	var parts := []
	for a in attrs:
		parts.append("%s|%s|%s" % [a[0], a[1], a[2]])
	parts.sort()
	return ",".join(parts)

func _tune_target_text() -> String:
	var parts := []
	for a in tune_target:
		parts.append("%s·%s·%s" % [ENERGY_CN[a[0]], STRUCT_CN[a[1]], TEMPO_CN[a[2]]])
	return "空腔在等：　" + "　／　".join(parts)

func _tune_check() -> void:
	if not tune_in or tune_solved or tune_target.is_empty():
		return
	if GameState.equipped_ids().size() != 3:
		return
	var eq := []
	for id_v in GameState.equipped_ids():
		var id: String = id_v
		eq.append([GameState.trait_attr(id, "energy"),
			GameState.trait_attr(id, "structure"), GameState.trait_attr(id, "tempo")])
	if _tune_key(eq) == _tune_key(tune_target):
		tune_solved = true
		AudioDirector.sfx_play("tune_ok")
		for p in get_tree().get_nodes_in_group("pickups"):
			if p.get("trait_id") == "gongzhenqiang":
				p.call("set_unlocked")
		hint("空腔醒了。它认出了这个声音，让开了路。")

func _tune_hint_tick(delta: float) -> void:
	if not tune_in or tune_solved or tune_target.is_empty():
		return
	tune_hint_cd = maxf(tune_hint_cd - delta, 0.0)
	if tune_hint_cd <= 0.0:
		tune_hint_cd = 9.0
		hint(_tune_target_text() + "　（Tab 打开特质库，调整你的声部槽）")

func _enemy(x: float, y: float, boss: bool, patrol := 80.0, tough := 30.0) -> CharacterBody2D:
	var e := CharacterBody2D.new()
	e.set_script(load("res://scripts/enemy_overload.gd"))
	e.is_boss = true if boss else false
	e.patrol_range = patrol
	e.max_toughness = tough
	if boss:
		e.burst_radius = 170.0
	e.position = Vector2(x, y)
	add_child(e)
	if boss:
		e.purified.connect(_on_boss_purified)
	else:
		e.purified.connect(_on_enemy_purified)
	return e

func _respawn(x: float, y: float) -> void:
	var area := Area2D.new()
	area.set_script(load("res://scripts/respawn_point.gd"))
	area.position = Vector2(x, y)
	add_child(area)

func _phantom(x: float, y: float, text: String) -> void:
	var area := Area2D.new()
	area.position = Vector2(x, y)
	area.collision_layer = 0
	area.collision_mask = 1
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 60.0
	cs.shape = sh
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(func(body):
		if body.is_in_group("player") and not area.get_meta("done", false):
			area.set_meta("done", true)
			hud.show_phantom(text))

func _end_zone(x: float, y: float) -> void:
	var area := Area2D.new()
	area.position = Vector2(x, y)
	area.collision_layer = 0
	area.collision_mask = 1
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(60, 120)
	cs.shape = sh
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(func(body):
		if body.is_in_group("player") and not ended:
			ended = true
		hud.show_end([
			"鸣响墟在身后安静下来。",
			"痕迹的另一半，通向坡顶那座断塔。",
			"",
			"测试问题：①四段收集挑战（探测／静默／音序／配平）哪种最有感觉？",
			"②跳跃与落差手感如何？③剧情文字的密度是太多还是太少？"]))

# ---------- 玩家与 HUD ----------
func _spawn_player() -> void:
	player = CharacterBody2D.new()
	player.set_script(load("res://scripts/player.gd"))
	player.collision_layer = 1
	player.collision_mask = 4
	player.position = GameState.respawn_point
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 8.0
	cs.shape = sh
	player.add_child(cs)
	cam = Camera2D.new()
	cam.limit_left = 0
	cam.limit_right = int(WORLD_W)
	cam.limit_top = 0
	cam.limit_bottom = int(WORLD_H)
	cam.position_smoothing_enabled = true
	player.add_child(cam)
	add_child(player)
	player.world = self

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.set_script(load("res://scripts/hud.gd"))
	add_child(hud)
	blackout = ColorRect.new()
	blackout.color = Color(0, 0, 0, 0)
	blackout.size = Vector2(640, 360)
	var layer := CanvasLayer.new()
	layer.layer = 8
	layer.add_child(blackout)
	add_child(layer)

func _show_intro() -> void:
	# 序幕：黑屏，一声很轻的呼吸，画面亮起——你已经在走路
	blackout.color.a = 1.0
	AudioDirector.sfx_play("tune_ok")   # 呼吸声（专用采样待做，暂用最轻的人声气音替代）
	var tw := create_tween()
	tw.tween_interval(0.8)
	tw.tween_property(blackout, "color:a", 0.0, 2.6)
	tw.tween_callback(func(): hud.show_phantom("你已经来过这里。"))

func _tablet(x: float, y: float, text: String) -> void:
	var s := Sprite2D.new()
	s.texture = T["deco_pillar"]
	s.scale = Vector2(0.8, 0.8)
	s.position = Vector2(x, y)
	add_child(s)
	var area := Area2D.new()
	area.position = Vector2(x, y)
	area.collision_layer = 0
	area.collision_mask = 1
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 30.0
	cs.shape = sh
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(func(body):
		if body.is_in_group("player") and not area.get_meta("done", false):
			area.set_meta("done", true)
			hud.show_phantom(text))

# ---------- 玩法响应 ----------
func hit_stop(duration: float) -> void:
	hit_stop_id += 1
	var my_id := hit_stop_id
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	if my_id == hit_stop_id:
		Engine.time_scale = 1.0

func shake(amount: float) -> void:
	shake_amount = maxf(shake_amount, amount)

var hint_cd := 0.0
## 提示行（节流，避免刷屏）
func hint(text: String) -> void:
	if hint_cd > 0.0:
		return
	hint_cd = 4.0
	hud.show_phantom(text)

func spawn_shot(pos: Vector2, dir: Vector2, dmg: float, speed: float, life: float) -> void:
	var shot := Area2D.new()
	shot.set_script(load("res://scripts/voice_projectile.gd"))
	shot.damage = dmg
	shot.velocity = dir.normalized() * speed
	shot.life = life
	shot.position = pos
	shot.rotation = dir.angle()
	add_child(shot)

func spawn_burst(pos: Vector2, facing: Vector2, count: int, dmg: float, speed: float) -> void:
	for i in range(count):
		var t := get_tree().create_timer(0.12 * i)
		t.timeout.connect(func(): spawn_shot(pos, facing, dmg, speed, 0.6))

func pull_enemies(pos: Vector2, radius: float) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.get("state") == 5:
			continue
		var d: Vector2 = e.global_position - pos
		if d.length() < radius:
			e.position -= d.normalized() * 60.0

## 声音应答：任何发音都会被附近的失调体听见
func on_voice(pos: Vector2) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		e.call("hear", pos)

## 安抚脉冲：僵直中的被当场引导净化；其余的脱离敌对并受少量削韧
func neutral_pulse(pos: Vector2) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		var st = e.get("state")
		if st == 5 or e.global_position.distance_to(pos) > 130.0:
			continue
		if st == 4:   # STAGGERED：净化窗口内的引导净化
			e.call("_purify")
		else:
			e.call("calm")
			e.take_hit(4.0, "neutral")

func detect_pulse(pos: Vector2) -> void:
	AudioDirector.sfx_play("respawn")
	var ripple := Sprite2D.new()
	ripple.texture = T["ripple"]
	ripple.position = pos
	ripple.scale = Vector2(0.3, 0.3)
	ripple.modulate.a = 0.8
	add_child(ripple)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ripple, "scale", Vector2(3.2, 3.2), 0.55)
	tw.tween_property(ripple, "modulate:a", 0.0, 0.55)
	tw.chain().tween_callback(ripple.queue_free)
	# 探测波纹：未收集的特质闪一瞬（探测显形型的透明度由其自身管理，跳过）
	for p in get_tree().get_nodes_in_group("pickups"):
		if p.get("req") == "detect":
			continue
		var tw2 := create_tween()
		tw2.tween_property(p, "modulate:a", 1.0, 0.2)
		tw2.tween_interval(1.2)
		tw2.tween_property(p, "modulate:a", p.modulate.a, 0.4)
	# 共鸣探测：波及的"探测显形"特质凝出实体
	for p in get_tree().get_nodes_in_group("pickups"):
		if p.get("req") == "detect" and p.global_position.distance_to(pos) < 150.0:
			p.call("reveal_by_detect")

func _on_enemy_purified() -> void:
	pass   # 普通净化：留场光点已由敌人自身表现

func _on_boss_purified() -> void:
	GameState.collect("yuansheng")   # ★原声：合唱化开时落进你手里
	shake(6.0)
	Input.start_joy_vibration(0, 0.4, 0.4, 0.8)
	AudioDirector.sfx_play("tune_ok")
	hud.show_phantom("……（全废墟安静了一瞬，然后重新开始震动——像松了口气。）")

func _on_blackout() -> void:
	# 满格失声：世界静音一瞬，退回回响点，失调重置为 30
	blackout.color.a = 1.0
	AudioDirector.sfx_play("respawn")
	await get_tree().create_timer(0.6).timeout
	player.position = GameState.respawn_point
	player.velocity = Vector2.ZERO
	GameState.do_blackout_reset()
	var tw := create_tween()
	tw.tween_property(blackout, "color:a", 0.0, 0.8)

func _on_trait_collected(id: String) -> void:
	hud.show_trait_card(id)

func _unhandled_input(event: InputEvent) -> void:
	if GameState.lib_open:
		return
	# 回声机音序应答：J／K／L 对应音 1／2／3
	for n in range(3):
		if event.is_action_pressed("voice_%d" % (n + 1)):
			_machine_press(n + 1)
			return

func _process(delta: float) -> void:
	hint_cd = maxf(hint_cd - delta, 0.0)
	_tune_hint_tick(delta)
	_tune_check()
	# 屏幕微震衰减
	if shake_amount > 0.0:
		shake_amount = maxf(shake_amount - 30.0 * delta, 0.0)
		if cam:
			cam.offset = Vector2(randf_range(-shake_amount, shake_amount), randf_range(-shake_amount, shake_amount))
	elif cam:
		cam.offset = Vector2.ZERO
	if boss != null and is_instance_valid(boss):
		if boss.get("purified_flag"):
			blackout.color.a = maxf(blackout.color.a - 0.01, 0.0)   # 净化后视野恢复
		elif player.global_position.distance_to(boss.global_position) < 320.0:
			var ratio := 1.0 - (float(boss.get("toughness")) / float(boss.get("max_toughness")))
			var phase := int(ratio * 3.0)
			if phase != boss_phase:
				boss_phase = phase
			# 渐盲：随 Boss 战进程压缩视觉（三阶段）
			blackout.color.a = [0.0, 0.45, 0.75, 0.92][clampi(phase, 0, 3)]
		else:
			blackout.color.a = maxf(blackout.color.a - 0.02, 0.0)
