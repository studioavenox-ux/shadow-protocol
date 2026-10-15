extends Node

# Mission Manager - Phase 3: Drivable Vehicles
# Handles "A NEW BEGINNING" with vehicle integration

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

# Objectives Phase 3 with vehicle
var objectives = [
	{
		"id": "explore",
		"title": "Explore the starting area",
		"description": "Get familiar with Blackwater City. Move around to explore. (0/30m)",
		"completed": false,
		"required_distance": 30.0,
		"optional": false,
		"marker_visible": false,
		"type": "explore"
	},
	{
		"id": "find_nightfall",
		"title": "Find the NIGHTFALL sedan",
		"description": "Locate the black NIGHTFALL sports sedan. Look for it near the starting area.",
		"completed": false,
		"trigger_area": "VehicleTrigger",
		"optional": false,
		"marker_visible": true,
		"type": "find_vehicle"
	},
	{
		"id": "enter_vehicle",
		"title": "Enter the NIGHTFALL",
		"description": "Approach the NIGHTFALL and press ENTER VEHICLE to get in.",
		"completed": false,
		"interaction_id": "vehicle_nightfall",
		"optional": false,
		"marker_visible": true,
		"type": "enter_vehicle"
	},
	{
		"id": "drive_to_garage",
		"title": "Drive to Iron Gate Garage",
		"description": "Drive north to the Iron Gate Garage. Follow the red beacon.",
		"completed": false,
		"trigger_area": "GarageEntranceTrigger",
		"optional": false,
		"marker_visible": true,
		"type": "drive"
	},
	{
		"id": "park_vehicle",
		"title": "Park near the destination",
		"description": "Park the NIGHTFALL safely inside or near the garage entrance.",
		"completed": false,
		"trigger_area": "ParkingTrigger",
		"optional": false,
		"marker_visible": true,
		"type": "park"
	},
	{
		"id": "exit_vehicle",
		"title": "Exit the vehicle",
		"description": "Stop the car and exit safely. [Press EXIT or E]",
		"completed": false,
		"interaction_id": "vehicle_exit",
		"optional": false,
		"marker_visible": false,
		"type": "exit_vehicle"
	},
	{
		"id": "meet_marcus",
		"title": "Interact with Marcus Reed",
		"description": "Find Marcus Reed inside the garage and talk to him. [Press E or Interact]",
		"completed": false,
		"interaction_id": "marcus_reed",
		"optional": false,
		"marker_visible": true,
		"type": "interact"
	},
	{
		"id": "complete",
		"title": "Mission Complete",
		"description": "You have reunited with Marcus. Welcome back to Blackwater City.",
		"completed": false,
		"optional": false,
		"marker_visible": false,
		"type": "complete"
	}
]

var player_distance_traveled: float = 0.0
var has_found_destination: bool = false
var has_reached_garage: bool = false
var has_entered_vehicle: bool = false
var has_parked: bool = false
var dialogue_active: bool = false

@onready var player: CharacterBody3D = null
var destination_marker: Node3D = null
var vehicle: VehicleBody3D = null
var dialogue_ui: CanvasLayer = null

func _ready():
	print("[MissionManager] Phase 3 - Vehicle mission: ", current_mission_name)
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_node_or_null("../Player")
	
	if player and player.has_signal("player_moved"):
		player.player_moved.connect(_on_player_moved)
	
	# Find markers and vehicle
	destination_marker = _find_marker(get_tree().current_scene)
	if destination_marker:
		destination_marker.visible = false
		print("[MissionManager] Destination marker found")
	
	vehicle = get_tree().get_first_node_in_group("vehicle")
	if not vehicle:
		vehicle = _find_vehicle(get_tree().current_scene)
	
	if vehicle:
		print("[MissionManager] Vehicle found: ", vehicle.name)
		if vehicle.has_signal("player_entered_vehicle"):
			vehicle.player_entered_vehicle.connect(_on_vehicle_entered)
		if vehicle.has_signal("player_exited_vehicle"):
			vehicle.player_exited_vehicle.connect(_on_vehicle_exited)
	
	# DialogueUI (CanvasLayer) is a direct child of the World root, as is this
	# MissionManager node (scenes/world.tscn), so the sibling path is "../DialogueUI".
	dialogue_ui = _find_dialogue_ui()
	if dialogue_ui == null:
		push_warning("[MissionManager] DialogueUI CanvasLayer not found (expected sibling \"DialogueUI\" under World). Dialogue UI will be disabled.")
	
	_setup_interactable_connections()
	
	await get_tree().create_timer(1.2).timeout
	start_mission()

func _find_dialogue_ui() -> CanvasLayer:
	# Typed lookup: returns null (never a Boolean) when the node is missing or is not a CanvasLayer.
	var node: CanvasLayer = get_node_or_null("../DialogueUI") as CanvasLayer
	if node == null:
		node = get_tree().get_first_node_in_group("dialogue_ui") as CanvasLayer
	return node

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

func _find_vehicle(node: Node) -> VehicleBody3D:
	if node == null:
		return null
	if node is VehicleBody3D:
		return node as VehicleBody3D
	for child in node.get_children():
		var found = _find_vehicle(child)
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
		if inter.has_signal("vehicle_enter_requested"):
			if not inter.vehicle_enter_requested.is_connected(_on_vehicle_enter_requested):
				inter.vehicle_enter_requested.connect(_on_vehicle_enter_requested)
		if inter.has_signal("vehicle_exit_requested"):
			if not inter.vehicle_exit_requested.is_connected(_on_vehicle_exit_requested):
				inter.vehicle_exit_requested.connect(_on_vehicle_exit_requested)
	
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
		if node.has_signal("vehicle_enter_requested"):
			if not node.vehicle_enter_requested.is_connected(_on_vehicle_enter_requested):
				node.vehicle_enter_requested.connect(_on_vehicle_enter_requested)
		if node.has_signal("vehicle_exit_requested"):
			if not node.vehicle_exit_requested.is_connected(_on_vehicle_exit_requested):
				node.vehicle_exit_requested.connect(_on_vehicle_exit_requested)
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

func complete_objective(index: int):
	if index < 0 or index >= objectives.size():
		return
	if objectives[index].completed:
		return
	if index != current_objective:
		print("[MissionManager] Cannot skip objective ", index, " current ", current_objective)
		return
	
	objectives[index].completed = true
	emit_signal("objective_completed", index)
	emit_signal("objective_updated", index, objectives[index].description, true)
	print("[MissionManager] Objective completed: ", objectives[index].title)
	emit_signal("show_notification", "✓ " + objectives[index].title, 2.8)
	
	# Audio feedback - mission completion audio hook
	var audio_mgr = get_tree().get_first_node_in_group("audio_manager")
	if audio_mgr and audio_mgr.has_method("play_mission_complete") and index == objectives.size() - 1:
		audio_mgr.play_mission_complete()
	elif audio_mgr and audio_mgr.has_method("play_interaction_feedback"):
		audio_mgr.play_interaction_feedback()
	
	if index == current_objective:
		current_objective += 1
		if current_objective < objectives.size():
			await get_tree().create_timer(1.8).timeout
			_update_current_objective()
		else:
			_complete_mission()

func _on_player_moved(distance: float):
	player_distance_traveled = distance
	if current_objective == 0 and not objectives[0].completed:
		var obj = objectives[0]
		var progress = int(min(distance, obj.required_distance))
		obj.description = "Get familiar with Blackwater City. Move around to explore. (%d/30m)" % progress
		emit_signal("objective_updated", 0, obj.description, false)
		if distance >= objectives[0].required_distance:
			complete_objective(0)

func _on_interacted(id: String, interactable: Interactable):
	print("[MissionManager] Interacted: ", id, " current: ", current_objective)
	
	if id.begins_with("vehicle"):
		if id == "vehicle_nightfall" and current_objective == 2:
			# Enter handled via vehicle signal, but mark if needed
			pass
		elif id == "marcus_reed":
			if current_objective == 6:
				dialogue_active = true
				emit_signal("dialogue_started", "Marcus Reed")
			else:
				emit_signal("show_notification", "Not yet - complete previous objectives first", 2.5)
	elif id == "marcus_reed":
		if current_objective == 6:
			dialogue_active = true
			emit_signal("dialogue_started", "Marcus Reed")
		else:
			emit_signal("show_notification", "Not yet - complete previous objectives first", 2.5)

func _on_vehicle_enter_requested(veh: VehicleBody3D):
	print("[MissionManager] Vehicle enter requested")
	if current_objective == 2:
		# Will complete when actually entered
		pass

func _on_vehicle_exit_requested(veh: VehicleBody3D):
	print("[MissionManager] Vehicle exit requested")
	if current_objective == 5:
		# Will complete when actually exited
		pass

func _on_vehicle_entered(veh: VehicleBody3D):
	print("[MissionManager] Vehicle entered")
	has_entered_vehicle = true
	if current_objective == 2:
		complete_objective(2)
		# Also complete find_nightfall if not yet
		if current_objective == 1 and not objectives[1].completed:
			# Find was via trigger, but if they entered directly, complete it
			objectives[1].completed = true
			emit_signal("objective_completed", 1)
			current_objective = 3
			_update_current_objective()
	elif current_objective == 1:
		# If they find and enter immediately
		complete_objective(1)
		complete_objective(2)

func _on_vehicle_exited(veh: VehicleBody3D):
	print("[MissionManager] Vehicle exited")
	if current_objective == 5:
		complete_objective(5)

func _on_marcus_dialogue_finished():
	print("[MissionManager] Marcus dialogue finished")
	if current_objective == 6:
		complete_objective(6)
		await get_tree().create_timer(1.0).timeout
		complete_objective(7)

func trigger_area_entered(area_id: String):
	print("[MissionManager] Trigger entered: ", area_id, " current: ", current_objective)
	match area_id:
		"ExploreTrigger":
			if current_objective == 0 and not objectives[0].completed and player_distance_traveled > 10.0:
				complete_objective(0)
		"VehicleTrigger":
			if current_objective == 1:
				complete_objective(1)
		"DestinationTrigger":
			if current_objective == 3:
				complete_objective(3)
				has_found_destination = true
				emit_signal("show_notification", "Iron Gate Garage ahead - park safely", 3.0)
			elif current_objective < 3 and current_objective > 1:
				emit_signal("show_notification", "Enter the NIGHTFALL first", 2.0)
		"GarageEntranceTrigger":
			if current_objective == 3:
				complete_objective(3)
				has_reached_garage = true
		"ParkingTrigger":
			if current_objective == 4:
				# Phase 4: Require proper garage positioning - check speed AND garage bounds
				if not vehicle:
					vehicle = get_tree().get_first_node_in_group("vehicle")
				if vehicle:
					var speed_ok = vehicle.get_speed_kmh() < 5.0
					var pos = vehicle.global_position
					# Garage bounds: Iron Gate Garage floor 26x32 at 0,0,75 - allow margin
					# Garage area: x in [-15, 15], z in [60, 92], y near 0-5
					var in_garage_bounds = pos.x > -16 and pos.x < 16 and pos.z > 58 and pos.z < 94 and pos.y < 6.0
					# Also check distance to garage center (0,0,75) < 18
					var garage_center = Vector3(0, pos.y, 75)
					var dist_to_center = pos.distance_to(garage_center)
					var properly_positioned = in_garage_bounds and dist_to_center < 20.0
					
					if not speed_ok:
						emit_signal("show_notification", "Stop the vehicle to park (%.0f km/h)" % vehicle.get_speed_kmh(), 2.0)
					elif not properly_positioned:
						emit_signal("show_notification", "Position vehicle properly inside garage [%.0fm from center]" % dist_to_center, 2.5)
						print("[MissionManager] Parking failed - not properly positioned: pos ", pos, " dist ", dist_to_center, " bounds ", in_garage_bounds)
					else:
						complete_objective(4)
						has_parked = true
						emit_signal("show_notification", "Parked inside Iron Gate Garage - exit vehicle", 2.5)
						print("[MissionManager] Parking succeeded - properly positioned at ", pos)
				else:
					emit_signal("show_notification", "Vehicle not found", 1.5)

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
	emit_signal("show_notification", "Welcome to Blackwater City, Alex. The NIGHTFALL is yours.", 3.5)
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
	return current_objective == 6 and mission_state == MissionState.IN_PROGRESS
