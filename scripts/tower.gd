extends Node2D

const TOWERS: Dictionary[String, TowerData] = {
	"archer": preload("res://data/archer/archer.tres"),
	"barrack": preload("res://data/barrack/barrack.tres"),
	"magic": preload("res://data/magic/magic.tres"),
	"bomb": preload("res://data/bomb/bomb.tres")
}
@onready var tower_collision: CollisionShape2D = $TowerImage/towerArea/towerCollision
@onready var tower_area: Area2D = $TowerImage/towerArea
@onready var range_circle: Node2D = $"TowerImage/towerArea/Range circle"
@onready var tower_top: Sprite2D = $TowerTop
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

var target = null
var fire_rate = 1.0
var fire_timer = 0.0
var enemies_in_range: Array = []
func _ready() -> void:
	pass

func _process(delta: float) -> void:
	if target and not is_instance_valid(target):
		enemies_in_range.erase(target)
		target = get_closest_enemy()
		if target == null:
			animated_sprite_2d.stop()



func purchaseTower(towerType: String) -> bool:
	if TOWERS.has(towerType):
		var getTower = TOWERS[towerType].upgrades[0]
		changeTower(getTower.towerImage)
		if getTower.isTowerTop:
			changeTop(getTower.towerTop)
		_play_place_animation()
		return true
	return false

func changeTower(towerimgs: Texture2D) -> void:
	var tower_image: Sprite2D = $TowerImage
	tower_image.texture = towerimgs

func changeTop(towerTop: Texture2D) -> void:
	var tower_top: Sprite2D = $TowerTop
	var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
	animated_sprite_2d.visible = true
	tower_top.visible = true
	tower_top.texture = towerTop

func _on_tower_area_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	if range_circle.visible:
		hide_range()
	else:
		show_range()

func show_range() -> void:
	range_circle.scale = Vector2(0, 0)
	range_circle.visible = true
	create_tween().tween_property(range_circle, "scale", Vector2(1, 1), 0.3) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_BACK)

func hide_range() -> void:
	var tween = create_tween()
	tween.tween_property(range_circle, "scale", Vector2(0, 0), 0.2) \
		.set_ease(Tween.EASE_IN) \
		.set_trans(Tween.TRANS_BACK)
	tween.tween_callback(func(): range_circle.visible = false)

func _play_place_animation() -> void:
	scale = Vector2(0, 0)
	modulate.a = 0.0
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1, 1), 0.4) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "modulate:a", 1.0, 0.3) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_QUAD)

func _on_tower_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		enemies_in_range.append(body)
		target = get_closest_enemy()
		animated_sprite_2d.play("attack")

func _on_tower_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		enemies_in_range.erase(body)
		target = get_closest_enemy()
		if target == null:
			animated_sprite_2d.stop()
		
func get_closest_enemy() -> Node2D:
	enemies_in_range = enemies_in_range.filter(func(e): return is_instance_valid(e))
	if enemies_in_range.is_empty():
		return null
	var closest = enemies_in_range[0]
	for e in enemies_in_range:
		if global_position.distance_to(e.global_position) < global_position.distance_to(closest.global_position):
			closest = e
	print("[Tower] Closest enemy: ", closest.name, " at ", closest.global_position)
	return closest
