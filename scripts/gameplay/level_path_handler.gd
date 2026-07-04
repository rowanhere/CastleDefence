extends Path2D

const ENEMY_SCENE = preload("res://scenes/enemies/enemy.tscn")
var spawn_schedule: Resource

@onready var timer: Timer = $Timer
var spawn_queue: Array[Dictionary] = []
var elapsed_time: float = 0.0
var next_entry_index: int = 0


func _ready() -> void:
	add_to_group("level_path")
	spawn_schedule = load(GameHandler.get_level_spawn_schedule_path(GameHandler.queued_level))
	if spawn_schedule == null:
		push_error("Failed to load spawn schedule for level %d" % GameHandler.queued_level)
		return
	timer.wait_time = 0.3
	timer.timeout.connect(_on_timer_timeout)
	timer.start()
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


func _on_timer_timeout() -> void:
	if spawn_queue.is_empty():
		if spawn_schedule != null and next_entry_index >= spawn_schedule.waves.size():
			timer.stop()
		return

	var spawn_data: Dictionary = spawn_queue.pop_front()
	var follow = PathFollow2D.new()
	follow.rotates = false
	follow.loop = false
	add_child(follow)
	var enemy_instance = ENEMY_SCENE.instantiate()
	follow.add_child(enemy_instance)     # _ready() runs here first
	var base_data: EnemyData = spawn_data["enemy_data"]
	var is_boss_wave: bool = spawn_data.get("is_boss_wave", false)
	var scaled_data: EnemyData = GameHandler.get_scaled_enemy_data(base_data, GameHandler.queued_level, is_boss_wave)
	if is_boss_wave:
		scaled_data.coin_drop = 0
	enemy_instance.is_boss_enemy = is_boss_wave
	enemy_instance.data = scaled_data  # set AFTER so _ready+@onready vars are ready


func _enqueue_entry(entry_index: int) -> void:
	if entry_index < 0 or entry_index >= spawn_schedule.waves.size():
		return
	var wave: Resource = spawn_schedule.waves[entry_index]
	var enemy_pool: Array[String] = wave.enemy_pool
	var total_multiplier: int = wave.total_multiplier
	var is_boss_wave: bool = wave.is_boss_wave
	if enemy_pool.is_empty() or total_multiplier <= 0:
		return

	var spawn_count: int = total_multiplier
	if enemy_pool.size() > 1:
		spawn_count = int(ceil(float(total_multiplier) / float(enemy_pool.size())))

	for enemy_id in enemy_pool:
		var enemy_data: EnemyData = GameHandler.get_enemy_data_by_id(enemy_id)
		if enemy_data == null:
			push_warning("Unknown enemy id in spawn entry: %s" % enemy_id)
			continue
		for _i in range(spawn_count):
			spawn_queue.append({
				"enemy_data": enemy_data,
				"is_boss_wave": is_boss_wave
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
