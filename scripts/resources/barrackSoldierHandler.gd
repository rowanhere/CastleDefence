extends CharacterBody2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var attack_collision: CollisionShape2D = $AttackArea/AttackCollision
@onready var health_bar: ProgressBar = $HealthBar

var speed = 60.0
var target: Node2D = null
var home: Vector2 = Vector2.ZERO
var last_direction: Vector2 = Vector2.RIGHT
var wait_position: Vector2 = Vector2.ZERO
var soldier_index: int = 0

var current_enemy: Node2D = null
var is_attacking = false
var attack_damage = 10.0
var attack_speed = 1.0
var attack_timer = 0.0

var is_dead = false
var hp = 100

func _ready():
	add_to_group("soldier")
	attack_area.body_entered.connect(_on_enemy_entered)
	attack_area.body_exited.connect(_on_enemy_exited)
	health_bar.max_value = hp
	health_bar.value = hp
	call_deferred("find_wait_position")

func find_wait_position():
	var path = get_tree().get_nodes_in_group("level_path")
	if path.size() > 0:
		var path2d = path[0]
		var closest = path2d.curve.get_closest_point(path2d.to_local(global_position))
		var base_pos = path2d.to_global(closest)
		wait_position = base_pos + Vector2(soldier_index * 40, 0)
	else:
		wait_position = home + Vector2(soldier_index * 20, 0)

func _on_enemy_entered(body):
	if body.is_in_group("enemies") and not body.is_dead:
		current_enemy = body
		body.is_stopped = true
		body.set_soldier(self)
		is_attacking = true

func _on_enemy_exited(body):
	if body.is_in_group("enemies"):
		if is_instance_valid(body):
			body.is_stopped = false
		current_enemy = null
		is_attacking = false

func take_damage(amount: float) -> void:
	if is_dead:
		return
	hp -= amount
	health_bar.value = hp
	if hp <= 0:
		die()

func die():
	if is_dead:
		return
	is_dead = true
	health_bar.hide()
	queue_free()

func _process(delta):
	if is_dead:
		return
	if is_attacking and (not is_instance_valid(current_enemy) or current_enemy.is_dead):
		is_attacking = false
		current_enemy = null
	if is_attacking and is_instance_valid(current_enemy):
		velocity = Vector2.ZERO
		play_attack_animation()
		attack_timer -= delta
		if attack_timer <= 0.0:
			attack_timer = attack_speed
			current_enemy.take_damage(attack_damage)
	elif target and is_instance_valid(target):
		var direction = (target.global_position - global_position).normalized()
		last_direction = direction
		velocity = direction * speed
		move_and_slide()
		play_walk_animation(direction)
	else:
		var distance = global_position.distance_to(wait_position)
		if distance > 40.0:
			var direction = (wait_position - global_position).normalized()
			last_direction = direction
			velocity = direction * speed
			move_and_slide()
			play_walk_animation(direction)
		else:
			velocity = Vector2.ZERO
			play_idle_animation()

func play_attack_animation():
	if abs(last_direction.x) > abs(last_direction.y):
		if last_direction.x > 0:
			anim.play("attackRight")
		else:
			anim.play("attackLeft")
	else:
		if last_direction.y > 0:
			anim.play("attackDown")
		else:
			anim.play("attackUp")

func play_walk_animation(direction: Vector2):
	if abs(direction.x) > abs(direction.y):
		if direction.x > 0:
			anim.play("walkRight")
		else:
			anim.play("walkLeft")
	else:
		if direction.y > 0:
			anim.play("walkDown")
		else:
			anim.play("walkUp")

func play_idle_animation():
	if abs(last_direction.x) > abs(last_direction.y):
		if last_direction.x > 0:
			anim.play("idleRight")
		else:
			anim.play("idleLeft")
	else:
		if last_direction.y > 0:
			anim.play("idleDown")
		else:
			anim.play("idleUp")
