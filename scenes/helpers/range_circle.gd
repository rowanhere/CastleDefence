extends Node2D

var radius: float = 250.00
var color: Color = Color(0x0000030)
func _ready() -> void:
	position = Vector2.ZERO
func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
