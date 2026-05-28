extends Sprite2D

@onready var tower_area: Area2D = $towerArea
@onready var tower_collision: CollisionShape2D = $towerArea/towerCollision
@onready var range_circle: Node2D = $towerArea/"Range circle"

var selected := false


func _ready() -> void:
	hide_range()

	tower_area.input_pickable = true
	tower_area.input_event.connect(_on_tower_clicked)


func _on_tower_clicked(viewport, event, shape_idx) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			selected = !selected

			if selected:
				show_range()
			else:
				hide_range()


func show_range() -> void:
	range_circle.scale = Vector2.ZERO
	range_circle.visible = true

	create_tween()\
		.tween_property(
			range_circle,
			"scale",
			Vector2.ONE,
			0.3
		)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)


func hide_range() -> void:
	var tween = create_tween()

	tween.tween_property(
		range_circle,
		"scale",
		Vector2.ZERO,
		0.2
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

	tween.tween_callback(
		func():
			range_circle.visible = false
	)
