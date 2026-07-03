extends Node2D

@onready var placement_area: Area2D = $PlacementArea

var can_place: bool = true

func _process(_delta: float) -> void:
	global_position = get_global_mouse_position()
	can_place = placement_area.get_overlapping_areas().is_empty()
	modulate = Color(0.2, 1.0, 0.2, 0.55) if can_place else Color(1.0, 0.2, 0.2, 0.55)
