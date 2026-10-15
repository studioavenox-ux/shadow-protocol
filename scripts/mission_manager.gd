extends Node

# Mission Manager - Handles "A NEW BEGINNING" and future missions
# Tracks objectives, triggers, and mission progression

signal objective_updated(index: int, description: String, completed: bool)
signal objective_completed(index: int)
signal mission_completed(mission_name: String)
signal mission_failed(reason: String)
signal show_notification(text: String, duration: float)

enum MissionState { NOT_STARTED, IN_PROGRESS, COMPLETED, FAILED }

var current_mission_name: String = "A NEW BEGINNING"
var mission_state: MissionState = MissionState.NOT_STARTED
var current_objective: int = 0

# Objectives for A NEW BEGINNING
var objectives = [
	{
		"id": "explore",
		"title": "Explore the starting area",
		"description": "Get familiar with Blackwater City. Move around to explore.",
		"completed": false,
		"required_distance": 30.0, # meters to travel
		"optional": false
	},
	{
		"id": "find_destination",
		"title": "Find the mission destination",
		"description": "Locate the underground parking garage. Check your surroundings.",
		"completed": false,
		"trigger_area": "DestinationTrigger",
		"optional": false
	},
	{
		"id": "reach_garage",
		"title": "Reach the garage entrance",
		"description": "Make your way to the underground garage entrance marked on your map.",
		"completed": false,
		"trigger_area": "GarageEntranceTrigger",
		"optional": false
	},
	{
		"id": "meet_marcus",
		"title": "Interact with Marcus Reed",
		"description": "Find Marcus Reed inside the garage and talk to him.",
		"completed": false,
		"interaction_id": "marcus_reed",
		"optional": false
	},
	{
		"id": "complete",
		"title": "Mission Complete",
		"description": "You have reunited with Marcus. Welcome back to Blackwater City.",
		"completed": false,
		"optional": false
	}
]

var player_distance_traveled: float = 0.0
var has_found_destination: bool = false
var has_reached_garage: bool = false

@onready var player: CharacterBody3D = null

func _ready():
	print("[MissionManager] Initializing mission: ", current_mission_name)
	# Find player
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_node_or_null("../Player")
	
	if player:
		if player.has_signal("player_moved"):
			player.player_moved.connect(_on_player_moved)
	
	# Connect to interactables
	_setup_interactable_connections()
	
	# Start mission after short delay
	await get_tree().create_timer(1.0).timeout
	start_mission()

func _setup_interactable_connections():
	# Find all interactables in scene
	var interactables = get_tree().get_nodes_in_group("interactable")
	for inter in interactables:
		if inter.has_signal("interacted"):
			inter.interacted.connect(_on_interacted)
	
	# Also search via scene tree
	_search_interactables(get_tree().current_scene)

func _search_interactables(node: Node):
	if node is Interactable:
		if not node.interacted.is_connected(_on_interacted):
			node.interacted.connect(_on_interacted)
	for child in node.get_children():
		_search_interactables(child)

func start_mission():
	if mission_state != MissionState.NOT_STARTED:
		return
	mission_state = MissionState.IN_PROGRESS
	current_objective = 0
	print("[MissionManager] Mission started: ", current_mission_name)
	emit_signal("show_notification", "Mission Started: " + current_mission_name, 3.0)
	_update_current_objective()

func _update_current_objective():
	if current_objective >= objectives.size():
		_complete_mission()
		return
	
	var obj = objectives[current_objective]
	emit_signal("objective_updated", current_objective, obj.description, obj.completed)
	print("[MissionManager] Objective ", current_objective, ": ", obj.title, " - ", obj.description)
	emit_signal("show_notification", "Objective: " + obj.title, 3.5)

func complete_objective(index: int):
	if index < 0 or index >= objectives.size():
		return
	if objectives[index].completed:
		return
	
	objectives[index].completed = true
	emit_signal("objective_completed", index)
	emit_signal("objective_updated", index, objectives[index].description, true)
	print("[MissionManager] Objective completed: ", objectives[index].title)
	emit_signal("show_notification", "Objective Complete: " + objectives[index].title, 2.5)
	
	# Move to next objective if this was current
	if index == current_objective:
		current_objective += 1
		if current_objective < objectives.size():
			# Small delay before next objective
			await get_tree().create_timer(1.5).timeout
			_update_current_objective()
		else:
			_complete_mission()

func _on_player_moved(distance: float):
	player_distance_traveled = distance
	# Check explore objective
	if current_objective == 0 and not objectives[0].completed:
		if distance >= objectives[0].required_distance:
			complete_objective(0)

func _on_interacted(id: String, interactable: Interactable):
	print("[MissionManager] Interacted with: ", id)
	if id == "marcus_reed":
		if current_objective == 3:
			complete_objective(3)
			# After dialogue, complete mission
			await get_tree().create_timer(2.0).timeout
			if interactable is Node and interactable.has_signal("mission_trigger_completed"):
				# Wait for Marcus dialogue to finish
				pass
			complete_objective(4)

func trigger_area_entered(area_id: String):
	print("[MissionManager] Trigger area entered: ", area_id)
	match area_id:
		"ExploreTrigger":
			if current_objective == 0 and not objectives[0].completed:
				complete_objective(0)
		"DestinationTrigger":
			if current_objective == 1:
				complete_objective(1)
				has_found_destination = true
		"GarageEntranceTrigger":
			if current_objective == 2:
				complete_objective(2)
				has_reached_garage = true
				emit_signal("show_notification", "Entering underground garage...", 2.0)

func _complete_mission():
	if mission_state == MissionState.COMPLETED:
		return
	mission_state = MissionState.COMPLETED
	print("[MissionManager] Mission completed: ", current_mission_name)
	emit_signal("mission_completed", current_mission_name)
	emit_signal("show_notification", "Mission Complete: " + current_mission_name, 4.0)
	
	if GameManager:
		GameManager.complete_mission()
		GameManager.has_save = true
		GameManager._save_game_data()
	
	# Show mission complete UI after delay
	await get_tree().create_timer(3.0).timeout
	emit_signal("show_notification", "Welcome to Blackwater City, Alex.", 3.0)

func _fail_mission(reason: String):
	mission_state = MissionState.FAILED
	emit_signal("mission_failed", reason)
	print("[MissionManager] Mission failed: ", reason)

func get_current_objective_text() -> String:
	if current_objective >= 0 and current_objective < objectives.size():
		return objectives[current_objective].description
	return "No active objective"

func get_current_objective_title() -> String:
	if current_objective >= 0 and current_objective < objectives.size():
		return objectives[current_objective].title
	return ""

func get_mission_progress() -> float:
	var completed = 0
	for obj in objectives:
		if obj.completed:
			completed += 1
	return float(completed) / float(objectives.size())

func is_objective_completed(index: int) -> bool:
	if index >= 0 and index < objectives.size():
		return objectives[index].completed
	return false
