extends TextureButton

func _ready():
	toggle_mode = true
	button_pressed = not AudioController.music_enabled
	pressed.connect(_on_toggle_pressed)

func _on_toggle_pressed():
	await AudioController.toggle_music()
	button_pressed = not AudioController.music_enabled
