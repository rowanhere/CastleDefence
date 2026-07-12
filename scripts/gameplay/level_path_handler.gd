extends Path2D

const ENEMY_SCENE = preload("res://scenes/enemies/enemy.tscn")
const DEFAULT_SPAWN_INTERVAL := 0.3
const MIN_SPAWN_INTERVAL := 0.18
const SPAWN_RETRY_INTERVAL := 0.08
const SPAWN_GROUP_SIZE := 2
const WAVE_POINTER_LEAD_TIME := 5.0

var spawn_schedule: Resource

@onready var timer: Timer = $Timer
var spawn_queue: Array[Dictionary] = []
var elapsed_time: float = 0.0
var next_entry_index: int = 0
var active_pointer_wave_index: int = -1
var level_complete_checked: bool = false


func _ready() -> void:
	add_to_group("level_path")
	spawn_schedule = load(GameHandler.get_level_spawn_schedule_path(GameHandler.queued_level))
	if spawn_schedule == null:
		push_error("Failed to load spawn schedule for level %d" % GameHandler.queued_level)
		return
	timer.one_shot = true
	timer.wait_time = DEFAULT_SPAWN_INTERVAL
	timer.timeout.connect(_on_timer_timeout)
	_update_wave_status_ui()


func _process(delta: float) -> void:
	if spawn_schedule == null:
		return

	elapsed_time += delta
	_update_wave_status_ui()

	while next_entry_index < spawn_schedule.waves.size():
		var wave: Resource = spawn_schedule.waves[next_entry_index]
		if elapsed_time < wave.start_time:
			break
		_enqueue_entry(next_entry_index)
		next_entry_index += 1

	_ensure_spawn_timer()
	_check_level_complete()


func _on_timer_timeout() -> void:
	if spawn_queue.is_empty():
		if spawn_schedule != null and next_entry_index >= spawn_schedule.waves.size():
			timer.stop()
		return

	var first_spawn_data: Dictionary = spawn_queue[0]
	var first_base_data: EnemyData = first_spawn_data["enemy_data"]
	var first_is_boss_wave: bool = first_spawn_data.get("is_boss_wave", false)
	var first_wave_number: int = first_spawn_data.get("wave_number", 1)
	var first_scaled_data: EnemyData = GameHandler.get_scaled_enemy_data(first_base_data, GameHandler.queued_level, first_wave_number, first_is_boss_wave)
	if not _can_spawn_enemy_now(first_scaled_data):
		timer.start(SPAWN_RETRY_INTERVAL)
		return

	var spawned_enemies: Array[Node] = []
	var group_size: int = 1 if first_is_boss_wave else SPAWN_GROUP_SIZE
	for i in range(group_size):
		if spawn_queue.is_empty():
			break
		var spawn_data: Dictionary = spawn_queue[0]
		var is_boss_wave: bool = spawn_data.get("is_boss_wave", false)
		if i > 0 and is_boss_wave:
			break
		spawn_queue.pop_front()
		var base_data: EnemyData = spawn_data["enemy_data"]
		var wave_number: int = spawn_data.get("wave_number", 1)
		var scaled_data: EnemyData = GameHandler.get_scaled_enemy_data(base_data, GameHandler.queued_level, wave_number, is_boss_wave)
		spawned_enemies.append(_spawn_enemy(scaled_data, is_boss_wave, _get_spawn_lane_index(i, group_size)))

	for enemy_instance in spawned_enemies:
		if enemy_instance != null and is_instance_valid(enemy_instance) and enemy_instance.has_method("refresh_path_crowd_offset"):
			enemy_instance.refresh_path_crowd_offset()

	timer.wait_time = _get_spawn_interval(first_scaled_data) * float(max(spawned_enemies.size(), 1))
	if not spawn_queue.is_empty():
		timer.start(timer.wait_time)


func _get_spawn_lane_index(index: int, group_size: int) -> int:
	if group_size <= 1:
		return 0
	var lanes: Array[int] = [-1, 1, 0, -2, 2]
	return lanes[index % lanes.size()]


func _spawn_enemy(scaled_data: EnemyData, is_boss_wave: bool, spawn_lane_index: int = 0) -> Node:
	var follow = PathFollow2D.new()
	follow.rotates = false
	follow.loop = false
	add_child(follow)
	var enemy_instance = ENEMY_SCENE.instantiate()
	follow.add_child(enemy_instance)     # _ready() runs here first
	if is_boss_wave:
		scaled_data.coin_drop = 0
	enemy_instance.is_boss_enemy = is_boss_wave
	enemy_instance.data = scaled_data  # set AFTER so _ready+@onready vars are ready
	_apply_spawn_facing(enemy_instance)
	if enemy_instance.has_method("set_spawn_lane_index"):
		enemy_instance.set_spawn_lane_index(spawn_lane_index)
	return enemy_instance


func _get_spawn_interval(enemy_data: EnemyData) -> float:
	if enemy_data == null:
		return DEFAULT_SPAWN_INTERVAL
	var spacing: float = max(enemy_data.path_spacing, 1.0)
	var enemy_speed: float = max(enemy_data.speed, 1.0)
	return maxf(spacing / enemy_speed, MIN_SPAWN_INTERVAL)


func _can_spawn_enemy_now(enemy_data: EnemyData) -> bool:
	if enemy_data == null:
		return true
	var required_spacing: float = max(enemy_data.path_spacing, 1.0)
	for child in get_children():
		var follow := child as PathFollow2D
		if follow == null:
			continue
		if not _path_follow_has_live_enemy(follow):
			continue
		if follow.progress < required_spacing:
			return false
	return true


func _path_follow_has_live_enemy(path_follow: PathFollow2D) -> bool:
	if path_follow == null:
		return false
	for child in path_follow.get_children():
		if child.is_in_group("enemies") and not child.is_dead:
			return true
	return false


func _has_live_enemies() -> bool:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy != null and is_instance_valid(enemy) and not enemy.is_dead:
			return true
	for child in get_children():
		var follow := child as PathFollow2D
		if follow != null and _path_follow_has_live_enemy(follow):
			return true
	return false


func _check_level_complete() -> void:
	if level_complete_checked or spawn_schedule == null:
		return
	if next_entry_index < spawn_schedule.waves.size():
		return
	if not spawn_queue.is_empty():
		return
	if timer != null and not timer.is_stopped():
		return
	if _has_live_enemies():
		return
	if GameHandler.castle_life <= 0:
		return
	level_complete_checked = true
	GameHandler.complete_level()


func _ensure_spawn_timer() -> void:
	if timer == null or not timer.is_stopped() or spawn_queue.is_empty():
		return
	var next_data: EnemyData = spawn_queue[0].get("enemy_data", null)
	var is_boss_wave: bool = spawn_queue[0].get("is_boss_wave", false)
	var wave_number: int = spawn_queue[0].get("wave_number", 1)
	var scaled_data: EnemyData = GameHandler.get_scaled_enemy_data(next_data, GameHandler.queued_level, wave_number, is_boss_wave)
	timer.start(_get_spawn_interval(scaled_data))


func _enqueue_entry(entry_index: int) -> void:
	if entry_index < 0 or entry_index >= spawn_schedule.waves.size():
		return
	var wave: Resource = spawn_schedule.waves[entry_index]
	var enemy_pool: Array[String] = wave.enemy_pool
	var total_multiplier: int = wave.total_multiplier
	var is_boss_wave: bool = wave.is_boss_wave
	if enemy_pool.is_empty() or total_multiplier <= 0:
		return

	for i in range(total_multiplier):
		var enemy_id: String = enemy_pool[i % enemy_pool.size()]
		var enemy_data: EnemyData = GameHandler.get_enemy_data_by_id(enemy_id)
		if enemy_data == null:
			push_warning("Unknown enemy id in spawn entry: %s" % enemy_id)
			continue
		spawn_queue.append({
			"enemy_data": enemy_data,
			"is_boss_wave": is_boss_wave,
			"wave_number": entry_index + 1
		})


func _update_wave_status_ui() -> void:
	if spawn_schedule == null:
		return
	var handler := get_tree().current_scene
	if handler == null or not handler.has_method("update_wave_status"):
		return

	var total_waves: int = spawn_schedule.waves.size()
	var started_waves: int = 0
	for wave in spawn_schedule.waves:
		if elapsed_time >= wave.start_time:
			started_waves += 1
		else:
			break

	var current_wave: int = clampi(started_waves, 1, max(total_waves, 1))
	var current_wave_index: int = clampi(started_waves - 1, 0, max(total_waves - 1, 0))
	var wave_start_time: float = 0.0
	var wave_end_time: float = 0.0

	if started_waves <= 0:
		current_wave = 1
		current_wave_index = 0
		wave_start_time = 0.0
		wave_end_time = spawn_schedule.waves[0].start_time
	elif current_wave_index >= total_waves - 1:
		if handler.has_method("clear_wave_alert"):
			handler.clear_wave_alert()
		if handler.has_method("update_wave_labels"):
			handler.update_wave_labels(total_waves, total_waves)
		return
	else:
		wave_start_time = spawn_schedule.waves[current_wave_index].start_time
		wave_end_time = spawn_schedule.waves[current_wave_index + 1].start_time

	var progress_ratio: float = 1.0
	var duration: float = wave_end_time - wave_start_time
	if duration > 0.0:
		progress_ratio = clampf((elapsed_time - wave_start_time) / duration, 0.0, 1.0)
	elif started_waves <= 0 and wave_end_time > 0.0:
		progress_ratio = clampf(elapsed_time / wave_end_time, 0.0, 1.0)

	handler.update_wave_status(current_wave, total_waves, progress_ratio)
	_update_wave_pointer(handler, started_waves, total_waves)


func _update_wave_pointer(handler: Node, started_waves: int, total_waves: int) -> void:
	if handler == null or not handler.has_method("show_wave_pointer"):
		return
	if started_waves >= total_waves:
		if handler.has_method("hide_wave_pointer"):
			handler.hide_wave_pointer()
		active_pointer_wave_index = -1
		return

	var next_wave_index: int = clampi(started_waves, 0, total_waves - 1)
	var next_wave: Resource = spawn_schedule.waves[next_wave_index]
	var time_until_wave: float = next_wave.start_time - elapsed_time
	if time_until_wave <= WAVE_POINTER_LEAD_TIME and time_until_wave > 0.0:
		if active_pointer_wave_index != next_wave_index:
			active_pointer_wave_index = next_wave_index
			handler.show_wave_pointer(_get_spawn_pointer_position(), _get_spawn_direction())
	elif active_pointer_wave_index != -1 and handler.has_method("hide_wave_pointer"):
		handler.hide_wave_pointer()
		active_pointer_wave_index = -1


func _get_spawn_pointer_position() -> Vector2:
	if curve == null or curve.get_point_count() <= 0:
		return global_position
	return to_global(curve.sample_baked(0.0))


func _get_spawn_direction() -> Vector2:
	if curve == null:
		return Vector2.RIGHT
	var path_length: float = curve.get_baked_length()
	if path_length <= 0.0:
		return Vector2.RIGHT
	var start_pos: Vector2 = curve.sample_baked(0.0)
	var next_pos: Vector2 = curve.sample_baked(minf(24.0, path_length))
	var direction: Vector2 = next_pos - start_pos
	if direction.length_squared() <= 0.001:
		return Vector2.RIGHT
	return direction.normalized()


func _apply_spawn_facing(enemy_instance: Node) -> void:
	if enemy_instance == null or not is_instance_valid(enemy_instance):
		return
	if curve == null:
		return
	var path_length: float = curve.get_baked_length()
	if path_length <= 0.0:
		return
	var start_pos: Vector2 = curve.sample_baked(0.0)
	var look_ahead: float = minf(24.0, path_length)
	var next_pos: Vector2 = curve.sample_baked(look_ahead)
	var direction: Vector2 = next_pos - start_pos
	if enemy_instance.has_method("set_initial_path_direction"):
		enemy_instance.set_initial_path_direction(direction)
