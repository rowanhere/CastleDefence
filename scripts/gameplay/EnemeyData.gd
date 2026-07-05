extends Resource
class_name EnemyData

@export var enemy_name: String = ""
@export var health: int = 100
@export var speed: float = 80.0
@export var attack_damage: float = 12.0
@export var attack_speed: float = 1.0
@export var coin_drop: int = 10
@export var path_spacing: float = 28.0
@export var health_bar_color: Color = Color(0.11655869, 0.075290434, 0.32217935, 1.0)
@export var sprite_frames: SpriteFrames
@export var scale: Vector2 = Vector2(1.0, 1.0)
