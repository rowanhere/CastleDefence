extends Control

signal ability_selected(ability_id: StringName)

const ABILITY_IDS: Array[StringName] = [&"fire", &"freeze", &"thunder", &"rock"]
const ABILITY_CAPTIONS: Dictionary = {
	&"fire": "Fire Storm",
	&"freeze": "Time Freeze",
	&"thunder": "Thunder Strike",
	&"rock": "Meteor Rocks",
}
const HOVER_SCALE := Vector2(1.06, 1.06)

@onready var _buttons: Array[TextureButton] = [
	$Buttons/Fire,
	$Buttons/Freeze,
	$Buttons/Thunder,
	$Buttons/Rock,
]
@onready var _caption: Label = $AbilityCaption

var _cooldown_remaining: Dictionary = {}
var _cooldown_duration: Dictionary = {}
var _button_tweens: Dictionary = {}
var _save_manager: Node = null


func _ready() -> void:
	_save_manager = get_node_or_null("/root/SaveManager")
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


func consume_ability(ability_id: StringName) -> bool:
	if _save_manager == null or not _save_manager.has_method("consume_ability"):
		return false
	var consumed: bool = bool(_save_manager.call("consume_ability", ability_id))
	refresh_inventory()
	return consumed


func _on_ability_pressed(ability_id: StringName) -> void:
	if float(_cooldown_remaining.get(ability_id, 0.0)) > 0.0:
		return
	ability_selected.emit(ability_id)


func _get_button(ability_id: StringName) -> TextureButton:
	var index: int = ABILITY_IDS.find(ability_id)
	if index < 0 or index >= _buttons.size():
		return null
	return _buttons[index]


func _get_inventory_count(ability_id: StringName) -> int:
	if _save_manager == null or not _save_manager.has_method("get_ability_count"):
		return 0
	return maxi(int(_save_manager.call("get_ability_count", ability_id)), 0)


func _update_button_cooldown(button: TextureButton, remaining: float, duration: float) -> void:
	var overlay: ColorRect = button.get_node("CooldownOverlay") as ColorRect
	var label: Label = button.get_node("CooldownLabel") as Label
	var active: bool = remaining > 0.0
	overlay.visible = active
	label.visible = active
	var index: int = _buttons.find(button)
	var ability_id: StringName = ABILITY_IDS[index] if index >= 0 else StringName()
	button.disabled = active or _get_inventory_count(ability_id) <= 0
	if not active:
		return
	var ratio: float = clampf(remaining / duration, 0.0, 1.0)
	overlay.anchor_top = 1.0 - ratio
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
