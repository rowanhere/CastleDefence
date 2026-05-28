extends CharacterBody2D

@onready var health_bar: ProgressBar = $HealthBar
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var speed = 80.0
var hp = 100
var is_dead = false


func _ready():
	add_to_group("enemies")
	health_bar.max_value = hp
	health_bar.value = hp


func _process(delta):
	if is_dead:
		return

	# Always keep moving
	get_parent().progress += speed * delta

	# Return to walk when hurt animation finishes
	if anim.animation == "hurt" and not anim.is_playing():
		anim.play("walk")

	# Play walk animation normally
	if anim.animation != "hurt" and anim.animation != "die":
		anim.play("walk")

	# Flip sprite according to direction
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

	# Play hurt animation (once)
	anim.play("hurt")


func die():
	if is_dead:
		return
	is_dead = true
	health_bar.hide()
	anim.play("die")
	await anim.animation_finished
	queue_free()


func reach_castle():
	die()
