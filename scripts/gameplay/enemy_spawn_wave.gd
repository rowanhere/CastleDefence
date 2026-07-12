extends Resource
class_name EnemySpawnWave

@export var start_time: float = 15.0
@export_enum("goblin", "gnoll", "imp", "mushroom", "demon", "zombie", "predator", "lizardman", "beholder", "golem", "boss") var enemy_pool: Array[String] = ["goblin"]
@export var total_multiplier: int = 10
@export var is_boss_wave: bool = false
