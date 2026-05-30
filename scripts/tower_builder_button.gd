extends Control

@onready var tower_btn_ring: TextureRect = $TowerBtnRing
@onready var cost_and_type_button: TextureButton = $TowerBtnRing/CostAndTypeButton
@onready var coin: Label = $TowerBtnRing/CostAndTypeButton/coin

@export var coinAmt: int = 100
@export var towerBuilderPosition: Vector2

signal purchased


var insertTower = {
	"archer": preload("res://data/archer/archerTower.tscn"),
	"barrack": preload("res://data/barrack/barrackTower.tscn"),
	#"magic": preload("res://data/magic/magicTower.tscn"),
	#"bomb": preload("res://data/bomb/bombTower.tscn")
}


const towerBtnsImages = {
	"archer": preload("res://assets/images/levelImages/towerBtnArrow.png"),
	"barrack": preload("res://assets/images/levelImages/towerBtnBarrack.png"),
	"magic": preload("res://assets/images/levelImages/towerBtnMagic.png"),
	"bomb": preload("res://assets/images/levelImages/towerBtnBomb.png")
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

	new_btn.get_node("purchaseTypeImg").texture = towerBtnsImages[tower_type]

	new_btn.pressed.connect(
		func():
			_purchase_tower(tower_type)
	)


func _purchase_tower(tower_type: String) -> void:
	if !insertTower.has(tower_type):
		print("Tower not found: ", tower_type)
		return

	var tower_scene: PackedScene = insertTower[tower_type]
	var tower_instance = tower_scene.instantiate()

	get_parent().get_parent().add_child(tower_instance)

	tower_instance.global_position = towerBuilderPosition
	tower_instance.z_index = 100

	play_place_animation(tower_instance)

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
