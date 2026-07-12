extends TextureButton

const STAR_TEXTURES: Dictionary = {
	1: preload("res://assets/textures/levelWin/star_1.png"),
	2: preload("res://assets/textures/levelWin/star_2.png"),
	3: preload("res://assets/textures/levelWin/star_3.png")
}

@export var level_number: int = 1
@onready var label: Label = $Label
@onready var star_rating: TextureRect = $StarRating


func _ready() -> void:
	label.text = str(level_number)
	var best_stars: int = SaveManager.get_best_stars(level_number)
	star_rating.visible = best_stars > 0
	if best_stars > 0:
		var star_texture := STAR_TEXTURES.get(clampi(best_stars, 1, 3)) as Texture2D
		star_rating.texture = star_texture
