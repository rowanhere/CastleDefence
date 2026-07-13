extends Node2D

const TOWER_BUILDER_BUTTON = preload("res://scenes/systems/tower/tower_builder_button.tscn")
const POPUP_OPEN_SCALE := Vector2(2, 2)
const POPUP_SCREEN_MARGIN := 24.0
const POPUP_EDGE_GAP := 12.0
const BUILDER_Z_INDEX := 2500
const POPUP_Z_INDEX := 4096
const DEFAULT_HOVER_MODULATE := Color(0.72, 0.72, 0.72, 1.0)

@export var button_texture_normal: Texture2D
@export var button_texture_hover: Texture2D
@export var button_texture_pressed: Texture2D

@onready var button: TextureButton = $TextureButton

var addTowerBuilder
var _builder_center := Vector2.ZERO


func _ready() -> void:
	z_as_relative = false
	z_index = BUILDER_Z_INDEX
	_apply_button_textures()
	button.mouse_entered.connect(_on_button_mouse_entered)
	button.mouse_exited.connect(_on_button_mouse_exited)
	button.z_as_relative = false
	button.z_index = BUILDER_Z_INDEX
	_builder_center = button.global_position + button.size / 2
	 
	addTowerBuilder = TOWER_BUILDER_BUTTON.instantiate()
	addTowerBuilder.coinAmt = 400
	addTowerBuilder.towerBuilderPosition = _builder_center
	addTowerBuilder.z_as_relative = false
	addTowerBuilder.z_index = POPUP_Z_INDEX
	addTowerBuilder.visible = false

	add_child(addTowerBuilder)

	addTowerBuilder.insertFour()

	# connect once
	addTowerBuilder.purchased.connect(func():
		close_popup()
		queue_free()
	)
	addTowerBuilder.purchased.connect(remove_builder)


func refresh_builder_position() -> void:
	_builder_center = button.global_position + button.size / 2
	if addTowerBuilder != null:
		addTowerBuilder.towerBuilderPosition = _builder_center


func _apply_button_textures() -> void:
	if button_texture_normal != null:
		button.texture_normal = button_texture_normal
	if button_texture_hover != null:
		button.texture_hover = button_texture_hover
	else:
		button.texture_hover = button.texture_normal
	if button_texture_pressed != null:
		button.texture_pressed = button_texture_pressed


func _on_button_mouse_entered() -> void:
	if button_texture_hover == null:
		button.self_modulate = DEFAULT_HOVER_MODULATE


func _on_button_mouse_exited() -> void:
	button.self_modulate = Color.WHITE


func get_button_texture_config() -> Dictionary:
	return {
		"normal": button_texture_normal,
		"hover": button_texture_hover,
		"pressed": button_texture_pressed,
	}

func _on_texture_button_pressed() -> void:
	if addTowerBuilder.visible:
		close_popup()
		return

	addTowerBuilder.global_position = _get_popup_position()
	addTowerBuilder.modulate.a = 1.0
	addTowerBuilder.scale = Vector2(0, 0)
	addTowerBuilder.visible = true
	
	create_tween().tween_property(addTowerBuilder, "scale", POPUP_OPEN_SCALE, 0.2) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _get_popup_position() -> Vector2:
	_builder_center = button.global_position + button.size / 2
	var popup_size := _get_popup_size()
	var visible_world_rect := _get_visible_world_rect()
	var popup_position := _builder_center - popup_size * 0.5

	if popup_position.x + popup_size.x > visible_world_rect.position.x + visible_world_rect.size.x - POPUP_SCREEN_MARGIN:
		popup_position.x = _builder_center.x - popup_size.x - POPUP_EDGE_GAP
	if popup_position.y + popup_size.y > visible_world_rect.position.y + visible_world_rect.size.y - POPUP_SCREEN_MARGIN:
		popup_position.y = _builder_center.y - popup_size.y - POPUP_EDGE_GAP

	popup_position.x = maxf(popup_position.x, visible_world_rect.position.x + POPUP_SCREEN_MARGIN)
	popup_position.y = maxf(popup_position.y, visible_world_rect.position.y + POPUP_SCREEN_MARGIN)
	return popup_position


func _get_popup_size() -> Vector2:
	var ring := addTowerBuilder.get_node_or_null("TowerBtnRing") as Control
	if ring == null:
		return Vector2(324.0, 258.0)
	return ring.size * POPUP_OPEN_SCALE


func _get_visible_world_rect() -> Rect2:
	var viewport_rect := get_viewport().get_visible_rect()
	var inverse_canvas_transform := get_viewport().get_canvas_transform().affine_inverse()
	var top_left := inverse_canvas_transform * viewport_rect.position
	var bottom_right := inverse_canvas_transform * (viewport_rect.position + viewport_rect.size)
	return Rect2(top_left, bottom_right - top_left).abs()

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
