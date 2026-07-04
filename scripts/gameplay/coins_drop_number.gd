extends Node2D
@onready var coin_drop: Label = $CoinDrop
@onready var coin_img: TextureRect = $CoinImg

var velocity := Vector2(randf_range(-20, 20), -60)
var lifetime := 1.0
var elapsed := 0.0
var amount: int = 0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	z_index = 10
	coin_drop.text = "+" + str(amount)
	coin_drop.add_theme_font_size_override("font_size", 12)
	coin_drop.add_theme_color_override("font_color", Color(1.0, 0.86, 0.22))
	scale = Vector2(1.15, 1.15)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	elapsed += delta
	var t = elapsed / lifetime
	position += velocity * delta
	velocity.y += 30 * delta
	modulate.a = 1.0 - t
	scale = Vector2.ONE * (1.0 + t * 0.4)
	if elapsed >= lifetime:
		queue_free()
