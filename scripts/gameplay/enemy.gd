extends CharacterBody2D

var data: EnemyData = null:
	set(value):
		data = value
		_apply_data()

@onready var health_bar: ProgressBar = $HealthBar
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea

var DamageNumber = preload("res://scenes/enemies/DamageNumber.tscn")
var CoinsDropNumber = preload("res://scenes/enemies/CoinsDropNumber.tscn")

var speed = 80.0
var hp = 100
var is_dead = false
var coin_drop = 0
var path_spacing = 28.0
var attack_damage = 12.0
var attack_speed = 1.0
var attack_timer = 0.0
var locked_soldier: Node2D = null
var is_boss_enemy: bool = false

var _dir_suffix: String = "Down"
var _detached: bool = false
var _returning: bool = false
var _attack_slot_angle: float = -1.0
const ATTACK_SLOT_RADIUS: float = 55.0
const DEPTH_SORT_DIVISOR := 4.0


func _apply_data() -> void:
	if not is_node_ready() or not data:
		return
	speed         = data.speed
	hp            = data.health
	coin_drop     = data.coin_drop
	path_spacing  = data.path_spacing
	attack_damage = data.attack_damage
	attack_speed  = data.attack_speed
	attack_timer  = attack_speed
	if data.scale != Vector2.ZERO:
		scale = data.scale
	health_bar.max_value = hp
	health_bar.value = hp
	_apply_health_bar_color()
	if data.sprite_frames:
		anim.sprite_frames = data.sprite_frames
		anim.play("walkDown")
	else:
		print("[Enemy] WARNING: ", data.enemy_name, " has no sprite_frames in .tres!")


func _ready() -> void:
	add_to_group("enemies")
	z_as_relative = false
	health_bar.max_value = hp
	health_bar.value = hp
	_update_depth()


func _update_depth() -> void:
	z_index = clampi(int(round(global_position.y / DEPTH_SORT_DIVISOR)), -4096, 4096)


func _apply_health_bar_color() -> void:
	if health_bar == null or data == null:
		return
	var fill_style := health_bar.get("theme_override_styles/fill") as StyleBoxFlat
	if fill_style == null:
		fill_style = StyleBoxFlat.new()
	else:
		fill_style = fill_style.duplicate()
	fill_style.bg_color = data.health_bar_color
	health_bar.add_theme_stylebox_override("fill", fill_style)


func _is_valid_soldier(s) -> bool:
	if s == null or not is_instance_valid(s):
		return false
	return s.is_in_group("soldier") and not s.is_dead


func _distance_to(other: Node2D) -> float:
	return global_position.distance_to(other.global_position)


func _engage_range(other: Node2D) -> float:
	var other_scale: float = other.scale.x if (other != null and is_instance_valid(other)) else 1.0
	return 22.0 * max(scale.x, other_scale) + 14.0


func _soldier_in_attack_area() -> Node2D:
	for body in attack_area.get_overlapping_bodies():
		if _is_valid_soldier(body):
			return body
	return null


func _pick_soldier() -> Node2D:
	var touch := _soldier_in_attack_area()
	if touch:
		return touch
	var closest: Node2D = null
	var closest_dist: float = INF
	for node in get_tree().get_nodes_in_group("soldier"):
		if not _is_valid_soldier(node):
			continue
		var d: float = _distance_to(node)
		if d <= 150.0 and d < closest_dist:
			closest_dist = d
			closest = node
	return closest


func _claim_attack_slot(soldier: Node2D) -> float:
	var taken: Array = []
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self or not is_instance_valid(other):
			continue
		if other._attack_slot_angle >= 0.0 and other.locked_soldier == soldier:
			taken.append(other._attack_slot_angle)
	for i in range(8):
		var angle: float = (TAU / 8.0) * i
		var blocked: bool = false
		for a in taken:
			if abs(angle - a) < 0.4:
				blocked = true
				break
		if not blocked:
			return angle
	return randf() * TAU


func _detach_from_path() -> void:
	if _detached:
		return
	var path_follow: PathFollow2D = get_parent() as PathFollow2D
	if path_follow == null:
		return
	_detached = true
	_returning = false
	reparent(get_tree().current_scene, true)
	path_follow.queue_free()


func _sanitize_lock() -> void:
	var had_soldier: bool = locked_soldier != null
	if locked_soldier != null and not is_instance_valid(locked_soldier):
		locked_soldier = null
	elif locked_soldier != null and not _is_valid_soldier(locked_soldier):
		locked_soldier = null
	if had_soldier and locked_soldier == null:
		_attack_slot_angle = -1.0
		_returning = true


func _get_dir_suffix(dir: Vector2) -> String:
	if abs(dir.x) >= abs(dir.y):
		return "Right" if dir.x >= 0 else "Left"
	else:
		return "Down" if dir.y >= 0 else "Up"


func _anim_name(base: String) -> String:
	return base + _dir_suffix


func _play_dir(base: String, force: bool = false) -> void:
	if not anim.sprite_frames:
		return
	var anim_name: String = _anim_name(base)
	if anim.sprite_frames.has_animation(anim_name):
		if force or anim.animation != anim_name or not anim.is_playing():
			anim.play(anim_name)
	elif anim.sprite_frames.has_animation(base):
		if force or anim.animation != base or not anim.is_playing():
			anim.play(base)


func _path_follow_has_live_enemy(path_follow: PathFollow2D) -> bool:
	if path_follow == null:
		return false
	for child in path_follow.get_children():
		var enemy := child as CharacterBody2D
		if enemy != null and is_instance_valid(enemy) and not enemy.is_dead:
			return true
	return false


func _collect_occupied_path_progress(path2d: Path2D) -> Array[float]:
	var occupied: Array[float] = []
	if path2d == null:
		return occupied

	for child in path2d.get_children():
		var other_follow := child as PathFollow2D
		if other_follow == null or other_follow == get_parent():
			continue
		if not _path_follow_has_live_enemy(other_follow):
			continue
		occupied.append(other_follow.progress)

	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self or not is_instance_valid(other) or other.is_dead:
			continue
		if other._detached and other._returning:
			var other_local_pos: Vector2 = path2d.to_local(other.global_position)
			occupied.append(path2d.curve.get_closest_offset(other_local_pos))

	occupied.sort()
	return occupied


func _find_open_path_progress(path2d: Path2D, desired_progress: float) -> float:
	if path2d == null:
		return desired_progress

	var candidate: float = max(desired_progress, 0.0)
	var min_spacing: float = max(path_spacing, 8.0)
	var occupied: Array[float] = _collect_occupied_path_progress(path2d)
	for progress_value in occupied:
		if abs(progress_value - candidate) < min_spacing:
			if candidate <= progress_value:
				candidate = max(progress_value - min_spacing, 0.0)
			else:
				candidate = progress_value + min_spacing

	return candidate


func _get_max_allowed_progress(path2d: Path2D, path_follow: PathFollow2D) -> float:
	if path2d == null or path_follow == null:
		return INF

	var max_progress: float = INF
	var min_spacing: float = max(path_spacing, 8.0)
	for child in path2d.get_children():
		var other_follow := child as PathFollow2D
		if other_follow == null or other_follow == path_follow:
			continue
		if not _path_follow_has_live_enemy(other_follow):
			continue
		if other_follow.progress > path_follow.progress:
			max_progress = min(max_progress, other_follow.progress - min_spacing)

	return max_progress


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_sanitize_lock()
	_update_depth()

	# ── Detached (free movement) ──────────────────────────────────────────────
	if _detached:
		# Always check for a new soldier first
		var new_soldier := _pick_soldier()
		if new_soldier:
			locked_soldier = new_soldier
			_returning = false

		# In combat — move to slot and attack
		if locked_soldier != null:
			var to_soldier: Vector2 = (locked_soldier.global_position - global_position).normalized()
			_dir_suffix = _get_dir_suffix(to_soldier)

			if _attack_slot_angle < 0.0:
				_attack_slot_angle = _claim_attack_slot(locked_soldier)

			var slot_pos: Vector2 = locked_soldier.global_position \
				+ Vector2(cos(_attack_slot_angle), sin(_attack_slot_angle)) * ATTACK_SLOT_RADIUS
			var dist_to_slot: float = global_position.distance_to(slot_pos)

			if dist_to_slot > 8.0:
				var dir: Vector2 = (slot_pos - global_position).normalized()
				_dir_suffix = _get_dir_suffix(dir)
				global_position = global_position.move_toward(slot_pos, speed * delta)
				_play_dir("walk")
			else:
				velocity = Vector2.ZERO
				attack_timer -= delta
				if not anim.animation.begins_with("attack") or not anim.is_playing():
					_play_dir("attack", true)
				if attack_timer <= 0.0:
					attack_timer = attack_speed
					locked_soldier.take_damage(attack_damage)
			return

		# Fallback — detached with no soldier and not marked as returning
		if not _returning:
			_returning = true

		# Returning to path — walk toward nearest path point
		if _returning:
			var path2d: Path2D = get_tree().get_first_node_in_group("level_path") as Path2D
			if path2d:
				var local_pos: Vector2 = path2d.to_local(global_position)
				var closest_offset: float = path2d.curve.get_closest_offset(local_pos)
				var rejoin_progress: float = _find_open_path_progress(path2d, closest_offset)
				var target: Vector2 = path2d.to_global(path2d.curve.sample_baked(rejoin_progress))
				if global_position.distance_to(target) > 6.0:
					var dir: Vector2 = (target - global_position).normalized()
					_dir_suffix = _get_dir_suffix(dir)
					global_position = global_position.move_toward(target, speed * delta)
					_play_dir("walk")
				else:
					# Arrived — reparent back cleanly
					_returning = false
					_detached = false
					var follow := PathFollow2D.new()
					follow.rotates = false
					follow.loop = false
					path2d.add_child(follow)
					follow.progress = rejoin_progress
					reparent(follow, false)
					position = Vector2.ZERO
		return

	# ── On path ──────────────────────────────────────────────────────────────
	var path_follow: PathFollow2D = get_parent() as PathFollow2D

	var soldier := _pick_soldier()
	if soldier:
		locked_soldier = soldier
		_detach_from_path()
		return

	if path_follow == null:
		return

	var prev_pos: Vector2 = global_position
	var next_progress: float = path_follow.progress + speed * delta
	var max_allowed_progress: float = _get_max_allowed_progress(path_follow.get_parent() as Path2D, path_follow)
	path_follow.progress = max(path_follow.progress, min(next_progress, max_allowed_progress))
	var move_delta: Vector2 = global_position - prev_pos
	if move_delta.length() > 0.1:
		_dir_suffix = _get_dir_suffix(move_delta)
	_play_dir("walk")

	if path_follow.progress_ratio >= 1.0:
		reach_castle()


func take_damage(amount: float) -> void:
	if is_dead:
		return
	hp -= amount
	health_bar.value = hp
	if hp <= 0:
		_start_death(true)
		return
	_spawn_damage_number(amount)


func _spawn_damage_number(amount: float) -> void:
	var dmg_label = DamageNumber.instantiate()
	dmg_label.velocity = Vector2(randf_range(-25, 25), -70)
	dmg_label.lifetime = 1.0
	dmg_label.text = "-" + str(int(amount))
	get_tree().current_scene.add_child(dmg_label)
	dmg_label.global_position = global_position + Vector2(randf_range(-8, 8), -50)
	dmg_label.add_theme_font_size_override("font_size", 14)
	dmg_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))


func _spawn_coin_drop_number(amount: int) -> void:
	var coin_label = CoinsDropNumber.instantiate()
	coin_label.amount = amount
	coin_label.velocity = Vector2(randf_range(-20, 20), -65)
	coin_label.lifetime = 1.0
	get_tree().current_scene.add_child(coin_label)
	coin_label.global_position = global_position + Vector2(randf_range(-10, 10), -42)


func _start_death(reward_coins: bool) -> void:
	if is_dead:
		return
	is_dead = true
	locked_soldier = null
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	if attack_area != null:
		attack_area.set_deferred("monitoring", false)
		attack_area.set_deferred("monitorable", false)
	call_deferred("_finish_death", reward_coins)


func _finish_death(reward_coins: bool) -> void:
	var parent_follow := get_parent() as PathFollow2D
	if parent_follow != null and is_instance_valid(parent_follow):
		reparent(get_tree().current_scene, true)
		parent_follow.queue_free()
	if reward_coins:
		_spawn_coin_drop_number(coin_drop)
		GameHandler.add_coins(coin_drop)
	health_bar.hide()
	_play_dir("die")
	await anim.animation_finished
	if is_boss_enemy:
		var handler := get_tree().current_scene
		if handler != null and handler.has_method("handle_boss_defeated"):
			handler.handle_boss_defeated()
	queue_free()


func die(reward_coins: bool = true) -> void:
	_start_death(reward_coins)


func reach_castle() -> void:
	_start_death(false)
