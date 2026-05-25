extends Control

@onready var music_btn: TextureButton = $MusicBtn

var texture_on: Texture2D
var texture_off: Texture2D

func _ready() -> void:
	texture_on = music_btn.texture_normal
	texture_off = music_btn.texture_disabled
	AudioController.play_music()
	set_music_texture(true)

func set_music_texture(enabled: bool) -> void:
	music_btn.texture_normal = texture_on if enabled else texture_off

func _update_button() -> void:
	set_music_texture(AudioController.bg_music.playing)

func _on_music_btn_pressed() -> void:
	if AudioController.bg_music.playing:
		AudioController.stop_music()
	else:
		AudioController.play_music()
	_update_button()
