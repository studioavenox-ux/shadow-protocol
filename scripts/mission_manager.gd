extends Node

# Mission Manager - Phase 2 Improved
# Handles "A NEW BEGINNING" with destination marker, dialogue, objective validation

signal objective_updated(index: int, description: String, completed: bool)
signal objective_completed(index: int)
signal mission_completed(mission_name: String)
signal mission_failed(reason: String)
signal show_notification(text: String, duration: float)
signal dialogue_started(speaker: String)
signal dialogue_line(line: String, index: int)
signal dialogue_finished

enum MissionState { NOT_STARTED, IN_PROGRESS, COMPLETED, FAILED }

var current_mission_name: String = "A NEW BEGINNING"
var mission_state: MissionState = MissionState.NOT_STARTED
var current_objective: int = 0

# Objectives for A NEW BEGINNING - Phase 2 with validation
var objectives = [
	{
		"id": "explore",
		"title": "Explore the starting area",
		"description": "Get familiar with Blackwater City. Move around to explore. (0/30m)",
		"completed": false,
		"required_distance": 30.0,
		"optional": false,
		"marker_visible": false
	},
	{
		"id": "find_destination",
		"title": "Locate the underground garage",
		"description": "Find the underground garage - look for the red beacon north of your position.",
		"completed": false,
		"trigger_area": "DestinationTrigger",
		"optional": false,
		"marker_visible": true
	},
	{
		"id": "reach_garage",
		"title": "Reach the garage entrance",
		"description": "Make your way to the garage entrance marked by the beacon. Follow the road north.",
		"completed": false,
		"trigger_area": "GarageEntranceTrigger",
		"optional": false,
		"marker_visible": true
	},
	{
		"id": "meet_marcus",
		"title": "Interact with Marcus Reed",
		"description": "Find Marcus Reed inside the garage and talk to him. [Press E or Interact]",
		"completed": false,
		"interaction_id": "marcus_reed",
		"optional": false,
		"marker_visible": true
	},
	{
		"id": "complete",
		"title": "Mission Complete",
		"description": "You have reunited with Marcus. Welcome back to Blackwater City.",
		"completed": false,
		"optional": false,
		"marker_visible": false
	}
]

var player_distance_traveled: float = 0.0
var has_found_destination: bool = false
var has_reached_garage: bool = false
var dialogue_active: bool = false

@onready var player: CharacterBody3D = null
var destination_marker: Node3D = null
var dialogue_ui: CanvasLayer = null

func _ready():
	print("[MissionManager] Phase 2 - Initializing mission: ", current_mission_name)
	# Find player
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_node_or_null("../Player")
	
	if player:
		if player.has_signal("player_moved"):
			player.player_moved.connect(_on_player_moved)
	
	# Find destination marker
	destination_marker = get_node_or_null("../GarageComplex/DestinationMarker") or get_node_or_null("../../GarageComplex/DestinationMarker") or get_tree().get_first_node_in_group("destination_marker")
	if not destination_marker:
		# Search recursively
		destination_marker = _find_marker(get_tree().current_scene)
	
	if destination_marker:
		destination_marker.visible = false
		print("[MissionManager] Destination marker found")
	
	# Find dialogue UI
	dialogue_ui = get_node_or_null("../DialogueUI") or get_node_or_null("../../DialogueUI")
	
	# Connect to interactables
	_setup_interactable_connections()
	
	# Start mission after short delay
	await get_tree().create_timer(1.2).timeout
	start_mission()

func _find_marker(node: Node) -> Node3D:
	if node == null:
		return null
	if node.name == "DestinationMarker" or node.is_in_group("destination_marker"):
		return node as Node3D
	for child in node.get_children():
		var found = _find_marker(child)
		if found:
			return found
	return null

func _setup_interactable_connections():
	var interactables = get_tree().get_nodes_in_group("interactable")
	for inter in interactables:
		if inter.has_signal("interacted"):
			if not inter.interacted.is_connected(_on_interacted):
				inter.interacted.connect(_on_interacted)
		if inter.has_signal("mission_trigger_completed"):
			if not inter.mission_trigger_completed.is_connected(_on_marcus_dialogue_finished):
				inter.mission_trigger_completed.connect(_on_marcus_dialogue_finished)
	
	_search_interactables(get_tree().current_scene)

func _search_interactables(node: Node):
	if node == null:
		return
	if node is Interactable:
		if not node.interacted.is_connected(_on_interacted):
			node.interacted.connect(_on_interacted)
		if node.has_signal("mission_trigger_completed"):
			if not node.mission_trigger_completed.is_connected(_on_marcus_dialogue_finished):
				node.mission_trigger_completed.connect(_on_marcus_dialogue_finished)
	for child in node.get_children():
		_search_interactables(child)

func start_mission():
	if mission_state != MissionState.NOT_STARTED:
		return
	mission_state = MissionState.IN_PROGRESS
	current_objective = 0
	print("[MissionManager] Mission started: ", current_mission_name)
	emit_signal("show_notification", "Mission Started: " + current_mission_name, 3.5)
	_update_current_objective()
	_update_marker_visibility()

func _update_current_objective():
	if current_objective >= objectives.size():
		_complete_mission()
		return
	
	var obj = objectives[current_objective]
	# Update description with progress for explore
	if obj.id == "explore":
		var progress = int(min(player_distance_traveled, obj.required_distance))
		obj.description = "Get familiar with Blackwater City. Move around to explore. (%d/30m)" % progress
	
	emit_signal("objective_updated", current_objective, obj.description, obj.completed)
	print("[MissionManager] Objective ", current_objective, ": ", obj.title, " - ", obj.description)
	emit_signal("show_notification", "Objective: " + obj.title, 4.0)
	_update_marker_visibility()

func _update_marker_visibility():
	if destination_marker == null:
		return
	if current_objective < 0 or current_objective >= objectives.size():
		destination_marker.visible = false
		return
	
	var obj = objectives[current_objective]
	var should_visible = obj.get("marker_visible", false) and mission_state == MissionState.IN_PROGRESS
	destination_marker.visible = should_visible
	
	if should_visible:
		print("[MissionManager] Destination marker visible for objective: ", obj.id)
	else:
		print("[MissionManager] Destination marker hidden")

func complete_objective(index: int):
	if index < 0 or index >= objectives.size():
		return
	if objectives[index].completed:
		return
	
	# Validation: cannot skip objectives
	if index != current_objective:
		print("[MissionManager] Cannot complete objective ", index, " - current is ", current_objective, " - skipping not allowed")
		return
	
	objectives[index].completed = true
	emit_signal("objective_completed", index)
	emit_signal("objective_updated", index, objectives[index].description, true)
	print("[MissionManager] Objective completed: ", objectives[index].title)
	emit_signal("show_notification", "✓ " + objectives[index].title, 2.8)
	
	# Move to next objective
	if index == current_objective:
		current_objective += 1
		if current_objective < objectives.size():
			await get_tree().create_timer(1.8).timeout
			_update_current_objective()
		else:
			_complete_mission()

func _on_player_moved(distance: float):
	player_distance_traveled = distance
	# Update explore progress
	if current_objective == 0 and not objectives[0].completed:
		var obj = objectives[0]
		var progress = int(min(distance, obj.required_distance))
		obj.description = "Get familiar with Blackwater City. Move around to explore. (%d/30m)" % progress
		emit_signal("objective_updated", 0, obj.description, false)
		
		if distance >= objectives[0].required_distance:
			complete_objective(0)

func _on_interacted(id: String, interactable: Interactable):
	print("[MissionManager] Interacted with: ", id, " current objective: ", current_objective)
	
	# Only allow Marcus interaction if we're at objective 3
	if id == "marcus_reed":
		if current_objective == 3:
			# Start dialogue sequence
			dialogue_active = true
			emit_signal("dialogue_started", "Marcus Reed")
			print("[MissionManager] Starting dialogue with Marcus")
			# Don't complete yet - wait for dialogue to finish
			# The NPC will emit mission_trigger_completed when dialogue done
		else:
			emit_signal("show_notification", "Not yet - complete previous objectives first", 2.5)
			print("[MissionManager] Marcus interaction blocked - wrong objective")

func _on_marcus_dialogue_finished():
	print("[MissionManager] Marcus dialogue finished, completing objectives")
	if current_objective == 3:
		complete_objective(3)
		await get_tree().create_timer(1.0).timeout
		complete_objective(4)

func trigger_area_entered(area_id: String):
	print("[MissionManager] Trigger area entered: ", area_id, " current objective: ", current_objective)
	match area_id:
		"ExploreTrigger":
			# Explore trigger can complete objective 0 as alternative to distance
			if current_objective == 0 and not objectives[0].completed:
				if player_distance_traveled > 10.0: # Need at least some movement
					complete_objective(0)
		"DestinationTrigger":
			# Must be at objective 1, cannot skip
			if current_objective == 1:
				complete_objective(1)
				has_found_destination = true
			elif current_objective < 1:
				emit_signal("show_notification", "Explore the area first", 2.0)
		"GarageEntranceTrigger":
			# Must be at objective 2
			if current_objective == 2:
				complete_objective(2)
				has_reached_garage = true
				emit_signal("show_notification", "Entering underground garage...", 2.5)
			elif current_objective < 2:
				emit_signal("show_notification", "Find the garage first", 2.0)

func _complete_mission():
	if mission_state == MissionState.COMPLETED:
		return
	mission_state = MissionState.COMPLETED
	print("[MissionManager] Mission completed: ", current_mission_name)
	emit_signal("mission_completed", current_mission_name)
	emit_signal("show_notification", "★ Mission Complete: " + current_mission_name, 4.5)
	
	if destination_marker:
		destination_marker.visible = false
	
	if GameManager:
		GameManager.complete_mission()
		GameManager.has_save = true
		GameManager._save_game_data()
	
	await get_tree().create_timer(3.0).timeout
	emit_signal("show_notification", "Welcome to Blackwater City, Alex.", 3.5)
	emit_signal("dialogue_finished")

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

func can_interact_with_marcus() -> bool:
	return current_objective == 3 and mission_state == MissionState.IN_PROGRESS
