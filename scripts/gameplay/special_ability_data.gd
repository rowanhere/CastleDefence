extends Resource
class_name SpecialAbilityData

@export var ability_id: StringName
@export var damage: float = 100.0
@export var sprite_frames: SpriteFrames
@export var animation_name: StringName = &"special"
@export var effect_scale: Vector2 = Vector2.ONE
@export var effect_offset: Vector2 = Vector2.ZERO
@export_range(1, 8, 1) var visual_instances: int = 1
@export_range(0.0, 200.0, 1.0) var visual_spread: float = 0.0
@export_range(0.0, 1.0, 0.01) var visual_stagger: float = 0.0
@export var sound: AudioStream
