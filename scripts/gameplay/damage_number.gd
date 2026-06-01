# DamageNumber.gd
extends Label

var velocity := Vector2(randf_range(-20, 20), -60)
var lifetime := 1.0
var elapsed := 0.0

func _ready():
	z_index = 10

func _process(delta):
	elapsed += delta
	var t = elapsed / lifetime
	position += velocity * delta
	velocity.y += 30 * delta  # slight gravity arc
	modulate.a = 1.0 - t      # fade out
	scale = Vector2.ONE * (1.0 + t * 0.4)  # grow slightly
	if elapsed >= lifetime:
		queue_free()
