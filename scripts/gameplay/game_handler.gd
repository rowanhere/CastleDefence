extends Node2D
class_name GameHandler

const DAMAGE_NUMBER_SCENE := preload("res://scenes/enemies/DamageNumber.tscn")
const WAVE_POINTER_SCENE := preload("res://scenes/gameplay/wavePointer.tscn")
const WAVE_POINTER_SCREEN_MARGIN := 96.0
const WAVE_POINTER_ARROW_DISTANCE := 62.0
const WAVE_POINTER_ARROW_SCALE := Vector2(1.35, 1.25)
const WAVE_POINTER_BASE_SCALE := Vector2(0.62, 0.62)
const WAVE_POINTER_PULSE_SCALE := Vector2(0.70, 0.70)

static var queued_level: int = 1
const LEVEL_STARTING_COINS := 5000

static var coins: int = LEVEL_STARTING_COINS
static var castle_life: int = 100
static var level_failed: bool = false
static var level_won: bool = false
static var _enemy_data_cache: Dictionary = {}
const HEALTH_SCALE_PER_LEVEL := 0.20
const DAMAGE_SCALE_PER_LEVEL := 0.12
const SPEED_SCALE_PER_LEVEL := 0.03
const COIN_SCALE_PER_LEVEL := 0.15
const HEALTH_SCALE_PER_WAVE := 0.12
const DAMAGE_SCALE_PER_WAVE := 0.08
const SPEED_SCALE_PER_WAVE := 0.015
const COIN_SCALE_PER_WAVE := 0.08
const MAX_SPEED_SCALE := 1.35
const THREE_STAR_LIFE_THRESHOLD := 75
const TWO_STAR_LIFE_THRESHOLD := 40

const BOSS_HEALTH_SCALE_PER_LEVEL := 0.35
const BOSS_DAMAGE_SCALE_PER_LEVEL := 0.18
const BOSS_SPEED_SCALE_PER_LEVEL := 0.04

@onready var level_container: Node2D = $LevelContainer
@onready var game_hud: CanvasLayer = $GameHUD

var _wave_pointer: Node2D = null
var _wave_pointer_tween: Tween = null

func _ready() -> void:
	coins = LEVEL_STARTING_COINS
	castle_life = 100
	level_failed = false
	level_won = false

	if AudioController.has_method("play_random_game_music"):
		AudioController.play_random_game_music()

	var path: String = get_level_scene_path(queued_level)
	var packed: PackedScene = load(path)
	if packed == null:
		push_error("GameHandler: failed to load level %d" % queued_level)
		return
	level_container.add_child(packed.instantiate())
	_update_hud()


static func get_level_scene_path(level_number: int) -> String:
	return "res://scenes/levels/level%d/level_%d.tscn" % [level_number, level_number]


static func get_level_spawn_schedule_path(level_number: int) -> String:
	return "res://scenes/levels/level%d/level%d_spawn.tres" % [level_number, level_number]


static func get_enemy_data_by_id(enemy_id: String) -> EnemyData:
	var normalized_id: String = enemy_id.strip_edges().to_lower()
	if normalized_id.is_empty():
		return null
	if _enemy_data_cache.has(normalized_id):
		return _enemy_data_cache[normalized_id]

	var enemy_path: String = "res://resources/enemies/%s.tres" % normalized_id
	var enemy_data = load(enemy_path)
	if enemy_data == null:
		push_warning("GameHandler: failed to load enemy data at %s" % enemy_path)
		return null

	_enemy_data_cache[normalized_id] = enemy_data
	return enemy_data


static func get_scaled_enemy_data(base_data: EnemyData, level_number: int, wave_number: int = 1, is_boss: bool = false) -> EnemyData:
	var scaled_data: EnemyData = base_data.duplicate(true)
	var level_offset: int = max(level_number - 1, 0)
	var wave_offset: int = max(wave_number - 1, 0)

	if is_boss:
		var boss_health_scale: float = 1.0 + level_offset * BOSS_HEALTH_SCALE_PER_LEVEL
		var boss_damage_scale: float = 1.0 + level_offset * BOSS_DAMAGE_SCALE_PER_LEVEL
		var boss_speed_scale: float = minf(1.0 + level_offset * BOSS_SPEED_SCALE_PER_LEVEL, MAX_SPEED_SCALE)
		scaled_data.health = int(round(base_data.health * boss_health_scale))
		scaled_data.attack_damage = base_data.attack_damage * boss_damage_scale
		scaled_data.speed = base_data.speed * boss_speed_scale
		scaled_data.coin_drop = 0
		return scaled_data

	var health_scale: float = 1.0 + level_offset * HEALTH_SCALE_PER_LEVEL + wave_offset * HEALTH_SCALE_PER_WAVE
	var damage_scale: float = 1.0 + level_offset * DAMAGE_SCALE_PER_LEVEL + wave_offset * DAMAGE_SCALE_PER_WAVE
	var speed_scale: float = minf(1.0 + level_offset * SPEED_SCALE_PER_LEVEL + wave_offset * SPEED_SCALE_PER_WAVE, MAX_SPEED_SCALE)
	var coin_scale: float = 1.0 + level_offset * COIN_SCALE_PER_LEVEL + wave_offset * COIN_SCALE_PER_WAVE

	scaled_data.health = int(round(base_data.health * health_scale))
	scaled_data.attack_damage = base_data.attack_damage * damage_scale
	scaled_data.speed = base_data.speed * speed_scale
	scaled_data.coin_drop = int(round(base_data.coin_drop * coin_scale))
	return scaled_data


static func add_coins(amount: int) -> void:
	coins += amount
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var handler := tree.current_scene
	if handler != null and handler.has_method("_update_hud"):
		handler._update_hud()


static func damage_castle(amount: int = 1) -> void:
	if level_failed or level_won:
		return
	castle_life = maxi(castle_life - maxi(amount, 0), 0)
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var handler := tree.current_scene
	if handler != null and handler.has_method("_update_hud"):
		handler._update_hud()
	if castle_life <= 0 and not level_failed:
		level_failed = true
		if handler != null and handler.has_method("_show_level_failed"):
			handler._show_level_failed()


static func complete_level() -> void:
	if level_failed or level_won or castle_life <= 0:
		return
	level_won = true
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var star_count: int = _get_star_count_for_life(castle_life)
	var save_manager: Node = tree.root.get_node_or_null("SaveManager")
	if save_manager != null and save_manager.has_method("complete_level"):
		save_manager.call("complete_level", queued_level, star_count, star_count)
	var handler := tree.current_scene
	if handler != null and handler.has_method("_show_level_won"):
		handler._show_level_won()


static func _get_star_count_for_life(life: int) -> int:
	if life >= THREE_STAR_LIFE_THRESHOLD:
		return 3
	if life >= TWO_STAR_LIFE_THRESHOLD:
		return 2
	return 1


static func play_purchase_failed_feedback() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var handler := tree.current_scene
	if handler == null:
		return
	var hud = handler.get_node_or_null("GameHUD")
	if hud != null and hud.has_method("play_purchase_failed_feedback"):
		hud.play_purchase_failed_feedback()


static func show_floating_message(world_position: Vector2, text: String, color: Color = Color(1.0, 0.25, 0.25), font_size: int = 15) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var handler := tree.current_scene
	if handler == null:
		return
	var popup := DAMAGE_NUMBER_SCENE.instantiate()
	handler.add_child(popup)
	popup.global_position = world_position
	popup.text = text
	popup.velocity = Vector2(randf_range(-12, 12), -64)
	popup.lifetime = 1.1
	popup.add_theme_font_size_override("font_size", font_size)
	popup.add_theme_color_override("font_color", color)




func _update_hud() -> void:
	if game_hud == null:
		return
	game_hud.set_life(castle_life, false)
	game_hud.set_coins(coins, false)


func _show_level_failed() -> void:
	if game_hud == null:
		return
	if game_hud.has_method("show_level_failed"):
		game_hud.show_level_failed()


func _show_level_won() -> void:
	if game_hud == null:
		return
	if game_hud.has_method("show_level_won"):
		game_hud.show_level_won(_get_level_star_count())


func _get_level_star_count() -> int:
	if castle_life >= THREE_STAR_LIFE_THRESHOLD:
		return 3
	if castle_life >= TWO_STAR_LIFE_THRESHOLD:
		return 2
	return 1


func update_wave_status(current_wave: int, total_waves: int, progress_ratio: float) -> void:
	if game_hud == null:
		return
	game_hud.set_current_wave(current_wave, false)
	game_hud.set_total_waves(total_waves, false)
	game_hud.set_wave_progress(progress_ratio)


func update_wave_labels(current_wave: int, total_waves: int) -> void:
	if game_hud == null:
		return
	game_hud.set_current_wave(current_wave, false)
	game_hud.set_total_waves(total_waves, false)


func clear_wave_alert() -> void:
	if game_hud == null:
		return
	game_hud.clear_wave_alert()
	hide_wave_pointer()


func show_wave_pointer(world_position: Vector2, path_direction: Vector2 = Vector2.RIGHT) -> void:
	if _wave_pointer == null or not is_instance_valid(_wave_pointer):
		_wave_pointer = WAVE_POINTER_SCENE.instantiate() as Node2D
		level_container.add_child(_wave_pointer)
		_wave_pointer.z_as_relative = false
		_wave_pointer.z_index = 4095

	var display_position := _get_wave_pointer_display_position(world_position)
	_wave_pointer.global_position = display_position
	_wave_pointer.visible = true
	_wave_pointer.modulate.a = 1.0
	_wave_pointer.scale = WAVE_POINTER_BASE_SCALE

	var arrow := _wave_pointer.get_node_or_null("waveArrow") as Sprite2D
	if arrow != null:
		var arrow_direction := world_position - display_position
		if arrow_direction.length_squared() <= 0.001:
			arrow_direction = -path_direction
		if arrow_direction.length_squared() <= 0.001:
			arrow_direction = Vector2.DOWN
		arrow_direction = arrow_direction.normalized()
		arrow.position = arrow_direction * WAVE_POINTER_ARROW_DISTANCE
		arrow.rotation = arrow_direction.angle()
		arrow.scale = WAVE_POINTER_ARROW_SCALE

	if _wave_pointer_tween != null and _wave_pointer_tween.is_valid():
		_wave_pointer_tween.kill()
	_wave_pointer_tween = create_tween().set_loops()
	_wave_pointer_tween.tween_property(_wave_pointer, "scale", WAVE_POINTER_PULSE_SCALE, 0.35).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_wave_pointer_tween.tween_property(_wave_pointer, "scale", WAVE_POINTER_BASE_SCALE, 0.35).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func hide_wave_pointer() -> void:
	if _wave_pointer_tween != null and _wave_pointer_tween.is_valid():
		_wave_pointer_tween.kill()
	_wave_pointer_tween = null
	if _wave_pointer != null and is_instance_valid(_wave_pointer):
		_wave_pointer.visible = false


func _get_wave_pointer_display_position(world_position: Vector2) -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return world_position

	var viewport_rect := viewport.get_visible_rect()
	var inverse_canvas_transform := viewport.get_canvas_transform().affine_inverse()
	var top_left := inverse_canvas_transform * viewport_rect.position
	var bottom_right := inverse_canvas_transform * (viewport_rect.position + viewport_rect.size)
	var visible_world_rect := Rect2(top_left, bottom_right - top_left).abs()

	return Vector2(
		clampf(world_position.x, visible_world_rect.position.x + WAVE_POINTER_SCREEN_MARGIN, visible_world_rect.end.x - WAVE_POINTER_SCREEN_MARGIN),
		clampf(world_position.y, visible_world_rect.position.y + WAVE_POINTER_SCREEN_MARGIN, visible_world_rect.end.y - WAVE_POINTER_SCREEN_MARGIN)
	)


func handle_boss_defeated() -> void:
	print("Boss defeated. Level complete.")
