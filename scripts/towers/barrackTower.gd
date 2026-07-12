extends Node2D

var getSoldier = preload("res://scenes/towers/barrack/BarrackSoldier.tscn")
var barrack_tower_data: TowerData = preload("res://resources/towers/barrack/barrack.tres")
var active_upgrade: UpgradeData = null

@onready var door_mark: Marker2D = $DoorMark
@onready var tower_area: Area2D = $TowerImage/towerArea
@onready var timer: Timer = $Timer
@onready var respawn_progress: TextureProgressBar = $RespawnProgress

const RESPAWN_TIME := 10.0
const INITIAL_SPAWN_DELAY := 3.0
const BASE_SOLDIER_SCALE := 2.5
const SCALE_PER_LEVEL := 0.5
const BASE_SOLDIER_HP := 200.0
const HP_PER_UPGRADE_LEVEL := 250.0
const MIN_COMBAT_PROGRESS_FROM_SPAWN := 160.0
const COMBAT_PROGRESS_BEHIND := 0.0
const COMBAT_PROGRESS_AHEAD := 96.0
const COMBAT_LINE_OFFSET := 42.0
const COMBAT_LINE_TOLERANCE := 54.0

var soldier: Node2D = null
var enemies_in_range: Array[Node2D] = []
var respawning := false
var current_wait_time := INITIAL_SPAWN_DELAY

var spawn_sound: AudioStream = preload("res://assets/audio/sfx/soldierSpawn.mp3")


func _ready() -> void:
	if barrack_tower_data != null:
		active_upgrade = barrack_tower_data.get_base_upgrade()
	tower_area.body_entered.connect(_on_body_entered)
	tower_area.body_exited.connect(_on_body_exited)
	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout)
	respawn_progress.value = 0.0
	respawn_progress.show()
	respawning = true
	current_wait_time = INITIAL_SPAWN_DELAY
	respawn_progress.max_value = INITIAL_SPAWN_DELAY
	timer.wait_time = INITIAL_SPAWN_DELAY
	timer.start()


func _spawn_soldier() -> void:
	if is_instance_valid(soldier):
		return
	soldier = _create_soldier(door_mark.global_position)
	GameSound.play(spawn_sound, -40.0)
	respawning = false
	respawn_progress.hide()


func _get_wait_position() -> Vector2:
	var path2d: Path2D = get_tree().get_first_node_in_group("level_path") as Path2D
	var wait_offset := Vector2(0, 34)
	if path2d != null:
		var local_pos: Vector2 = path2d.to_local(global_position)
		var closest_offset: float = path2d.curve.get_closest_offset(local_pos)
		var base_pos: Vector2 = path2d.to_global(path2d.curve.sample_baked(closest_offset))
		return base_pos + wait_offset
	return global_position + wait_offset


func _get_soldier_scale() -> Vector2:
	var level: int = 1
	if active_upgrade != null:
		level = max(active_upgrade.level, 1)
	var scale_value: float = BASE_SOLDIER_SCALE + float(level - 1) * SCALE_PER_LEVEL
	return Vector2.ONE * scale_value


func _get_soldier_hp() -> float:
	var level: int = 1
	if active_upgrade != null:
		level = max(active_upgrade.level, 1)
	return BASE_SOLDIER_HP + float(level - 1) * HP_PER_UPGRADE_LEVEL


func _create_soldier(spawn_from: Vector2) -> Node2D:
	var soldier_instance = getSoldier.instantiate()
	get_tree().current_scene.add_child(soldier_instance)
	var final_pos: Vector2 = _get_wait_position()
	soldier_instance.home = global_position
	soldier_instance.soldier_index = 0
	soldier_instance.scale = _get_soldier_scale()
	soldier_instance.last_direction = Vector2.RIGHT
	soldier_instance.wait_position = final_pos
	soldier_instance.hp = _get_soldier_hp()
	if soldier_instance.health_bar != null:
		soldier_instance.health_bar.max_value = soldier_instance.hp
		soldier_instance.health_bar.value = soldier_instance.hp
	if active_upgrade != null:
		soldier_instance.attack_damage = active_upgrade.damage
		soldier_instance.attack_speed = 1.0 / max(active_upgrade.attackSpeed, 0.01)
	soldier_instance.modulate = Color(1.0, 1.0, 1.0, 0.0)
	soldier_instance.global_position = spawn_from

	var tween: Tween = get_tree().create_tween()
	tween.tween_property(soldier_instance, "global_position", final_pos, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(soldier_instance, "modulate:a", 1.0, 0.3)
	return soldier_instance


func handle_upgrade_applied() -> void:
	if not is_instance_valid(soldier) or active_upgrade == null:
		return
	soldier.attack_damage = active_upgrade.damage
	soldier.attack_speed = 1.0 / max(active_upgrade.attackSpeed, 0.01)
	soldier.hp = _get_soldier_hp()
	if soldier.health_bar != null:
		soldier.health_bar.max_value = soldier.hp
		soldier.health_bar.value = soldier.hp
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(soldier, "scale", _get_soldier_scale(), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _exit_tree() -> void:
	if soldier != null and is_instance_valid(soldier):
		soldier.queue_free()
	soldier = null


func _is_valid_enemy(enemy) -> bool:
	return enemy != null and is_instance_valid(enemy) and enemy.is_in_group("enemies") and not enemy.is_dead


func _prune_enemies_in_range() -> void:
	enemies_in_range = enemies_in_range.filter(func(e): return _is_valid_enemy(e))


func _enemy_progress(enemy: Node2D) -> float:
	if enemy != null and is_instance_valid(enemy) and enemy.has_method("get_path_progress"):
		return enemy.get_path_progress()
	return 0.0


func _tower_path_progress() -> float:
	var path2d: Path2D = get_tree().get_first_node_in_group("level_path") as Path2D
	if path2d == null or path2d.curve == null:
		return 0.0
	var local_pos: Vector2 = path2d.to_local(global_position)
	return path2d.curve.get_closest_offset(local_pos)


func _enemy_is_in_combat_window(enemy: Node2D, tower_progress: float) -> bool:
	if not _is_valid_enemy(enemy):
		return false
	var enemy_progress: float = _enemy_progress(enemy)
	if enemy_progress < MIN_COMBAT_PROGRESS_FROM_SPAWN:
		return false
	return enemy_progress >= tower_progress - COMBAT_PROGRESS_BEHIND and enemy_progress <= tower_progress + COMBAT_PROGRESS_AHEAD


func _assign_target() -> void:
	_prune_enemies_in_range()
	if not is_instance_valid(soldier):
		return

	if enemies_in_range.is_empty():
		if soldier.has_method("release_enemy"):
			soldier.release_enemy()
		soldier.target = null
		return

	var tower_progress: float = _tower_path_progress()
	var best_enemy: Node2D = null
	var best_line_distance: float = INF
	var best_progress: float = -INF
	var best_dist: float = INF
	var hold_progress: float = tower_progress + COMBAT_LINE_OFFSET

	for enemy in enemies_in_range:
		if not _enemy_is_in_combat_window(enemy, tower_progress):
			continue
		var progress: float = _enemy_progress(enemy)
		var line_distance: float = abs(progress - hold_progress)
		if line_distance > COMBAT_LINE_TOLERANCE:
			continue
		var distance_score: float = soldier.global_position.distance_squared_to(enemy.global_position)
		if line_distance < best_line_distance \
			or (is_equal_approx(line_distance, best_line_distance) and progress > best_progress) \
			or (is_equal_approx(line_distance, best_line_distance) and is_equal_approx(progress, best_progress) and distance_score < best_dist):
			best_line_distance = line_distance
			best_progress = progress
			best_dist = distance_score
			best_enemy = enemy

	soldier.target = best_enemy

	for enemy in enemies_in_range:
		if not _is_valid_enemy(enemy):
			continue
		if enemy.has_method("clear_barrack_hold"):
			enemy.clear_barrack_hold()


func _on_body_entered(body: Node2D) -> void:
	if _is_valid_enemy(body) and body not in enemies_in_range:
		enemies_in_range.append(body)
		_assign_target()


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("enemies"):
		return
	enemies_in_range.erase(body)
	if is_instance_valid(soldier) and soldier.target == body:
		soldier.target = null
	_assign_target()


func _process(_delta: float) -> void:
	if soldier != null and not is_instance_valid(soldier):
		soldier = null
	_prune_enemies_in_range()
	_assign_target()

	if soldier == null and not respawning:
		respawning = true
		current_wait_time = RESPAWN_TIME
		respawn_progress.max_value = RESPAWN_TIME
		timer.wait_time = RESPAWN_TIME
		timer.start()
		respawn_progress.value = 0.0
		respawn_progress.show()

	if respawning:
		respawn_progress.value = current_wait_time - timer.time_left


func _on_timer_timeout() -> void:
	_spawn_soldier()
	_assign_target()
