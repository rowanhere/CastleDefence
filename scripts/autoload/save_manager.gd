extends Node

const SAVE_PATH := "user://save.cfg"
const SAVE_VERSION := 2
const DEFAULT_ABILITY_COUNTS: Dictionary = {
	"fire": 1,
	"freeze": 1,
	"thunder": 1,
	"rock": 1,
}

var total_rewards: int = 0
var unlocked_levels: Array[int] = [1]
var best_stars_by_level: Dictionary = {}
var highest_completed_level: int = 0
var music_enabled: bool = true
var sound_enabled: bool = true
var ability_counts: Dictionary = DEFAULT_ABILITY_COUNTS.duplicate()


func _ready() -> void:
	load_game()


func load_game() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		save_game()
		return

	total_rewards = maxi(int(config.get_value("progress", "total_rewards", 0)), 0)
	highest_completed_level = maxi(int(config.get_value("progress", "highest_completed_level", 0)), 0)
	music_enabled = bool(config.get_value("settings", "music_enabled", true))
	sound_enabled = bool(config.get_value("settings", "sound_enabled", true))
	ability_counts = DEFAULT_ABILITY_COUNTS.duplicate()
	var saved_abilities: Dictionary = config.get_value("inventory", "special_abilities", {})
	for ability_id in DEFAULT_ABILITY_COUNTS:
		var default_count: int = int(DEFAULT_ABILITY_COUNTS[ability_id])
		ability_counts[ability_id] = maxi(int(saved_abilities.get(ability_id, default_count)), 0)

	unlocked_levels.clear()
	var saved_levels: Array = config.get_value("progress", "unlocked_levels", [1])
	for value in saved_levels:
		var level_number := int(value)
		if level_number > 0 and level_number not in unlocked_levels:
			unlocked_levels.append(level_number)
	if 1 not in unlocked_levels:
		unlocked_levels.append(1)
	unlocked_levels.sort()

	best_stars_by_level.clear()
	var saved_stars: Dictionary = config.get_value("progress", "best_stars_by_level", {})
	for key in saved_stars:
		var level_number := int(key)
		if level_number > 0:
			best_stars_by_level[str(level_number)] = clampi(int(saved_stars[key]), 0, 3)


func save_game() -> void:
	var config := ConfigFile.new()
	config.set_value("save", "version", SAVE_VERSION)
	config.set_value("progress", "total_rewards", total_rewards)
	config.set_value("progress", "unlocked_levels", unlocked_levels)
	config.set_value("progress", "best_stars_by_level", best_stars_by_level)
	config.set_value("progress", "highest_completed_level", highest_completed_level)
	config.set_value("settings", "music_enabled", music_enabled)
	config.set_value("settings", "sound_enabled", sound_enabled)
	config.set_value("inventory", "special_abilities", ability_counts)
	var error := config.save(SAVE_PATH)
	if error != OK:
		push_error("SaveManager: failed to save progress (%s)" % error_string(error))


func complete_level(level_number: int, stars: int, reward: int) -> void:
	var safe_level := maxi(level_number, 1)
	var safe_stars := clampi(stars, 1, 3)
	var safe_reward := maxi(reward, 0)
	var level_key := str(safe_level)

	total_rewards += safe_reward
	best_stars_by_level[level_key] = maxi(int(best_stars_by_level.get(level_key, 0)), safe_stars)
	highest_completed_level = maxi(highest_completed_level, safe_level)
	var next_level := safe_level + 1
	if next_level not in unlocked_levels:
		unlocked_levels.append(next_level)
		unlocked_levels.sort()
	save_game()


func get_best_stars(level_number: int) -> int:
	return int(best_stars_by_level.get(str(level_number), 0))


func can_afford_reward_cost(cost: int) -> bool:
	return total_rewards >= maxi(cost, 0)


func spend_rewards(cost: int) -> bool:
	var safe_cost := maxi(cost, 0)
	if total_rewards < safe_cost:
		return false
	total_rewards -= safe_cost
	save_game()
	return true


func add_rewards(amount: int) -> void:
	total_rewards += maxi(amount, 0)
	save_game()


func get_ability_count(ability_id: StringName) -> int:
	return maxi(int(ability_counts.get(str(ability_id), 0)), 0)


func add_ability(ability_id: StringName, amount: int = 1) -> void:
	var key: String = str(ability_id)
	if not DEFAULT_ABILITY_COUNTS.has(key) or amount <= 0:
		return
	ability_counts[key] = get_ability_count(ability_id) + amount
	save_game()


func consume_ability(ability_id: StringName) -> bool:
	var key: String = str(ability_id)
	var current_count: int = get_ability_count(ability_id)
	if not DEFAULT_ABILITY_COUNTS.has(key) or current_count <= 0:
		return false
	ability_counts[key] = current_count - 1
	save_game()
	return true


func purchase_ability(ability_id: StringName, cost: int) -> bool:
	var key: String = str(ability_id)
	var safe_cost: int = maxi(cost, 0)
	if not DEFAULT_ABILITY_COUNTS.has(key) or total_rewards < safe_cost:
		return false
	total_rewards -= safe_cost
	ability_counts[key] = get_ability_count(ability_id) + 1
	save_game()
	return true


func purchase_abilities(purchases: Dictionary, prices: Dictionary) -> bool:
	var total_cost: int = 0
	for ability_id in purchases:
		var key: String = str(ability_id)
		var quantity: int = maxi(int(purchases[ability_id]), 0)
		if not DEFAULT_ABILITY_COUNTS.has(key) or not prices.has(ability_id):
			return false
		total_cost += quantity * maxi(int(prices[ability_id]), 0)
	if total_cost <= 0 or total_rewards < total_cost:
		return false
	total_rewards -= total_cost
	for ability_id in purchases:
		var quantity: int = maxi(int(purchases[ability_id]), 0)
		if quantity > 0:
			var key: String = str(ability_id)
			ability_counts[key] = get_ability_count(StringName(key)) + quantity
	save_game()
	return true


func set_music_enabled(enabled: bool) -> void:
	if music_enabled == enabled:
		return
	music_enabled = enabled
	save_game()


func set_sound_enabled(enabled: bool) -> void:
	if sound_enabled == enabled:
		return
	sound_enabled = enabled
	save_game()


func reset_progress() -> void:
	total_rewards = 0
	unlocked_levels = [1]
	best_stars_by_level.clear()
	highest_completed_level = 0
	ability_counts = DEFAULT_ABILITY_COUNTS.duplicate()
	save_game()
