extends Node2D

var getSoldier = preload("res://data/barrack/BarrackSoldier.tscn")
@onready var tower_image: Sprite2D = $TowerImage
@onready var tower_area: Area2D = $TowerImage/towerArea
@onready var timer: Timer = $Timer

var soldiers = []
var max_soldiers = 3
var respawn_time = 10.0

func _ready() -> void:
	tower_area.body_entered.connect(_on_body_entered)
	tower_area.body_exited.connect(_on_body_exited)
	timer.wait_time = respawn_time
	timer.timeout.connect(_on_timer_timeout)
	timer.start()
	await get_tree().create_timer(4.0).timeout
	call_deferred("spawn_soldiers")

func create_soldier(index: int) -> void:
	var path2d = get_tree().get_first_node_in_group("level_path")
	var soldier = getSoldier.instantiate()
	get_tree().current_scene.add_child(soldier)
	soldier.global_position = global_position + Vector2(index * 20, 0)
	soldier.home = global_position
	soldier.soldier_index = index
	soldier.scale = Vector2(2.5, 2.5)
	soldier.last_direction = Vector2.RIGHT
	if path2d:
		var local_pos = path2d.to_local(global_position)
		var closest_offset = path2d.curve.get_closest_offset(local_pos)
		var base_pos = path2d.to_global(path2d.curve.sample_baked(closest_offset))
		soldier.wait_position = base_pos + Vector2(index * 25, 0)
	else:
		soldier.wait_position = global_position + Vector2(index * 25, 0)
	soldiers.append(soldier)

func spawn_soldiers() -> void:
	for i in max_soldiers:
		create_soldier(i)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		for soldier in soldiers:
			if is_instance_valid(soldier) and soldier.target == null:
				soldier.target = body

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		for soldier in soldiers:
			if is_instance_valid(soldier) and soldier.target == body:
				soldier.target = null

func _on_timer_timeout() -> void:
	soldiers = soldiers.filter(func(s): return is_instance_valid(s))
	if soldiers.size() < max_soldiers:
		var missing = max_soldiers - soldiers.size()
		for i in missing:
			create_soldier(soldiers.size())
