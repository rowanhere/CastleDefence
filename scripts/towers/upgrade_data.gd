@tool
extends Resource
class_name UpgradeData

@export var upgradeCost: int = 500
@export var damage:float = 10.00
@export var attackSpeed:float= 1.00
@export var tower_range:float
@export_range(0.0, 100.0, 1.0) var slowPercent: float = 0.0
@export var towerImage: Texture2D
@export var isBombTower: bool = false:
	set(value):
		isBombTower = value
		notify_property_list_changed()
@export var launcherAImage: Texture2D
@export var launcherBImage: Texture2D
@export var level: int = 1 
@export var isTowerTop: bool = false
@export var towerTop: Texture2D


func _validate_property(property: Dictionary) -> void:
	if property.name == "launcherAImage" or property.name == "launcherBImage":
		if not isBombTower:
			property.usage = property.usage & ~PROPERTY_USAGE_EDITOR
