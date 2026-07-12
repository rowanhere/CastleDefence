extends CanvasLayer

const BASE_TOWER_COST := 400
const UPGRADE_SOUND: AudioStream = preload("res://assets/audio/sfx/tower-upgrade.mp3")
const SFX_VOLUME_60_PERCENT := -4.4
const TOWER_DESCRIPTIONS := {
	"archer": "Fast shots and steady lane control.",
	"barrack": "Hold the path with melee soldiers.",
	"bomb": "Burst damage with heavy reloads.",
	"magic": "Focused arcane damage with strong range."
}

@onready var header_text: Label = $Root/Window/Header
@onready var subheader_text: Label = $Root/Window/SubHeader
@onready var description_text: Label = $Root/Window/TowerDescription
@onready var stats_card: Panel = $Root/Window/StatsCard
@onready var stats_title_text: Label = $Root/Window/StatsCard/StatsTitle
@onready var damage_row: Panel = $Root/Window/StatsCard/DamageRow
@onready var damage_text: Label = $Root/Window/StatsCard/DamageRow/DamageText
@onready var range_row: Panel = $Root/Window/StatsCard/RangeRow
@onready var range_text: Label = $Root/Window/StatsCard/RangeRow/RangeText
@onready var speed_row: Panel = $Root/Window/StatsCard/SpeedRow
@onready var speed_text: Label = $Root/Window/StatsCard/SpeedRow/SpeedText
@onready var close_button: TextureButton = $Root/Window/CloseButton
@onready var upgrade_card: Panel = $Root/Window/UpgradeCard
@onready var destroy_card: Panel = $Root/Window/DestroyCard
@onready var upgrade_title_text: Label = $Root/Window/UpgradeCard/UpgradeTitle
@onready var destroy_title_text: Label = $Root/Window/DestroyCard/DestroyTitle
@onready var upgrade_cost_text: Label = $Root/Window/UpgradeCard/UpgradeCostText
@onready var refund_text: Label = $Root/Window/DestroyCard/RefundText

var tower_node: Node = null


func setup_for_tower(target_tower: Node) -> void:
	tower_node = target_tower
	if is_node_ready():
		_apply_tower_data()

func _ready() -> void:
	if close_button != null:
		close_button.pressed.connect(_on_close_pressed)
	if upgrade_card != null:
		upgrade_card.gui_input.connect(_on_upgrade_card_input)
	if destroy_card != null:
		destroy_card.gui_input.connect(_on_destroy_card_input)
	_apply_tower_data()


func _apply_tower_data() -> void:
	var tower_data: TowerData = _get_tower_data()
	var current_upgrade: UpgradeData = _get_current_upgrade()
	var next_upgrade: UpgradeData = _get_next_upgrade(tower_data, current_upgrade)
	var has_next_upgrade: bool = next_upgrade != null and next_upgrade != current_upgrade
	var tower_name: String = "Tower"

	if tower_data != null and not tower_data.name.is_empty():
		tower_name = tower_data.name.capitalize() + " Tower"

	if header_text != null:
		header_text.text = tower_name
	if description_text != null:
		var key := tower_data.name.to_lower() if tower_data != null else ""
		description_text.text = TOWER_DESCRIPTIONS.get(key, "Upgrade this tower.")
	if subheader_text != null:
		var current_level: int = current_upgrade.level if current_upgrade != null else 1
		if has_next_upgrade:
			subheader_text.text = "Level %d  ->  Level %d" % [current_level, next_upgrade.level]
		else:
			subheader_text.text = "Level %d" % current_level
	if upgrade_title_text != null:
		upgrade_title_text.text = "Upgrade"
	if destroy_title_text != null:
		destroy_title_text.text = "Destroy"
	if stats_title_text != null:
		stats_title_text.text = "Upgrade Preview" if has_next_upgrade else "Max upgrade reach"
	if damage_row != null:
		damage_row.visible = has_next_upgrade
	if range_row != null:
		range_row.visible = has_next_upgrade
	if speed_row != null:
		speed_row.visible = has_next_upgrade
	if upgrade_card != null:
		upgrade_card.visible = has_next_upgrade
	if stats_card != null:
		stats_card.size.y = 58.0 if has_next_upgrade else 30.0
	if destroy_card != null:
		destroy_card.position.x = 96.0 if has_next_upgrade else 52.0
	if damage_text != null:
		damage_text.text = "Damage %s -> %s" % [
			_format_number(current_upgrade.damage if current_upgrade != null else 0.0),
			_format_number(next_upgrade.damage if next_upgrade != null else (current_upgrade.damage if current_upgrade != null else 0.0))
		]
	if range_text != null:
		range_text.text = "Range %s -> %s" % [
			_format_number(current_upgrade.tower_range if current_upgrade != null else 0.0),
			_format_number(next_upgrade.tower_range if next_upgrade != null else (current_upgrade.tower_range if current_upgrade != null else 0.0))
		]
	if speed_text != null:
		speed_text.text = "Rate %s -> %s" % [
			_format_number(current_upgrade.attackSpeed if current_upgrade != null else 0.0),
			_format_number(next_upgrade.attackSpeed if next_upgrade != null else (current_upgrade.attackSpeed if current_upgrade != null else 0.0))
		]
	if upgrade_cost_text != null:
		var upgrade_cost: int = next_upgrade.upgradeCost if next_upgrade != null else (current_upgrade.upgradeCost if current_upgrade != null else BASE_TOWER_COST)
		upgrade_cost_text.text = str(upgrade_cost)
	if refund_text != null:
		var current_cost: int = current_upgrade.upgradeCost if current_upgrade != null else BASE_TOWER_COST
		refund_text.text = str(int(round(current_cost * 0.8)))


func _get_tower_data() -> TowerData:
	var tower_root := _get_tower_root()
	if tower_root == null:
		return null
	if "archer_tower_data" in tower_root:
		return tower_root.archer_tower_data
	if "barrack_tower_data" in tower_root:
		return tower_root.barrack_tower_data
	if "bomb_tower_data" in tower_root:
		return tower_root.bomb_tower_data
	if "magic_tower_data" in tower_root:
		return tower_root.magic_tower_data
	return null


func _get_current_upgrade() -> UpgradeData:
	var tower_root := _get_tower_root()
	if tower_root == null:
		return null
	if "active_upgrade" in tower_root:
		return tower_root.active_upgrade
	return null


func _get_tower_root() -> Node:
	if tower_node == null or not is_instance_valid(tower_node):
		return null
	if "active_upgrade" in tower_node or "archer_tower_data" in tower_node or "barrack_tower_data" in tower_node or "bomb_tower_data" in tower_node or "magic_tower_data" in tower_node:
		return tower_node
	return tower_node.get_parent()


func _get_next_upgrade(tower_data: TowerData, current_upgrade: UpgradeData) -> UpgradeData:
	if tower_data == null or tower_data.upgrades.is_empty():
		return null
	if current_upgrade == null:
		return tower_data.upgrades[0]
	var current_index: int = max(current_upgrade.level - 1, 0)
	if current_index >= tower_data.upgrades.size():
		current_index = tower_data.upgrades.find(current_upgrade)
	if current_index < 0:
		current_index = 0
	var next_index: int = min(current_index + 1, tower_data.upgrades.size() - 1)
	return tower_data.upgrades[next_index]


func _format_number(value: float) -> String:
	if is_zero_approx(value - round(value)):
		return str(int(round(value)))
	return str(snappedf(value, 0.01))


func _on_upgrade_card_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_try_upgrade_tower()


func _on_destroy_card_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_destroy_tower()


func _try_upgrade_tower() -> void:
	var tower_root := _get_tower_root()
	var tower_data: TowerData = _get_tower_data()
	var current_upgrade: UpgradeData = _get_current_upgrade()
	var next_upgrade: UpgradeData = _get_next_upgrade(tower_data, current_upgrade)
	if tower_root == null or next_upgrade == null or next_upgrade == current_upgrade:
		_apply_tower_data()
		return

	var upgrade_cost: int = next_upgrade.upgradeCost
	if GameHandler.coins < upgrade_cost:
		GameHandler.play_purchase_failed_feedback()
		return

	GameHandler.coins -= upgrade_cost
	var current_scene := get_tree().current_scene
	if current_scene != null and current_scene.has_method("_update_hud"):
		current_scene._update_hud()

	tower_root.active_upgrade = next_upgrade
	_apply_upgrade_to_tower(tower_root, next_upgrade)
	if tower_root.has_method("handle_upgrade_applied"):
		tower_root.handle_upgrade_applied()
	GameSound.play(UPGRADE_SOUND, SFX_VOLUME_60_PERCENT)
	_on_close_pressed()


func _destroy_tower() -> void:
	var tower_root := _get_tower_root()
	if tower_root == null:
		_on_close_pressed()
		return

	var current_upgrade: UpgradeData = _get_current_upgrade()
	var current_cost: int = current_upgrade.upgradeCost if current_upgrade != null else BASE_TOWER_COST
	GameHandler.add_coins(int(round(current_cost * 0.8)))
	_restore_tower_builder(tower_root)
	_on_close_pressed()
	tower_root.queue_free()


func _restore_tower_builder(tower_root: Node) -> void:
	if not tower_root.has_meta("builder_scene") or not tower_root.has_meta("builder_global_transform"):
		return
	var builder_scene := tower_root.get_meta("builder_scene") as PackedScene
	var tower_parent := tower_root.get_parent()
	if builder_scene == null or tower_parent == null:
		return
	var builder := builder_scene.instantiate() as Node2D
	if builder == null:
		return
	var builder_transform: Transform2D = tower_root.get_meta("builder_global_transform")
	tower_parent.add_child(builder)
	builder.global_transform = builder_transform
	if builder.has_method("refresh_builder_position"):
		builder.refresh_builder_position()


func _apply_upgrade_to_tower(tower_root: Node, next_upgrade: UpgradeData) -> void:
	if tower_root == null or next_upgrade == null:
		return

	var tower_image := tower_root.get_node_or_null("TowerImage") as Sprite2D
	if tower_image != null and next_upgrade.towerImage != null:
		tower_image.texture = next_upgrade.towerImage

	if next_upgrade.isTowerTop:
		var tower_top := tower_root.get_node_or_null("TowerTop") as Sprite2D
		if tower_top != null and next_upgrade.towerTop != null:
			tower_top.texture = next_upgrade.towerTop

	var tower_collision := tower_root.get_node_or_null("TowerImage/towerArea/towerCollision") as CollisionShape2D
	if tower_collision != null and tower_collision.shape is CircleShape2D:
		var circle := tower_collision.shape as CircleShape2D
		circle.radius = next_upgrade.tower_range

	var range_circle := tower_root.get_node_or_null("TowerImage/towerArea/Range circle")
	if range_circle != null and "radius" in range_circle:
		range_circle.radius = next_upgrade.tower_range
		if range_circle.has_method("queue_redraw"):
			range_circle.queue_redraw()

	if "attack_rate" in tower_root:
		tower_root.attack_rate = max(next_upgrade.attackSpeed, 0.01)



func _on_close_pressed() -> void:
	if tower_node != null and is_instance_valid(tower_node):
		if "selected" in tower_node:
			tower_node.selected = false
		if tower_node.has_method("hide_range"):
			tower_node.hide_range()
	var script := load("res://scripts/towers/tower_collision_animation.gd")
	if script != null:
		script.active_upgrade_ui = null
		script.active_selected_tower = null
	queue_free()
