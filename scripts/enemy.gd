extends CharacterBody2D

@onready var health_bar: ProgressBar = $HealthBar
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var attack_collision: CollisionShape2D = $AttackArea/attackCollision

var speed = 80.0
var hp = 100
var is_dead = false
var is_stopped = false
var attack_damage = 8.0
var attack_speed = 1.2
var attack_timer = 0.0
var current_soldier: Node2D = null

func _ready():
	add_to_group("enemies")
	health_bar.max_value = hp
	health_bar.value = hp
	attack_area.body_entered.connect(_on_soldier_entered)
	attack_area.body_exited.connect(_on_soldier_exited)

func _on_soldier_entered(body):
	if body.is_in_group("soldier") and not body.is_dead:
		current_soldier = body

func _on_soldier_exited(body):
	if body.is_in_group("soldier"):
		current_soldier = null
func _process(delta):
	if is_dead:
		return
	if is_stopped:
		velocity = Vector2.ZERO
		move_and_slide()
		if anim.animation != "attack" and anim.animation != "hurt":
			anim.play("attack")
		if is_instance_valid(current_soldier) and not current_soldier.is_dead:
			attack_timer -= delta
			if attack_timer <= 0.0:
				attack_timer = attack_speed
				current_soldier.take_damage(attack_damage)
		return
	get_parent().progress += speed * delta
	if anim.animation == "hurt" and not anim.is_playing():
		anim.play("walk")
	if anim.animation != "hurt" and anim.animation != "die":
		anim.play("walk")
	var forward = get_parent().transform.x
	anim.flip_h = forward.x < 0
	if get_parent().progress_ratio >= 1.0:
		reach_castle()
func take_damage(amount: float) -> void:
	if is_dead:
		return
	hp -= amount
	health_bar.value = hp
	if hp <= 0:
		die()
		return
	# only play hurt if not currently attacking
	if not is_stopped:
		anim.play("hurt")

func set_soldier(soldier: Node2D) -> void:
	current_soldier = soldier

func die():
	if is_dead:
		return
	is_dead = true
	is_stopped = false
	health_bar.hide()
	anim.play("die")
	await anim.animation_finished
	queue_free()

func reach_castle():
	die()
