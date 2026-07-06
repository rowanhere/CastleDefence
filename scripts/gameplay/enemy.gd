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
var barrack_hold_progress: float = -1.0

var _dir_suffix: String = "Down"
var _path_progress_hint: float = 0.0

const DEPTH_SORT_DIVISOR := 4.0


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


func _soldier_is_assigned_to_me(soldier: Node2D) -> bool:
	if not _is_valid_soldier(soldier):
		return false
	return soldier.locked_enemy == self or soldier.target == self


func _pick_soldier() -> Node2D:
	var touch := _soldier_in_attack_area()
	if touch and _soldier_is_assigned_to_me(touch) and _soldier_can_accept_enemy(touch):
		return touch
	var closest: Node2D = null
	var closest_dist: float = INF
	for node in get_tree().get_nodes_in_group("soldier"):
		if not _soldier_is_assigned_to_me(node) or not _soldier_can_accept_enemy(node):
			continue
		var d: float = _distance_to(node)
		if d <= 150.0 and d < closest_dist:
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


func _sanitize_lock() -> void:
	if locked_soldier != null and not is_instance_valid(locked_soldier):
		locked_soldier = null
	elif locked_soldier != null and not _is_valid_soldier(locked_soldier):
		locked_soldier = null


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


func _get_nearest_ahead_progress(path2d: Path2D, current_progress: float) -> float:
	if path2d == null:
		return INF
	var nearest_ahead := INF
	for child in path2d.get_children():
		var other_follow := child as PathFollow2D
		if other_follow == null or other_follow == get_parent():
			continue
		if not _path_follow_has_live_enemy(other_follow):
			continue
		if other_follow.progress > current_progress:
			nearest_ahead = min(nearest_ahead, other_follow.progress)
	return nearest_ahead


func _get_max_allowed_progress(path2d: Path2D, current_progress: float) -> float:
	var nearest_ahead: float = _get_nearest_ahead_progress(path2d, current_progress)
	if not is_finite(nearest_ahead):
		return INF
	return max(nearest_ahead - max(path_spacing, 8.0), current_progress)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_sanitize_lock()
	_update_depth()

	var path_follow: PathFollow2D = get_parent() as PathFollow2D

	if path_follow == null:
		return

	if locked_soldier == null:
		var soldier := _pick_soldier()
		if soldier:
			_try_lock_soldier(soldier)

	if locked_soldier != null:
		var soldier_in_range := _distance_to(locked_soldier) <= _engage_range(locked_soldier) or _soldier_in_attack_area() == locked_soldier
		if soldier_in_range:
			velocity = Vector2.ZERO
			var to_soldier: Vector2 = locked_soldier.global_position - global_position
			if to_soldier.length_squared() > 0.001:
				_dir_suffix = _get_dir_suffix(to_soldier.normalized())
			attack_timer -= delta
			_play_dir("attack", true)
			if attack_timer <= 0.0:
				attack_timer = attack_speed
				locked_soldier.take_damage(attack_damage)
			return

	_path_progress_hint = path_follow.progress
	var prev_pos: Vector2 = global_position
	var path2d := path_follow.get_parent() as Path2D
	var next_progress: float = path_follow.progress + speed * delta
	var max_allowed_progress: float = _get_max_allowed_progress(path2d, path_follow.progress)
	if barrack_hold_progress >= 0.0:
		max_allowed_progress = min(max_allowed_progress, barrack_hold_progress)
	path_follow.progress = min(next_progress, max_allowed_progress)
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
