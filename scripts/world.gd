extends Node3D

# World - Blackwater City main world script
# Manages environment, triggers, interaction system, and mission flow

@onready var player: CharacterBody3D = $Player
@onready var mission_manager = $MissionManager
@onready var game_hud = $UI/GameHUD
@onready var pause_menu = $UI/PauseMenu
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var directional_light: DirectionalLight3D = $DirectionalLight3D

var current_interactable: Interactable = null
var interactables_in_range: Array[Interactable] = []

func _ready():
	print("[World] Initializing Blackwater City...")
	
	# Set initial fog and lighting for cinematic crime thriller
	_setup_environment()
	
	# Find and connect interactables
	_setup_interactables()
	
	# Setup triggers
	_setup_triggers()
	
	# Connect HUD to interaction system
	if game_hud:
		print("[World] GameHUD found")
	
	# Set player spawn
	if player:
		player.global_position = $PlayerSpawn.global_position if has_node("PlayerSpawn") else Vector3(0, 2, 0)
		print("[World] Player spawned at: ", player.global_position)
	
	# Welcome notification
	await get_tree().create_timer(1.5).timeout
	if mission_manager and mission_manager.has_signal("show_notification"):
		mission_manager.show_notification.emit("BLACKWATER CITY - 11:47 PM", 3.0)
	
	print("[World] Blackwater City ready - EVERY CHOICE LEAVES A TRACE")

func _setup_environment():
	# Cinematic crime thriller lighting
	if directional_light:
		directional_light.light_energy = 0.8
		directional_light.shadow_enabled = true
		directional_light.shadow_blur = 1.0
		# Moonlight-like directional light
		directional_light.rotation_degrees = Vector3(-45, 30, 0)
	
	# World environment already configured via default_env.tres
	print("[World] Environment setup complete")

func _setup_interactables():
	# Find all interactables
	var all_interactables = _find_nodes_of_type(self, "Interactable")
	# Also search for class_name Interactable via group or script
	for node in get_tree().get_nodes_in_group("interactable"):
		if node not in all_interactables:
			all_interactables.append(node)
	
	# Manual search for Interactable instances
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

func _find_nodes_of_type(root: Node, type_name: String) -> Array:
	var result = []
	# This is a generic search, but we use is_class and script checks
	return result

func _setup_triggers():
	# Connect trigger areas for mission
	var explore_trigger = get_node_or_null("MissionTriggers/ExploreTrigger")
	var dest_trigger = get_node_or_null("MissionTriggers/DestinationTrigger")
	var garage_trigger = get_node_or_null("MissionTriggers/GarageEntranceTrigger")
	
	if explore_trigger and explore_trigger is Area3D:
		explore_trigger.body_entered.connect(func(body): _on_trigger_entered(body, "ExploreTrigger"))
	if dest_trigger and dest_trigger is Area3D:
		dest_trigger.body_entered.connect(func(body): _on_trigger_entered(body, "DestinationTrigger"))
	if garage_trigger and garage_trigger is Area3D:
		garage_trigger.body_entered.connect(func(body): _on_trigger_entered(body, "GarageEntranceTrigger"))
	
	print("[World] Triggers setup complete")

func _on_trigger_entered(body, trigger_id: String):
	if not body.is_in_group("player") and body.name != "Player" and not body is CharacterBody3D:
		return
	
	print("[World] Player entered trigger: ", trigger_id)
	
	if mission_manager and mission_manager.has_method("trigger_area_entered"):
		mission_manager.trigger_area_entered(trigger_id)

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
	# Find closest interactable
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
			var dist = player.global_position.distance_to(inter.global_position)
			if dist < closest_dist:
				closest_dist = dist
				closest = inter
	
	current_interactable = closest
	
	if game_hud and game_hud.has_method("set_interaction_prompt"):
		game_hud.set_interaction_prompt(current_interactable)

func _input(event):
	# Handle interact via keyboard
	if event.is_action_pressed("interact"):
		if current_interactable:
			current_interactable.interact()

func _process(delta):
	# Continuously update closest interactable
	if interactables_in_range.size() > 1 and player:
		_update_current_interactable()

# Called when Marcus dialogue finishes mission
func _on_marcus_mission_completed():
	print("[World] Marcus mission trigger completed")
	if mission_manager:
		# Mission manager will handle via signal
		pass

func get_player() -> CharacterBody3D:
	return player

func get_mission_manager():
	return mission_manager
