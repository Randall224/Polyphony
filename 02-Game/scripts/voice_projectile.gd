extends Area2D
## 音波（灰盒→像素）：直飞、命中失调体削韧、碰墙消失。

var velocity := Vector2.ZERO
var damage := 10.0
var attr := "release"
var life := 0.9

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 | 4   # 失调体(2) + 地形(4)
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(10, 5)
	cs.shape = sh
	add_child(cs)
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/sprites/wave_shot.png")
	add_child(sprite)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += velocity * delta
	life -= delta
	if life <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemies") and body.has_method("take_hit"):
		body.take_hit(damage, attr)
	queue_free()
