extends Area2D

var speed = 200.0
var damage = 25.0
var target: Node2D = null
var hit_sound: AudioStream = preload("res://assets/images/towerPlaceHolder/arrowHit.mp3")

func _ready():
	monitoring = true
	body_entered.connect(_on_body_entered)
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(self):
		queue_free()

func _process(delta):
	if is_instance_valid(target):
		var direction = (target.global_position - global_position).normalized()
		rotation = direction.angle()
		position += direction * speed * delta
	else:
		queue_free()

func _on_body_entered(body):
	if body.is_in_group("enemies") and not body.is_dead:
		body.take_damage(damage)
		GameSound.play(hit_sound)
		queue_free()
