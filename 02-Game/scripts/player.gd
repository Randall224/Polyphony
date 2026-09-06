extends CharacterBody2D
## 玩家（横版·有重力）：左右移动／跳跃／发音／受击／调声。
## 操作：A/D 或左摇杆 移动；空格/A 跳；J/K/L 或 X/B/Y 发音；E/RB 调声（换气点）；F/LB 探测。

const SPEED := 150.0
const GRAVITY := 820.0
const FALL_MAX := 520.0
const JUMP_V := -360.0
const COYOTE := 0.12

var facing := Vector2.RIGHT
var invuln := 0.0
var shield := 0.0
var overuse_count := 0
var last_voice := ""
var quiet_t := 0.0        # 距上次发音的静默时长（"止语"类收集判定用）
var coyote := 0.0
var world: Node2D = null
var sprite: Sprite2D
var tex := {}
var anim_t := 0.0
var voice_t := 0.0

func _ready() -> void:
	add_to_group("player")
	for n in ["idle", "walk1", "walk2", "voice"]:
		tex[n] = load("res://assets/sprites/player_%s.png" % n)
	sprite = Sprite2D.new()
	sprite.texture = tex["idle"]
	add_child(sprite)

func _physics_process(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	velocity.x = dir * SPEED
	velocity.y = minf(velocity.y + GRAVITY * delta, FALL_MAX)
	if is_on_floor():
		coyote = COYOTE
	else:
		coyote -= delta
	if Input.is_action_just_pressed("jump") and coyote > 0.0:
		velocity.y = JUMP_V
		coyote = 0.0
	# 调声与探测走轮询＋边沿检测：RT/LT 是模拟轴，事件驱动会连发多次
	if Input.is_action_just_pressed("tune_beat") and can_tune():
		if AudioDirector.breath_window_open():
			GameState.vent()           # 调声：换气点输入，排解自身失调
			GameState.tune_ok_count += 1
			AudioDirector.sfx_play("tune_ok")
	if Input.is_action_just_pressed("detect") and world != null:
		world.call("detect_pulse", global_position)
	if Input.is_action_just_pressed("help") and world != null:
		world.call("help_hint", global_position)
	move_and_slide()
	if dir != 0.0:
		facing = Vector2(signf(dir), 0)
		sprite.flip_h = dir < 0
	if invuln > 0.0:
		invuln -= delta
	if shield > 0.0:
		shield -= delta
	if voice_t > 0.0:
		voice_t -= delta
	quiet_t += delta
	_animate(dir, delta)

func _animate(dir: float, delta: float) -> void:
	sprite.flip_h = facing.x < 0
	var t := "idle"
	if voice_t > 0.0:
		t = "voice"
	elif not is_on_floor():
		t = "walk1"          # 空中：跨步帧
	elif absf(dir) > 0.1:
		anim_t += delta
		t = "walk1" if fmod(anim_t, 0.28) < 0.14 else "walk2"
	if sprite.texture != tex[t]:
		sprite.texture = tex[t]

func can_tune() -> bool:
	return is_on_floor() and absf(velocity.x) < 1.0

func _unhandled_input(event: InputEvent) -> void:
	if GameState.lib_open:
		return   # 特质库打开时，发音输入交给库面板
	# 回声机答题中：J/K/L/X/B/Y 只属于机关——不发音、不攻击（否则键位语义混乱）
	if world != null and world.get("machine_in") and not world.get("machine_solved"):
		return
	for i in range(GameState.SLOT_CAP):
		if event.is_action_pressed("voice_%d" % (i + 1)):
			voice(i)
			return

func voice(slot: int) -> void:
	var id: String = GameState.slot_trait(slot)
	if id == "" or world == null:
		return
	# 失声槽位：高失调下后位声部发不出声（灰化的槽是真哑的）
	if slot >= GameState.available_slots():
		world.call("hint", "（这一声部已经失了——在换气点调声，或用还亮着的声部。）")
		return
	# 过载使用：连续同一发音第 4 次起，每次 +4 失调
	if last_voice == id:
		overuse_count += 1
		if overuse_count >= 4:
			GameState.add_chaos(4.0)
	else:
		overuse_count = 0
	last_voice = id
	voice_t = 0.25
	quiet_t = 0.0

	var energy := GameState.trait_attr(id, "energy")
	var tempo := GameState.trait_attr(id, "tempo")
	var structure := GameState.trait_attr(id, "structure")
	var fragile := structure == "fragile"

	# 声音有代价：每次发音都会被附近的失调体听见（应答）
	world.call("on_voice", global_position)

	match energy:
		"release":
			# 放：攻击声部——全部是"近距离喊声"（短射程声波），不是子弹
			# 快调＝贴身三连喊；中调＝一声横扫；慢调＝远距重声（唯一的长射程）
			if tempo == "fast":
				world.call("spawn_burst", global_position + facing * 8.0, facing, 3, 5.0, 340.0)
			elif tempo == "slow":
				world.call("spawn_shot", global_position + facing * 8.0, facing, 18.0, 150.0, 1.6)
			elif fragile:
				# 脆结构：扇形三向散（覆盖广但每发弱，且每次自增失调）
				for a in [-0.35, 0.0, 0.35]:
					world.call("spawn_shot", global_position + facing * 8.0, facing.rotated(a), 5.0, 300.0, 0.45)
			else:
				world.call("spawn_shot", global_position + facing * 8.0, facing, 10.0, 300.0, 0.55)
		"absorb":
			# 收：回声牵引——把身前一片的失调体拉向你，僵直中的会被拉近
			world.call("pull_enemies", global_position + facing * 60.0, 170.0)
			if tempo == "slow":
				world.call("spawn_shot", global_position + facing * 8.0, facing, 12.0, 200.0, 0.8)
		"neutral":
			# 静：安抚脉冲——周围失调体脱离敌对；僵直中的被当场净化
			world.call("neutral_pulse", global_position)

	if structure == "tough":
		shield = maxf(shield, 1.2)
	if fragile:
		GameState.add_chaos(2.0)   # 脆结构：每响一次自增失调

	var sfx := "voice_release"
	if energy == "absorb":
		sfx = "voice_absorb"
	elif energy == "neutral":
		sfx = "tune_ok"
	elif structure == "tough":
		sfx = "voice_tough"
	AudioDirector.sfx_play(sfx)

## 受击（无死亡）：击退＋失调＋短暂无敌。from_pos 用于击退方向。
func hit(amount: float, from_pos: Vector2) -> void:
	if invuln > 0.0:
		return
	AudioDirector.sfx_play("hurt")
	Input.start_joy_vibration(0, 0.2, 0.5, 0.25)
	if world:
		world.call("shake", 2.5)
	velocity += (global_position - from_pos).normalized() * 220.0
	velocity.y = minf(velocity.y, -140.0)   # 向上弹开：脱离粘着，给逃跑窗口
	hurt_flash()
	if shield > 0.0:
		invuln = 0.5
		return
	invuln = 0.8
	GameState.add_chaos(amount)

func hurt_flash() -> void:
	sprite.modulate = Color(2, 1, 1, 1)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.25)
