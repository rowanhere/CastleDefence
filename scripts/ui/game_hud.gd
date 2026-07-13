extends CanvasLayer

const COUNT_ANIM_TIME := 0.35
const WAVE_PROGRESS_SAFE := Color(0.33, 0.74, 0.88, 0.55)
const WAVE_PROGRESS_WARN := Color(0.97, 0.72, 0.22, 0.65)
const WAVE_PROGRESS_DANGER := Color(0.93, 0.27, 0.35, 0.78)
const WAVE_ICON_SAFE := Color(1.0, 1.0, 1.0, 1.0)
const WAVE_ICON_WARN := Color(1.15, 0.88, 0.58, 1.0)
const WAVE_ICON_DANGER := Color(1.35, 0.45, 0.45, 1.0)
const WAVE_ICON_WIGGLE_SPEED := 18.0
const WAVE_ICON_WIGGLE_AMOUNT := 0.08
const WAVE_ICON_NORMAL_SCALE := Vector2(0.066, 0.066)
const COIN_ALERT_COLOR := Color(1.0, 0.35, 0.35, 1.0)
const COIN_NORMAL_COLOR := Color(1, 1, 1, 1)
const COIN_SHAKE_OFFSET := 12.0
const COIN_SHAKE_STEP := 0.045
const LEVEL_SELECTOR_SCENE := "res://scenes/ui/level.tscn"
const GAME_SCENE := "res://scenes/gameplay/GameHandler.tscn"
const TRANSITION_SCENE := "res://scenes/ui/scene_transition.tscn"
const SceneTransitionScript = preload("res://scripts/ui/scene_transition.gd")
const WIN_STAR_TEXTURES: Dictionary = {
	1: preload("res://assets/textures/levelWin/star_1.png"),
	2: preload("res://assets/textures/levelWin/star_2.png"),
	3: preload("res://assets/textures/levelWin/star_3.png")
}
const SPECIAL_ABILITIES_ENABLED := false # Turn true to show in-game special abilities again.
const THREE_STAR_LIFE_THRESHOLD := 75
const TWO_STAR_LIFE_THRESHOLD := 40

@onready var life_label: Label = $LevelData/PanelContainer/LifeNode/CoinsAmt
@onready var coin_label: Label = $LevelData/PanelContainer/CoinNode/CoinsAmt
@onready var current_wave_label: Label = $LevelData/PanelContainer/WaveNode/CurrentWave
@onready var total_wave_label: Label = $LevelData/PanelContainer/WaveNode/TotalWave
@onready var wave_progress: TextureProgressBar = $LevelData/WaveTextureProgress
@onready var wave_icon: Sprite2D = $LevelData/PanelContainer/WaveNode/Sprite2D
@onready var coin_node: Node2D = $LevelData/PanelContainer/CoinNode
@onready var menu_button: TextureButton = $MenuButton
@onready var pause_overlay: Control = $PauseOverlay
@onready var close_button: TextureButton = $PauseOverlay/Panel/CloseButton
@onready var back_button: TextureButton = $PauseOverlay/Panel/Buttons/BackButton
@onready var resume_button: TextureButton = $PauseOverlay/Panel/Buttons/ResumeButton
@onready var pause_restart_button: TextureButton = $PauseOverlay/Panel/Buttons/RestartButton
@onready var quit_button: TextureButton = $PauseOverlay/Panel/Buttons/QuitButton
@onready var level_failed_overlay: Control = $LevelFailedOverlay
@onready var failed_back_button: TextureButton = $LevelFailedOverlay/Panel/BackButton
@onready var failed_restart_button: TextureButton = $LevelFailedOverlay/Panel/RestartButton
@onready var level_win_overlay: Control = $LevelWinOverlay
@onready var win_next_button: TextureButton = $LevelWinOverlay/Panel/NextButton
@onready var win_star_rating: TextureRect = $LevelWinOverlay/Panel/StarRating
@onready var win_reward_label: Label = $LevelWinOverlay/Panel/RewardLabel
@onready var special_abilities_ui: Control = $SpecialAbilitiesUI
@onready var ability_target_blocker: Control = $AbilityTargetBlocker

var _label_values: Dictionary = {}
var _label_tweens: Dictionary = {}
var _wave_urgency_level: int = 0
var _wave_icon_base_position: Vector2 = Vector2.ZERO
var _wave_wiggle_time: float = 0.0
var _coin_base_position: Vector2 = Vector2.ZERO
var _coin_alert_tween: Tween = null
var _coin_alert_active: bool = false


func _ready() -> void:
	_cache_label_value(life_label)
	_cache_label_value(coin_label)
	_cache_label_value(current_wave_label)
	_cache_label_value(total_wave_label)
	if wave_progress != null:
		wave_progress.min_value = 0.0
		wave_progress.max_value = 100.0
		wave_progress.step = 0.0
		wave_progress.value = 0.0
		wave_progress.tint_progress = WAVE_PROGRESS_SAFE
	if wave_icon != null:
		_wave_icon_base_position = wave_icon.position
		wave_icon.modulate = WAVE_ICON_SAFE
		wave_icon.scale = WAVE_ICON_NORMAL_SCALE
	if coin_node != null:
		_coin_base_position = coin_node.position
	if coin_label != null:
		coin_label.modulate = COIN_NORMAL_COLOR
	_apply_special_ability_visibility()
	_setup_pause_menu()
	_setup_level_failed_menu()
	_setup_level_win_menu()


func _apply_special_ability_visibility() -> void:
	if special_abilities_ui != null:
		special_abilities_ui.visible = SPECIAL_ABILITIES_ENABLED
		special_abilities_ui.process_mode = Node.PROCESS_MODE_INHERIT if SPECIAL_ABILITIES_ENABLED else Node.PROCESS_MODE_DISABLED
	if ability_target_blocker != null:
		ability_target_blocker.hide()
		ability_target_blocker.process_mode = Node.PROCESS_MODE_INHERIT if SPECIAL_ABILITIES_ENABLED else Node.PROCESS_MODE_DISABLED


func _process(delta: float) -> void:
	if wave_icon == null:
		return
	if _wave_urgency_level <= 0:
		wave_icon.position = _wave_icon_base_position
		wave_icon.rotation = 0.0
		return

	_wave_wiggle_time += delta * WAVE_ICON_WIGGLE_SPEED * float(_wave_urgency_level)
	var wiggle_strength: float = WAVE_ICON_WIGGLE_AMOUNT * float(_wave_urgency_level)
	wave_icon.rotation = sin(_wave_wiggle_time) * wiggle_strength
	wave_icon.position = _wave_icon_base_position + Vector2(cos(_wave_wiggle_time * 0.7), sin(_wave_wiggle_time)) * (0.8 * float(_wave_urgency_level))


func set_life(value: int, immediate: bool = false) -> void:
	_update_counter(life_label, value, immediate)


func set_coins(value: int, immediate: bool = false) -> void:
	_update_counter(coin_label, value, immediate)
	if coin_label != null and not _coin_alert_active:
		coin_label.modulate = COIN_NORMAL_COLOR
		coin_label.scale = Vector2.ONE


func play_purchase_failed_feedback() -> void:
	play_coin_warning()


func play_coin_warning() -> void:
	if coin_label == null or coin_node == null:
		return
	if _coin_alert_tween != null:
		_coin_alert_tween.kill()
	_coin_alert_active = true
	coin_node.position = _coin_base_position
	coin_label.modulate = COIN_ALERT_COLOR
	coin_label.scale = Vector2.ONE
	_coin_alert_tween = create_tween()
	_coin_alert_tween.tween_property(coin_node, "position:x", _coin_base_position.x - COIN_SHAKE_OFFSET, COIN_SHAKE_STEP)
	_coin_alert_tween.tween_property(coin_node, "position:x", _coin_base_position.x + COIN_SHAKE_OFFSET, COIN_SHAKE_STEP)
	_coin_alert_tween.tween_property(coin_node, "position:x", _coin_base_position.x - COIN_SHAKE_OFFSET * 0.6, COIN_SHAKE_STEP)
	_coin_alert_tween.tween_property(coin_node, "position:x", _coin_base_position.x + COIN_SHAKE_OFFSET * 0.6, COIN_SHAKE_STEP)
	_coin_alert_tween.tween_property(coin_node, "position:x", _coin_base_position.x, COIN_SHAKE_STEP)
	_coin_alert_tween.parallel().tween_property(coin_label, "scale", Vector2(1.12, 1.12), 0.08)
	_coin_alert_tween.tween_property(coin_label, "modulate", COIN_NORMAL_COLOR, 0.14)
	_coin_alert_tween.parallel().tween_property(coin_label, "scale", Vector2.ONE, 0.14)
	_coin_alert_tween.finished.connect(
		func():
			coin_node.position = _coin_base_position
			coin_label.modulate = COIN_NORMAL_COLOR
			coin_label.scale = Vector2.ONE
			_coin_alert_active = false
			_coin_alert_tween = null
	)


func _setup_pause_menu() -> void:
	if pause_overlay != null:
		pause_overlay.visible = false
	if menu_button != null:
		menu_button.pressed.connect(_on_menu_button_pressed)
	if close_button != null:
		close_button.pressed.connect(_on_resume_button_pressed)
	if resume_button != null:
		resume_button.pressed.connect(_on_resume_button_pressed)
	if pause_restart_button != null:
		pause_restart_button.pressed.connect(_on_restart_button_pressed)
	if back_button != null:
		back_button.pressed.connect(_on_back_button_pressed)
	if quit_button != null:
		quit_button.pressed.connect(_on_quit_button_pressed)


func _setup_level_failed_menu() -> void:
	if level_failed_overlay != null:
		level_failed_overlay.visible = false
	if failed_back_button != null:
		failed_back_button.pressed.connect(_on_failed_back_button_pressed)
	if failed_restart_button != null:
		failed_restart_button.pressed.connect(_on_failed_restart_button_pressed)


func _setup_level_win_menu() -> void:
	if level_win_overlay != null:
		level_win_overlay.visible = false
	if win_next_button != null:
		win_next_button.pressed.connect(_on_win_next_button_pressed)


func show_level_failed() -> void:
	get_tree().paused = true
	if pause_overlay != null:
		pause_overlay.visible = false
	if level_win_overlay != null:
		level_win_overlay.visible = false
	if level_failed_overlay != null:
		level_failed_overlay.visible = true


func show_level_won(star_count: int = 3) -> void:
	set_life(GameHandler.castle_life, true)
	star_count = _get_star_count_from_life(GameHandler.castle_life)
	var clamped_star_count: int = clampi(star_count, 1, 3)
	get_tree().paused = true
	if pause_overlay != null:
		pause_overlay.visible = false
	if level_failed_overlay != null:
		level_failed_overlay.visible = false
	if win_star_rating != null:
		match clamped_star_count:
			1:
				win_star_rating.texture = WIN_STAR_TEXTURES[1]
			2:
				win_star_rating.texture = WIN_STAR_TEXTURES[2]
			_:
				win_star_rating.texture = WIN_STAR_TEXTURES[3]
	if win_reward_label != null:
		win_reward_label.text = "+%d" % clamped_star_count
	if level_win_overlay != null:
		level_win_overlay.visible = true


func _get_star_count_from_life(castle_life: int) -> int:
	if castle_life >= THREE_STAR_LIFE_THRESHOLD:
		return 3
	if castle_life >= TWO_STAR_LIFE_THRESHOLD:
		return 2
	return 1


func _on_failed_back_button_pressed() -> void:
	_go_to_level_selector()


func _on_failed_restart_button_pressed() -> void:
	_restart_level()


func _on_win_next_button_pressed() -> void:
	_go_to_level_selector()


func _on_restart_button_pressed() -> void:
	_restart_level()


func _restart_level() -> void:
	_transition_to(GAME_SCENE, "Restarting....")


func _go_to_level_selector() -> void:
	_transition_to(LEVEL_SELECTOR_SCENE, "Please wait....")


func _transition_to(scene_path: String, transition_message: String) -> void:
	get_tree().paused = false
	SceneTransitionScript.setup(scene_path, transition_message)
	get_tree().change_scene_to_file(TRANSITION_SCENE)


func _on_menu_button_pressed() -> void:
	_show_pause_menu()


func _on_resume_button_pressed() -> void:
	_hide_pause_menu()


func _on_back_button_pressed() -> void:
	_go_to_level_selector()


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _show_pause_menu() -> void:
	get_tree().paused = true
	if pause_overlay != null:
		pause_overlay.visible = true


func _hide_pause_menu() -> void:
	get_tree().paused = false
	if pause_overlay != null:
		pause_overlay.visible = false


func set_current_wave(value: int, immediate: bool = false) -> void:
	_update_counter(current_wave_label, value, immediate)


func set_total_waves(value: int, immediate: bool = false) -> void:
	_update_counter(total_wave_label, value, immediate)


func set_wave_progress(ratio: float) -> void:
	if wave_progress == null:
		return
	var clamped_ratio: float = clampf(ratio, 0.0, 1.0)
	var countdown_ratio: float = 1.0 - clamped_ratio
	wave_progress.value = countdown_ratio * 100.0
	if countdown_ratio <= 0.2:
		wave_progress.tint_progress = WAVE_PROGRESS_DANGER
		_set_wave_icon_urgency(2)
	elif countdown_ratio <= 0.45:
		wave_progress.tint_progress = WAVE_PROGRESS_WARN
		_set_wave_icon_urgency(1)
	else:
		wave_progress.tint_progress = WAVE_PROGRESS_SAFE
		_set_wave_icon_urgency(0)


func clear_wave_alert() -> void:
	if wave_progress != null:
		wave_progress.value = 0.0
		wave_progress.tint_progress = WAVE_PROGRESS_SAFE
	_set_wave_icon_urgency(0)


func _cache_label_value(label: Label) -> void:
	_label_values[label] = int(label.text)


func _update_counter(label: Label, target_value: int, immediate: bool) -> void:
	if label == null:
		return

	var start_value: int = _label_values.get(label, int(label.text))
	_label_values[label] = target_value

	if _label_tweens.has(label):
		var running_tween: Tween = _label_tweens[label]
		if running_tween != null:
			running_tween.kill()
		_label_tweens.erase(label)

	if immediate or start_value == target_value:
		label.text = str(target_value)
		return

	var tween := create_tween()
	_label_tweens[label] = tween
	tween.tween_method(
		func(animated_value: float):
			label.text = str(int(round(animated_value))),
		float(start_value),
		float(target_value),
		COUNT_ANIM_TIME
	)
	tween.finished.connect(
		func():
			label.text = str(target_value)
			_label_tweens.erase(label)
	)


func _set_wave_icon_urgency(level: int) -> void:
	_wave_urgency_level = level
	if wave_icon == null:
		return
	match level:
		2:
			wave_icon.modulate = WAVE_ICON_DANGER
			wave_icon.scale = WAVE_ICON_NORMAL_SCALE
		1:
			wave_icon.modulate = WAVE_ICON_WARN
			wave_icon.scale = WAVE_ICON_NORMAL_SCALE
		_:
			wave_icon.modulate = WAVE_ICON_SAFE
			wave_icon.scale = WAVE_ICON_NORMAL_SCALE
			wave_icon.position = _wave_icon_base_position
			wave_icon.rotation = 0.0
