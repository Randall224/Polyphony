extends CharacterBody2D
## 过载型失调体（横版·有重力）：游走 → 蓄力 1.2s → 近距爆发音波 → 硬直 1.5s。
## 韧性清空 → 僵直 3s（自动净化窗口）→ 净化；僵直期被攻击＝击碎。
## 设计见大纲 9.2；原声 Boss＝放大版（韧性 60、三阶段渐盲）。

signal purified
signal phase_changed(p: int)

enum State { PATROL, CHARGE, BURST, RECOVER, STAGGERED, PURIFIED }

const GRAVITY := 820.0
const FALL_MAX := 520.0

var max_toughness := 30.0
var toughness := 30.0
var aggro_hear_range := 260.0
var state: int = State.PATROL
var wander_dir := Vector2(-1, 0)
var wander_t := 0.0
var home_pos := Vector2.ZERO
var patrol_range := 80.0
var charge_t := 0.0
var recover_t := 0.0
var stagger_t := 0.0
var contact_cd := 0.0
var burst_radius := 140.0
var is_boss := false
var purified_flag := false
var sprite: Sprite2D
var tex1: Texture2D
var tex2: Texture2D
var anim_t := 0.0

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 1 | 4
	home_pos = position
	toughness = max_toughness
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 13.0 if is_boss else 9.0
	cs.shape = sh
	add_child(cs)
	sprite = Sprite2D.new()
	tex1 = load("res://assets/sprites/boss_yuansheng.png" if is_boss else "res://assets/sprites/enemy1.png")
	tex2 = load("res://assets/sprites/boss_yuansheng.png" if is_boss else "res://assets/sprites/enemy2.png")
	sprite.texture = tex1
	add_child(sprite)

func _physics_process(delta: float) -> void:
	contact_cd = maxf(contact_cd - delta, 0.0)
	velocity.y = minf(velocity.y + GRAVITY * delta, FALL_MAX)
	match state:
		State.PATROL:
			wander_t -= delta
			# 横版巡逻：撞墙或走出领地即折返（不追下平台边缘）
			if wander_t <= 0.0 or is_on_wall() \
					or position.x < home_pos.x - patrol_range or position.x > home_pos.x + patrol_range:
				if is_on_wall() or position.x < home_pos.x - patrol_range or position.x > home_pos.x + patrol_range:
					wander_dir.x = -wander_dir.x if wander_t > 0.0 else signf(home_pos.x - position.x)
					wander_dir.x = wander_dir.x if wander_dir.x != 0.0 else -1.0
				wander_t = randf_range(1.2, 2.6)
			velocity.x = wander_dir.x * 50.0
			_contact_check()
			if _player_near(200.0):
				state = State.CHARGE
				charge_t = 1.2
			anim_t += delta
			sprite.texture = tex1 if fmod(anim_t, 0.5) < 0.25 else tex2
			sprite.modulate = Color(1, 1, 1)
		State.CHARGE:
			velocity.x = 0.0
			charge_t -= delta
			sprite.texture = load("res://assets/sprites/enemy_charge.png")
			sprite.modulate = Color(1, 1, 1).lerp(Color(1.6, 1.2, 0.7), 1.0 - charge_t / 1.2)
			if charge_t <= 0.0:
				_burst()
		State.BURST:
			velocity.x = 0.0
		State.RECOVER:
			velocity.x = 0.0
			recover_t -= delta
			if recover_t <= 0.0:
				state = State.PATROL
		State.STAGGERED:
			velocity.x = 0.0
			stagger_t -= delta
			# 净化窗口：3 秒后自动净化；玩家在窗口内继续攻击＝击碎
			sprite.modulate = Color(0.45, 0.8, 1.3).lerp(Color(0.55, 0.95, 1.1), 1.0 - stagger_t / 3.0)
			if stagger_t <= 0.0:
				_purify()
		State.PURIFIED:
			velocity.x = 0.0
	move_and_slide()

func _player_near(dist: float) -> bool:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return false
	var p = players[0]
	return p.global_position.distance_to(global_position) < dist

## 声音应答：巡逻中的失调体听见发音（250 内）即被惊动——开火是有代价的
func hear(pos: Vector2) -> void:
	if state == State.PATROL and global_position.distance_to(pos) < aggro_hear_range:
		state = State.CHARGE
		charge_t = 1.2

## 被安抚脉冲平息：脱离敌对，回到巡逻
func calm() -> void:
	if state == State.CHARGE:
		state = State.PATROL
		wander_t = 0.0
		sprite.modulate = Color(1, 1, 1)

func _burst() -> void:
	state = State.BURST
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var p = players[0]
		if p.global_position.distance_to(global_position) < burst_radius:
			p.hit(8.0, global_position)
	AudioDirector.sfx_play("shatter")
	state = State.RECOVER
	recover_t = 1.2
	if is_boss:
		_advance_phase()

func _contact_check() -> void:
	if contact_cd > 0.0:
		return
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var p = players[0]
		if p.global_position.distance_to(global_position) < 26.0:
			p.hit(8.0, global_position)
			contact_cd = 1.0

func take_hit(dmg: float, attr: String) -> void:
	if state == State.PURIFIED:
		return
	if state == State.STAGGERED:
		shatter()
		return
	var mult := 2.0 if attr in ["absorb", "slow"] else 1.0
	toughness -= dmg * mult
	_flash()
	var m = get_tree().get_first_node_in_group("main")
	if m:
		m.call("hit_stop", 0.05)
		m.call("shake", 2.0)
	if toughness <= 0.0:
		state = State.STAGGERED
		stagger_t = 3.0

func shatter() -> void:
	GameState.shatter_count += 1
	AudioDirector.sfx_play("shatter")
	Input.start_joy_vibration(0, 0.1, 0.8, 0.3)
	var m = get_tree().get_first_node_in_group("main")
	if m:
		m.call("shake", 3.0)
	_vanish()

func _purify() -> void:
	GameState.purify_count += 1
	AudioDirector.sfx_play("tune_ok")
	_vanish()
	purified.emit()

func _vanish() -> void:
	state = State.PURIFIED
	purified_flag = true
	sprite.texture = load("res://assets/sprites/trait_dot2.png")
	sprite.modulate = Color(1, 1, 1, 0.9)
	sprite.scale = Vector2(1.6, 1.6) if is_boss else Vector2(0.9, 0.9)
	for c in get_children():
		if c is CollisionShape2D:
			c.set_deferred("disabled", true)

func _advance_phase() -> void:
	var ratio := 1.0 - (toughness / max_toughness)
	phase_changed.emit(int(ratio * 3))

func _flash() -> void:
	sprite.modulate = Color(2, 2, 2, 1)
