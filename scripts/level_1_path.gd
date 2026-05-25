extends Path2D

var enemy = preload("res://scenes/helpers/Enemy.tscn")
@onready var timer: Timer = $Timer

var wave_count = 5
var spawned = 0

func _ready() -> void:
	print("Spawner ready, starting timer")
	timer.wait_time = 1.0
	timer.timeout.connect(_on_timer_timeout)
	timer.start()

func _on_timer_timeout() -> void:
	if spawned >= wave_count:
		timer.stop()
		return
	var follow = PathFollow2D.new()
	follow.rotates = false
	follow.loop = false
	add_child(follow)
	var enemy_instance = enemy.instantiate()
	follow.add_child(enemy_instance)
	spawned += 1
