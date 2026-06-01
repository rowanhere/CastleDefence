extends CharacterBody2D

@onready var health_bar: ProgressBar = $HealthBar
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea

var DamageNumber = preload("res://scenes/enemies/DamageNumber.tscn")

var speed = 80.0
var hp = 100
var is_dead = false
var attack_damage = 12.0
var attack_speed = 1.0
var attack_timer = 0.0
var locked_soldier: Node2D = null


func _ready() -> void:
	add_to_group("enemies")
	health_bar.max_value = hp
	health_bar.value = hp


func _other_scale(other: Node2D) -> float:
	if other == null or not is_instance_valid(other):
		return 1.0
	return other.scale.x


func _engage_range(other: Node2D) -> float:
	# Soldiers are scaled up; use the larger scale so melee actually connects.
	return 22.0 * max(scale.x, _other_scale(other)) + 14.0


func _disengage_range(other: Node2D) -> float:
	return _engage_range(other) * 1.35


func _is_valid_soldier(soldier) -> bool:
	if soldier == null:
		return false
	if not is_instance_valid(soldier):
		return false
	return soldier.is_in_group("soldier") and not soldier.is_dead


func _distance_to(other: Node2D) -> float:
	return global_position.distance_to(other.global_position)


func _soldier_in_attack_area() -> Node2D:
	for body in attack_area.get_overlapping_bodies():
		if _is_valid_soldier(body):
			return body
	return null


func _can_engage(soldier: Node2D) -> bool:
	if not _is_valid_soldier(soldier):
		return false
	if _distance_to(soldier) <= _engage_range(soldier):
		return true
	return _soldier_in_attack_area() == soldier


func _still_in_combat(soldier: Node2D) -> bool:
	if not _is_valid_soldier(soldier):
		return false
	return _distance_to(soldier) <= _disengage_range(soldier)


func _sanitize_lock() -> void:
	if locked_soldier != null and not is_instance_valid(locked_soldier):
		locked_soldier = null
	elif locked_soldier != null and not _is_valid_soldier(locked_soldier):
		locked_soldier = null


func _pick_combat_soldier() -> Node2D:
	var touch: Node2D = _soldier_in_attack_area()
	if touch:
		return touch
	var closest_soldier: Node2D = null
	var closest_distance: float = INF
	for node in get_tree().get_nodes_in_group("soldier"):
		if not _is_valid_soldier(node):
			continue
		var distance: float = _distance_to(node)
		var range_limit: float = _engage_range(node)
		if distance <= range_limit and distance < closest_distance:
			closest_distance = distance
			closest_soldier = node
	return closest_soldier


func _fight_soldier(soldier: Node2D, delta: float) -> void:
	locked_soldier = soldier
	velocity = Vector2.ZERO
	# Do not call move_and_slide — parent PathFollow2D handles position while walking.
	if anim.animation != "attack" and anim.animation != "hurt":
		anim.play("attack")
	attack_timer -= delta
	if attack_timer <= 0.0:
		attack_timer = attack_speed
		soldier.take_damage(attack_damage)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_sanitize_lock()

	var path_follow: PathFollow2D = get_parent() as PathFollow2D

	if locked_soldier != null and is_instance_valid(locked_soldier) and _still_in_combat(locked_soldier):
		_fight_soldier(locked_soldier, delta)
		return

	locked_soldier = null
	var new_soldier: Node2D = _pick_combat_soldier()
	if new_soldier:
		_fight_soldier(new_soldier, delta)
		return

	if path_follow == null:
		return

	# Only advance along the path when not in combat.
	path_follow.progress += speed * delta
	if anim.animation == "hurt" and not anim.is_playing():
		anim.play("walk")
	elif anim.animation != "hurt" and anim.animation != "die":
		anim.play("walk")

	var forward: Vector2 = path_follow.transform.x
	anim.flip_h = forward.x < 0

	if path_follow.progress_ratio >= 1.0:
		reach_castle()


func take_damage(amount: float) -> void:
	if is_dead:
		return
	hp -= amount
	health_bar.value = hp
	if hp <= 0:
		die()
		return
	if not _still_in_combat(locked_soldier):
		anim.play("hurt")
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


func die() -> void:
	if is_dead:
		return
	is_dead = true
	locked_soldier = null
	health_bar.hide()
	anim.play("die")
	await anim.animation_finished
	queue_free()


func reach_castle() -> void:
	die()
