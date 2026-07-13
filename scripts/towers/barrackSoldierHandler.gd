extends CharacterBody2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var health_bar: ProgressBar = $HealthBar

var hitSound = preload("res://assets/audio/sfx/swordHit.mp3")

var home: Vector2 = Vector2.ZERO
var wait_position: Vector2 = Vector2.ZERO
var soldier_index: int = 0
var target: Node2D = null

var speed: float = 50.0
var last_direction: Vector2 = Vector2.RIGHT

var locked_enemy: Node2D = null
var attack_damage: float = 10.0
var attack_speed: float = 1.0
var attack_timer: float = 0.0

var hp: float = 100.0
var is_dead: bool = false

const COMBAT_OFFSET_DISTANCE := 34.0
const DEPTH_SORT_DIVISOR := 4.0
const MIN_GROUND_ACTOR_Z_INDEX := 2


func _ready() -> void:
	add_to_group("soldier")
	z_as_relative = false
	health_bar.max_value = hp
	health_bar.value = hp
	_update_depth()


func _update_depth() -> void:
	z_index = clampi(int(round(global_position.y / DEPTH_SORT_DIVISOR)), MIN_GROUND_ACTOR_Z_INDEX, 4096)


func _step_toward(target_pos: Vector2, delta: float) -> void:
	global_position = global_position.move_toward(target_pos, speed * delta)


func _is_valid_enemy(enemy) -> bool:
	return enemy != null and is_instance_valid(enemy) and enemy.is_in_group("enemies") and not enemy.is_dead


func _dist_to(node: Node2D) -> float:
	return global_position.distance_to(node.global_position)


func _engage_range(other: Node2D) -> float:
	var other_scale: float = other.scale.x if (other != null and is_instance_valid(other)) else 1.0
	return 28.0 * max(scale.x, other_scale) + 18.0


func _disengage_range(other: Node2D) -> float:
	return _engage_range(other) * 1.35


func _enemy_in_attack_area() -> Node2D:
	for body in attack_area.get_overlapping_bodies():
		if _is_valid_enemy(body):
			return body
	return null


func _enemy_attacking_me() -> Node2D:
	var closest: Node2D = null
	var closest_dist: float = INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not _is_valid_enemy(enemy):
			continue
		if enemy.get("locked_soldier") != self:
			continue
		var d: float = _dist_to(enemy)
		if d < closest_dist:
			closest_dist = d
			closest = enemy
	return closest


func _still_in_combat(enemy: Node2D) -> bool:
	if not _is_valid_enemy(enemy):
		return false
	return _dist_to(enemy) <= _disengage_range(enemy)


func release_enemy(enemy: Node2D = null, clear_target: bool = true) -> void:
	if enemy == null or locked_enemy == enemy:
		locked_enemy = null
	if clear_target and (enemy == null or target == enemy):
		target = null
	attack_timer = attack_speed


func can_reserve_enemy(enemy: Node2D) -> bool:
	return not is_dead and _is_valid_enemy(enemy)


func reserve_enemy(enemy: Node2D) -> bool:
	if not can_reserve_enemy(enemy):
		return false
	locked_enemy = enemy
	target = enemy
	return true


func is_fighting() -> bool:
	return _is_valid_enemy(locked_enemy) or _is_valid_enemy(target)


func _combat_slot(enemy: Node2D) -> Vector2:
	var away_from_enemy: Vector2 = global_position - enemy.global_position
	if away_from_enemy.length_squared() <= 0.001:
		away_from_enemy = wait_position - enemy.global_position
	if away_from_enemy.length_squared() <= 0.001:
		away_from_enemy = Vector2.RIGHT
	return enemy.global_position + away_from_enemy.normalized() * COMBAT_OFFSET_DISTANCE


func _fight_enemy(enemy: Node2D, delta: float) -> void:
	locked_enemy = enemy
	if enemy.has_method("reserve_soldier"):
		enemy.reserve_soldier(self)
	var dist_to_enemy: float = _dist_to(enemy)
	_face(enemy.global_position)
	if dist_to_enemy <= _engage_range(enemy) or _enemy_in_attack_area() == enemy:
		velocity = Vector2.ZERO
		_play_attack_anim()
		attack_timer -= delta
		if attack_timer <= 0.0:
			attack_timer = attack_speed
			enemy.take_damage(attack_damage)
			GameSound.play(hitSound)
		return
	var move_target: Vector2 = _combat_slot(enemy)
	var dir: Vector2 = (move_target - global_position).normalized()
	last_direction = dir
	velocity = Vector2.ZERO
	_step_toward(move_target, delta)
	if not _is_attacking():
		_play_walk_anim(dir)


func take_damage(amount: float) -> void:
	if is_dead:
		return
	hp -= amount
	health_bar.value = hp
	if hp <= 0.0:
		die()


func die() -> void:
	if is_dead:
		return
	is_dead = true
	if locked_enemy != null and is_instance_valid(locked_enemy) and locked_enemy.has_method("release_soldier"):
		locked_enemy.release_soldier(self)
	release_enemy()
	health_bar.hide()
	queue_free()


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	velocity = Vector2.ZERO
	_update_depth()

	if locked_enemy != null and (not is_instance_valid(locked_enemy) or not _is_valid_enemy(locked_enemy)):
		locked_enemy = null
	if target != null and (not is_instance_valid(target) or not _is_valid_enemy(target)):
		target = null

	var active_enemy: Node2D = locked_enemy if _is_valid_enemy(locked_enemy) else target
	if _is_valid_enemy(active_enemy):
		locked_enemy = active_enemy
		target = active_enemy
		_fight_enemy(active_enemy, delta)
		return

	locked_enemy = null

	var touch: Node2D = _enemy_in_attack_area()
	if touch:
		_fight_enemy(touch, delta)
		return

	var attacker: Node2D = _enemy_attacking_me()
	if attacker:
		_fight_enemy(attacker, delta)
		return

	if _is_attacking():
		_play_idle_anim()
		return

	var dist_to_wait: float = global_position.distance_to(wait_position)
	if dist_to_wait > 8.0:
		var dir: Vector2 = (wait_position - global_position).normalized()
		last_direction = dir
		_step_toward(wait_position, delta)
		if not _is_attacking():
			_play_walk_anim(dir)
	else:
		_play_idle_anim()


func _face(target_pos: Vector2) -> void:
	var d: Vector2 = target_pos - global_position
	if d.length_squared() > 0.001:
		last_direction = d.normalized()


func _is_attacking() -> bool:
	return str(anim.animation).begins_with("attack")


func _play_attack_anim() -> void:
	var name: String
	if abs(last_direction.x) > abs(last_direction.y):
		name = "attackRight" if last_direction.x > 0 else "attackLeft"
	else:
		name = "attackDown" if last_direction.y > 0 else "attackUp"
	if str(anim.animation) != name:
		anim.play(name)


func _play_walk_anim(dir: Vector2) -> void:
	if _is_attacking():
		return
	var name: String
	if abs(dir.x) > abs(dir.y):
		name = "walkRight" if dir.x > 0 else "walkLeft"
	else:
		name = "walkDown" if dir.y > 0 else "walkUp"
	if str(anim.animation) != name or not anim.is_playing():
		anim.play(name)


func _play_idle_anim() -> void:
	var name: String
	if abs(last_direction.x) > abs(last_direction.y):
		name = "idleRight" if last_direction.x > 0 else "idleLeft"
	else:
		name = "idleDown" if last_direction.y > 0 else "idleUp"
	if str(anim.animation) != name or _is_attacking():
		anim.play(name)
