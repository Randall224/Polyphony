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

	# ---- 中景视差（远山与废墟轮廓之间的层次）----
	var par := ParallaxBackground.new()
	var mid_layer := ParallaxLayer.new()
	mid_layer.motion_scale = Vector2(0.5, 0.5)
	mid_layer.motion_mirroring = Vector2(640, 0)
	var mid := Sprite2D.new()
	mid.texture = load("res://assets/bg/mid.png")
	mid.centered = false
	mid.position = Vector2(0, 310)
	mid_layer.add_child(mid)
	par.add_child(mid_layer)
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
	# ---- 外边界（不给顶沿亮线，避免与地形拼接出假缝）----
	var bed := Color(0.05, 0.065, 0.10)
	_slab(-40, -40, WORLD_W + 80, 100, bed, false)       # 顶
	_slab(-40, 1340, WORLD_W + 80, 100, bed, false)      # 底（安全底线）
	_slab(-40, -40, 100, WORLD_H + 80, bed, false)       # 左
	_slab(4740, -40, 100, WORLD_H + 80, bed, false)      # 右

	# ---- 地形（实心地块：每区独立基色＋地砖肌理＋顶沿亮线，顶面即地表）----
	_slab(60, 940, 600, 460, Color(0.07, 0.10, 0.16))       # 苏醒谷地
	_slab(660, 940, 420, 460, Color(0.08, 0.11, 0.17))      # 教学段
	_slab(1080, 940, 480, 460, Color(0.09, 0.115, 0.175))   # 岔路噪声区（偏灰）
	_slab(1560, 880, 180, 320, Color(0.06, 0.09, 0.14))     # 谐音桥西段（桥墩落地）
	_slab(1560, 1200, 350, 200, Color(0.05, 0.075, 0.115))  # 桥下深谷底（坠而不死，东行可爬回）
	_slab(1830, 880, 80, 40, Color(0.06, 0.09, 0.14))       # 谐音桥东段（断口东侧悬段）
	_slab(1910, 1000, 340, 400, Color(0.035, 0.05, 0.08))   # 止语凹地（近乎全黑）
	_slab(2250, 940, 130, 460, Color(0.06, 0.12, 0.18))     # 回声环井沿（青）
	_slab(2380, 1280, 260, 120, Color(0.05, 0.08, 0.12))    # 井底
	_slab(2640, 900, 410, 500, Color(0.08, 0.12, 0.17))     # 共鸣厅
	_slab(3050, 800, 400, 600, Color(0.115, 0.075, 0.08))   # 轰鸣带脊地（暗红）
	_slab(3210, 700, 170, 100, Color(0.125, 0.08, 0.085))   # 高台（末音悬于其上）
	_slab(3450, 940, 170, 460, Color(0.075, 0.07, 0.15))    # 幻声林地（蓝紫）
	_slab(3620, 1240, 180, 160, Color(0.05, 0.075, 0.115))  # 裂谷底
	_slab(3800, 980, 600, 420, Color(0.10, 0.13, 0.17))     # 声骸之海（尸白蓝）
	_slab(4400, 920, 100, 480, Color(0.12, 0.15, 0.19))     # 塔阶一（渐亮上行）
	_slab(4500, 860, 100, 540, Color(0.13, 0.16, 0.20))     # 塔阶二
	_slab(4600, 800, 140, 600, Color(0.14, 0.17, 0.21))     # 塔阶三（出口）

	# ---- 平台（全部实体——可以从下方穿过属于穿模；之字排列保证每级都能从侧面跳上）----
	var plat := Color(0.15, 0.20, 0.28)
	# 噪声区碎石上行（西侧逐级跳）
	_slab(1130, 880, 110, 26, plat)
	_slab(1290, 820, 110, 26, plat)
	_slab(1400, 760, 110, 26, plat)
	# 桥下深谷回程梯（坠落者的路，之字避开桥墩爬回盆地）
	_slab(1750, 1140, 70, 26, plat)
	_slab(1830, 1080, 75, 26, plat)
	_slab(1750, 1020, 70, 26, plat)
	# 盆地→桥东段回程踏步
	_slab(1915, 940, 50, 26, plat)
	# 回声环井梯（之字爬出东口）
	_slab(2390, 1220, 80, 26, plat)
	_slab(2540, 1160, 80, 26, plat)
	_slab(2390, 1100, 80, 26, plat)
	_slab(2540, 1040, 80, 26, plat)
	_slab(2390, 980, 80, 26, plat)
	_slab(2540, 920, 80, 26, plat)
	# 轰鸣带踏步（厅→脊→台）
	_slab(2970, 840, 78, 26, plat)
	_slab(3130, 740, 80, 26, plat)
	# 脊地东壁回程踏步（林地→脊地，错位两跳，从侧面跳上）
	_slab(3560, 900, 60, 26, plat)
	_slab(3452, 840, 46, 26, plat)
	# 裂谷之字梯（西回地面／东上海洼）
	_slab(3625, 1180, 65, 26, plat)
	_slab(3725, 1120, 65, 26, plat)
	_slab(3625, 1060, 65, 26, plat)
	_slab(3700, 1000, 60, 26, plat)

	# ---- 回响点 ----
	_respawn(100, 915)      # R1·苏醒谷地
	_respawn(3900, 955)     # R2·声骸之海（Boss 前）

	# ---- 特质全量分布（9 颗收集＋原声 Boss 掉落）——收集方式按特质表"获取语法"----
	# （悬空高度统一落在站立可触范围，只有"悬着"的末音与断口上的谐音保留跳跃）
	_pickup("chuxiang", 560, 918)                       # ①初响：触碰即得（教走与触碰）
	_pickup("zhongsheng", 1450, 738, 0, "detect")       # ②众声：碎石顶——共鸣探测才凝出实体
	_pickup("xieyin", 1785, 836, 2)                     # ③谐音：断口上方——集齐两特质才显形
	_pickup("zhiyu", 2100, 978, 0, "silence")           # ④止语：站定不出声它才接受你
	_pickup("raoliang", 2500, 1258, 0, "detect")        # ⑤绕梁：井底——用探测听出自己的回声
	_pickup("pinlvshu", 3080, 778, 0, "machine")        # ⑥频率梳：回声机音序应答
	_pickup("gongzhenqiang", 2900, 878, 0, "tune")      # ⑦共振腔：配出空腔要的属性组合
	_pickup("moyin", 3340, 678)                         # ⑧末音：高台之上（悬着，E3 把守）
	_pickup("shiyu", 3685, 1218)                        # ⑨失语的记忆：相信幻声，跳进裂谷
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
	_phantom(1020, 900, "（前面挤满了声音——几百个字、几百段旋律，谁也听不清谁。）")
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

	# ---- 分区布景（y＝所在表面高度，贴图按真实高度落地；柱／容器有碰撞，
	#      声纹是冻结的声音——可穿行；桥栏残柱放行避免堵落点）----
	_decos([[250, 940, "deco_pillar", true], [430, 940, "deco_wave1"], [540, 940, "deco_pillar", true],
		[90, 940, "deco_wave2"], [650, 940, "deco_wave2"], [940, 940, "deco_pillar", true]])
	_decos([[1120, 940, "deco_wave1"], [1210, 940, "deco_wave2"], [1330, 940, "deco_wave1"],
		[1175, 880, "deco_wave1"], [1345, 820, "deco_wave2"], [1445, 760, "deco_wave1"],
		[1490, 940, "deco_wave2"]])
	_decos([[1568, 880, "deco_pillar", false], [1732, 880, "deco_pillar", false], [1850, 880, "deco_pillar", false]])
	_decos([[1950, 1000, "deco_pillar", true]])
	_decos([[2280, 940, "deco_pillar", false], [2350, 940, "deco_pillar", false]])   # 井沿残柱（放行，井沿太窄）
	_decos([[2420, 1280, "deco_wave1"], [2590, 1280, "deco_wave2"]])
	_decos([[2700, 900, "deco_container", true], [2770, 900, "deco_container", true], [2840, 900, "deco_pillar", true],
		[2990, 900, "deco_container", true], [3030, 900, "deco_wave1"]])
	_decos([[3140, 800, "deco_container", true], [3400, 800, "deco_container", true], [3296, 700, "deco_container", true]])
	_decos([[3480, 940, "deco_wave1"], [3570, 940, "deco_wave2"], [3475, 940, "deco_pillar", false]])
	_decos([[3860, 980, "deco_container", true], [3960, 980, "deco_wave1"], [4060, 980, "deco_container", true],
		[4260, 980, "deco_wave2"], [4360, 980, "deco_container", true], [4000, 980, "deco_wave1"]])
	_decos([[4460, 920, "deco_pillar", true], [4560, 860, "deco_pillar", true], [4660, 800, "deco_pillar", true]])

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

	# ---- 碑文×3（实体石碑，y＝所在表面）----
	_tablet(1100, 940, "碑①——字迹几乎磨平了，只剩一个词还认得出：听。")
	_tablet(2300, 940, "碑②——回声不辨新旧。")
	_tablet(4440, 980, "碑③——路。")

# ---------- 构建工具 ----------
func _slab(x: float, y: float, w: float, h: float, col: Color, edge := true) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 4
	body.position = Vector2(x + w / 2.0, y + h / 2.0)
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(w, h)
	cs.shape = sh
	body.add_child(cs)
	add_child(body)
	# 基色（分区色调直接烘进地表）
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])
	poly.color = col
	add_child(poly)
	# 地砖肌理：薄块用平台砖，厚地形用表砖＋填充砖
	if h < 40.0:
		_tile_strip("tile_platform", x, y, w, 10.0, Color(1, 1, 1, 0.95))
	else:
		_tile_strip("tile_ground_top", x, y, w, 16.0, Color(1, 1, 1, 0.55))
		if h > 40.0:
			_tile_strip("tile_ground_fill", x, y + 16.0, w, h - 16.0, Color(1, 1, 1, 0.30))
		# 顶沿亮线＋沿下阴影（勾出地形轮廓）
		if edge:
			var top := ColorRect.new()
			top.color = Color(0.34, 0.44, 0.54, 0.95)
			top.position = Vector2(x, y)
			top.size = Vector2(w, 2)
			add_child(top)
			if h > 40.0:
				var shade := ColorRect.new()
				shade.color = Color(0, 0, 0, 0.22)
				shade.position = Vector2(x, y + 16.0)
				shade.size = Vector2(w, 2)
				add_child(shade)

func _tile_strip(tex: String, x: float, y: float, w: float, h: float, mod: Color) -> void:
	if h <= 0.0:
		return
	var s := Sprite2D.new()
	s.texture = T[tex]
	s.centered = false
	s.region_enabled = true
	s.region_rect = Rect2(0, 0, w, h)
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.position = Vector2(x, y)
	s.modulate = mod
	add_child(s)

func _decos(list: Array) -> void:
	for d in list:
		var tex: String = d[2]
		var s := Sprite2D.new()
		s.texture = T[tex]
		# 落地：y 参数＝所在表面，贴图按自身高度站立（下沉 2px 咬住地面）
		s.position = Vector2(d[0], d[1] - T[tex].get_height() / 2.0 + 2.0)
		add_child(s)
		# 柱／容器是实体（能撞上）；声纹可穿行；第 4 项可显式覆盖
		var solid: bool = d[3] if d.size() > 3 else (tex == "deco_pillar" or tex == "deco_container")
		if solid:
			var body := StaticBody2D.new()
			body.collision_layer = 4
			body.position = s.position
			var cs := CollisionShape2D.new()
			var sh := RectangleShape2D.new()
			sh.size = Vector2(T[tex].get_width() - 2.0, T[tex].get_height() - 4.0)
			cs.shape = sh
			body.add_child(cs)
			add_child(body)

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
			if not area.get_meta("cool", false):
				area.set_meta("cool", true)
				hud.show_phantom("安静——这里在替你听。")
				get_tree().create_timer(20.0).timeout.connect(func():
					if is_instance_valid(area):
						area.set_meta("cool", false)))
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
var machine_labels: Array = []
const MACHINE_KEY_NAMES := ["J / X", "K / B", "L / Y"]
const MACHINE_KEY_COLS := [Color(0.55, 0.85, 1.0), Color(1.0, 0.8, 0.45), Color(0.7, 1.0, 0.85)]

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
				_machine_show_keys()
				if machine_seq.is_empty():
					_machine_new_seq()
				hint("回声机卡住了。看它点亮哪个键位牌，就用哪个键回答。（J／K／L）")
				_machine_hum())
	area.body_exited.connect(func(body):
		if body.is_in_group("player"):
			machine_in = false
			for l in machine_labels:
				l.visible = false)

## 键位牌：三个键各自颜色＋对应音——哼哪个音亮哪个牌，按哪个键闪哪个牌
func _machine_show_keys() -> void:
	if machine_labels.is_empty():
		for i in range(3):
			var l := Label.new()
			l.text = MACHINE_KEY_NAMES[i]
			l.add_theme_font_size_override("font_size", 8)
			l.add_theme_color_override("font_color", MACHINE_KEY_COLS[i])
			l.position = Vector2(3092 + i * 28, 714)
			add_child(l)
			machine_labels.append(l)
	for l in machine_labels:
		l.visible = true

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
	# 键位牌高亮＋音点浮升＋该键专属音高（看与听都能对应）
	if machine_labels.size() == 3:
		var l: Label = machine_labels[note - 1]
		l.modulate = Color(2.2, 2.2, 2.2, 1)
		var twl := create_tween()
		twl.tween_property(l, "modulate", Color(1, 1, 1, 1), 0.45)
	var s := Sprite2D.new()
	s.texture = T["trait_dot"] if note == 1 else (T["trait_dot2"] if note == 2 else T["glow"])
	s.modulate = MACHINE_KEY_COLS[note - 1]
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
	AudioDirector.sfx_play("collect%d" % note)   # 每个键的确认音＝它对应的音高
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
		hint("不对。它把那串音重新哼了一遍——再看一次键位牌。")
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
	_add_trigger(x, y, 60.0, text, 20.0)

func _add_trigger(x: float, y: float, radius: float, text: String, cooldown: float) -> void:
	var area := Area2D.new()
	area.position = Vector2(x, y)
	area.collision_layer = 0
	area.collision_mask = 1
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = radius
	cs.shape = sh
	area.add_child(cs)
	add_child(area)
	# 可重复：进入触发一次，冷却（默认 20s）后再次进入可重听
	area.body_entered.connect(func(body):
		if body.is_in_group("player") and not area.get_meta("cool", false):
			area.set_meta("cool", true)
			hud.show_phantom(text)
			get_tree().create_timer(cooldown).timeout.connect(func():
				if is_instance_valid(area):
					area.set_meta("cool", false)))

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

func _tablet(x: float, surface_y: float, text: String) -> void:
	var s := Sprite2D.new()
	s.texture = T["deco_pillar"]
	s.scale = Vector2(0.8, 0.8)
	s.position = Vector2(x, surface_y - T["deco_pillar"].get_height() * 0.4 + 2.0)
	add_child(s)
	var body := StaticBody2D.new()
	body.collision_layer = 4
	body.position = s.position
	var bcs := CollisionShape2D.new()
	var bsh := RectangleShape2D.new()
	bsh.size = Vector2(T["deco_pillar"].get_width() * 0.8, T["deco_pillar"].get_height() * 0.8 - 4.0)
	bcs.shape = bsh
	body.add_child(bcs)
	add_child(body)
	var area := Area2D.new()
	area.position = Vector2(x, surface_y - 20.0)
	area.collision_layer = 0
	area.collision_mask = 1
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 30.0
	cs.shape = sh
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(func(body):
		if body.is_in_group("player") and not area.get_meta("cool", false):
			area.set_meta("cool", true)
			hud.show_phantom(text)
			get_tree().create_timer(20.0).timeout.connect(func():
				if is_instance_valid(area):
					area.set_meta("cool", false)))

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

## 求助（H／Back）：报告附近最近的机关怎么解——应玩家请求的重复提示
func help_hint(pos: Vector2) -> void:
	# 1) 附近未收集的条件型特质
	var best: Node2D = null
	var best_d := 180.0
	for p in get_tree().get_nodes_in_group("pickups"):
		if p.get("req") == "" or p.get("_collected"):
			continue
		var d: float = p.global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = p
	if best != null:
		var req: String = best.get("req")
		match req:
			"detect":
				hint("【%s】用共鸣探测（F／LB）——它会从杂音里凝出来，几秒内伸手碰它。" % GameState.trait_name(best.get("trait_id")))
			"silence":
				hint("【%s】站定，三秒内不出任何声音，它会接受你。" % GameState.trait_name(best.get("trait_id")))
			"machine":
				hint("【%s】听回声机哼出的四个音，用 J／K／L（X／B／Y）按同样顺序回答。" % GameState.trait_name(best.get("trait_id")))
			"tune":
				hint("【%s】按 Tab 开特质库，把声部槽配成空腔报出的三条属性组合。" % GameState.trait_name(best.get("trait_id")))
		return
	# 2) 回声机／空腔（特质还没显形的挑战本体）
	if machine_in and not machine_solved:
		hint("回声机：听它哼的四个音，用 J／K／L（X／B／Y）按序回答。")
		return
	if tune_in and not tune_solved:
		hint("空腔：" + (_tune_target_text() if not tune_target.is_empty() else "先攒够三个声音再来。"))
		return
	# 3) 谐音门槛
	for p in get_tree().get_nodes_in_group("pickups"):
		if p.get("trait_id") == "xieyin" and p.global_position.distance_to(pos) < 180.0:
			hint("谐音要两个声音同时在场才显形——先去收集别的特质，再回到断桥。")
			return
	hint("（附近没有正在等你的机关。跟着痕迹走，或按 F 探测试试。）")

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
		t.timeout.connect(func(): spawn_shot(pos, facing, dmg, speed, 0.28))

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
