extends Path2D

const ENEMY_SCENE = preload("res://scenes/enemies/enemy.tscn")

# Preload all enemy data resources
const GOBLIN_DATA = preload("res://resources/enemies/goblin.tres")
const ORC_DATA    = preload("res://resources/enemies/orc.tres")
const TROLL_DATA  = preload("res://resources/enemies/troll.tres")

# Define the wave: list of EnemyData resources in spawn order
var wave: Array = [
	GOBLIN_DATA,
	GOBLIN_DATA,
	GOBLIN_DATA,
	GOBLIN_DATA,
	GOBLIN_DATA,
	GOBLIN_DATA,
	GOBLIN_DATA,
	GOBLIN_DATA,
	GOBLIN_DATA,
	GOBLIN_DATA,
]

@onready var timer: Timer = $Timer
var spawned = 0


func _ready() -> void:
	add_to_group("level_path")
	timer.wait_time = 0.3
	timer.timeout.connect(_on_timer_timeout)
	timer.start()


func _on_timer_timeout() -> void:
	if spawned >= wave.size():
		timer.stop()
		return
	var follow = PathFollow2D.new()
	follow.rotates = false
	follow.loop = false
	add_child(follow)
	var enemy_instance = ENEMY_SCENE.instantiate()
	follow.add_child(enemy_instance)     # _ready() runs here first
	enemy_instance.data = wave[spawned]  # set AFTER so _ready+@onready vars are ready
	spawned += 1
