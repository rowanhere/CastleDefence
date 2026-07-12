extends Node2D

const ANIMATIONS: Array[StringName] = [
	&"idleDown", &"idleUp", &"idleLeft", &"idleRight",
	&"walkDown", &"walkUp", &"walkLeft", &"walkRight",
	&"runDown", &"runUp", &"runLeft", &"runRight",
	&"attackDown", &"attackUp", &"attackLeft", &"attackRight",
	&"hurtDown", &"hurtUp", &"hurtLeft", &"hurtRight",
	&"dieDown", &"dieUp", &"dieLeft", &"dieRight"
]

@onready var sprite: AnimatedSprite2D = $Boss/AnimatedSprite2D
@onready var animation_label: Label = $AnimationLabel
@onready var timer: Timer = $AnimationTimer

var animation_index := 0


func _ready() -> void:
	timer.timeout.connect(_show_next_animation)
	_play_current_animation()


func _show_next_animation() -> void:
	animation_index = (animation_index + 1) % ANIMATIONS.size()
	_play_current_animation()


func _play_current_animation() -> void:
	var animation_name: StringName = ANIMATIONS[animation_index]
	animation_label.text = str(animation_name)
	sprite.play(animation_name)
