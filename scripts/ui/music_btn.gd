extends TextureButton

@export var music_on_texture: Texture2D
@export var music_off_texture: Texture2D

var _is_toggling: bool = false


func _ready() -> void:
	toggle_mode = false
	_sync_button_state()
	pressed.connect(_on_toggle_pressed)


func _on_toggle_pressed() -> void:
	AudioController.toggle_music()
	_sync_button_state()


func _sync_button_state() -> void:
	set_pressed_no_signal(false)
	var target_texture: Texture2D = music_off_texture
	if AudioController.music_enabled:
		target_texture = music_on_texture
	texture_normal = target_texture
	texture_pressed = target_texture
	texture_hover = target_texture
	texture_disabled = target_texture
