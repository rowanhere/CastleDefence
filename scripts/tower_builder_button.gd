extends Control

@onready var tower_btn_ring: TextureRect = $TowerBtnRing
@onready var cost_and_type_button: TextureButton = $TowerBtnRing/CostAndTypeButton
@onready var coin: Label = $TowerBtnRing/CostAndTypeButton/coin
@export var coinAmt = 100
@export var towerBuilderPosition: Vector2
var insertTower = preload("res://scenes/helpers/tower.tscn")
const towerBtnsImages = {
	"archer": preload("res://assets/images/levelImages/towerBtnArrow.png"),
	"barrack": preload("res://assets/images/levelImages/towerBtnBarrack.png"),
	"magic": preload("res://assets/images/levelImages/towerBtnMagic.png"),
	"bomb": preload("res://assets/images/levelImages/towerBtnBomb.png")
}
signal purchased


func _ready() -> void:
	coin.text = str(coinAmt)
	cost_and_type_button.visible = false


func _process(delta: float) -> void:
	pass


func insertFour() -> void:
	var positions = [
		{ "name": "archer", "pos": Vector2.ZERO },
		{ "name": "barrack", "pos": Vector2(tower_btn_ring.size.x - cost_and_type_button.size.x, 0) },
		{ "name": "magic", "pos": Vector2(0, tower_btn_ring.size.y - cost_and_type_button.size.y) },
		{ "name": "bomb", "pos": tower_btn_ring.size - cost_and_type_button.size },
	]
	for i in positions:
		insertBtns(i.pos, i.name)


func insertTwo() -> void:
	var positions = [
		{ "name": "upgrade", "pos": Vector2((tower_btn_ring.size.x - cost_and_type_button.size.x) / 2, 0) },
		{ "name": "sell",    "pos": Vector2((tower_btn_ring.size.x - cost_and_type_button.size.x) / 2, tower_btn_ring.size.y - cost_and_type_button.size.y) },
	]
	for i in positions:
		insertBtns(i.pos, i.name)


func insertBtns(pos: Vector2, type: String) -> void:
	var new_btn = cost_and_type_button.duplicate()
	tower_btn_ring.add_child(new_btn)
	new_btn.pressed.connect(_purchase_tower.bind(type))
	await get_tree().process_frame
	new_btn.position = pos
	new_btn.get_node("purchaseTypeImg").texture = towerBtnsImages[type]
	new_btn.visible = true


func _purchase_tower(type: String) -> void:
	#print("trying to purchase: ", type)
	#print("position: ", towerBuilderPosition)
	var addTowerOnMap = insertTower.instantiate()
	var towerInserted = addTowerOnMap.purchaseTower(type) #check if tower exists 
	if towerInserted:
		get_parent().get_parent().add_child(addTowerOnMap)
		addTowerOnMap.z_index = 100
		addTowerOnMap.global_position = Vector2(towerBuilderPosition.x + 10, towerBuilderPosition.y-40)
		purchased.emit()
