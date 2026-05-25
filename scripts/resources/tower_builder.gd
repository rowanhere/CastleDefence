extends Node2D

const TOWER_BUILDER_BUTTON = preload("res://scenes/towerHelpers/tower_builder_button.tscn")
var addTowerBuilder
func _ready() -> void:
	var btn = $TextureButton
	 
	addTowerBuilder = TOWER_BUILDER_BUTTON.instantiate()
	addTowerBuilder.coinAmt = 400
	addTowerBuilder.towerBuilderPosition = btn.global_position + btn.size / 2
	addTowerBuilder.z_index = 100
	addTowerBuilder.visible = false

	add_child(addTowerBuilder)

	addTowerBuilder.insertFour()

	# connect once
	addTowerBuilder.purchased.connect(func():
		close_popup()
		queue_free()
	)
	addTowerBuilder.purchased.connect(remove_builder)

func _on_texture_button_pressed() -> void:
	if addTowerBuilder.visible:
		close_popup()
		return

	addTowerBuilder.global_position = global_position
	addTowerBuilder.modulate.a = 1.0
	addTowerBuilder.scale = Vector2(0, 0)
	addTowerBuilder.visible = true
	
	create_tween().tween_property(addTowerBuilder, "scale", Vector2(2, 2), 0.2) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _unhandled_input(event: InputEvent) -> void:
	if not addTowerBuilder.visible or not event is InputEventMouseButton or not event.pressed:
		return

	if addTowerBuilder.get_global_rect().has_point(get_viewport().get_mouse_position()):
		if addTowerBuilder.isPurchased():
			close_popup()
	else:
		close_popup()

func close_popup() -> void:
	var tween = create_tween().set_parallel(true)

	tween.tween_property(addTowerBuilder, "modulate:a", 0.0, 0.2) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	tween.tween_property(addTowerBuilder, "scale", Vector2(0, 0), 0.2) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)

	tween.chain().tween_callback(func(): addTowerBuilder.visible = false)

func remove_builder() -> void:
	queue_free()
