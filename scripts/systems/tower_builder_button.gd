extends Control

@onready var tower_btn_ring: TextureRect = $TowerBtnRing
@onready var cost_and_type_button: TextureButton = $TowerBtnRing/CostAndTypeButton
@onready var coin: Label = $TowerBtnRing/CostAndTypeButton/coin

@export var coinAmt: int = 100
@export var towerBuilderPosition: Vector2

signal purchased

const PURCHASE_SOUND: AudioStream = preload("res://assets/audio/sfx/tower_purchase.mp3")
const SFX_VOLUME_60_PERCENT := -4.4
const PURCHASE_ICON_OFFSET: Vector2 = Vector2(0.0, -4.0)
const PURCHASE_ICON_SCALE: Vector2 = Vector2(0.95, 0.95)


var insertTower = {
	"archer": preload("res://scenes/towers/archer/archerTower.tscn"),
	"barrack": preload("res://scenes/towers/barrack/barrackTower.tscn"),
	"magic": preload("res://scenes/towers/magic/magicTower.tscn"),
	"bomb": preload("res://scenes/towers/bomb/BombTower.tscn")
}


const towerBtnsImages = {
	"archer": preload("res://assets/textures/levels/towerBtnArrow.png"),
	"barrack": preload("res://assets/textures/levels/towerBtnBarrack.png"),
	"magic": preload("res://assets/textures/levels/towerBtnMagic.png"),
	"bomb": preload("res://assets/textures/levels/towerBtnBomb.png")
}


func _ready() -> void:
	coin.text = str(coinAmt)
	cost_and_type_button.visible = false


func insertFour() -> void:
	clear_buttons()

	var positions = [
		{
			"name": "archer",
			"pos": Vector2.ZERO
		},
		{
			"name": "barrack",
			"pos": Vector2(
				tower_btn_ring.size.x - cost_and_type_button.size.x,
				0
			)
		},
		{
			"name": "magic",
			"pos": Vector2(
				0,
				tower_btn_ring.size.y - cost_and_type_button.size.y
			)
		},
		{
			"name": "bomb",
			"pos": tower_btn_ring.size - cost_and_type_button.size
		}
	]

	for tower in positions:
		insertBtns(tower.pos, tower.name)


func insertBtns(pos: Vector2, tower_type: String) -> void:
	var new_btn = cost_and_type_button.duplicate()

	tower_btn_ring.add_child(new_btn)

	new_btn.position = pos
	new_btn.visible = true
	new_btn.modulate = Color.WHITE

	_set_purchase_icon(new_btn, tower_type)

	new_btn.pressed.connect(
		func():
			_purchase_tower(tower_type)
	)


func _set_purchase_icon(button: TextureButton, tower_type: String) -> void:
	var purchase_icon := button.get_node("purchaseTypeImg") as Sprite2D
	purchase_icon.texture = towerBtnsImages[tower_type] as Texture2D
	purchase_icon.position = (button.size * 0.5) + PURCHASE_ICON_OFFSET
	purchase_icon.scale = PURCHASE_ICON_SCALE


func _purchase_tower(tower_type: String) -> void:
	if !insertTower.has(tower_type):
		print("Tower not found: ", tower_type)
		return
	if GameHandler.coins < coinAmt:
		print("Not enough coins to purchase tower: ", tower_type)
		GameHandler.play_purchase_failed_feedback()
		return

	GameHandler.coins -= coinAmt
	var current_scene := get_tree().current_scene
	if current_scene != null and current_scene.has_method("_update_hud"):
		current_scene._update_hud()

	var tower_scene: PackedScene = insertTower[tower_type]
	var tower_instance = tower_scene.instantiate()
	var builder := get_parent() as Node2D
	if builder != null:
		tower_instance.set_meta("builder_scene", load("res://scenes/systems/tower/tower_builder.tscn"))
		tower_instance.set_meta("builder_global_transform", builder.global_transform)
		if builder.has_method("get_button_texture_config"):
			tower_instance.set_meta("builder_button_textures", builder.call("get_button_texture_config"))

	get_parent().get_parent().add_child(tower_instance)

	tower_instance.global_position = towerBuilderPosition
	tower_instance.z_index = 100

	play_place_animation(tower_instance)
	GameSound.play(PURCHASE_SOUND, SFX_VOLUME_60_PERCENT)

	purchased.emit()
	queue_free()


func play_place_animation(tower: Node2D) -> void:
	tower.scale = Vector2.ZERO
	tower.modulate.a = 0.0

	var tween = tower.create_tween().set_parallel(true)

	tween.tween_property(
		tower,
		"scale",
		Vector2.ONE,
		0.35
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	tween.tween_property(
		tower,
		"modulate:a",
		1.0,
		0.25
	)


func clear_buttons() -> void:
	for child in tower_btn_ring.get_children():
		if child != cost_and_type_button:
			child.queue_free()
