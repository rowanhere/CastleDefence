extends Node2D

@onready var tower_area: Area2D = get_node_or_null("TowerImage/towerArea") as Area2D
@onready var tower_collision: CollisionShape2D = get_node_or_null("TowerImage/towerArea/towerCollision") as CollisionShape2D
@onready var range_circle: Node2D = get_node_or_null("TowerImage/towerArea/Range circle") as Node2D
@onready var tower_image: Sprite2D = get_node_or_null("TowerImage") as Sprite2D
@onready var launcher_a: Sprite2D = get_node_or_null("LauncherA") as Sprite2D
@onready var launcher_b: Sprite2D = get_node_or_null("LauncherB") as Sprite2D
@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer
@onready var projectile_preview: Sprite2D = get_node_or_null("BombProjectile") as Sprite2D
@onready var bomb_spawn_point: Marker2D = get_node_or_null("BombSpawnPoint") as Marker2D

var bomb_tower_data: TowerData = preload("res://resources/towers/bomb/bomb.tres")
var bomb_scene: PackedScene = preload("res://scenes/projectiles/Bomb.tscn")
var active_upgrade: UpgradeData = null
var attack_rate: float = 1.0
var enemies_in_range: Array[Node2D] = []
var is_attacking := false
var projectile_preview_start_position: Vector2 = Vector2.ZERO

const BURST_COUNT := 3
const BURST_COOLDOWN := 5.0
const ANIMATION_HIT_TIME := 0.45
const IDLE_FRAME := 3
const HIT_FRAME := 2
const LAUNCH_SOUND: AudioStream = preload("res://assets/audio/sfx/BombTowerLauncher.mp3")
const SFX_VOLUME_50_PERCENT := -6.0


func _ready() -> void:
	if projectile_preview != null:
		projectile_preview_start_position = _get_projectile_preview_home_position()
		projectile_preview.position = projectile_preview_start_position
	active_upgrade = bomb_tower_data.get_base_upgrade() if bomb_tower_data != null else null
	_apply_active_upgrade()
	if tower_area != null:
		tower_area.body_entered.connect(_on_body_entered)
		tower_area.body_exited.connect(_on_body_exited)
	_show_idle_frame()


func _process(_delta: float) -> void:
	enemies_in_range = enemies_in_range.filter(_is_valid_enemy)
	if not is_attacking and not enemies_in_range.is_empty():
		_start_burst()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") and body not in enemies_in_range:
		enemies_in_range.append(body)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		enemies_in_range.erase(body)


func _is_valid_enemy(enemy: Node2D) -> bool:
	return enemy != null and is_instance_valid(enemy) and enemy.is_in_group("enemies") and not enemy.is_dead


func _get_target() -> Node2D:
	enemies_in_range = enemies_in_range.filter(_is_valid_enemy)
	if enemies_in_range.is_empty():
		return null
	return enemies_in_range[0]


func _start_burst() -> void:
	is_attacking = true
	call_deferred("_attack_burst")


func _attack_burst() -> void:
	for i in range(BURST_COUNT):
		var target := _get_target()
		if target == null:
			break
		await _play_attack_and_hit(target)
	if projectile_preview != null:
		projectile_preview.position = projectile_preview_start_position
		projectile_preview.visible = true
	await _settle_to_idle()
	await get_tree().create_timer(BURST_COOLDOWN).timeout
	is_attacking = false


func _play_attack_and_hit(target: Node2D) -> void:
	var attack_name := _attack_anim_name()
	if animation_player != null:
		if not animation_player.has_animation(attack_name) and animation_player.has_animation("attack_1"):
			attack_name = "attack_1"
		if not animation_player.has_animation(attack_name):
			_damage_target(target)
			return
		if projectile_preview != null:
			projectile_preview.visible = true
		animation_player.play(attack_name)
		await get_tree().create_timer(ANIMATION_HIT_TIME).timeout
		_launch_projectile(target)
		await animation_player.animation_finished
		_reload_projectile_preview()
		await get_tree().create_timer(_get_shot_interval()).timeout
		return

	if animated_sprite == null or animated_sprite.sprite_frames == null:
		_damage_target(target)
		return
	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(attack_name):
		animated_sprite.play(attack_name)
	elif animated_sprite.sprite_frames.has_animation("attack_1"):
		animated_sprite.play("attack_1")
	else:
		_damage_target(target)
		return

	var target_frame: int = min(HIT_FRAME, animated_sprite.sprite_frames.get_frame_count(animated_sprite.animation) - 1)
	while animated_sprite.is_playing() and animated_sprite.frame < target_frame:
		await animated_sprite.frame_changed

	_damage_target(target)

	if animated_sprite.is_playing():
		await animated_sprite.animation_finished
	await get_tree().create_timer(_get_shot_interval()).timeout


func _current_level() -> int:
	return active_upgrade.level if active_upgrade != null else 1


func _attack_anim_name() -> String:
	return "attack_%d" % _current_level()


func _idle_anim_name() -> String:
	return "idle_%d" % _current_level()


func _damage_target(target: Node2D) -> void:
	if _is_valid_enemy(target):
		var damage: float = active_upgrade.damage if active_upgrade != null else 10.0
		target.take_damage(damage)


func _launch_projectile(target: Node2D) -> void:
	if not _is_valid_enemy(target):
		return
	GameSound.play(LAUNCH_SOUND, SFX_VOLUME_50_PERCENT)
	var bomb := bomb_scene.instantiate()
	var projectile_parent := get_parent()
	if projectile_parent == null:
		projectile_parent = get_tree().current_scene
	projectile_parent.add_child(bomb)
	var launch_position := _get_launch_position()
	var launch_damage: float = active_upgrade.damage if active_upgrade != null else 10.0
	if bomb.has_method("setup_launch"):
		bomb.setup_launch(launch_position, target, launch_damage)
	else:
		bomb.global_position = launch_position
		if "target" in bomb:
			bomb.target = target
		if "damage" in bomb:
			bomb.damage = launch_damage
	if projectile_preview != null:
		projectile_preview.visible = false


func _get_launch_position() -> Vector2:
	if bomb_spawn_point != null:
		return bomb_spawn_point.global_position
	if projectile_preview != null:
		return projectile_preview.global_position
	return global_position + Vector2(0.0, -31.0)


func _get_projectile_preview_home_position() -> Vector2:
	if bomb_spawn_point != null:
		return bomb_spawn_point.position
	return projectile_preview.position if projectile_preview != null else Vector2.ZERO


func _reload_projectile_preview() -> void:
	if projectile_preview == null:
		return
	projectile_preview.position = projectile_preview_start_position
	projectile_preview.visible = true


func _show_idle_frame() -> void:
	_reload_projectile_preview()
	if animated_sprite == null:
		return
	if animated_sprite.sprite_frames == null:
		animated_sprite.stop()
		return
	var idle_name := _idle_anim_name()
	if animated_sprite.sprite_frames.has_animation(idle_name):
		animated_sprite.play(idle_name)
	else:
		var attack_name := _attack_anim_name()
		if not animated_sprite.sprite_frames.has_animation(attack_name):
			animated_sprite.stop()
			return
		var frame_count: int = animated_sprite.sprite_frames.get_frame_count(attack_name)
		animated_sprite.play(attack_name)
		animated_sprite.frame = clampi(IDLE_FRAME, 0, frame_count - 1)
		animated_sprite.pause()


func _settle_to_idle() -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return
	var base_scale: Vector2 = animated_sprite.scale
	var tween := create_tween()
	tween.tween_property(animated_sprite, "scale", base_scale * 0.96, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_show_idle_frame)
	tween.tween_property(animated_sprite, "scale", base_scale, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished


func _apply_active_upgrade() -> void:
	if active_upgrade == null:
		return
	attack_rate = max(active_upgrade.attackSpeed, 0.01)
	_apply_upgrade_textures()
	if tower_collision != null and tower_collision.shape is CircleShape2D:
		var circle := tower_collision.shape as CircleShape2D
		circle.radius = active_upgrade.tower_range
	if range_circle != null and "radius" in range_circle:
		range_circle.radius = active_upgrade.tower_range
		if range_circle.has_method("queue_redraw"):
			range_circle.queue_redraw()


func handle_upgrade_applied() -> void:
	_apply_active_upgrade()
	_show_idle_frame()


func _apply_upgrade_textures() -> void:
	if tower_image != null and active_upgrade.towerImage != null:
		tower_image.texture = active_upgrade.towerImage
	if launcher_a != null and active_upgrade.launcherAImage != null:
		launcher_a.texture = active_upgrade.launcherAImage
	if launcher_b != null and active_upgrade.launcherBImage != null:
		launcher_b.texture = active_upgrade.launcherBImage


func _get_shot_interval() -> float:
	return 1.0 / max(attack_rate, 0.01)
