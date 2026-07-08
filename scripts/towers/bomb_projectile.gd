extends Area2D

var damage: float = 25.0
var target: Node2D = null

const ASCENT_SPEED: float = 1550.0
const INITIAL_HORIZONTAL_SPEED: float = 10.0
const GRAVITY: float = 1325.0
const HORIZONTAL_STEER_DELAY: float = 0.42
const HORIZONTAL_STEER_STRENGTH: float = 2.6
const MAX_HORIZONTAL_SPEED: float = 520.0
const IMPACT_DISTANCE: float = 18.0
const SPRITE_UP_ROTATION_OFFSET: float = -PI * 0.5
const ROTATION_SMOOTHNESS: float = 12.0
const ENEMY_COLLISION_MASK: int = 1
const IMPACT_SOUND: AudioStream = preload("res://assets/audio/sfx/bombImpact.mp3")
const IMPACT_SOUND_VOLUME := -1.5

@onready var projectile_sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var explosion: AnimatedSprite2D = $Explosion

var _target_position: Vector2 = Vector2.ZERO
var _velocity: Vector2 = Vector2.ZERO
var _elapsed: float = 0.0
var _has_impacted: bool = false
var _is_configured: bool = false


func _ready() -> void:
	if projectile_sprite != null:
		projectile_sprite.visible = true
	if explosion != null:
		explosion.visible = false
	monitoring = true
	body_entered.connect(_on_body_entered)
	if not _is_configured:
		_configure_launch(global_position, target, damage)
	await get_tree().create_timer(5.0).timeout
	if is_instance_valid(self):
		queue_free()


func _process(delta: float) -> void:
	if _has_impacted:
		return

	_elapsed += delta
	if is_instance_valid(target):
		_target_position = target.global_position

	if _elapsed >= HORIZONTAL_STEER_DELAY:
		var horizontal_error: float = _target_position.x - global_position.x
		var steer_target: float = clampf(horizontal_error * HORIZONTAL_STEER_STRENGTH, -MAX_HORIZONTAL_SPEED, MAX_HORIZONTAL_SPEED)
		_velocity.x = move_toward(_velocity.x, steer_target, MAX_HORIZONTAL_SPEED * delta)

	_velocity.y += GRAVITY * delta
	global_position += _velocity * delta

	if _velocity.length_squared() > 0.001:
		var target_rotation: float = _velocity.angle() + SPRITE_UP_ROTATION_OFFSET
		rotation = lerp_angle(rotation, target_rotation, clampf(delta * ROTATION_SMOOTHNESS, 0.0, 1.0))

	if global_position.distance_to(_target_position) <= IMPACT_DISTANCE or (_velocity.y > 0.0 and global_position.y >= _target_position.y):
		_impact_target()


func _on_body_entered(body: Node2D) -> void:
	if _has_impacted:
		return
	if _velocity.y <= 0.0:
		return
	if body.is_in_group("enemies") and body.get("is_dead") != true:
		_impact_target()


func _get_target_position() -> Vector2:
	if is_instance_valid(target):
		return target.global_position
	return global_position


func setup_launch(launch_position: Vector2, launch_target: Node2D, launch_damage: float) -> void:
	_configure_launch(launch_position, launch_target, launch_damage)


func _configure_launch(launch_position: Vector2, launch_target: Node2D, launch_damage: float) -> void:
	if projectile_sprite != null:
		projectile_sprite.visible = true
	if explosion != null:
		explosion.visible = false
	global_position = launch_position
	target = launch_target
	damage = launch_damage
	_target_position = _get_target_position()
	_elapsed = 0.0
	_has_impacted = false
	_is_configured = true

	var horizontal_direction: float = signf(_target_position.x - global_position.x)
	if is_zero_approx(horizontal_direction):
		horizontal_direction = 1.0
	_velocity = Vector2(INITIAL_HORIZONTAL_SPEED * horizontal_direction, -ASCENT_SPEED)
	rotation = _velocity.angle() + SPRITE_UP_ROTATION_OFFSET


func _impact_target() -> void:
	_has_impacted = true
	GameSound.play(IMPACT_SOUND, IMPACT_SOUND_VOLUME)
	var enemies_in_blast: Array[Node2D] = _get_enemies_in_blast()
	for body: Node2D in enemies_in_blast:
		if body.get("is_dead") != true:
			body.take_damage(damage)
	await _play_explosion()
	queue_free()


func _play_explosion() -> void:
	set_deferred("monitoring", false)
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	if projectile_sprite != null:
		projectile_sprite.visible = false
	if explosion == null:
		return
	explosion.visible = true
	explosion.rotation = -rotation
	explosion.frame = 0
	explosion.play("explode")
	await explosion.animation_finished


func _get_enemies_in_blast() -> Array[Node2D]:
	var shape := CircleShape2D.new()
	shape.radius = _get_blast_radius()

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = ENEMY_COLLISION_MASK
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var enemies: Array[Node2D] = []
	var seen: Dictionary = {}
	var results: Array[Dictionary] = get_world_2d().direct_space_state.intersect_shape(query)
	for result: Dictionary in results:
		var body: Node2D = result.get("collider") as Node2D
		if body == null or not is_instance_valid(body):
			continue
		if not body.is_in_group("enemies") or body.get("is_dead") == true:
			continue
		if seen.has(body.get_instance_id()):
			continue
		seen[body.get_instance_id()] = true
		enemies.append(body)

	return enemies


func _get_blast_radius() -> float:
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		var circle_shape := collision_shape.shape as CircleShape2D
		return circle_shape.radius
	return 44.6
