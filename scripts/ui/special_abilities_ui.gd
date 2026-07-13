extends Control

signal ability_selected(ability_id: StringName)
signal ability_targeted(ability_id: StringName, world_position: Vector2)

const ABILITY_IDS: Array[StringName] = [&"fire", &"thunder", &"rock"]
const ABILITY_CAPTIONS: Dictionary = {
	&"fire": "Fire Storm",
	&"thunder": "Thunder Strike",
	&"rock": "Meteor Rocks",
}
const HOVER_SCALE := Vector2(1.06, 1.06)
const TARGET_INDICATOR_SCENE: PackedScene = preload("res://scenes/gameplay/ability_target_indicator.tscn")
const ABILITY_EFFECT_SCENE: PackedScene = preload("res://scenes/gameplay/special_ability_effect.tscn")
const FIRE_DATA: Resource = preload("res://resources/special_abilities/fire.tres")
const THUNDER_DATA: Resource = preload("res://resources/special_abilities/thunder.tres")
const ROCK_DATA: Resource = preload("res://resources/special_abilities/rock.tres")
const TARGET_RADIUS := 100.0
const EFFECT_DURATION := 1.25
const ABILITY_COOLDOWN := 20.0
const ABILITY_DATA: Dictionary = {
	&"fire": FIRE_DATA,
	&"thunder": THUNDER_DATA,
	&"rock": ROCK_DATA,
}

@onready var _buttons: Array[TextureButton] = [
	$Buttons/Fire,
	$Buttons/Thunder,
	$Buttons/Rock,
]
@onready var _caption: Label = $AbilityCaption
@onready var _input_blocker: Control = get_node_or_null("../AbilityTargetBlocker") as Control

var _cooldown_remaining: Dictionary = {}
var _cooldown_duration: Dictionary = {}
var _button_tweens: Dictionary = {}
var _save_manager: Node = null
var _selected_ability: StringName = StringName()
var _target_indicator: Node2D = null


func _ready() -> void:
	_save_manager = get_node_or_null("/root/SaveManager")
	if _input_blocker != null:
		_input_blocker.gui_input.connect(_on_target_blocker_input)
	for index in range(_buttons.size()):
		var button: TextureButton = _buttons[index]
		var ability_id: StringName = ABILITY_IDS[index]
		button.pivot_offset = button.size * 0.5
		button.pressed.connect(_on_ability_pressed.bind(ability_id))
		button.mouse_entered.connect(_on_button_hovered.bind(button, ability_id))
		button.mouse_exited.connect(_on_button_exited.bind(button))
		_update_button_cooldown(button, 0.0, 1.0)
	refresh_inventory()


func _process(delta: float) -> void:
	for ability_id in _cooldown_remaining.keys():
		var remaining: float = maxf(float(_cooldown_remaining[ability_id]) - delta, 0.0)
		var duration: float = maxf(float(_cooldown_duration.get(ability_id, 1.0)), 0.001)
		_cooldown_remaining[ability_id] = remaining
		var button: TextureButton = _get_button(ability_id)
		if button != null:
			_update_button_cooldown(button, remaining, duration)
		if remaining <= 0.0:
			_cooldown_remaining.erase(ability_id)
			_cooldown_duration.erase(ability_id)


func start_cooldown(ability_id: StringName, duration: float) -> void:
	if duration <= 0.0:
		return
	var button: TextureButton = _get_button(ability_id)
	if button == null:
		return
	_cooldown_remaining[ability_id] = duration
	_cooldown_duration[ability_id] = duration
	_update_button_cooldown(button, duration, duration)


func set_ability_enabled(ability_id: StringName, enabled: bool) -> void:
	var button: TextureButton = _get_button(ability_id)
	if button != null:
		button.disabled = not enabled


func refresh_inventory() -> void:
	for index in range(_buttons.size()):
		var button: TextureButton = _buttons[index]
		var ability_id: StringName = ABILITY_IDS[index]
		var count: int = _get_inventory_count(ability_id)
		var count_label: Label = button.get_node("CountLabel") as Label
		count_label.text = str(count)
		count_label.visible = true
		button.disabled = count <= 0 or float(_cooldown_remaining.get(ability_id, 0.0)) > 0.0
	if not _selected_ability.is_empty() and _get_inventory_count(_selected_ability) <= 0:
		clear_selection()


func consume_ability(ability_id: StringName) -> bool:
	if _save_manager == null or not _save_manager.has_method("consume_ability"):
		return false
	var consumed: bool = bool(_save_manager.call("consume_ability", ability_id))
	refresh_inventory()
	return consumed


func _on_ability_pressed(ability_id: StringName) -> void:
	if float(_cooldown_remaining.get(ability_id, 0.0)) > 0.0:
		return
	if _selected_ability == ability_id:
		clear_selection()
		return
	_select_ability(ability_id)
	ability_selected.emit(ability_id)


func _unhandled_input(event: InputEvent) -> void:
	if _selected_ability.is_empty():
		return
	if event.is_action_pressed("ui_cancel"):
		clear_selection()
		get_viewport().set_input_as_handled()


func _on_target_blocker_input(event: InputEvent) -> void:
	if _selected_ability.is_empty() or not event is InputEventMouseButton:
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_event.pressed:
		return
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		clear_selection()
		return
	if mouse_event.button_index == MOUSE_BUTTON_LEFT and _target_indicator != null and is_instance_valid(_target_indicator):
		var target_position: Vector2 = _target_indicator.get_global_mouse_position()
		_target_indicator.global_position = target_position
		_use_selected_ability(target_position)


func _use_selected_ability(world_position: Vector2) -> void:
	if not ABILITY_DATA.has(_selected_ability):
		return
	var ability_id: StringName = _selected_ability
	if not consume_ability(ability_id):
		clear_selection()
		return
	var data: Resource = ABILITY_DATA[ability_id] as Resource
	var effect: Node2D = ABILITY_EFFECT_SCENE.instantiate() as Node2D
	if effect == null:
		return
	effect.call("configure", data, TARGET_RADIUS, EFFECT_DURATION)
	effect.global_position = world_position
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		effect.queue_free()
		return
	current_scene.add_child(effect)
	effect.call("activate")
	start_cooldown(ability_id, ABILITY_COOLDOWN)
	ability_targeted.emit(ability_id, world_position)
	clear_selection()


func clear_selection() -> void:
	_selected_ability = StringName()
	_update_selection_glows()
	if _input_blocker != null:
		_input_blocker.hide()
	if _target_indicator != null and is_instance_valid(_target_indicator):
		_target_indicator.queue_free()
	_target_indicator = null


func _select_ability(ability_id: StringName) -> void:
	_selected_ability = ability_id
	_update_selection_glows()
	if _input_blocker != null:
		_input_blocker.show()
	if _target_indicator == null or not is_instance_valid(_target_indicator):
		_target_indicator = TARGET_INDICATOR_SCENE.instantiate() as Node2D
		var current_scene: Node = get_tree().current_scene
		if current_scene != null:
			current_scene.add_child(_target_indicator)


func _update_selection_glows() -> void:
	for index in range(_buttons.size()):
		var glow: Panel = _buttons[index].get_node("SelectionGlow") as Panel
		glow.visible = ABILITY_IDS[index] == _selected_ability


func _get_button(ability_id: StringName) -> TextureButton:
	var index: int = ABILITY_IDS.find(ability_id)
	if index < 0 or index >= _buttons.size():
		return null
	return _buttons[index]


func _get_inventory_count(ability_id: StringName) -> int:
	if _save_manager == null or not _save_manager.has_method("get_ability_count"):
		return 0
	return maxi(int(_save_manager.call("get_ability_count", ability_id)), 0)


func _update_button_cooldown(button: TextureButton, remaining: float, _duration: float) -> void:
	var label: Label = button.get_node("CooldownLabel") as Label
	var count_label: Label = button.get_node("CountLabel") as Label
	var active: bool = remaining > 0.0
	label.visible = active
	count_label.visible = not active
	var index: int = _buttons.find(button)
	var ability_id: StringName = ABILITY_IDS[index] if index >= 0 else StringName()
	button.disabled = active or _get_inventory_count(ability_id) <= 0
	if not active:
		return
	label.text = str(ceili(remaining))


func _animate_button(button: TextureButton, target_scale: Vector2) -> void:
	if button.disabled:
		return
	var existing: Tween = _button_tweens.get(button) as Tween
	if existing != null and existing.is_valid():
		existing.kill()
	var tween: Tween = create_tween()
	_button_tweens[button] = tween
	tween.tween_property(button, "scale", target_scale, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_button_hovered(button: TextureButton, ability_id: StringName) -> void:
	_caption.text = str(ABILITY_CAPTIONS.get(ability_id, ""))
	_caption.visible = not _caption.text.is_empty()
	_animate_button(button, HOVER_SCALE)


func _on_button_exited(button: TextureButton) -> void:
	_caption.hide()
	_animate_button(button, Vector2.ONE)
