extends CanvasLayer
class_name SceneTransition

const DEFAULT_MESSAGE := "Please wait...."
const DEFAULT_TARGET_SCENE := "res://scenes/ui/level.tscn"
const LOAD_DELAY := 0.8
const DOT_INTERVAL := 0.16

static var next_scene_path: String = DEFAULT_TARGET_SCENE
static var message: String = DEFAULT_MESSAGE

@onready var message_label: Label = $Screen/MessageLabel
@onready var loading_bar: ColorRect = $Screen/LoadingTrack/LoadingBar

var _elapsed: float = 0.0
var _dot_time: float = 0.0
var _dot_count: int = 0
var _is_changing_scene: bool = false
var _music_global_handler: CanvasLayer = null
var _music_global_handler_was_visible: bool = true


func _ready() -> void:
	layer = 100
	get_tree().paused = false
	_hide_global_buttons()
	if message_label != null:
		message_label.text = message
	if loading_bar != null:
		loading_bar.scale.x = 0.0
	ResourceLoader.load_threaded_request(next_scene_path)


func _process(delta: float) -> void:
	_elapsed += delta
	_dot_time += delta
	var progress: float = clampf(_elapsed / LOAD_DELAY, 0.0, 1.0)

	if _dot_time >= DOT_INTERVAL:
		_dot_time = 0.0
		_dot_count = (_dot_count + 1) % 4
		if message_label != null:
			message_label.text = message + ".".repeat(_dot_count)

	if loading_bar != null:
		loading_bar.scale.x = progress

	if _is_changing_scene or _elapsed < LOAD_DELAY:
		return

	var load_status: int = ResourceLoader.load_threaded_get_status(next_scene_path)
	if load_status == ResourceLoader.THREAD_LOAD_LOADED:
		_is_changing_scene = true
		var packed_scene := ResourceLoader.load_threaded_get(next_scene_path) as PackedScene
		if packed_scene != null:
			_change_scene_to_packed(packed_scene)
		else:
			_change_scene_to_file(next_scene_path)
	elif load_status == ResourceLoader.THREAD_LOAD_FAILED:
		_is_changing_scene = true
		_change_scene_to_file(next_scene_path)


func _hide_global_buttons() -> void:
	_music_global_handler = get_node_or_null("/root/MusicGlobalhandler") as CanvasLayer
	if _music_global_handler == null:
		return
	_music_global_handler_was_visible = _music_global_handler.visible
	_music_global_handler.visible = false


func _restore_global_buttons_after_scene_change() -> void:
	if _music_global_handler != null and is_instance_valid(_music_global_handler):
		_music_global_handler.visible = _music_global_handler_was_visible


func _schedule_global_buttons_restore() -> void:
	if _music_global_handler == null or not is_instance_valid(_music_global_handler):
		return
	var handler := _music_global_handler
	var was_visible := _music_global_handler_was_visible
	var tree := get_tree()
	if tree == null:
		return
	var restore_timer := tree.create_timer(0.12)
	restore_timer.timeout.connect(
		func():
			if is_instance_valid(handler):
				handler.visible = was_visible
	)


func _change_scene_to_packed(packed_scene: PackedScene) -> void:
	_schedule_global_buttons_restore()
	get_tree().change_scene_to_packed(packed_scene)


func _change_scene_to_file(scene_path: String) -> void:
	_schedule_global_buttons_restore()
	get_tree().change_scene_to_file(scene_path)


static func setup(target_scene_path: String, transition_message: String) -> void:
	next_scene_path = target_scene_path
	message = transition_message
