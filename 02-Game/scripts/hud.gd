extends CanvasLayer
## HUD（像素切片）：声部槽（失声灰化）、失调条、幻声/提示文本、特质库面板（Tab）、结束卡。

const ENERGY_CN := {"release": "释放", "absorb": "吸收", "neutral": "中性"}
const STRUCT_CN := {"tough": "坚韧", "mid": "中等", "fragile": "脆弱"}
const TEMPO_CN := {"fast": "快", "mid": "中", "slow": "慢"}

var slot_boxes: Array[ColorRect] = []
var slot_labels: Array[Label] = []
var chaos_fill: ColorRect
var chaos_frame: ColorRect
var center_label: Label
var prompt_label: Label
var end_label: Label
var phantom_tween: Tween
# 特质库面板
var lib_panel: ColorRect
var lib_slot_label: Label
var lib_list: Label
var lib_hint: Label
var lib_select := 0
var lib_slot := 0
var lib_open := false
var nav_cd := 0.0
# 特质卡（获得时展示：层级＋图标＋名称＋介绍）
var card_panel: ColorRect
var card_tier: Label
var card_icon: TextureRect
var card_name: Label
var card_intro: Label
var card_tween: Tween

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS   # 库打开时场景暂停，面板仍可用
	# 声部槽（切片 3 格）
	for i in range(3):
		var box := ColorRect.new()
		box.color = Color(1, 1, 1, 0.16)
		box.position = Vector2(12 + i * 40, 12)
		box.size = Vector2(34, 44)
		add_child(box)
		slot_boxes.append(box)
		var lb := Label.new()
		lb.position = Vector2(2, 14)
		lb.add_theme_font_size_override("font_size", 8)
		box.add_child(lb)
		slot_labels.append(lb)
	# 失调条
	chaos_frame = ColorRect.new()
	chaos_frame.color = Color(1, 1, 1, 0.25)
	chaos_frame.position = Vector2(12, 62)
	chaos_frame.size = Vector2(114, 8)
	add_child(chaos_frame)
	chaos_fill = ColorRect.new()
	chaos_fill.color = Color(0.4, 0.9, 0.6)
	chaos_fill.position = Vector2(13, 63)
	chaos_fill.size = Vector2(0, 6)
	add_child(chaos_fill)
	# 中央幻声文本
	center_label = Label.new()
	center_label.position = Vector2(120, 140)
	center_label.size = Vector2(400, 60)
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_label.add_theme_font_size_override("font_size", 14)
	center_label.modulate.a = 0.0
	add_child(center_label)
	# 底部提示
	prompt_label = Label.new()
	prompt_label.position = Vector2(12, 336)
	prompt_label.add_theme_font_size_override("font_size", 9)
	prompt_label.text = "WASD 移动 · Space 跳 · J/K/L 发音 · E 调声（换气点） · F 探测 · Tab 特质库"
	prompt_label.modulate.a = 0.75
	add_child(prompt_label)
	# 特质库面板（Tab 开关）
	lib_panel = ColorRect.new()
	lib_panel.color = Color(0.04, 0.08, 0.12, 0.92)
	lib_panel.position = Vector2(140, 40)
	lib_panel.size = Vector2(360, 240)
	lib_panel.visible = false
	add_child(lib_panel)
	var title := Label.new()
	title.position = Vector2(14, 8)
	title.add_theme_font_size_override("font_size", 12)
	title.text = "特质库——五域记得你的方式"
	lib_panel.add_child(title)
	lib_slot_label = Label.new()
	lib_slot_label.position = Vector2(14, 32)
	lib_slot_label.add_theme_font_size_override("font_size", 10)
	lib_panel.add_child(lib_slot_label)
	lib_list = Label.new()
	lib_list.position = Vector2(14, 60)
	lib_list.add_theme_font_size_override("font_size", 10)
	lib_panel.add_child(lib_list)
	lib_hint = Label.new()
	lib_hint.position = Vector2(14, 214)
	lib_hint.add_theme_font_size_override("font_size", 9)
	lib_hint.modulate.a = 0.7
	lib_hint.text = "W/S 选特质 · A/D 选槽位 · E 装入 · Q 卸下 · J/K/L 快捷装入 · Tab 关闭"
	lib_panel.add_child(lib_hint)
	# 特质卡（获得时展示：层级标签＋图标＋名称＋介绍文本）
	card_panel = ColorRect.new()
	card_panel.color = Color(0.04, 0.08, 0.12, 0.9)
	card_panel.position = Vector2(170, 240)
	card_panel.size = Vector2(300, 74)
	card_panel.visible = false
	add_child(card_panel)
	card_tier = Label.new()
	card_tier.position = Vector2(72, 10)
	card_tier.add_theme_font_size_override("font_size", 9)
	card_panel.add_child(card_tier)
	card_icon = TextureRect.new()
	card_icon.position = Vector2(12, 14)
	card_icon.custom_minimum_size = Vector2(48, 48)
	card_icon.size = Vector2(48, 48)
	card_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	card_icon.texture = load("res://assets/sprites/trait_dot.png")
	card_panel.add_child(card_icon)
	card_name = Label.new()
	card_name.position = Vector2(72, 24)
	card_name.add_theme_font_size_override("font_size", 13)
	card_panel.add_child(card_name)
	card_intro = Label.new()
	card_intro.position = Vector2(72, 44)
	card_intro.size = Vector2(216, 26)
	card_intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_intro.add_theme_font_size_override("font_size", 9)
	card_panel.add_child(card_intro)
	# 结束卡
	end_label = Label.new()
	end_label.position = Vector2(60, 120)
	end_label.size = Vector2(520, 120)
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_label.add_theme_font_size_override("font_size", 13)
	end_label.modulate.a = 0.0
	add_child(end_label)
	GameState.chaos_changed.connect(_on_chaos)
	GameState.slots_changed.connect(_refresh_slots)
	_refresh_slots()

func _on_chaos(v: float) -> void:
	chaos_fill.size.x = 112.0 * v / 100.0
	chaos_fill.color = Color(0.4, 0.9, 0.6).lerp(Color(0.95, 0.25, 0.25), v / 100.0)
	# 失声灰化（阈值见大纲 9.1）
	for i in range(3):
		var lost := (v >= 80.0) or (v >= 60.0 and i >= 1) or (v >= 40.0 and i >= 2)
		slot_boxes[i].color = Color(0.25, 0.28, 0.35, 0.35) if lost else Color(1, 1, 1, 0.16)
		slot_labels[i].modulate.a = 0.35 if lost else 1.0

func _refresh_slots() -> void:
	for i in range(3):
		slot_labels[i].text = GameState.trait_name(GameState.slot_trait(i))
	if lib_panel.visible:
		_refresh_lib()

# ---------- 特质库面板 ----------
func _process(delta: float) -> void:
	nav_cd = maxf(nav_cd - delta, 0.0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("library"):
		lib_open = not lib_open
		lib_panel.visible = lib_open
		GameState.lib_open = lib_open
		get_tree().paused = lib_open   # 库打开＝游戏暂停（音乐由 ALWAYS 总监继续）
		if lib_open:
			_refresh_lib()
		get_viewport().set_input_as_handled()
		return
	if not lib_open:
		return
	# 导航重复抑制：摇杆轴事件会逐帧连发，必须冷却
	if nav_cd > 0.0:
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("move_up") and lib_select > 0:
		lib_select -= 1
		nav_cd = 0.22
		_refresh_lib()
	elif event.is_action_pressed("move_down") and lib_select < GameState.collected.size() - 1:
		lib_select += 1
		nav_cd = 0.22
		_refresh_lib()
	elif event.is_action_pressed("move_left") and lib_slot > 0:
		lib_slot -= 1
		nav_cd = 0.22
		_refresh_lib()
	elif event.is_action_pressed("move_right") and lib_slot < GameState.slots.size() - 1:
		lib_slot += 1
		nav_cd = 0.22
		_refresh_lib()
	elif event.is_action_pressed("tune_beat") or event.is_action_pressed("interact"):
		GameState.equip(lib_slot, GameState.collected[lib_select])
		_refresh_lib()
	elif event.is_action_pressed("drop"):
		GameState.clear_slot(lib_slot)
		_refresh_lib()
	get_viewport().set_input_as_handled()

func _refresh_lib() -> void:
	lib_select = clampi(lib_select, 0, maxi(GameState.collected.size() - 1, 0))
	lib_slot = clampi(lib_slot, 0, GameState.slots.size() - 1)
	var slots_line := "声部槽："
	for i in range(GameState.slots.size()):
		var mark := "▶" if i == lib_slot else " "
		var nm := GameState.trait_name(GameState.slots[i])
		if nm == "":
			nm = "（空）"
		slots_line += " %s[%d]%s" % [mark, i + 1, nm]
	lib_slot_label.text = slots_line
	var lines := ""
	for i in range(GameState.collected.size()):
		var id: String = GameState.collected[i]
		var marker := "▶ " if i == lib_select else "    "
		var tag: String = GameState.TIER_TAG[GameState.trait_tier(id)]
		lines += "%s[%s] %s（%s／%s／%s）\n" % [
			marker, tag, GameState.trait_name(id),
			ENERGY_CN[GameState.trait_attr(id, "energy")],
			STRUCT_CN[GameState.trait_attr(id, "structure")],
			TEMPO_CN[GameState.trait_attr(id, "tempo")]]
	lib_list.text = lines

func show_phantom(text: String) -> void:
	if phantom_tween:
		phantom_tween.kill()
	center_label.text = text
	center_label.modulate.a = 0.0
	phantom_tween = create_tween()
	phantom_tween.tween_property(center_label, "modulate:a", 1.0, 0.6)
	phantom_tween.tween_interval(2.6)
	phantom_tween.tween_property(center_label, "modulate:a", 0.0, 1.2)

func show_trait_card(id: String) -> void:
	if card_tween:
		card_tween.kill()
	var tier: String = GameState.trait_tier(id)
	var tcol: Color = GameState.TIER_COLOR[tier]
	card_tier.text = "%s · %s特质" % [GameState.TIER_TAG[tier], GameState.TIER_NAME[tier]]
	card_tier.add_theme_color_override("font_color", tcol)
	card_panel.color = Color(0.04, 0.08, 0.12, 0.92).lerp(tcol, 0.1)
	if ResourceLoader.exists("res://assets/sprites/icon_%s.png" % id):
		card_icon.texture = load("res://assets/sprites/icon_%s.png" % id)
	card_name.text = GameState.trait_name(id)
	card_intro.text = GameState.trait_intro(id)
	card_panel.visible = true
	card_panel.modulate.a = 0.0
	card_tween = create_tween()
	card_tween.tween_property(card_panel, "modulate:a", 1.0, 0.35)
	card_tween.tween_interval(3.2)
	card_tween.tween_property(card_panel, "modulate:a", 0.0, 0.8)

func show_end(lines: Array) -> void:
	end_label.text = "\n".join(lines)
	var tw := create_tween()
	tw.tween_property(end_label, "modulate.a", 1.0, 2.0)
