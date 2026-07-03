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

@onready var life_label: Label = $LevelData/PanelContainer/LifeNode/CoinsAmt
@onready var coin_label: Label = $LevelData/PanelContainer/CoinNode/CoinsAmt
@onready var current_wave_label: Label = $LevelData/PanelContainer/WaveNode/CurrentWave
@onready var total_wave_label: Label = $LevelData/PanelContainer/WaveNode/TotalWave
@onready var wave_progress: TextureProgressBar = $LevelData/WaveTextureProgress
@onready var wave_icon: Sprite2D = $LevelData/PanelContainer/WaveNode/Sprite2D

var _label_values: Dictionary = {}
var _label_tweens: Dictionary = {}
var _wave_urgency_level: int = 0
var _wave_icon_base_position: Vector2 = Vector2.ZERO
var _wave_wiggle_time: float = 0.0


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
