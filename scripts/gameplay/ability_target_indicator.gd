extends Node2D

const TARGET_RADIUS := 100.0
const FILL_COLOR := Color(0.18, 0.9, 0.3, 0.12)
const RING_COLOR := Color(0.35, 1.0, 0.42, 0.9)
const CENTER_COLOR := Color(0.7, 1.0, 0.72, 0.95)


func _ready() -> void:
	z_as_relative = false
	z_index = 4094
	queue_redraw()


func _process(_delta: float) -> void:
	global_position = get_global_mouse_position()


func _draw() -> void:
	draw_circle(Vector2.ZERO, TARGET_RADIUS, FILL_COLOR)
	draw_arc(Vector2.ZERO, TARGET_RADIUS, 0.0, TAU, 96, RING_COLOR, 1.5, true)
	draw_circle(Vector2.ZERO, 3.0, CENTER_COLOR)
