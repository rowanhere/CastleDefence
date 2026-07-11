extends Area2D
class_name Castle

@export var max_hp: float = 100.0

var hp: float = 100.0

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	max_hp = float(GameHandler.castle_life)
	hp = max_hp
	body_entered.connect(_on_body_entered)


func take_damage(amount: float) -> void:
	if amount <= 0.0:
		return

	var life_damage: int = maxi(int(round(amount)), 1)
	GameHandler.damage_castle(life_damage)
	hp = float(GameHandler.castle_life)
	GameHandler.show_floating_message(global_position + Vector2(0.0, -110.0), "-%d" % int(round(amount)))
	_play_hit_feedback()

	if hp <= 0.0:
		print("Castle destroyed.")


func _on_body_entered(body: Node2D) -> void:
	if body == null or not body.has_method("reach_castle"):
		return
	if "locked_castle" in body and body.locked_castle != null:
		return

	body.reach_castle()


func _play_hit_feedback() -> void:
	if sprite == null:
		return

	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1.0, 0.45, 0.45), 0.06)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.12)
