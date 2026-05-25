extends Control

var next_scene: String = "res://scenes/main_menu.tscn"
@onready var progress_bar: ProgressBar = $ProgressBar

var display_progress := 0.0   # what user sees (fake smooth)
var min_time := 2          # minimum loading screen time
var elapsed := 0.0
var is_loaded := false

func _ready() -> void:
	ResourceLoader.load_threaded_request(next_scene)

func _process(delta: float) -> void:
	elapsed += delta
	
	var progress_array = []
	var loader_status = ResourceLoader.load_threaded_get_status(next_scene, progress_array)
	
	if progress_array.size() > 0:
		var real_progress = progress_array[0]  
		
		display_progress = lerp(display_progress, real_progress, 3 * delta)
		
		progress_bar.value = display_progress * 100
	
	if loader_status == ResourceLoader.ThreadLoadStatus.THREAD_LOAD_LOADED:
		is_loaded = true
	
	if is_loaded and elapsed >= min_time:
		var packed_next_scene = ResourceLoader.load_threaded_get(next_scene)
		get_tree().change_scene_to_packed(packed_next_scene)
