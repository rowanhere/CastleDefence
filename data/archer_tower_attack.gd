extends Node2D

@onready var tower_area: Area2D = $TowerImage/towerArea
@onready var tower_collision: CollisionShape2D = $TowerImage/towerArea/towerCollision
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

var arrow_scene = preload("res://scenes/arrow.tscn")

var enemies_in_range: Array = []
var attack_speed: float = 1.0
var attack_timer: float = 0.0

func _ready() -> void:
	tower_area.body_entered.connect(_on_body_entered)
	tower_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		enemies_in_range.append(body)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		enemies_in_range.erase(body)

func _process(delta: float) -> void:
	enemies_in_range = enemies_in_range.filter(func(e): return is_instance_valid(e) and not e.is_dead)
	if enemies_in_range.size() > 0:
		animated_sprite_2d.play("attack")
		attack_timer -= delta
		if attack_timer <= 0.0:
			attack_timer = attack_speed
			_attack_enemy(enemies_in_range[0])
	else:
		animated_sprite_2d.stop()

func _attack_enemy(enemy: Node2D) -> void:
	if is_instance_valid(enemy):
		var spawned_arrow = arrow_scene.instantiate()
		get_tree().current_scene.add_child(spawned_arrow)
		spawned_arrow.global_position = animated_sprite_2d.global_position 
		spawned_arrow.target = enemy
