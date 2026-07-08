extends Node2D

@onready var tower_collision: CollisionShape2D = get_node_or_null("TowerImage/towerArea/towerCollision") as CollisionShape2D
@onready var range_circle: Node2D = get_node_or_null("TowerImage/towerArea/Range circle") as Node2D
@onready var tower_image: Sprite2D = get_node_or_null("TowerImage") as Sprite2D
@onready var tower_top: Sprite2D = get_node_or_null("TowerTop") as Sprite2D
@onready var tower_area: Area2D = get_node_or_null("TowerImage/towerArea") as Area2D
@onready var magic_spawn_point: Marker2D = get_node_or_null("TowerTop/MagicSpawnPoint") as Marker2D

var magic_tower_data: TowerData = preload("res://resources/towers/magic/magic.tres")
var active_upgrade: UpgradeData = null
var attack_rate: float = 1.0
var attack_timer: float = 0.0
var enemies_in_range: Array[Node2D] = []
var active_targets: Array[Node2D] = []
var laser_lines: Array[Line2D] = []
var tower_top_start_position: Vector2 = Vector2.ZERO
var laser_sound_player: AudioStreamPlayer = null

const MAX_CHAIN_TARGETS := 3
const CHAIN_DAMAGE_FALLOFF := 0.65
const LASER_WIDTH := 5.0
const LASER_GLOW_WIDTH := 12.0
const LASER_GLOW_COLOR := Color(1.0, 0.24, 0.02, 0.35)
const LASER_COLOR := Color(1.0, 0.08, 0.02, 0.92)
const LASER_CORE_COLOR := Color(1.0, 0.86, 0.32, 0.98)
const LASER_START_OFFSET := Vector2.ZERO
const LASER_Z_INDEX := 200
const LASER_SOUND: AudioStream = preload("res://assets/audio/sfx/magicLaser.mp3")
const LASER_SOUND_VOLUME := -5.0


func _ready() -> void:
	if tower_top != null:
		tower_top_start_position = tower_top.position
	active_upgrade = magic_tower_data.get_base_upgrade() if magic_tower_data != null else null
	_apply_active_upgrade()
	if tower_area != null:
		tower_area.body_entered.connect(_on_body_entered)
		tower_area.body_exited.connect(_on_body_exited)


func _exit_tree() -> void:
	_clear_lasers()
	_stop_laser_sound()


func _process(delta: float) -> void:
	enemies_in_range = enemies_in_range.filter(_is_valid_enemy)
	if enemies_in_range.is_empty():
		active_targets.clear()
		_clear_lasers()
		_stop_laser_sound()
		attack_timer = min(attack_timer, _get_attack_interval())
		return

	active_targets = _get_chain_targets()
	_update_lasers(active_targets)
	_play_laser_sound()
	attack_timer -= delta
	if attack_timer <= 0.0:
		attack_timer = _get_attack_interval()
		_attack_enemies()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") and body not in enemies_in_range:
		enemies_in_range.append(body)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		enemies_in_range.erase(body)
		active_targets.erase(body)


func handle_upgrade_applied() -> void:
	_apply_active_upgrade()


func _apply_active_upgrade() -> void:
	if active_upgrade == null:
		return
	attack_rate = max(active_upgrade.attackSpeed, 0.01)
	if tower_image != null and active_upgrade.towerImage != null:
		tower_image.texture = active_upgrade.towerImage
	if tower_top != null and active_upgrade.towerTop != null:
		tower_top.texture = active_upgrade.towerTop
	if tower_top != null:
		tower_top.position = tower_top_start_position + Vector2(0.0, -5.0 * float(max(active_upgrade.level - 1, 0)))
	if tower_collision != null and tower_collision.shape is CircleShape2D:
		var circle := tower_collision.shape as CircleShape2D
		circle.radius = active_upgrade.tower_range
	if range_circle != null and "radius" in range_circle:
		range_circle.radius = active_upgrade.tower_range
		if range_circle.has_method("queue_redraw"):
			range_circle.queue_redraw()


func _attack_enemies() -> void:
	var targets: Array[Node2D] = active_targets
	if targets.is_empty():
		return

	var damage: float = active_upgrade.damage if active_upgrade != null else 10.0
	for index: int in range(targets.size()):
		var enemy: Node2D = targets[index]
		if _is_valid_enemy(enemy):
			var target_damage: float = damage * pow(CHAIN_DAMAGE_FALLOFF, index)
			enemy.take_damage(target_damage)


func _get_chain_targets() -> Array[Node2D]:
	enemies_in_range.sort_custom(func(a, b) -> bool:
		return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position)
	)

	var targets: Array[Node2D] = []
	for enemy: Node2D in enemies_in_range:
		if _is_valid_enemy(enemy):
			targets.append(enemy)
		if targets.size() >= MAX_CHAIN_TARGETS:
			break
	return targets


func _update_lasers(targets: Array[Node2D]) -> void:
	var required_lines: int = targets.size() * 3
	while laser_lines.size() < required_lines:
		var lines: Array[Line2D] = _create_laser_segment_lines()
		for line: Line2D in lines:
			laser_lines.append(line)
	while laser_lines.size() > required_lines:
		var line: Line2D = laser_lines.pop_back()
		if is_instance_valid(line):
			line.queue_free()

	var start_position: Vector2 = _get_laser_start_position()
	for index: int in range(targets.size()):
		var enemy: Node2D = targets[index]
		if not _is_valid_enemy(enemy):
			continue
		var end_position: Vector2 = enemy.global_position + Vector2(0.0, -18.0)
		var from_position: Vector2 = start_position if index == 0 else targets[index - 1].global_position + Vector2(0.0, -18.0)
		var points: PackedVector2Array = _get_curved_laser_points(from_position, end_position)
		laser_lines[index * 3].points = points
		laser_lines[index * 3 + 1].points = points
		laser_lines[index * 3 + 2].points = points


func _create_laser_segment_lines() -> Array[Line2D]:
	var glow_line := _create_laser_line(LASER_GLOW_COLOR, LASER_GLOW_WIDTH)
	var outer_line := _create_laser_line(LASER_COLOR, LASER_WIDTH)
	var core_line := _create_laser_line(LASER_CORE_COLOR, maxf(LASER_WIDTH * 0.35, 1.0))

	get_tree().current_scene.add_child(glow_line)
	get_tree().current_scene.add_child(outer_line)
	get_tree().current_scene.add_child(core_line)
	return [glow_line, outer_line, core_line]


func _clear_lasers() -> void:
	for line: Line2D in laser_lines:
		if is_instance_valid(line):
			line.queue_free()
	laser_lines.clear()


func _play_laser_sound() -> void:
	if laser_sound_player == null:
		laser_sound_player = AudioStreamPlayer.new()
		laser_sound_player.stream = LASER_SOUND
		if laser_sound_player.stream != null and "loop" in laser_sound_player.stream:
			laser_sound_player.stream.loop = true
		laser_sound_player.volume_db = LASER_SOUND_VOLUME
		add_child(laser_sound_player)
	if not laser_sound_player.playing:
		laser_sound_player.play()


func _stop_laser_sound() -> void:
	if laser_sound_player != null and is_instance_valid(laser_sound_player):
		laser_sound_player.stop()


func _create_laser_line(color: Color, width: float) -> Line2D:
	var line := Line2D.new()
	line.default_color = color
	line.width = width
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.z_index = LASER_Z_INDEX
	return line


func _get_curved_laser_points(from_position: Vector2, end_position: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var direction: Vector2 = end_position - from_position
	var normal: Vector2 = direction.orthogonal().normalized()
	var curve_strength: float = minf(direction.length() * 0.18, 42.0)
	var wave: float = randf_range(-curve_strength, curve_strength)

	for i in range(7):
		var t: float = float(i) / 6.0
		var base_position: Vector2 = from_position.lerp(end_position, t)
		var curve_offset: Vector2 = normal * sin(t * PI) * wave
		points.append(base_position + curve_offset)
	return points


func _get_laser_start_position() -> Vector2:
	if magic_spawn_point != null:
		return magic_spawn_point.global_position + LASER_START_OFFSET
	if tower_top != null:
		return tower_top.global_position + LASER_START_OFFSET
	return global_position


func _get_attack_interval() -> float:
	return 1.0 / max(attack_rate, 0.01)


func _is_valid_enemy(enemy: Node2D) -> bool:
	return enemy != null and is_instance_valid(enemy) and enemy.is_in_group("enemies") and enemy.get("is_dead") != true
