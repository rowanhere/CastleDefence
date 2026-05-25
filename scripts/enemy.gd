extends CharacterBody2D

@onready var anim = $AnimatedSprite2D
var speed = 80.0
var hp = 100
var is_dead = false

func _ready():
	add_to_group("enemies")

func _process(delta):
	if is_dead:
		return
	get_parent().progress += speed * delta
	anim.play("walk")
	var forward = get_parent().transform.x
	anim.flip_h = forward.x < 0
	if get_parent().progress_ratio >= 1.0:
		reach_castle()

func take_damage(amount):
	hp -= amount
	if hp <= 0:
		die()

func die():
	queue_free()

func reach_castle():
	is_dead = true
	anim.play("die")
	await anim.animation_finished
	get_parent().queue_free()
