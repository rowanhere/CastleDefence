extends Node2D

var getSoldier = preload("res://scenes/towers/barrack/BarrackSoldier.tscn")
@onready var door_mark: Marker2D = $DoorMark

@onready var tower_area: Area2D = $TowerImage/towerArea
@onready var timer: Timer = $Timer
@onready var respawn_progress: TextureProgressBar = $RespawnProgress

const MAX_SOLDIERS := 3
const RESPAWN_TIME := 10.0
const INITIAL_SPAWN_DELAY := 3.0

var soldiers: Array = []
var enemies_in_range: Array[Node2D] = []
var respawning := false
var current_wait_time := INITIAL_SPAWN_DELAY


func _ready() -> void:
	tower_area.body_entered.connect(_on_body_entered)
	tower_area.body_exited.connect(_on_body_exited)
	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout)
	respawn_progress.value = 0.0
	respawn_progress.show()
	# Use the main timer for the initial 3s spawn so the progress bar tracks it
	respawning = true
	current_wait_time = INITIAL_SPAWN_DELAY
	respawn_progress.max_value = INITIAL_SPAWN_DELAY
	timer.wait_time = INITIAL_SPAWN_DELAY
	timer.start()


# ─── Spawning ────────────────────────────────────────────────────────────────

var spawn_sound: AudioStream = preload("res://assets/audio/sfx/soldierSpawn.mp3")

func _spawn_all_soldiers() -> void:
	for i in MAX_SOLDIERS:
		_create_soldier(i)
	respawning = false
	respawn_progress.hide()


func _create_soldier(index: int) -> void:
	var path2d: Path2D = get_tree().get_first_node_in_group("level_path") as Path2D
	var soldier = getSoldier.instantiate()
	get_tree().current_scene.add_child(soldier)

	# Final resting wait positions spread around the tower
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

	# Start hidden at the door marker — tween outward so they march out of the gate
	soldier.global_position = door_mark.global_position
	soldier.modulate.a = 0.0

	# Play spawn sound once per soldier at 60% volume (-4.4 dB), timed with the stagger
	get_tree().create_timer(index * 0.25).timeout.connect(func(): GameSound.play(spawn_sound, -40.0))

	var stagger_delay: float = index * 0.25
	var tween: Tween = get_tree().create_tween()
	tween.tween_interval(stagger_delay)
	tween.tween_property(soldier, "global_position", final_pos, 0.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(soldier, "modulate:a", 1.0, 0.3)

	soldiers.append(soldier)


# ─── Validation helpers ──────────────────────────────────────────────────────

func _is_valid_enemy(enemy) -> bool:
	return enemy != null and is_instance_valid(enemy) \
		and enemy.is_in_group("enemies") and not enemy.is_dead


func _prune_enemies_in_range() -> void:
	enemies_in_range = enemies_in_range.filter(func(e): return _is_valid_enemy(e))


# ─── Target assignment ───────────────────────────────────────────────────────

func _assign_targets() -> void:
	_prune_enemies_in_range()
	if enemies_in_range.is_empty():
		# Clear targets so soldiers return to wait positions
		for soldier in soldiers:
			if is_instance_valid(soldier) and not soldier.is_fighting():
				soldier.target = null
		return

	for soldier in soldiers:
		if not is_instance_valid(soldier):
			continue
		# Keep current target if soldier is actively fighting
		if soldier.is_fighting():
			continue
		# Keep current target if it is still valid
		if _is_valid_enemy(soldier.target):
			continue
		# Assign closest enemy
		var best_enemy: Node2D = null
		var best_dist: float = INF
		for enemy in enemies_in_range:
			var d: float = soldier.global_position.distance_squared_to(enemy.global_position)
			if d < best_dist:
				best_dist = d
				best_enemy = enemy
		soldier.target = best_enemy


# ─── Area signals ────────────────────────────────────────────────────────────

func _on_body_entered(body: Node2D) -> void:
	if _is_valid_enemy(body) and body not in enemies_in_range:
		enemies_in_range.append(body)
		_assign_targets()


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("enemies"):
		return
	enemies_in_range.erase(body)
	# Clear target on soldiers that were chasing this enemy
	for soldier in soldiers:
		if is_instance_valid(soldier) and soldier.target == body:
			soldier.target = null
	_assign_targets()


# ─── Main loop ───────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	# Remove freed soldiers
	soldiers = soldiers.filter(func(s): return is_instance_valid(s))
	_prune_enemies_in_range()
	_assign_targets()

	# If all soldiers are dead and we are not already waiting to respawn, start timer
	if soldiers.is_empty() and not respawning:
		respawning = true
		current_wait_time = RESPAWN_TIME
		respawn_progress.max_value = RESPAWN_TIME
		timer.wait_time = RESPAWN_TIME
		timer.start()
		respawn_progress.value = 0.0
		respawn_progress.show()

	# Update progress bar accurately using the actual timer's wait_time
	if respawning:
		respawn_progress.value = current_wait_time - timer.time_left


# ─── Respawn timer ───────────────────────────────────────────────────────────

func _on_timer_timeout() -> void:
	_spawn_all_soldiers()
	# Re-assign targets in case enemies are still in range
	_assign_targets()
