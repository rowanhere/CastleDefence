extends Resource
class_name TowerData
@export var name: String
@export var upgrades: Array[UpgradeData]


func get_base_upgrade() -> UpgradeData:
	if upgrades.is_empty():
		return null
	return upgrades[0]
