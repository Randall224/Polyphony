extends Area2D
## 回响点（检查点）：激活时响起该关调式主音；失声重置回到最近激活的回响点。

var activated := false
var pole: ColorRect

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(40, 120)
	cs.shape = sh
	add_child(cs)
	var lamp := Sprite2D.new()
	lamp.texture = load("res://assets/sprites/lamp.png")
	lamp.position = Vector2(0, -20)
	add_child(lamp)
	pole = ColorRect.new()
	pole.color = Color(0.8, 0.85, 0.6, 0.0)   # 激活泛光用
	pole.size = Vector2(40, 90)
	pole.position = Vector2(-20, -50)
	add_child(pole)
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player") or activated:
		return
	activated = true
	GameState.respawn_point = global_position + Vector2(0, -20)
	AudioDirector.sfx_play("respawn")
	var tw := create_tween()
	tw.tween_property(pole, "color:a", 0.5, 0.3)
	tw.tween_property(pole, "color:a", 0.0, 0.6)
