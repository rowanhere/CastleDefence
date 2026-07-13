extends Node2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var _data: Resource = null
var _radius: float = 100.0
var _duration: float = 1.25


func configure(data: Resource, radius: float, duration: float) -> void:
	_data = data
	_radius = radius
	_duration = maxf(duration, 0.1)


func activate() -> void:
	if _data == null:
		queue_free()
		return
	_apply_aoe_damage()
	var sound: AudioStream = _data.get("sound") as AudioStream
	if sound != null:
		GameSound.play(sound, -4.0)
	var configured_frames: SpriteFrames = _data.get("sprite_frames") as SpriteFrames
	var animation_name: StringName = StringName(_data.get("animation_name"))
	if configured_frames == null or not configured_frames.has_animation(animation_name):
		get_tree().create_timer(_duration).timeout.connect(queue_free)
		return
	var offset_value: Variant = _data.get("effect_offset")
	var effect_offset: Vector2 = offset_value if offset_value is Vector2 else Vector2.ZERO
	var frame_texture: Texture2D = configured_frames.get_frame_texture(animation_name, 0)
	var texture_size: Vector2 = frame_texture.get_size() if frame_texture != null else Vector2.ZERO
	var final_scale: Vector2 = Vector2.ONE
	if texture_size.x > 0.0 and texture_size.y > 0.0:
		var diameter: float = _radius * 2.0
		var fit_factor: float = minf(diameter / texture_size.x, diameter / texture_size.y)
		var fitted_scale: Vector2 = Vector2.ONE * fit_factor
		var resource_scale_value: Variant = _data.get("effect_scale")
		var resource_scale: Vector2 = resource_scale_value if resource_scale_value is Vector2 else Vector2.ONE
		final_scale = fitted_scale * resource_scale
	var frame_count: int = configured_frames.get_frame_count(animation_name)
	var animation_fps: float = configured_frames.get_animation_speed(animation_name)
	var speed_scale: float = 1.0
	if animation_fps > 0.0:
		var source_duration: float = float(frame_count) / animation_fps
		speed_scale = source_duration / _duration
	var visual_instances: int = maxi(int(_data.get("visual_instances")), 1)
	var visual_spread: float = maxf(float(_data.get("visual_spread")), 0.0)
	var visual_stagger: float = maxf(float(_data.get("visual_stagger")), 0.0)
	for index in range(visual_instances):
		var visual: AnimatedSprite2D = sprite if index == 0 else AnimatedSprite2D.new()
		if index > 0:
			add_child(visual)
		visual.sprite_frames = configured_frames
		visual.centered = true
		visual.scale = final_scale
		visual.speed_scale = speed_scale
		var spread_offset: Vector2 = Vector2.ZERO
		if index > 0 and visual_spread > 0.0:
			spread_offset = Vector2.RIGHT.rotated(randf_range(0.0, TAU)) * randf_range(visual_spread * 0.55, visual_spread)
		visual.position = effect_offset + spread_offset
		var delay: float = visual_stagger * float(index)
		if delay <= 0.0:
			visual.play(animation_name)
		else:
			get_tree().create_timer(delay).timeout.connect(_play_visual.bind(visual, animation_name))
	get_tree().create_timer(_duration + visual_stagger * float(visual_instances - 1) + 0.05).timeout.connect(queue_free)


func _play_visual(visual: AnimatedSprite2D, animation_name: StringName) -> void:
	if visual != null and is_instance_valid(visual):
		visual.play(animation_name)


func _apply_aoe_damage() -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if "is_dead" in enemy and bool(enemy.get("is_dead")):
			continue
		if global_position.distance_to(enemy.global_position) <= _radius and enemy.has_method("take_damage"):
			enemy.call("take_damage", float(_data.get("damage")))
