extends Node

# GameManager - Autoload singleton
# Handles scene transitions, game state, save data, pause logic

signal game_paused
signal game_resumed

enum GameState { MAIN_MENU, PLAYING, PAUSED, MISSION_COMPLETE }

var current_state: GameState = GameState.MAIN_MENU
var has_save: bool = false
var current_mission: String = "A NEW BEGINNING"
var player_position: Vector3 = Vector3.ZERO
var is_first_launch: bool = true

var settings = {
	"master_volume": 1.0,
	"sfx_volume": 1.0,
	"music_volume": 0.8,
	"sensitivity": 1.0,
	"graphics_quality": 1 # 0 low, 1 medium, 2 high
}

func _ready():
	# Load save if exists
	_load_save_data()
	print("[GameManager] Initialized - SHADOW PROTOCOL v0.1.0")
	print("[GameManager] Has save: ", has_save)

func _input(event):
	if event.is_action_pressed("pause"):
		if current_state == GameState.PLAYING:
			pause_game()
		elif current_state == GameState.PAUSED:
			resume_game()

## Returns true when the world scene was loaded. Returns false (and reports an
## error) when it could not be loaded, so the caller can keep the menu visible.
func new_game() -> bool:
	print("[GameManager] Starting new game...")
	has_save = true
	current_mission = "A NEW BEGINNING"
	player_position = Vector3.ZERO
	_save_game_data()
	current_state = GameState.PLAYING
	get_tree().paused = false
	# Transition to world scene
	var err = get_tree().change_scene_to_file("res://scenes/world.tscn")
	if err != OK:
		print("[GameManager] Failed to load world scene: ", err)
		# Fallback: try loading via resource
		var world_scene = load("res://scenes/world.tscn")
		if world_scene:
			err = get_tree().change_scene_to_packed(world_scene)
		if err != OK:
			push_error("[GameManager] Could not load res://scenes/world.tscn (error %d). Staying on the main menu." % err)
			current_state = GameState.MAIN_MENU
			return false
	return true

## Returns true when the world scene was loaded (see new_game).
func continue_game() -> bool:
	if not has_save:
		print("[GameManager] No save found, starting new game instead")
		return new_game()
	print("[GameManager] Continuing game...")
	current_state = GameState.PLAYING
	get_tree().paused = false
	var err = get_tree().change_scene_to_file("res://scenes/world.tscn")
	if err != OK:
		push_error("[GameManager] Could not load res://scenes/world.tscn (error %d). Staying on the main menu." % err)
		current_state = GameState.MAIN_MENU
		return false
	return true

func go_to_main_menu():
	print("[GameManager] Returning to main menu...")
	current_state = GameState.MAIN_MENU
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func restart_mission():
	print("[GameManager] Restarting mission...")
	current_state = GameState.PLAYING
	get_tree().paused = false
	get_tree().reload_current_scene()

func pause_game():
	if current_state != GameState.PLAYING:
		return
	current_state = GameState.PAUSED
	get_tree().paused = true
	emit_signal("game_paused")
	print("[GameManager] Game paused")

func resume_game():
	if current_state != GameState.PAUSED:
		return
	current_state = GameState.PLAYING
	get_tree().paused = false
	emit_signal("game_resumed")
	print("[GameManager] Game resumed")

func complete_mission():
	current_state = GameState.MISSION_COMPLETE
	print("[GameManager] Mission complete: ", current_mission)

func _save_game_data():
	var save_path = "user://shadow_save.cfg"
	var config = ConfigFile.new()
	config.set_value("progress", "has_save", has_save)
	config.set_value("progress", "current_mission", current_mission)
	config.set_value("progress", "player_position_x", player_position.x)
	config.set_value("progress", "player_position_y", player_position.y)
	config.set_value("progress", "player_position_z", player_position.z)
	config.set_value("settings", "master_volume", settings.master_volume)
	config.set_value("settings", "sensitivity", settings.sensitivity)
	var err = config.save(save_path)
	if err == OK:
		print("[GameManager] Save successful")
	else:
		print("[GameManager] Save failed: ", err)

func _load_save_data():
	var save_path = "user://shadow_save.cfg"
	var config = ConfigFile.new()
	var err = config.load(save_path)
	if err != OK:
		print("[GameManager] No save file found, starting fresh")
		has_save = false
		return
	has_save = config.get_value("progress", "has_save", false)
	current_mission = config.get_value("progress", "current_mission", "A NEW BEGINNING")
	player_position.x = config.get_value("progress", "player_position_x", 0.0)
	player_position.y = config.get_value("progress", "player_position_y", 0.0)
	player_position.z = config.get_value("progress", "player_position_z", 0.0)
	settings.master_volume = config.get_value("settings", "master_volume", 1.0)
	settings.sensitivity = config.get_value("settings", "sensitivity", 1.0)
	print("[GameManager] Save loaded")

func set_setting(key: String, value):
	if settings.has(key):
		settings[key] = value
		_save_game_data()

func get_setting(key: String):
	if settings.has(key):
		return settings[key]
	return null
