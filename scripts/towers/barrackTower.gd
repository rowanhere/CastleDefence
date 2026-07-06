extends Node2D

var getSoldier = preload("res://scenes/towers/barrack/BarrackSoldier.tscn")
var barrack_tower_data: TowerData = preload("res://resources/towers/barrack/barrack.tres")
var active_upgrade: UpgradeData = null

@onready var door_mark: Marker2D = $DoorMark
@onready var tower_area: Area2D = $TowerImage/towerArea
@onready var timer: Timer = $Timer
@onready var respawn_progress: TextureProgressBar = $RespawnProgress

const MAX_SOLDIERS := 3
const RESPAWN_TIME := 10.0
const INITIAL_SPAWN_DELAY := 3.0
const CLONE_START_INDEX := 1
const MIN_COMBAT_PROGRESS_FROM_SPAWN := 160.0
const COMBAT_PROGRESS_BEHIND := 0.0
const COMBAT_PROGRESS_AHEAD := 96.0
const COMBAT_LINE_OFFSET := 42.0
const COMBAT_LINE_TOLERANCE := 54.0
const SOLDIER_HOLD_SPACING := 34.0

var soldiers: Array = []
var enemies_in_range: Array[Node2D] = []
var respawning := false
var current_wait_time := INITIAL_SPAWN_DELAY

var spawn_sound: AudioStream = preload("res://assets/audio/sfx/soldierSpawn.mp3")
var clone_sound: AudioStream = preload("res://assets/audio/sfx/clone.mp3")
var smoke_scene: PackedScene = preload("res://scenes/towers/barrack/SoldierSmoke.tscn")


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


func _spawn_all_soldiers() -> void:
	var soldier_count: int = _get_active_soldier_count()
	var real_soldier = _create_soldier(0, door_mark.global_position)
	soldiers.append(real_soldier)
	GameSound.play(spawn_sound, -40.0)

	var clone_spawn_delay: float = 0.6
	for i in range(CLONE_START_INDEX, soldier_count):
		var clone_index: int = i
		var clone_wait_pos: Vector2 = _get_wait_position(clone_index)
		get_tree().create_timer(clone_spawn_delay).timeout.connect(
			func():
				var smoke = smoke_scene.instantiate()
				get_tree().current_scene.add_child(smoke)
				smoke.global_position = clone_wait_pos
				smoke.modulate = Color.WHITE
				var anim: AnimatedSprite2D = smoke.get_node("AnimatedSprite2D")
				anim.play("default")

				var clone = _create_soldier(clone_index, clone_wait_pos)
				soldiers.append(clone)
				clone.modulate.a = 0.0

				get_tree().create_timer(0.2).timeout.connect(
					func():
						if is_instance_valid(smoke):
							var smoke_tween: Tween = get_tree().create_tween()
							smoke_tween.tween_property(smoke, "modulate:a", 0.0, 0.2)
							smoke_tween.tween_callback(smoke.queue_free)
						if is_instance_valid(clone):
							var clone_tween: Tween = get_tree().create_tween()
							clone_tween.tween_property(clone, "modulate:a", 0.85, 0.15)
				)

				GameSound.play(clone_sound, -40.0)
		)
		clone_spawn_delay += 0.6

	respawning = false
	respawn_progress.hide()


func _get_wait_position(index: int) -> Vector2:
	var path2d: Path2D = get_tree().get_first_node_in_group("level_path") as Path2D
	var offsets := [Vector2(-50, 20), Vector2(0, 40), Vector2(50, 20)]
	if path2d != null:
		var local_pos: Vector2 = path2d.to_local(global_position)
		var closest_offset: float = path2d.curve.get_closest_offset(local_pos)
		var base_pos: Vector2 = path2d.to_global(path2d.curve.sample_baked(closest_offset))
		var wait_off: Vector2 = offsets[index] if index < offsets.size() else Vector2(index * 50, 20)
		return base_pos + wait_off
	var spawn_offset: Vector2 = offsets[index] if index < offsets.size() else Vector2(index * 50, 20)
	return global_position + spawn_offset


func _create_soldier(index: int, spawn_from: Vector2) -> Node2D:
	var path2d: Path2D = get_tree().get_first_node_in_group("level_path") as Path2D
	var soldier = getSoldier.instantiate()
	get_tree().current_scene.add_child(soldier)

	var offsets := [Vector2(-50, 20), Vector2(0, 40), Vector2(50, 20)]
	var spawn_offset: Vector2 = offsets[index] if index < offsets.size() else Vector2(index * 50, 20)
	var final_pos: Vector2

	if path2d != null:
		var local_pos: Vector2 = path2d.to_local(global_position)
		var closest_offset: float = path2d.curve.get_closest_offset(local_pos)
		var base_pos: Vector2 = path2d.to_global(path2d.curve.sample_baked(closest_offset))
		var wait_offsets := [Vector2(-50, 20), Vector2(0, 40), Vector2(50, 20)]
		var wait_off: Vector2 = wait_offsets[index] if index < wait_offsets.size() else Vector2(index * 50, 20)
		final_pos = base_pos + wait_off
	else:
		final_pos = global_position + spawn_offset

	soldier.home = global_position
	soldier.soldier_index = index
	soldier.scale = Vector2(2.5, 2.5)
	soldier.last_direction = Vector2.RIGHT
	soldier.wait_position = final_pos
	if active_upgrade != null:
		soldier.attack_damage = active_upgrade.damage
		soldier.attack_speed = 1.0 / max(active_upgrade.attackSpeed, 0.01)

	if index >= CLONE_START_INDEX:
		soldier.modulate = Color(0.45, 0.75, 1.0, 0.0)
		soldier.scale = Vector2(1.5, 1.5)
	else:
		soldier.modulate = Color(1.0, 1.0, 1.0, 0.0)

	soldier.global_position = spawn_from

	var tween: Tween = get_tree().create_tween()
	if index >= CLONE_START_INDEX:
		tween.tween_property(soldier, "scale", Vector2(2.5, 2.5), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tween.tween_property(soldier, "global_position", final_pos, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(soldier, "modulate:a", 1.0, 0.3)

	return soldier


func handle_upgrade_applied() -> void:
	soldiers = soldiers.filter(func(s): return is_instance_valid(s))
	_refresh_soldier_stats()
	if respawning or soldiers.is_empty():
		return

	var desired_count: int = _get_active_soldier_count()
	for i in range(soldiers.size(), desired_count):
		_spawn_upgrade_soldier(i)


func _refresh_soldier_stats() -> void:
	if active_upgrade == null:
		return
	for soldier in soldiers:
		if soldier == null or not is_instance_valid(soldier):
			continue
		soldier.attack_damage = active_upgrade.damage
		soldier.attack_speed = 1.0 / max(active_upgrade.attackSpeed, 0.01)


func _spawn_upgrade_soldier(index: int) -> void:
	var clone_wait_pos: Vector2 = _get_wait_position(index)
	var smoke = smoke_scene.instantiate()
	get_tree().current_scene.add_child(smoke)
	smoke.global_position = clone_wait_pos
	smoke.modulate = Color.WHITE
	var smoke_anim: AnimatedSprite2D = smoke.get_node("AnimatedSprite2D")
	smoke_anim.play("default")

	var soldier = _create_soldier(index, clone_wait_pos)
	soldiers.append(soldier)
	soldier.modulate.a = 0.0

	get_tree().create_timer(0.2).timeout.connect(
		func():
			if is_instance_valid(smoke):
				var smoke_tween: Tween = get_tree().create_tween()
				smoke_tween.tween_property(smoke, "modulate:a", 0.0, 0.2)
				smoke_tween.tween_callback(smoke.queue_free)
			if is_instance_valid(soldier):
				var clone_tween: Tween = get_tree().create_tween()
				clone_tween.tween_property(soldier, "modulate:a", 0.85, 0.15)
	)

	GameSound.play(clone_sound, -40.0)


func _exit_tree() -> void:
	for soldier in soldiers:
		if soldier != null and is_instance_valid(soldier):
			soldier.queue_free()
	soldiers.clear()


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
	return enemy_progress >= tower_progress - COMBAT_PROGRESS_BEHIND \
		and enemy_progress <= tower_progress + COMBAT_PROGRESS_AHEAD


func _enemy_battle_line_distance(enemy: Node2D, tower_progress: float) -> float:
	var combat_line: float = tower_progress + COMBAT_LINE_OFFSET
	return abs(_enemy_progress(enemy) - combat_line)


func _combat_line_progress(tower_progress: float) -> float:
	return tower_progress + COMBAT_LINE_OFFSET


func _assign_targets() -> void:
	_prune_enemies_in_range()
	var live_soldiers: Array = soldiers.filter(func(s): return is_instance_valid(s))
	var primary_soldier: Node2D = live_soldiers[0] if not live_soldiers.is_empty() else null
	var existing_primary_enemy: Node2D = null

	for soldier in live_soldiers:
		if is_instance_valid(soldier) and _is_valid_enemy(soldier.locked_enemy):
			existing_primary_enemy = soldier.locked_enemy
			break

	if enemies_in_range.is_empty():
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(enemy) and enemy.has_method("clear_barrack_hold"):
				enemy.clear_barrack_hold()
		for soldier in live_soldiers:
			if is_instance_valid(soldier) and not soldier.is_fighting():
				soldier.target = null
		return

	var tower_progress: float = _tower_path_progress()
	var combat_candidates: Array = []
	for enemy in enemies_in_range:
		if _enemy_is_in_combat_window(enemy, tower_progress):
			combat_candidates.append(enemy)

	if combat_candidates.is_empty() and existing_primary_enemy == null:
		for enemy in enemies_in_range:
			if is_instance_valid(enemy) and enemy.has_method("clear_barrack_hold"):
				enemy.clear_barrack_hold()
		for soldier in live_soldiers:
			if is_instance_valid(soldier) and not soldier.is_fighting():
				soldier.target = null
		return

	if live_soldiers.is_empty():
		return

	var sorted_enemies: Array = combat_candidates.duplicate()
	sorted_enemies.sort_custom(func(a: Node2D, b: Node2D): return _enemy_progress(a) > _enemy_progress(b))
	var held_enemies: Dictionary = {}
	var base_hold_progress: float = _combat_line_progress(tower_progress)

	var primary_enemy: Node2D = existing_primary_enemy

	if is_instance_valid(primary_soldier):
		var hold_progress: float = base_hold_progress
		if primary_enemy != null:
			primary_soldier.target = primary_enemy
		elif _is_valid_enemy(primary_soldier.locked_enemy):
			primary_enemy = primary_soldier.locked_enemy
			primary_soldier.target = primary_enemy
		elif _is_valid_enemy(primary_soldier.target):
			primary_enemy = primary_soldier.target
		else:
			primary_soldier.target = null

		if primary_enemy == null:
			var best_enemy: Node2D = null
			var best_line_distance: float = INF
			var best_progress: float = -INF
			var best_dist: float = INF

			for enemy in sorted_enemies:
				var progress: float = _enemy_progress(enemy)
				var line_distance: float = abs(progress - base_hold_progress)
				if line_distance > COMBAT_LINE_TOLERANCE:
					continue
				var distance_score: float = primary_soldier.global_position.distance_squared_to(enemy.global_position)
				if line_distance < best_line_distance \
					or (is_equal_approx(line_distance, best_line_distance) and progress > best_progress) \
					or (is_equal_approx(line_distance, best_line_distance) and is_equal_approx(progress, best_progress) and distance_score < best_dist):
					best_line_distance = line_distance
					best_progress = progress
					best_dist = distance_score
					best_enemy = enemy

			primary_enemy = best_enemy
			primary_soldier.target = best_enemy

		if primary_enemy != null:
			held_enemies[primary_enemy] = true
			if primary_enemy.has_method("set_barrack_hold"):
				primary_enemy.set_barrack_hold(hold_progress, primary_soldier)
			if primary_soldier.has_method("force_target_enemy"):
				primary_soldier.force_target_enemy(primary_enemy)

	for i in range(1, live_soldiers.size()):
		var support_soldier: Node2D = live_soldiers[i]
		if _is_valid_enemy(primary_enemy):
			if support_soldier.has_method("force_target_enemy"):
				support_soldier.force_target_enemy(primary_enemy)
			else:
				support_soldier.target = primary_enemy
				support_soldier.locked_enemy = primary_enemy
		else:
			if support_soldier.locked_enemy != null and is_instance_valid(support_soldier.locked_enemy) and support_soldier.locked_enemy.has_method("release_soldier"):
				support_soldier.locked_enemy.release_soldier(support_soldier)
			if support_soldier.has_method("release_enemy"):
				support_soldier.release_enemy()
			if support_soldier.has_method("clear_forced_enemy"):
				support_soldier.clear_forced_enemy()
			support_soldier.target = null

	for enemy in enemies_in_range:
		if not _is_valid_enemy(enemy):
			continue
		if held_enemies.has(enemy):
			continue
		if enemy.has_method("clear_barrack_hold"):
			enemy.clear_barrack_hold()


func _on_body_entered(body: Node2D) -> void:
	if _is_valid_enemy(body) and body not in enemies_in_range:
		enemies_in_range.append(body)
		_assign_targets()


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("enemies"):
		return
	enemies_in_range.erase(body)
	for soldier in soldiers:
		if is_instance_valid(soldier) and soldier.target == body:
			soldier.target = null
	_assign_targets()


func _process(_delta: float) -> void:
	soldiers = soldiers.filter(func(s): return is_instance_valid(s))
	_prune_enemies_in_range()
	_assign_targets()

	if soldiers.is_empty() and not respawning:
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
	_spawn_all_soldiers()
	_assign_targets()


func _get_active_soldier_count() -> int:
	if active_upgrade == null:
		return 1
	return clampi(active_upgrade.level, 1, MAX_SOLDIERS)
