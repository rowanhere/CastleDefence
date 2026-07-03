extends Resource
class_name EnemySpawnSchedule

const ENEMY_SPAWN_WAVE_SCRIPT = preload("res://scripts/gameplay/enemy_spawn_wave.gd")

@export var waves: Array[Resource] = [
	_create_wave(15.0, ["goblin"], 10, false),
	_create_wave(45.0, ["goblin"], 15, false),
	_create_wave(75.0, ["orc"], 5, false),
	_create_wave(105.0, ["orc", "goblin"], 10, false),
	_create_wave(135.0, ["goblin"], 1, true)
]


static func _create_wave(start_time: float, enemy_pool: Array[String], total_multiplier: int, is_boss_wave: bool) -> Resource:
	var wave: Resource = ENEMY_SPAWN_WAVE_SCRIPT.new()
	wave.start_time = start_time
	wave.enemy_pool = enemy_pool
	wave.total_multiplier = total_multiplier
	wave.is_boss_wave = is_boss_wave
	return wave
