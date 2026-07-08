extends Sprite2D

const TOWER_UPGRADE_SCENE := preload("res://scenes/systems/tower/tower_upgrade.tscn")

static var active_upgrade_ui: Node = null
static var active_selected_tower: Sprite2D = null

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
			if active_selected_tower != null and active_selected_tower != self:
				active_selected_tower.selected = false
				active_selected_tower.hide_range()
			if active_upgrade_ui != null and is_instance_valid(active_upgrade_ui):
				active_upgrade_ui.queue_free()
				active_upgrade_ui = null

			selected = !selected

			if selected:
				active_selected_tower = self
				show_range()
				_open_upgrade_ui()
			else:
				if active_selected_tower == self:
					active_selected_tower = null
				hide_range()


func _open_upgrade_ui() -> void:
	var ui := TOWER_UPGRADE_SCENE.instantiate()
	if ui.has_method("setup_for_tower"):
		ui.setup_for_tower(self)
	active_upgrade_ui = ui
	get_tree().current_scene.add_child(ui)


static func clear_active_upgrade_ui_selection() -> void:
	if active_upgrade_ui != null and is_instance_valid(active_upgrade_ui):
		active_upgrade_ui = null
	if active_selected_tower != null and is_instance_valid(active_selected_tower):
		active_selected_tower.selected = false
		active_selected_tower.hide_range()
	active_selected_tower = null


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
