extends Control
var level_scene = preload("res://scenes/level.tscn")
var menu_music = preload("res://assets/Music/Forest Day.ogg")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	AudioController.change_music(menu_music)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_packed(level_scene)


func _on_music_button_pressed() -> void:
	print("music")
