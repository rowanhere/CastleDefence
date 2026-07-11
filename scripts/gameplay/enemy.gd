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
var locked_castle: Node2D = null
var is_boss_enemy: bool = false
var barrack_hold_progress: float = -1.0

var _dir_suffix: String = "Down"
var _path_progress_hint: float = 0.0
var _detached: bool = false
var _attack_slot_angle: float = -1.0
var _path_lane_offset: Vector2 = Vector2.ZERO
var _path_lane_index: int = 0
var _has_path_lane: bool = false
var _spawn_lane_index: int = 0
var _has_spawn_lane: bool = false
var _slow_multiplier: float = 1.0
var _slow_timer: float = 0.0

const DEPTH_SORT_DIVISOR := 4.0
const MAX_DEPTH_Z_INDEX := 2000
const SOLDIER_DETECT_RANGE := 150.0
const ATTACK_SLOT_RADIUS := 42.0
const PATH_LANE_WIDTH := 10.0
const PATH_ROW_DEPTH := 5.0
const PATH_LANE_PROGRESS_RANGE := 18.0
const PATH_LANE_SMOOTH := 10.0
const SPAWN_LANE_PROGRESS := 96.0
const CROWD_SPACING_RANGE := 34.0
const CROWD_MIN_SPEED_SCALE := 0.82
const CROWD_MAX_SPEED_SCALE := 1.16
const CROWD_SPACE_PUSH := 0.18


func _apply_data() -> void:
	if not is_node_ready() or not data:
		return
	speed = data.speed
	hp = data.health
	coin_drop = data.coin_drop
	path_spacing = max(data.path_spacing, 26.0 * max(data.scale.x, 1.0))
	attack_damage = data.attack_damage
	attack_speed = data.attack_speed
	attack_timer = attack_speed
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
	z_index = clampi(int(round(global_position.y / DEPTH_SORT_DIVISOR)), -4096, MAX_DEPTH_Z_INDEX)


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
	if touch and _soldier_can_accept_enemy(touch):
		return touch
	var closest: Node2D = null
	var closest_dist: float = INF
	for node in get_tree().get_nodes_in_group("soldier"):
		if not _is_valid_soldier(node) or not _soldier_can_accept_enemy(node):
			continue
		var d: float = _distance_to(node)
		if d <= SOLDIER_DETECT_RANGE and d < closest_dist:
			closest_dist = d
			closest = node
	return closest


func _soldier_can_accept_enemy(soldier: Node2D) -> bool:
	return soldier != null and is_instance_valid(soldier) \
		and soldier.has_method("can_reserve_enemy") \
		and soldier.can_reserve_enemy(self)


func can_reserve_soldier(soldier: Node2D) -> bool:
	return _is_valid_soldier(soldier)


func reserve_soldier(soldier: Node2D) -> bool:
	if not can_reserve_soldier(soldier):
		return false
	if locked_soldier == null:
		locked_soldier = soldier
	return true


func release_soldier(soldier: Node2D = null) -> void:
	if soldier == null or locked_soldier == soldier:
		locked_soldier = null
		attack_timer = attack_speed


func set_barrack_hold(progress: float, soldier: Node2D = null) -> void:
	if soldier != null and locked_soldier != null and locked_soldier != soldier:
		return
	barrack_hold_progress = progress


func clear_barrack_hold(soldier: Node2D = null) -> void:
	if soldier != null and locked_soldier != null and locked_soldier != soldier:
		return
	barrack_hold_progress = -1.0


func get_path_progress() -> float:
	var path_follow: PathFollow2D = get_parent() as PathFollow2D
	if path_follow != null:
		return path_follow.progress
	return _path_progress_hint


func _try_lock_soldier(soldier: Node2D) -> bool:
	if not _is_valid_soldier(soldier):
		return false
	if locked_soldier == soldier:
		return true
	if locked_soldier != null and locked_soldier != soldier:
		return false
	if not soldier.has_method("reserve_enemy") or not soldier.reserve_enemy(self):
		return false
	locked_soldier = soldier
	return true


func _claim_attack_slot(soldier: Node2D) -> float:
	var taken: Array[float] = []
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self or not is_instance_valid(other):
			continue
		if other.locked_soldier == soldier and other._attack_slot_angle >= 0.0:
			taken.append(other._attack_slot_angle)

	for i in range(8):
		var angle: float = (TAU / 8.0) * float(i)
		var available := true
		for taken_angle in taken:
			if abs(wrapf(angle - taken_angle, -PI, PI)) < 0.35:
				available = false
				break
		if available:
			return angle
	return randf() * TAU


func _detach_from_path() -> void:
	if _detached:
		return
	var path_follow: PathFollow2D = get_parent() as PathFollow2D
	if path_follow == null:
		return
	var detach_parent: Node = path_follow.get_parent()
	if detach_parent == null:
		return
	_path_progress_hint = path_follow.progress
	_detached = true
	_path_lane_offset = Vector2.ZERO
	_has_path_lane = false
	reparent(detach_parent, true)
	path_follow.queue_free()


func _rejoin_path() -> void:
	if not _detached:
		return
	var path2d: Path2D = get_tree().get_first_node_in_group("level_path") as Path2D
	if path2d == null or path2d.curve == null:
		return
	var local_pos: Vector2 = path2d.to_local(global_position)
	var closest_offset: float = path2d.curve.get_closest_offset(local_pos)
	var follow := PathFollow2D.new()
	follow.rotates = false
	follow.loop = false
	path2d.add_child(follow)
	follow.progress = max(closest_offset, _path_progress_hint)
	_path_progress_hint = follow.progress
	_detached = false
	_attack_slot_angle = -1.0
	reparent(follow, false)
	position = Vector2.ZERO
	_path_lane_offset = Vector2.ZERO
	_path_lane_index = _claim_path_lane(path2d, follow)
	_has_path_lane = true
	refresh_path_crowd_offset()


func _sanitize_lock() -> void:
	if locked_soldier != null and not is_instance_valid(locked_soldier):
		locked_soldier = null
	elif locked_soldier != null and not _is_valid_soldier(locked_soldier):
		locked_soldier = null
	if locked_soldier == null:
		_attack_slot_angle = -1.0


func _get_dir_suffix(dir: Vector2) -> String:
	if abs(dir.x) >= abs(dir.y):
		return "Right" if dir.x >= 0 else "Left"
	return "Down" if dir.y >= 0 else "Up"


func _anim_name(base: String) -> String:
	return base + _dir_suffix


func _play_dir(base: String, force: bool = false) -> void:
	if not anim.sprite_frames:
		return
	var anim_name := _anim_name(base)
	if anim.sprite_frames.has_animation(anim_name):
		if force or anim.animation != anim_name or not anim.is_playing():
			anim.play(anim_name)
	elif anim.sprite_frames.has_animation(base):
		if force or anim.animation != base or not anim.is_playing():
			anim.play(base)


func set_initial_path_direction(direction: Vector2) -> void:
	if direction.length_squared() <= 0.001:
		return
	_dir_suffix = _get_dir_suffix(direction.normalized())
	_play_dir("walk", true)


func _path_follow_has_live_enemy(path_follow: PathFollow2D) -> bool:
	if path_follow == null:
		return false
	for child in path_follow.get_children():
		var enemy := child as CharacterBody2D
		if enemy != null and is_instance_valid(enemy) and not enemy.is_dead:
			return true
	return false


func _get_lane_index(path2d: Path2D, path_follow: PathFollow2D) -> int:
	if path2d == null or path_follow == null:
		return 0
	if _has_spawn_lane and path_follow.progress <= SPAWN_LANE_PROGRESS:
		return _spawn_lane_index
	_has_spawn_lane = false
	if _has_path_lane:
		return _path_lane_index
	var nearby: Array = []
	for child in path2d.get_children():
		var other_follow := child as PathFollow2D
		if other_follow == null:
			continue
		if not _path_follow_has_live_enemy(other_follow):
			continue
		if abs(other_follow.progress - path_follow.progress) <= PATH_LANE_PROGRESS_RANGE:
			nearby.append(other_follow)
	if nearby.size() <= 1:
		return 0
	nearby.sort_custom(func(a, b):
		return a.get_instance_id() < b.get_instance_id()
	)
	var rank: int = nearby.find(path_follow)
	var lanes: Array[int] = [0, -1, 1, -2, 2, -3, 3]
	_path_lane_index = lanes[rank % lanes.size()]
	_has_path_lane = true
	return _path_lane_index


func _get_enemy_from_follow(path_follow: PathFollow2D) -> Node:
	if path_follow == null:
		return null
	for child in path_follow.get_children():
		if child.is_in_group("enemies") and not child.is_dead:
			return child
	return null


func _claim_path_lane(path2d: Path2D, path_follow: PathFollow2D) -> int:
	if path2d == null or path_follow == null:
		return 0
	var taken: Array[int] = []
	for child in path2d.get_children():
		var other_follow := child as PathFollow2D
		if other_follow == null or other_follow == path_follow:
			continue
		if abs(other_follow.progress - path_follow.progress) > PATH_LANE_PROGRESS_RANGE:
			continue
		var other_enemy := _get_enemy_from_follow(other_follow)
		if other_enemy == null or not is_instance_valid(other_enemy):
			continue
		if other_enemy.get("_has_path_lane") or other_enemy.get("_has_spawn_lane"):
			taken.append(int(other_enemy.get("_path_lane_index")))

	var lanes: Array[int] = [-1, 1, -2, 2, 0, -3, 3, -4, 4]
	for lane in lanes:
		if lane not in taken:
			return lane
	return lanes[get_instance_id() % lanes.size()]


func _get_crowd_speed_scale(path2d: Path2D, path_follow: PathFollow2D) -> float:
	if path2d == null or path_follow == null:
		return 1.0
	var progress: float = path_follow.progress
	var nearest_ahead_gap: float = INF
	var nearest_behind_gap: float = INF
	for child in path2d.get_children():
		var other_follow := child as PathFollow2D
		if other_follow == null or other_follow == path_follow:
			continue
		if not _path_follow_has_live_enemy(other_follow):
			continue
		var gap: float = other_follow.progress - progress
		if gap > 0.0:
			nearest_ahead_gap = min(nearest_ahead_gap, gap)
		elif gap < 0.0:
			nearest_behind_gap = min(nearest_behind_gap, abs(gap))

	var speed_scale := 1.0
	if nearest_ahead_gap < CROWD_SPACING_RANGE:
		var ahead_crowd_amount: float = 1.0 - nearest_ahead_gap / CROWD_SPACING_RANGE
		speed_scale -= ahead_crowd_amount * CROWD_SPACE_PUSH
	if nearest_behind_gap < CROWD_SPACING_RANGE:
		var behind_crowd_amount: float = 1.0 - nearest_behind_gap / CROWD_SPACING_RANGE
		speed_scale += behind_crowd_amount * CROWD_SPACE_PUSH
	return clampf(speed_scale, CROWD_MIN_SPEED_SCALE, CROWD_MAX_SPEED_SCALE)


func _get_path_normal(path2d: Path2D, progress: float) -> Vector2:
	if path2d == null or path2d.curve == null:
		return Vector2.ZERO
	var path_length: float = path2d.curve.get_baked_length()
	if path_length <= 0.0:
		return Vector2.ZERO
	var before: Vector2 = path2d.curve.sample_baked(clampf(progress - 8.0, 0.0, path_length))
	var after: Vector2 = path2d.curve.sample_baked(clampf(progress + 8.0, 0.0, path_length))
	var tangent: Vector2 = after - before
	if tangent.length_squared() <= 0.001:
		return Vector2.ZERO
	tangent = tangent.normalized()
	return Vector2(-tangent.y, tangent.x)


func _get_path_tangent(path2d: Path2D, progress: float) -> Vector2:
	if path2d == null or path2d.curve == null:
		return Vector2.ZERO
	var path_length: float = path2d.curve.get_baked_length()
	if path_length <= 0.0:
		return Vector2.ZERO
	var before: Vector2 = path2d.curve.sample_baked(clampf(progress - 8.0, 0.0, path_length))
	var after: Vector2 = path2d.curve.sample_baked(clampf(progress + 8.0, 0.0, path_length))
	var tangent: Vector2 = after - before
	if tangent.length_squared() <= 0.001:
		return Vector2.ZERO
	return tangent.normalized()


func _update_path_lane_offset(path2d: Path2D, path_follow: PathFollow2D, delta: float) -> void:
	var lane_index: int = _get_lane_index(path2d, path_follow)
	var side_offset: Vector2 = _get_path_normal(path2d, path_follow.progress) * PATH_LANE_WIDTH * float(lane_index)
	var depth_offset: Vector2 = _get_path_tangent(path2d, path_follow.progress) * PATH_ROW_DEPTH * float(abs(lane_index))
	var target_offset: Vector2 = side_offset - depth_offset
	var weight: float = clampf(delta * PATH_LANE_SMOOTH, 0.0, 1.0)
	_path_lane_offset = _path_lane_offset.lerp(target_offset, weight)
	position = _path_lane_offset


func refresh_path_crowd_offset() -> void:
	var path_follow: PathFollow2D = get_parent() as PathFollow2D
	if path_follow == null:
		return
	var path2d := path_follow.get_parent() as Path2D
	_update_path_lane_offset(path2d, path_follow, 1.0)


func set_spawn_lane_index(lane_index: int) -> void:
	_spawn_lane_index = lane_index
	_has_spawn_lane = lane_index != 0
	_path_lane_index = lane_index
	_has_path_lane = lane_index != 0
	refresh_path_crowd_offset()


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_update_slow(delta)
	_sanitize_lock()
	_update_depth()

	if locked_castle != null:
		_attack_castle(delta)
		return

	var path_follow: PathFollow2D = get_parent() as PathFollow2D

	if _detached:
		if locked_soldier == null:
			var next_soldier := _pick_soldier()
			if next_soldier != null:
				_try_lock_soldier(next_soldier)

		if locked_soldier != null:
			if _attack_slot_angle < 0.0:
				_attack_slot_angle = _claim_attack_slot(locked_soldier)
			var slot_pos: Vector2 = locked_soldier.global_position + Vector2(cos(_attack_slot_angle), sin(_attack_slot_angle)) * ATTACK_SLOT_RADIUS
			var dist_to_slot: float = global_position.distance_to(slot_pos)
			var dist_to_soldier: float = _distance_to(locked_soldier)
			if dist_to_slot > 6.0 and dist_to_soldier > _engage_range(locked_soldier):
				var dir: Vector2 = (slot_pos - global_position).normalized()
				_dir_suffix = _get_dir_suffix(dir)
				global_position = global_position.move_toward(slot_pos, _get_current_speed() * delta)
				_play_dir("walk")
			else:
				velocity = Vector2.ZERO
				var to_soldier: Vector2 = locked_soldier.global_position - global_position
				if to_soldier.length_squared() > 0.001:
					_dir_suffix = _get_dir_suffix(to_soldier.normalized())
				attack_timer -= delta
				_play_dir("attack")
				if attack_timer <= 0.0:
					attack_timer = attack_speed
					locked_soldier.take_damage(attack_damage)
			return

		_rejoin_path()
		return

	if path_follow == null:
		return

	if locked_soldier == null:
		var soldier := _pick_soldier()
		if soldier:
			_try_lock_soldier(soldier)
			_detach_from_path()
			return

	if locked_soldier != null:
		if not _detached:
			_detach_from_path()
			return
		var soldier_in_range := _distance_to(locked_soldier) <= _engage_range(locked_soldier) or _soldier_in_attack_area() == locked_soldier
		if soldier_in_range:
			velocity = Vector2.ZERO
			var to_soldier: Vector2 = locked_soldier.global_position - global_position
			if to_soldier.length_squared() > 0.001:
				_dir_suffix = _get_dir_suffix(to_soldier.normalized())
			attack_timer -= delta
			_play_dir("attack")
			if attack_timer <= 0.0:
				attack_timer = attack_speed
				locked_soldier.take_damage(attack_damage)
			return

	_path_progress_hint = path_follow.progress
	var prev_pos: Vector2 = global_position
	var path2d := path_follow.get_parent() as Path2D
	var next_progress: float = path_follow.progress + _get_current_speed() * _get_crowd_speed_scale(path2d, path_follow) * delta
	if barrack_hold_progress >= 0.0:
		next_progress = min(next_progress, barrack_hold_progress)
	path_follow.progress = next_progress
	_update_path_lane_offset(path2d, path_follow, delta)
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


func apply_slow(multiplier: float, duration: float) -> void:
	_slow_multiplier = min(_slow_multiplier, clampf(multiplier, 0.05, 1.0))
	_slow_timer = max(_slow_timer, duration)


func _update_slow(delta: float) -> void:
	if _slow_timer <= 0.0:
		_slow_multiplier = 1.0
		return
	_slow_timer -= delta
	if _slow_timer <= 0.0:
		_slow_multiplier = 1.0


func _get_current_speed() -> float:
	return speed * _slow_multiplier


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
	if locked_soldier != null and is_instance_valid(locked_soldier) and locked_soldier.has_method("release_enemy"):
		locked_soldier.release_enemy(self)
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
		var detach_parent: Node = parent_follow.get_parent()
		if detach_parent != null:
			reparent(detach_parent, true)
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
	if is_dead:
		return

	var castle: Node = get_tree().current_scene.find_child("Castle", true, false)
	if castle == null or not castle is Node2D:
		return

	locked_castle = castle as Node2D
	_detach_from_path()
	attack_timer = 0.0


func _attack_castle(delta: float) -> void:
	if locked_castle == null or not is_instance_valid(locked_castle):
		locked_castle = null
		return

	velocity = Vector2.ZERO
	var to_castle: Vector2 = locked_castle.global_position - global_position
	if to_castle.length_squared() > 0.001:
		_dir_suffix = _get_dir_suffix(to_castle.normalized())
	_play_dir("attack")

	attack_timer -= delta
	if attack_timer > 0.0:
		return

	attack_timer = attack_speed
	var castle_damage: int = 1
	# Boss enemies can one-shot the castle later when real boss data is added.
	# if is_boss_enemy:
	# 	castle_damage = GameHandler.castle_life
	if locked_castle.has_method("take_damage"):
		locked_castle.take_damage(castle_damage)
