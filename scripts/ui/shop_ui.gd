extends Control

signal balance_changed(new_balance: int)

const BUTTON_HOVER_SOUND: AudioStream = preload("res://assets/audio/sfx/buttonHover.mp3")
const PANEL_SCALE := Vector2(0.86, 0.86)
const PANEL_OPEN_START_SCALE := Vector2(0.78, 0.78)
const ITEM_DATA: Dictionary = {
	&"fire": {"price": 3, "node": "Fire", "count": "FireCount"},
	&"thunder": {"price": 5, "node": "Thunder", "count": "ThunderCount"},
	&"rock": {"price": 4, "node": "Rock", "count": "RockCount"},
}

@onready var panel: Control = $Panel
@onready var close_button: TextureButton = $Panel/CloseButton
@onready var done_button: TextureButton = $Panel/DoneButton
@onready var balance_label: Label = $Panel/Balance/Amount
@onready var total_label: Label = $Panel/Total/Amount

var _save_manager: Node = null
var _feedback_tween: Tween = null
var _selection: Dictionary = {}


func _ready() -> void:
	_save_manager = get_node_or_null("/root/SaveManager")
	close_button.pressed.connect(close_shop)
	done_button.pressed.connect(_confirm_purchase)
	for ability_id in ITEM_DATA:
		_selection[ability_id] = 0
		var item: Dictionary = ITEM_DATA[ability_id]
		var item_node: Node = panel.get_node("Items/%s" % item["node"])
		var minus_button: Button = item_node.get_node("Selector/Minus") as Button
		var plus_button: Button = item_node.get_node("Selector/Plus") as Button
		minus_button.pressed.connect(_change_quantity.bind(ability_id, -1))
		plus_button.pressed.connect(_change_quantity.bind(ability_id, 1))
		plus_button.mouse_entered.connect(_play_hover)
		minus_button.mouse_entered.connect(_play_hover)
	refresh()


func open_shop() -> void:
	_reset_selection()
	refresh()
	show()
	panel.pivot_offset = panel.size * 0.5
	panel.scale = PANEL_OPEN_START_SCALE
	panel.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "scale", PANEL_SCALE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.12)


func close_shop() -> void:
	if not visible:
		return
	_reset_selection()
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "scale", PANEL_OPEN_START_SCALE, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "modulate:a", 0.0, 0.08)
	tween.chain().tween_callback(hide)


func refresh() -> void:
	if _save_manager == null:
		return
	var balance: int = int(_save_manager.get("total_rewards"))
	balance_label.text = str(balance)
	var total_cost: int = _get_total_cost()
	total_label.text = str(total_cost)
	done_button.disabled = total_cost <= 0 or total_cost > balance
	for ability_id in ITEM_DATA:
		var item: Dictionary = ITEM_DATA[ability_id]
		var item_node: Node = panel.get_node("Items/%s" % item["node"])
		var owned_label: Label = item_node.get_node(item["count"]) as Label
		var quantity_label: Label = item_node.get_node("Selector/Quantity") as Label
		var minus_button: Button = item_node.get_node("Selector/Minus") as Button
		var plus_button: Button = item_node.get_node("Selector/Plus") as Button
		owned_label.text = "OWNED %d" % int(_save_manager.call("get_ability_count", ability_id))
		quantity_label.text = str(int(_selection.get(ability_id, 0)))
		minus_button.disabled = int(_selection.get(ability_id, 0)) <= 0
		plus_button.disabled = total_cost + int(item["price"]) > balance


func _change_quantity(ability_id: StringName, delta: int) -> void:
	var current: int = int(_selection.get(ability_id, 0))
	var next: int = maxi(current + delta, 0)
	if delta > 0:
		var price: int = int(ITEM_DATA[ability_id]["price"])
		var balance: int = int(_save_manager.get("total_rewards")) if _save_manager != null else 0
		if _get_total_cost() + price > balance:
			_show_insufficient_feedback()
			return
	_selection[ability_id] = next
	refresh()


func _confirm_purchase() -> void:
	if _save_manager == null or not _save_manager.has_method("purchase_abilities"):
		return
	var prices: Dictionary = {}
	for ability_id in ITEM_DATA:
		prices[ability_id] = int(ITEM_DATA[ability_id]["price"])
	if not bool(_save_manager.call("purchase_abilities", _selection.duplicate(), prices)):
		_show_insufficient_feedback()
		return
	_reset_selection()
	refresh()
	balance_changed.emit(int(_save_manager.get("total_rewards")))
	_pulse(done_button)


func _reset_selection() -> void:
	for ability_id in ITEM_DATA:
		_selection[ability_id] = 0


func _get_total_cost() -> int:
	var total: int = 0
	for ability_id in ITEM_DATA:
		total += int(_selection.get(ability_id, 0)) * int(ITEM_DATA[ability_id]["price"])
	return total


func _show_insufficient_feedback() -> void:
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()
	var base_position: Vector2 = balance_label.position
	balance_label.modulate = Color(1.0, 0.3, 0.3)
	_feedback_tween = create_tween()
	_feedback_tween.tween_property(balance_label, "position:x", base_position.x - 3.0, 0.04)
	_feedback_tween.tween_property(balance_label, "position:x", base_position.x + 3.0, 0.06)
	_feedback_tween.tween_property(balance_label, "position:x", base_position.x, 0.05)
	_feedback_tween.parallel().tween_property(balance_label, "modulate", Color.WHITE, 0.18)


func _play_hover() -> void:
	GameSound.play(BUTTON_HOVER_SOUND, -8.0)


func _pulse(button: BaseButton) -> void:
	button.pivot_offset = button.size * 0.5
	var tween: Tween = create_tween()
	tween.tween_property(button, "scale", Vector2(0.92, 0.92), 0.06)
	tween.tween_property(button, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
