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
	var configured_frames: SpriteFrames = _data.get("sprite_frames") as SpriteFrames
	var animation_name: StringName = StringName(_data.get("animation_name"))
	if configured_frames == null or not configured_frames.has_animation(animation_name):
		_trigger_impact()
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
	var sync_animation: bool = bool(_data.get("sync_animation_to_effect_duration"))
	if sync_animation and animation_fps > 0.0:
		var source_duration: float = float(frame_count) / animation_fps
		speed_scale = source_duration / _duration
	var visual_instances: int = maxi(int(_data.get("visual_instances")), 1)
	var visual_spread: float = maxf(float(_data.get("visual_spread")), 0.0)
	var visual_stagger: float = maxf(float(_data.get("visual_stagger")), 0.0)
	var enter_from_top: bool = bool(_data.get("enter_from_screen_top"))
	var entry_duration: float = maxf(float(_data.get("entry_duration")), 0.1)
	var entry_margin: float = maxf(float(_data.get("screen_entry_margin")), 0.0)
	if enter_from_top:
		get_tree().create_timer(entry_duration).timeout.connect(_trigger_impact)
	else:
		_trigger_impact()
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
		var landing_position: Vector2 = effect_offset + spread_offset
		var delay: float = visual_stagger * float(index)
		visual.visible = delay <= 0.0
		if delay <= 0.0:
			_launch_visual(visual, animation_name, landing_position, enter_from_top, entry_duration, entry_margin)
		else:
			get_tree().create_timer(delay).timeout.connect(
				_launch_visual.bind(visual, animation_name, landing_position, enter_from_top, entry_duration, entry_margin)
			)
	var effect_lifetime: float = _duration
	if enter_from_top:
		effect_lifetime = entry_duration
	get_tree().create_timer(effect_lifetime + visual_stagger * float(visual_instances - 1) + 0.05).timeout.connect(queue_free)


func _launch_visual(
	visual: AnimatedSprite2D,
	animation_name: StringName,
	landing_position: Vector2,
	enter_from_top: bool,
	entry_duration: float,
	entry_margin: float
) -> void:
	if visual == null or not is_instance_valid(visual):
		return
	visual.visible = true
	visual.position = landing_position
	var anchor_to_top: bool = bool(_data.get("anchor_to_screen_top"))
	if anchor_to_top:
		_anchor_visual_to_screen_top(visual, animation_name, landing_position, entry_margin)
		get_tree().create_timer(entry_duration).timeout.connect(_finish_visual.bind(visual))
	elif enter_from_top:
		visual.position = _get_screen_top_entry_position(landing_position, entry_margin)
		var entry_tween: Tween = create_tween()
		entry_tween.tween_property(visual, "position", landing_position, entry_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		entry_tween.tween_callback(_finish_visual.bind(visual))
	visual.play(animation_name)


func _finish_visual(visual: AnimatedSprite2D) -> void:
	if visual != null and is_instance_valid(visual):
		visual.hide()


func _anchor_visual_to_screen_top(
	visual: AnimatedSprite2D,
	animation_name: StringName,
	landing_position: Vector2,
	entry_margin: float
) -> void:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	var viewport_rect: Rect2 = viewport.get_visible_rect()
	var inverse_canvas_transform: Transform2D = viewport.get_canvas_transform().affine_inverse()
	var visible_top_left: Vector2 = inverse_canvas_transform * viewport_rect.position
	var landing_global_position: Vector2 = to_global(landing_position)
	var top_y: float = visible_top_left.y - entry_margin
	var bolt_height: float = maxf(landing_global_position.y - top_y, 1.0)
	var frame_texture: Texture2D = visual.sprite_frames.get_frame_texture(animation_name, 0)
	var texture_height: float = frame_texture.get_height() if frame_texture != null else 1.0
	visual.position = to_local(Vector2(landing_global_position.x, top_y + bolt_height * 0.5))
	visual.scale.y = bolt_height / maxf(texture_height, 1.0)


func _get_screen_top_entry_position(landing_position: Vector2, entry_margin: float) -> Vector2:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return landing_position + Vector2(0.0, -500.0)
	var viewport_rect: Rect2 = viewport.get_visible_rect()
	var inverse_canvas_transform: Transform2D = viewport.get_canvas_transform().affine_inverse()
	var visible_top_left: Vector2 = inverse_canvas_transform * viewport_rect.position
	var entry_global_position: Vector2 = to_global(landing_position)
	entry_global_position.y = visible_top_left.y - entry_margin
	return to_local(entry_global_position)


func _trigger_impact() -> void:
	if _data == null or not is_instance_valid(self):
		return
	_apply_aoe_damage()
	var sound: AudioStream = _data.get("sound") as AudioStream
	if sound != null:
		GameSound.play(sound, -4.0)


func _apply_aoe_damage() -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if "is_dead" in enemy and bool(enemy.get("is_dead")):
			continue
		if global_position.distance_to(enemy.global_position) <= _radius and enemy.has_method("take_damage"):
			enemy.call("take_damage", float(_data.get("damage")))
