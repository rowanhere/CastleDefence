extends Control
const LevelButton = preload("res://scenes/level_button.tscn")
const lockedButton = preload("res://scenes/helpers/speech_bubble.tscn")
var levelMap = preload("res://assets/Music/levelMap.ogg")
var lBtn
@onready var level_group: Control = $LevelGroup
@onready var color_rect: ColorRect = $ColorRect
@onready var level_load: ProgressBar = $levelLoad
var loading_path: String = ""
var fake_timer: float = 0.0
var fake_duration: float = 2.0
var resource_ready: bool = false
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
func _ready() -> void:
	set_process(false)
	level_load.visible = false
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
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if loading_path == "":
		return

	# check resource in background
	var status = ResourceLoader.load_threaded_get_status(loading_path)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		resource_ready = true

	# fake progress bar takes 2 seconds regardless
	fake_timer += delta
	level_load.value = minf(fake_timer / fake_duration, 1.0) * 100

	# only switch scene when BOTH fake timer and resource are done
	if fake_timer >= fake_duration and resource_ready:
		var scene = ResourceLoader.load_threaded_get(loading_path)
		loading_path = ""
		set_process(false)
		AudioController.stop_music()
		get_tree().change_scene_to_packed(scene)
	elif status == ResourceLoader.THREAD_LOAD_FAILED:
		print("Failed to load: ", loading_path)
		loading_path = ""
		set_process(false)
		level_load.visible = false


	


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	
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
	loading_path = "res://scenes/levels/level_%d.tscn" % level_number
	level_load.visible = true
	color_rect.visible = true

	level_load.value = 0
	fake_timer = 0.0
	resource_ready = false
	ResourceLoader.load_threaded_request(loading_path)
	set_process(true)

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
	btn.modulate = Color(1.5,1.5,0.5)

func _on_level_button_exited(btn:TextureButton) -> void:
	btn.modulate = Color(1, 1, 1)
	
