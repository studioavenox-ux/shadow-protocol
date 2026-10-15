extends Node3D

# World - Blackwater City main world script (Phase 2 Improved)
# Manages environment, triggers, interaction system, mission flow, props

@onready var player: CharacterBody3D = $Player
@onready var mission_manager = $MissionManager
@onready var game_hud = $UI/GameHUD
@onready var pause_menu = $UI/PauseMenu
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var directional_light: DirectionalLight3D = $DirectionalLight3D

var current_interactable: Interactable = null
var interactables_in_range: Array[Interactable] = []
var destination_marker: Node3D = null

func _ready():
	print("[World] Phase 2 - Initializing Blackwater City District...")
	
	_setup_environment()
	_setup_interactables()
	_setup_triggers()
	_setup_destination_marker()
	
	if game_hud:
		print("[World] GameHUD found - Phase 2 polished")
	
	if player:
		player.global_position = $PlayerSpawn.global_position if has_node("PlayerSpawn") else Vector3(0, 2, 0)
		print("[World] Player Alex Mercer spawned at: ", player.global_position)
	
	# Welcome sequence
	await get_tree().create_timer(1.5).timeout
	if mission_manager and mission_manager.has_signal("show_notification"):
		mission_manager.show_notification.emit("BLACKWATER CITY - DISTRICT 7 - 11:47 PM", 3.5)
	
	await get_tree().create_timer(3.0).timeout
	if mission_manager and mission_manager.has_signal("show_notification"):
		mission_manager.show_notification.emit("Follow the red beacon north to find Marcus", 4.0)
	
	print("[World] Blackwater City ready - EVERY CHOICE LEAVES A TRACE - Phase 2")

func _setup_environment():
	if directional_light:
		directional_light.light_energy = 0.85
		directional_light.shadow_enabled = true
		directional_light.shadow_blur = 1.2
		directional_light.shadow_bias = 0.04
		directional_light.rotation_degrees = Vector3(-50, 35, 0)
		print("[World] Directional light configured - moonlight")
	
	print("[World] Environment setup complete - nighttime atmosphere, fog 0.007, 6 lights max")

func _setup_destination_marker():
	destination_marker = get_node_or_null("GarageComplex/DestinationMarker")
	if destination_marker:
		destination_marker.visible = false
		destination_marker.add_to_group("destination_marker")
		print("[World] Destination marker initialized - hidden until needed")

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
			print("[World] Connected interactable: ", inter.interaction_id)

func _recursive_find_interactables(node: Node, list: Array):
	for child in node.get_children():
		if child is Interactable and child not in list:
			list.append(child)
		_recursive_find_interactables(child, list)

func _setup_triggers():
	var explore_trigger = get_node_or_null("MissionTriggers/ExploreTrigger")
	var dest_trigger = get_node_or_null("MissionTriggers/DestinationTrigger")
	var garage_trigger = get_node_or_null("MissionTriggers/GarageEntranceTrigger")
	
	if explore_trigger and explore_trigger is Area3D:
		explore_trigger.body_entered.connect(func(body): _on_trigger_entered(body, "ExploreTrigger"))
		explore_trigger.monitoring = true
	if dest_trigger and dest_trigger is Area3D:
		dest_trigger.body_entered.connect(func(body): _on_trigger_entered(body, "DestinationTrigger"))
	if garage_trigger and garage_trigger is Area3D:
		garage_trigger.body_entered.connect(func(body): _on_trigger_entered(body, "GarageEntranceTrigger"))
	
	print("[World] Triggers setup complete - Explore, Destination, GarageEntrance")

func _on_trigger_entered(body, trigger_id: String):
	if not body.is_in_group("player") and body.name != "Player" and not body is CharacterBody3D:
		return
	
	print("[World] Player entered trigger: ", trigger_id)
	
	if mission_manager and mission_manager.has_method("trigger_area_entered"):
		mission_manager.trigger_area_entered(trigger_id)
	
	# Visual feedback for trigger
	if trigger_id == "DestinationTrigger":
		if game_hud and game_hud.has_method("show_notification"):
			game_hud.show_notification("Garage located - head to entrance", 2.5)

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
		if game_hud and game_hud.has_method("clear_interaction_prompt"):
			game_hud.clear_interaction_prompt()
		return
	
	var closest: Interactable = null
	var closest_dist: float = INF
	
	if player == null:
		closest = interactables_in_range[0]
	else:
		for inter in interactables_in_range:
			if not is_instance_valid(inter):
				continue
			var dist = player.global_position.distance_to(inter.global_position)
			if dist < closest_dist:
				closest_dist = dist
				closest = inter
	
	current_interactable = closest
	
	if game_hud and game_hud.has_method("set_interaction_prompt"):
		game_hud.set_interaction_prompt(current_interactable)

func _input(event):
	if event.is_action_pressed("interact"):
		if current_interactable:
			current_interactable.interact()

func _process(delta):
	if interactables_in_range.size() > 1 and player:
		_update_current_interactable()
	
	# Update destination marker to face player (billboard effect for beacon)
	if destination_marker and destination_marker.visible and player:
		var beacon_top = destination_marker.get_node_or_null("BeaconTop")
		if beacon_top:
			# Slight pulse based on distance
			var dist = player.global_position.distance_to(destination_marker.global_position)
			var pulse = 1.0 + sin(Time.get_ticks_msec() / 300.0) * 0.1
			beacon_top.scale = Vector3(pulse, pulse, pulse)

func get_player() -> CharacterBody3D:
	return player

func get_mission_manager():
	return mission_manager

func get_destination_marker() -> Node3D:
	return destination_marker
