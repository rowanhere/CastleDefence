extends Node2D
class_name GameHandler

const DAMAGE_NUMBER_SCENE := preload("res://scenes/enemies/DamageNumber.tscn")

static var queued_level: int = 1
static var coins: int = 5000
static var castle_life: int = 100
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

# Boss formulas can live here later once boss data/resources are added.
# const BOSS_HEALTH_SCALE_PER_LEVEL := 0.35
# const BOSS_DAMAGE_SCALE_PER_LEVEL := 0.18
# const BOSS_SPEED_SCALE_PER_LEVEL := 0.04
# const BOSS_COIN_SCALE_PER_LEVEL := 0.30

@onready var level_container: Node2D = $LevelContainer
@onready var game_hud: CanvasLayer = $GameHUD

func _ready() -> void:
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
		# Uncomment and tune once boss enemies are added.
		# scaled_data.health = int(round(base_data.health * (1.0 + level_offset * BOSS_HEALTH_SCALE_PER_LEVEL)))
		# scaled_data.attack_damage = base_data.attack_damage * (1.0 + level_offset * BOSS_DAMAGE_SCALE_PER_LEVEL)
		# scaled_data.speed = base_data.speed * min(1.0 + level_offset * BOSS_SPEED_SCALE_PER_LEVEL, MAX_SPEED_SCALE)
		# scaled_data.coin_drop = int(round(base_data.coin_drop * (1.0 + level_offset * BOSS_COIN_SCALE_PER_LEVEL)))
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
	castle_life = maxi(castle_life - maxi(amount, 0), 0)
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var handler := tree.current_scene
	if handler != null and handler.has_method("_update_hud"):
		handler._update_hud()


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


func handle_boss_defeated() -> void:
	print("Boss defeated. Level complete.")
