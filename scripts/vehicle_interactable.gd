extends Interactable

# Vehicle Interactable - Handles ENTER VEHICLE prompt and interaction
# Extends Interactable base class for consistent interaction system

@export var vehicle_path: NodePath
@export var enter_prompt: String = "ENTER VEHICLE"
@export var exit_prompt: String = "EXIT VEHICLE"

var vehicle: VehicleBody3D = null
var is_player_inside: bool = false

signal vehicle_enter_requested(vehicle: VehicleBody3D)
signal vehicle_exit_requested(vehicle: VehicleBody3D)

func _ready():
	super._ready()
	
	if vehicle_path != NodePath(""):
		vehicle = get_node_or_null(vehicle_path) as VehicleBody3D
	else:
		# Try parent
		var parent = get_parent()
		if parent is VehicleBody3D:
			vehicle = parent as VehicleBody3D
		else:
			# Search children
			for child in get_parent().get_children():
				if child is VehicleBody3D:
					vehicle = child as VehicleBody3D
					break
	
	if vehicle:
		prompt_text = enter_prompt
		interaction_id = "vehicle_" + vehicle.name.to_lower()
		print("[VehicleInteractable] Linked to vehicle: ", vehicle.name)
		
		# Connect to vehicle signals
		if vehicle.has_signal("player_entered_vehicle"):
			vehicle.player_entered_vehicle.connect(_on_player_entered)
		if vehicle.has_signal("player_exited_vehicle"):
			vehicle.player_exited_vehicle.connect(_on_player_exited)
	else:
		print("[VehicleInteractable] WARNING: No vehicle found!")
	
	# Vehicle should be interactable from larger distance
	var col = get_node_or_null("CollisionShape3D")
	if col and col.shape is BoxShape3D:
		col.shape.size = Vector3(5.5, 2.2, 3.0)
	
	# Ensure correct layers: Interactable layer 4 = bitmask 8, mask player layer 2 = bitmask 2
	collision_layer = 8
	collision_mask = 2

func _on_player_entered(_veh: VehicleBody3D):
	is_player_inside = true
	prompt_text = exit_prompt
	# Hide interaction when inside? Actually we need exit via HUD button
	# But keep for keyboard E
	print("[VehicleInteractable] Player inside vehicle")

func _on_player_exited(_veh: VehicleBody3D):
	is_player_inside = false
	prompt_text = enter_prompt
	has_been_used = false
	monitoring = true
	print("[VehicleInteractable] Player exited vehicle")

func interact():
	if vehicle == null:
		print("[VehicleInteractable] No vehicle to interact with")
		return
	
	if not is_player_in_range:
		return
	
	if is_player_inside:
		# Exit request
		if vehicle.has_method("can_exit") and not vehicle.can_exit():
			print("[VehicleInteractable] Cannot exit - unsafe")
			return
		emit_signal("vehicle_exit_requested", vehicle)
		if vehicle.has_method("exit_vehicle"):
			vehicle.exit_vehicle()
		emit_signal("interacted", interaction_id, self)
	else:
		# Enter request
		if vehicle.has_method("can_enter") and not vehicle.can_enter():
			print("[VehicleInteractable] Cannot enter - moving too fast")
			return
		var player = get_tree().get_first_node_in_group("player")
		if not player:
			player = get_node_or_null("../../Player")
			if player == null:
				player = get_node_or_null("../../../Player")
		
		if player:
			emit_signal("vehicle_enter_requested", vehicle)
			if vehicle.has_method("enter_vehicle"):
				var success = vehicle.enter_vehicle(player)
				if success:
					emit_signal("interacted", interaction_id, self)
					# Disable monitoring while inside
					set_deferred("monitoring", false)

func can_interact() -> bool:
	if vehicle == null:
		return false
	if is_player_inside:
		if vehicle.has_method("can_exit"):
			return vehicle.can_exit() and is_player_in_range
		return is_player_in_range
	else:
		if vehicle.has_method("can_enter"):
			return vehicle.can_enter() and is_player_in_range
		return is_player_in_range

func get_prompt() -> String:
	if is_player_inside:
		return exit_prompt
	return enter_prompt
