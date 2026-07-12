extends Control
const LevelButton = preload("res://scenes/ui/level_button.tscn")
const lockedButton = preload("res://scenes/ui/speech_bubble.tscn")
const BUTTON_HOVER_SOUND: AudioStream = preload("res://assets/audio/sfx/buttonHover.mp3")
var levelMap = preload("res://assets/audio/music/levelMap.ogg")
const GameHandlerScript = preload("res://scripts/gameplay/game_handler.gd")
const SceneTransitionScript = preload("res://scripts/ui/scene_transition.gd")
const GAME_SCENE := "res://scenes/gameplay/GameHandler.tscn"
const TRANSITION_SCENE := "res://scenes/ui/scene_transition.tscn"
var lBtn
@onready var level_group: Control = $LevelGroup
# Called when the node enters the scene tree for the first time.
var positions: Array[Vector2] = [
	Vector2(19.0, 106.0),
	Vector2(57.0, 142.0),
	Vector2(132.0, 150.0),
	Vector2(208.0, 153.0),
	Vector2(282.0, 150.0),
	Vector2(288.0, 103.0),
	Vector2(224.0, 46.0),
	Vector2(215.0, 111.0),
	Vector2(154.0, 100.0),
	Vector2(119.0, 59.0),
	Vector2(88.0, 84.0),
	Vector2(15.0, 21.0),
	Vector2(90.0, 3.0),
	Vector2(169.0, 29.0),
	Vector2(281.0, 4.0)
]
var unlocked_levels:Array[int] = [1]
var current_level_number: int = 1
func _ready() -> void:
	AudioController.change_music(levelMap)
	lBtn = lockedButton.instantiate()
	lBtn.scale = Vector2(0,0)
	add_child(lBtn)
	for i in range(positions.size()):
		var btn = LevelButton.instantiate()
		btn.level_number = i+1
		if i+1 not in unlocked_levels:
			btn.texture_normal = btn.texture_disabled
		btn.position = positions[i]
		$LevelGroup.add_child(btn)
		btn.pressed.connect(_on_level_button_pressed.bind(i + 1,positions[i]))
		btn.mouse_entered.connect(_on_level_button_hovered.bind(btn))
		btn.mouse_exited.connect(_on_level_button_exited.bind(btn))


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	
func _on_level_button_pressed(level_number: int,Locked_position:Vector2) -> void:
	if level_number in unlocked_levels:
		handle_unlockedLevel(level_number)
		return
	var x= Locked_position.x - 12
	var y = Locked_position.y - 13
	lBtn.modulate.a = 1.0
	lBtn.position = Vector2(x,y)
	lBtn.scale= Vector2(1,1)
	shake(lBtn)

#shake animation
func handle_unlockedLevel(level_number: int) -> void:
	print("Level ", level_number, " is unlocked")
	current_level_number = level_number
	AudioController.stop_music()
	GameHandlerScript.queued_level = current_level_number
	SceneTransitionScript.setup(GAME_SCENE, "Loading....")
	get_tree().change_scene_to_file(TRANSITION_SCENE)

var current_tween: Tween = null	
func shake(btn:Button) -> void:
	if current_tween:
		current_tween.kill()
	current_tween = create_tween()
	current_tween.tween_property(btn, "position:x", btn.position.x - 5, 0.1)
	current_tween.tween_property(btn, "position:x", btn.position.x + 5, 0.1)
	current_tween.tween_property(btn, "position:x", btn.position.x - 5, 0.1)
	current_tween.tween_property(btn, "position:x", btn.position.x + 5, 0.1)
	current_tween.tween_property(btn, "position:x", btn.position.x, 0.1)
	#wait for a second
	current_tween.tween_interval(1.0)
	#scale animation
	current_tween.tween_property(btn,"modulate:a",0.0,0.3)
	current_tween.tween_property(btn, "scale", Vector2(0, 0), 0.3)
	#kill back after tween animation ends
  
func _on_level_button_hovered(btn: TextureButton) -> void:
	GameSound.play(BUTTON_HOVER_SOUND, -8.0)
	btn.modulate = Color(1.5,1.5,0.5)

func _on_level_button_exited(btn:TextureButton) -> void:
	btn.modulate = Color(1, 1, 1)
	
