extends Resource
class_name SpecialAbilityData

@export var ability_id: StringName
@export var damage: float = 100.0
@export var sprite_frames: SpriteFrames
@export var animation_name: StringName = &"special"
@export var sync_animation_to_effect_duration: bool = true
@export var effect_scale: Vector2 = Vector2.ONE
@export var effect_offset: Vector2 = Vector2.ZERO
@export_range(1, 8, 1) var visual_instances: int = 1
@export_range(0.0, 200.0, 1.0) var visual_spread: float = 0.0
@export_range(0.0, 1.0, 0.01) var visual_stagger: float = 0.0
@export var enter_from_screen_top: bool = false
@export var anchor_to_screen_top: bool = false
@export_range(0.1, 2.0, 0.05) var entry_duration: float = 0.6
@export_range(0.0, 300.0, 1.0) var screen_entry_margin: float = 80.0
@export var sound: AudioStream
