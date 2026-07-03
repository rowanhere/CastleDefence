extends Node2D

const TWEEN_DURATION = 0.18
const OFFSET_UP = Vector2(0, -8)
const SCALE_HOVER = Vector2(1.1, 1.1)
const SCALE_NORMAL = Vector2(1.0, 1.0)
const SELECTED_COLOR = Color("#ffff42")
const TOWER_TYPE_CLICKED = {
	"ArrowTower": "keke",
	"BarrackTower": "koko",
	"CloseButton": "CLoseIt"
}

var playHoverSound: AudioStream = preload("res://assets/audio/buttonHover.mp3")
var hovered_buttons = {}
var original_positions = {}
var current_selected_button: TextureButton = null

@onready var sprite_2d: Sprite2D = $Sprite2D

func _ready() -> void:
	for button in sprite_2d.get_children():
		if button is TextureButton:
			hovered_buttons[button] = false
			original_positions[button] = button.position
			if not TOWER_TYPE_CLICKED.has(button.name) or button.name == "CloseButton":
				if button.name != "CloseButton":
					_disable_button(button)
			else:
				_create_hover_zone(button)

func _create_hover_zone(button: TextureButton) -> void:
	var zone = Control.new()
	zone.position = original_positions[button]
	zone.size = button.size
	zone.mouse_filter = Control.MOUSE_FILTER_STOP
	zone.modulate = Color(1, 1, 1, 0)
	button.get_parent().add_child(zone)
	zone.mouse_entered.connect(_on_button_hover_enter.bind(button))
	zone.mouse_exited.connect(_on_button_hover_exit.bind(button))
	zone.gui_input.connect(_on_zone_input.bind(button))

func _on_zone_input(event: InputEvent, button: TextureButton) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_button_clicked(button)

func _disable_button(button: TextureButton) -> void:
	button.disabled = true
	button.modulate = Color(0.3, 0.3, 0.3, 1.0)
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_button_clicked(button: TextureButton) -> void:
	print("clicked: ", button.name)
	if TOWER_TYPE_CLICKED.has(button.name):
		print(TOWER_TYPE_CLICKED[button.name])
	_select_button(button)

func _select_button(button: TextureButton) -> void:
	# Deselect previous
	if current_selected_button != null and current_selected_button != button:
		current_selected_button.modulate = Color.WHITE

	# Toggle off if same button clicked again
	if current_selected_button == button:
		button.modulate = Color.WHITE
		current_selected_button = null
		return

	current_selected_button = button
	button.modulate = SELECTED_COLOR
	print("current selected: ", current_selected_button.name)

func _on_button_hover_enter(button: TextureButton) -> void:
	if hovered_buttons.get(button, false):
		return
	GameSound.play(playHoverSound)
	hovered_buttons[button] = true
	button.pivot_offset = button.size / 2.0
	_tween_button(button, original_positions[button] + OFFSET_UP, SCALE_HOVER)

func _on_button_hover_exit(button: TextureButton) -> void:
	if not hovered_buttons.get(button, false):
		return
	hovered_buttons[button] = false
	button.pivot_offset = button.size / 2.0
	_tween_button(button, original_positions[button], SCALE_NORMAL)

func _tween_button(button: TextureButton, target_pos: Vector2, target_scale: Vector2) -> void:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_parallel(true)
	tween.tween_property(button, "position", target_pos, TWEEN_DURATION)
	tween.tween_property(button, "scale", target_scale, TWEEN_DURATION)




func _on_close_button_pressed() -> void:
	print("closing")
