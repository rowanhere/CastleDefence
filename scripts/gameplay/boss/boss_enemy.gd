extends "res://scripts/gameplay/enemy.gd"

const FLIGHT_SPEED_MULTIPLIER := 1.25
const AIR_SPRITE_POSITION := Vector2.ZERO
const GROUND_SPRITE_POSITION := Vector2(0.0, 10.0)
const BOSS_Z_INDEX := 2500

var _is_airborne := true
var _flight_tween: Tween = null


func _physics_process(delta: float) -> void:
	super._physics_process(delta)


func _play_dir(base: String, force: bool = false) -> void:
	if base == "walk":
		_set_airborne(true)
		super._play_dir("run", force)
		return
	if base == "attack" or base == "die":
		_set_airborne(false)
	super._play_dir(base, force)


func _get_current_speed() -> float:
	var movement_speed: float = super._get_current_speed()
	return movement_speed * FLIGHT_SPEED_MULTIPLIER


func _update_depth() -> void:
	z_as_relative = false
	z_index = BOSS_Z_INDEX


func _set_airborne(airborne: bool) -> void:
	if _is_airborne == airborne:
		return
	_is_airborne = airborne
	if _flight_tween != null and _flight_tween.is_valid():
		_flight_tween.kill()
	var target_position: Vector2 = AIR_SPRITE_POSITION if airborne else GROUND_SPRITE_POSITION
	var duration: float = 0.26 if airborne else 0.16
	_flight_tween = create_tween()
	_flight_tween.tween_property(anim, "position", target_position, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _get_crowd_speed_scale(_path2d: Path2D, _path_follow: PathFollow2D) -> float:
	return 1.0


func _update_path_lane_offset(_path2d: Path2D, _path_follow: PathFollow2D, _delta: float) -> void:
	_path_lane_offset = Vector2.ZERO
	position = Vector2.ZERO
