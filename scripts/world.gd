extends Node3D

# World - Blackwater City Phase 4: Police Pursuit & Audio
# Manages environment, triggers, interaction, mission, vehicle, HUD switching, police, audio

@onready var player: CharacterBody3D = $Player
@onready var mission_manager = $MissionManager
@onready var game_hud = $UI/GameHUD
@onready var driving_hud = $UI/DrivingHUD
@onready var pause_menu = $UI/PauseMenu
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var directional_light: DirectionalLight3D = $DirectionalLight3D

var current_interactable: Interactable = null
var interactables_in_range: Array[Interactable] = []
var destination_marker: Node3D = null
var vehicle: VehicleBody3D = null
var is_in_vehicle: bool = false

# Phase 4 managers
var wanted_manager: Node = null
var audio_manager: Node = null
var environment_manager: Node = null

func _ready():
	print("[World] Phase 4 - Blackwater City with NIGHTFALL + Police Pursuit + Audio...")
	
	_setup_environment()
	_setup_phase4_managers()
	_setup_interactables()
	_setup_triggers()
	_setup_destination_marker()
	_setup_vehicle()
	_setup_hud_switching()
	
	if game_hud:
		print("[World] GameHUD found")
	if driving_hud:
		driving_hud.visible = false
		print("[World] DrivingHUD found - hidden")
	
	if player:
		player.global_position = $PlayerSpawn.global_position if has_node("PlayerSpawn") else Vector3(0, 2, 0)
		print("[World] Player spawned at: ", player.global_position)
	
	await get_tree().create_timer(1.5).timeout
	if mission_manager and mission_manager.has_signal("show_notification"):
		mission_manager.show_notification.emit("BLACKWATER CITY - DISTRICT 7 - 11:47 PM", 3.5)
	
	await get_tree().create_timer(3.0).timeout
	if mission_manager and mission_manager.has_signal("show_notification"):
		mission_manager.show_notification.emit("Find the NIGHTFALL sedan - black sports car", 4.0)
	
	print("[World] Blackwater City ready - Phase 4: Vehicle fixed, Police, Audio - EVERY CHOICE LEAVES A TRACE")

func _setup_environment():
	if directional_light:
		directional_light.light_energy = 0.85
		directional_light.shadow_enabled = true
		directional_light.shadow_blur = 1.2
		directional_light.shadow_bias = 0.04
		directional_light.rotation_degrees = Vector3(-50, 35, 0)

func _setup_phase4_managers():
	# Wanted Manager
	if has_node("WantedManager"):
		wanted_manager = $WantedManager
	else:
		# Create wanted manager
		var wm_script = load("res://scripts/wanted_manager.gd")
		if wm_script:
			wanted_manager = Node.new()
			wanted_manager.name = "WantedManager"
			wanted_manager.set_script(wm_script)
			add_child(wanted_manager)
			print("[World] WantedManager created")
	
	# Audio Manager
	if has_node("AudioManager"):
		audio_manager = $AudioManager
	else:
		var am_script = load("res://scripts/audio_manager.gd")
		if am_script:
			audio_manager = Node.new()
			audio_manager.name = "AudioManager"
			audio_manager.set_script(am_script)
			add_child(audio_manager)
			print("[World] AudioManager created")
	
	# Environment Manager
	if has_node("EnvironmentManager"):
		environment_manager = $EnvironmentManager
	else:
		var em_script = load("res://scripts/environment_manager.gd")
		if em_script:
			environment_manager = Node.new()
			environment_manager.name = "EnvironmentManager"
			environment_manager.set_script(em_script)
			add_child(environment_manager)
			print("[World] EnvironmentManager created")

func _setup_destination_marker():
	destination_marker = get_node_or_null("GarageComplex/DestinationMarker")
	if not destination_marker:
		destination_marker = _find_node_by_name(self, "DestinationMarker")
	if destination_marker:
		destination_marker.visible = false
		destination_marker.add_to_group("destination_marker")
		print("[World] Destination marker initialized")

func _find_node_by_name(root: Node, name: String) -> Node:
	if root.name == name:
		return root
	for child in root.get_children():
		var found = _find_node_by_name(child, name)
		if found:
			return found
	return null

func _setup_vehicle():
	vehicle = get_tree().get_first_node_in_group("vehicle")
	if not vehicle:
		vehicle = _find_vehicle(self)
	
	if vehicle:
		print("[World] Vehicle found: ", vehicle.name, " at ", vehicle.global_position)
		if vehicle.has_signal("player_entered_vehicle"):
			if not vehicle.player_entered_vehicle.is_connected(_on_player_entered_vehicle):
				vehicle.player_entered_vehicle.connect(_on_player_entered_vehicle)
		if vehicle.has_signal("player_exited_vehicle"):
			if not vehicle.player_exited_vehicle.is_connected(_on_player_exited_vehicle):
				vehicle.player_exited_vehicle.connect(_on_player_exited_vehicle)
		
		if driving_hud and driving_hud.has_method("set_vehicle"):
			driving_hud.set_vehicle(vehicle)
	else:
		print("[World] WARNING: No vehicle found in scene!")

func _find_vehicle(node: Node) -> VehicleBody3D:
	if node is VehicleBody3D and not node.is_in_group("police"):
		return node as VehicleBody3D
	for child in node.get_children():
		var found = _find_vehicle(child)
		if found:
			return found
	return null

func _setup_hud_switching():
	if game_hud:
		game_hud.visible = true
	if driving_hud:
		driving_hud.visible = false

func _setup_interactables():
	var all_interactables: Array = []
	for node in get_tree().get_nodes_in_group("interactable"):
		if node not in all_interactables:
			all_interactables.append(node)
	
	_recursive_find_interactables(self, all_interactables)
	
	print("[World] Found ", all_interactables.size(), " interactables")
	
	for inter in all_interactables:
		if inter is Interactable:
			if not inter.player_entered_range.is_connected(_on_interactable_entered_range):
				inter.player_entered_range.connect(_on_interactable_entered_range)
			if not inter.player_exited_range.is_connected(_on_interactable_exited_range):
				inter.player_exited_range.connect(_on_interactable_exited_range)

func _recursive_find_interactables(node: Node, list: Array):
	for child in node.get_children():
		if child is Interactable and child not in list:
			list.append(child)
		_recursive_find_interactables(child, list)

func _setup_triggers():
	var trigger_names = ["ExploreTrigger", "VehicleTrigger", "DestinationTrigger", "GarageEntranceTrigger", "ParkingTrigger"]
	for t_name in trigger_names:
		var trigger = get_node_or_null("MissionTriggers/" + t_name)
		if trigger and trigger is Area3D:
			trigger.body_entered.connect(func(body): _on_trigger_entered(body, t_name))
			trigger.monitoring = true
			print("[World] Trigger connected: ", t_name)

func _on_trigger_entered(body, trigger_id: String):
	if not body.is_in_group("player") and not body.is_in_group("vehicle") and body.name != "Player" and not body is CharacterBody3D and not body is VehicleBody3D:
		return
	
	print("[World] Trigger entered: ", trigger_id, " by ", body.name)
	
	if mission_manager and mission_manager.has_method("trigger_area_entered"):
		mission_manager.trigger_area_entered(trigger_id)
	
	if trigger_id == "DestinationTrigger" and game_hud and game_hud.has_method("show_notification"):
		if not is_in_vehicle:
			game_hud.show_notification("Garage located - you need the NIGHTFALL to get there fast", 3.0)
		else:
			if driving_hud and driving_hud.has_method("show_notification"):
				driving_hud.show_notification("Iron Gate Garage ahead - park safely", 2.5)

func _on_interactable_entered_range(interactable: Interactable):
	if interactable in interactables_in_range:
		return
	interactables_in_range.append(interactable)
	_update_current_interactable()
	print("[World] Interactable in range: ", interactable.interaction_id)

func _on_interactable_exited_range(interactable: Interactable):
	interactables_in_range.erase(interactable)
	_update_current_interactable()
	print("[World] Interactable out of range: ", interactable.interaction_id)

func _update_current_interactable():
	if interactables_in_range.is_empty():
		current_interactable = null
		if not is_in_vehicle and game_hud and game_hud.has_method("clear_interaction_prompt"):
			game_hud.clear_interaction_prompt()
		return
	
	var closest: Interactable = null
	var closest_dist: float = INF
	
	var reference_pos = player.global_position if player and not is_in_vehicle else (vehicle.global_position if vehicle else Vector3.ZERO)
	
	for inter in interactables_in_range:
		if not is_instance_valid(inter):
			continue
		var dist = reference_pos.distance_to(inter.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = inter
	
	current_interactable = closest
	
	if not is_in_vehicle and game_hud and game_hud.has_method("set_interaction_prompt"):
		game_hud.set_interaction_prompt(current_interactable)

func _on_player_entered_vehicle(veh: VehicleBody3D):
	is_in_vehicle = true
	print("[World] Player entered vehicle - switching HUDs, preventing control conflict")
	
	# Prevent control conflict: disable on-foot HUD, hide interaction prompts
	if game_hud:
		game_hud.visible = false
		if game_hud.has_method("clear_interaction_prompt"):
			game_hud.clear_interaction_prompt()
		# Disable mobile joystick
		game_hud.process_mode = Node.PROCESS_MODE_DISABLED
	
	if driving_hud:
		driving_hud.visible = true
		driving_hud.process_mode = Node.PROCESS_MODE_INHERIT
		if driving_hud.has_method("set_vehicle"):
			driving_hud.set_vehicle(veh)
	
	interactables_in_range.clear()
	current_interactable = null
	
	# Camera switching
	if player:
		var player_cam_pivot = player.get_node_or_null("CameraPivot")
		if player_cam_pivot:
			var player_cam = player_cam_pivot.get_node_or_null("SpringArm3D/Camera3D")
			if player_cam and player_cam is Camera3D:
				player_cam.current = false
	
	if veh:
		var veh_cam_pivot = veh.get_node_or_null("CameraPivot")
		if veh_cam_pivot:
			var veh_cam = veh_cam_pivot.get_node_or_null("SpringArm3D/Camera3D")
			if veh_cam and veh_cam is Camera3D:
				veh_cam.current = true
	
	# Police: vehicle theft increases wanted
	if wanted_manager and wanted_manager.has_method("on_vehicle_theft"):
		# Only if not already in vehicle mission context - for testing police
		if mission_manager and mission_manager.current_objective > 2:
			pass # Don't increase wanted during tutorial theft
		else:
			wanted_manager.on_vehicle_theft()

func _on_player_exited_vehicle(veh: VehicleBody3D):
	is_in_vehicle = false
	print("[World] Player exited vehicle - restoring HUDs, preventing control conflict")
	
	if driving_hud:
		driving_hud.visible = false
		driving_hud.process_mode = Node.PROCESS_MODE_DISABLED
	
	if game_hud:
		game_hud.visible = true
		game_hud.process_mode = Node.PROCESS_MODE_INHERIT
	
	if player:
		var player_cam_pivot = player.get_node_or_null("CameraPivot")
		if player_cam_pivot:
			var player_cam = player_cam_pivot.get_node_or_null("SpringArm3D/Camera3D")
			if player_cam and player_cam is Camera3D:
				player_cam.current = true
	
	if veh:
		var veh_cam_pivot = veh.get_node_or_null("CameraPivot")
		if veh_cam_pivot:
			var veh_cam = veh_cam_pivot.get_node_or_null("SpringArm3D/Camera3D")
			if veh_cam and veh_cam is Camera3D:
				veh_cam.current = false
	
	_setup_interactables()

func _input(event):
	if event.is_action_pressed("interact"):
		if not is_in_vehicle and current_interactable:
			current_interactable.interact()
			if audio_manager and audio_manager.has_method("play_interaction_feedback"):
				audio_manager.play_interaction_feedback()
		elif is_in_vehicle and vehicle:
			if vehicle.has_method("can_exit") and vehicle.can_exit():
				vehicle.exit_vehicle()

func _process(delta):
	if interactables_in_range.size() > 1 and player and not is_in_vehicle:
		_update_current_interactable()
	
	if destination_marker and destination_marker.visible and player:
		var beacon_top = destination_marker.get_node_or_null("BeaconTop")
		if beacon_top:
			var pulse = 1.0 + sin(Time.get_ticks_msec() / 300.0) * 0.1
			beacon_top.scale = Vector3(pulse, pulse, pulse)
	
	# Check speeding for police
	if is_in_vehicle and vehicle and wanted_manager:
		var speed = vehicle.get_speed_kmh() if vehicle.has_method("get_speed_kmh") else 0.0
		if speed > 100.0 and wanted_manager.has_method("on_speeding"):
			# Only occasionally trigger to avoid spam
			if randf() < 0.02:
				wanted_manager.on_speeding(speed)

func get_player() -> CharacterBody3D:
	return player

func get_mission_manager():
	return mission_manager

func get_vehicle() -> VehicleBody3D:
	return vehicle

func get_destination_marker() -> Node3D:
	return destination_marker

func is_player_in_vehicle() -> bool:
	return is_in_vehicle

func get_wanted_manager():
	return wanted_manager

func get_audio_manager():
	return audio_manager
