extends Node

# Wanted Manager - Police Pursuit System Phase 4
# Implements 3 wanted levels with state machine: No pursuit, Alerted, Active, Intense

signal wanted_level_changed(new_level: int, old_level: int)
signal pursuit_started(level: int)
signal pursuit_ended(escaped: bool)
signal search_started(last_known_position: Vector3)
signal search_ended(found: bool)
signal police_alert(message: String, duration: float)
signal last_known_position_updated(position: Vector3)

enum WantedLevel {
	LEVEL_0 = 0, # No pursuit
	LEVEL_1 = 1, # Police alerted
	LEVEL_2 = 2, # Active pursuit
	LEVEL_3 = 3  # Intense pursuit
}

enum PursuitState {
	STATE_NONE = 0,
	STATE_ALERTED = 1,
	STATE_PURSUIT = 2,
	STATE_SEARCH = 3,
	STATE_ESCAPED = 4
}

@export_group("Wanted Settings")
@export var max_wanted_level: int = 3
@export var wanted_decay_time: float = 30.0 # Time without crime to reduce wanted
@export var search_duration: float = 20.0 # How long police search last known position
@export var escape_time_required: float = 12.0 # Time out of sight to escape
@export var police_spawn_distance_min: float = 35.0
@export var police_spawn_distance_max: float = 80.0

@export_group("Detection")
@export var police_detection_range: float = 60.0
@export var police_los_range: float = 45.0
@export var last_known_position_update_interval: float = 1.5

var current_wanted_level: int = WantedLevel.LEVEL_0
var current_state: int = PursuitState.STATE_NONE
var last_known_position: Vector3 = Vector3.ZERO
var player_last_seen_time: float = 0.0
var time_since_last_crime: float = 0.0
var search_timer: float = 0.0
var escape_timer: float = 0.0
var is_player_in_los: bool = false
var is_pursuit_active: bool = false

var player: Node3D = null
var vehicle: VehicleBody3D = null
var active_police_vehicles: Array = []

# Timers
var wanted_decay_timer: float = 0.0
var los_check_timer: float = 0.0
var last_known_update_timer: float = 0.0

# Crime tracking
var crimes_committed: Array = []
var total_crimes: int = 0

func _ready():
	add_to_group("wanted_manager")
	print("[WantedManager] Phase 4 - Police Pursuit System initialized")
	print("[WantedManager] Levels: 0=No pursuit, 1=Alerted, 2=Active, 3=Intense")
	
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	vehicle = get_tree().get_first_node_in_group("vehicle")
	
	# For testing, start at level 0
	current_wanted_level = WantedLevel.LEVEL_0
	current_state = PursuitState.STATE_NONE
	
	# Prevent clearing via menu/scene change - save wanted level
	if GameManager:
		# Don't clear on pause
		pass

func _process(delta):
	if current_wanted_level == WantedLevel.LEVEL_0 and current_state == PursuitState.STATE_NONE:
		return
	
	# Update timers
	time_since_last_crime += delta
	los_check_timer += delta
	last_known_update_timer += delta
	
	# Check LOS periodically
	if los_check_timer > 0.5:
		_check_line_of_sight()
		los_check_timer = 0.0
	
	# Update last known position if in LOS
	if is_player_in_los and last_known_update_timer > last_known_position_update_interval:
		_update_last_known_position()
		last_known_update_timer = 0.0
	
	# Handle state machine
	match current_state:
		PursuitState.STATE_ALERTED:
			_handle_alerted_state(delta)
		PursuitState.STATE_PURSUIT:
			_handle_pursuit_state(delta)
		PursuitState.STATE_SEARCH:
			_handle_search_state(delta)
	
	# Wanted decay when no crimes and not in pursuit
	if current_wanted_level > 0 and not is_pursuit_active and current_state == PursuitState.STATE_NONE:
		wanted_decay_timer += delta
		if wanted_decay_timer > wanted_decay_time:
			_decrease_wanted_level()
			wanted_decay_timer = 0.0

func _check_line_of_sight():
	if not player and not vehicle:
		player = get_tree().get_first_node_in_group("player")
		vehicle = get_tree().get_first_node_in_group("vehicle")
		if not player:
			return
	
	var player_pos = _get_player_position()
	if player_pos == Vector3.ZERO:
		return
	
	# Check distance to police
	var police_in_range = false
	for police in active_police_vehicles:
		if not is_instance_valid(police):
			continue
		var dist = police.global_position.distance_to(player_pos)
		if dist < police_los_range:
			police_in_range = true
			# Raycast for LOS
			var space_state = get_world_3d().direct_space_state
			var query = PhysicsRayQueryParameters3D.create(police.global_position + Vector3(0, 1, 0), player_pos + Vector3(0, 1, 0))
			query.collision_mask = 1 # World
			query.exclude = [police]
			if police is VehicleBody3D:
				query.exclude.append(police)
			var result = space_state.intersect_ray(query)
			if not result:
				# Has LOS
				is_player_in_los = true
				player_last_seen_time = Time.get_ticks_msec() / 1000.0
				_update_last_known_position()
				return
	
	# If no police in range or no LOS, check if player is in detection range of any police
	if not police_in_range:
		# No police nearby, LOS false
		if is_player_in_los:
			# Just lost LOS
			print("[WantedManager] Lost line of sight - last known: ", last_known_position)
			_start_search()
		is_player_in_los = false

func _get_player_position() -> Vector3:
	# Get position of player or vehicle if player in vehicle
	if vehicle and vehicle.is_player_in_vehicle:
		return vehicle.global_position
	if player:
		return player.global_position
	return Vector3.ZERO

func _update_last_known_position():
	var pos = _get_player_position()
	if pos != Vector3.ZERO:
		last_known_position = pos
		emit_signal("last_known_position_updated", last_known_position)
		# Notify police
		for police in active_police_vehicles:
			if police.has_method("set_target_position"):
				police.set_target_position(last_known_position)

func _handle_alerted_state(delta):
	# Alerted state - police are aware but not yet pursuing actively
	# Transition to pursuit after short delay or if player commits more crimes
	if Time.get_ticks_msec() / 1000.0 - player_last_seen_time > 2.0:
		_start_pursuit()

func _handle_pursuit_state(delta):
	if not is_player_in_los:
		escape_timer += delta
		if escape_timer > 4.0:
			# Lost sight for 4 seconds, start search
			_start_search()
	else:
		escape_timer = 0.0

func _handle_search_state(delta):
	# Search timer decreases only when player not in LOS and in search state
	if is_player_in_los:
		# Found again - back to pursuit
		_start_pursuit()
		return
	
	search_timer -= delta
	escape_timer += delta
	
	if search_timer <= 0:
		# Search failed - player escaped
		_end_pursuit(true)
	elif escape_timer > escape_time_required:
		# Escaped for required time
		_end_pursuit(true)

# Public API - driven by actual gameplay events
func increase_wanted_level(amount: int = 1, reason: String = "crime"):
	var old_level = current_wanted_level
	current_wanted_level = clamp(current_wanted_level + amount, 0, max_wanted_level)
	
	if current_wanted_level != old_level:
		emit_signal("wanted_level_changed", current_wanted_level, old_level)
		emit_signal("police_alert", "WANTED LEVEL %d - %s" % [current_wanted_level, reason.to_upper()], 3.5)
		print("[WantedManager] Wanted level increased: ", old_level, " -> ", current_wanted_level, " Reason: ", reason)
		
		total_crimes += 1
		crimes_committed.append({"reason": reason, "time": Time.get_ticks_msec() / 1000.0, "level": current_wanted_level})
		time_since_last_crime = 0.0
		wanted_decay_timer = 0.0
		
		_update_last_known_position()
		
		# Start pursuit based on level
		if current_wanted_level >= WantedLevel.LEVEL_1 and current_state == PursuitState.STATE_NONE:
			_start_alerted()
		elif current_wanted_level >= WantedLevel.LEVEL_2:
			_start_pursuit()

func _decrease_wanted_level():
	if current_wanted_level <= 0:
		return
	var old_level = current_wanted_level
	current_wanted_level -= 1
	emit_signal("wanted_level_changed", current_wanted_level, old_level)
	print("[WantedManager] Wanted level decreased: ", old_level, " -> ", current_wanted_level)
	
	if current_wanted_level == 0:
		_end_pursuit(true)

func reduce_wanted_level(amount: int = 1):
	var old_level = current_wanted_level
	current_wanted_level = max(current_wanted_level - amount, 0)
	if current_wanted_level != old_level:
		emit_signal("wanted_level_changed", current_wanted_level, old_level)
		print("[WantedManager] Wanted reduced: ", old_level, " -> ", current_wanted_level)
		if current_wanted_level == 0:
			_end_pursuit(true)

func clear_wanted_level():
	var old_level = current_wanted_level
	current_wanted_level = 0
	current_state = PursuitState.STATE_NONE
	is_pursuit_active = false
	emit_signal("wanted_level_changed", 0, old_level)
	emit_signal("pursuit_ended", true)
	print("[WantedManager] Wanted cleared")

func _start_alerted():
	if current_state != PursuitState.STATE_NONE:
		return
	current_state = PursuitState.STATE_ALERTED
	player_last_seen_time = Time.get_ticks_msec() / 1000.0
	emit_signal("police_alert", "POLICE ALERTED - LEVEL %d" % current_wanted_level, 3.0)
	print("[WantedManager] State: ALERTED Level: ", current_wanted_level)

func _start_pursuit():
	if current_state == PursuitState.STATE_PURSUIT and is_pursuit_active:
		return
	
	var was_searching = current_state == PursuitState.STATE_SEARCH
	current_state = PursuitState.STATE_PURSUIT
	is_pursuit_active = true
	escape_timer = 0.0
	
	if not was_searching:
		emit_signal("pursuit_started", current_wanted_level)
		emit_signal("police_alert", "PURSUIT ACTIVE - LEVEL %d" % current_wanted_level, 3.5)
		print("[WantedManager] State: PURSUIT Level: ", current_wanted_level)
	else:
		emit_signal("police_alert", "PURSUIT RESUMED - TARGET REACQUIRED", 2.5)
		print("[WantedManager] State: PURSUIT RESUMED")
	
	# Spawn police if needed
	_spawn_police_if_needed()

func _start_search():
	if current_state != PursuitState.STATE_PURSUIT:
		return
	current_state = PursuitState.STATE_SEARCH
	search_timer = search_duration
	escape_timer = 0.0
	emit_signal("search_started", last_known_position)
	emit_signal("police_alert", "SEARCHING LAST KNOWN POSITION", 3.0)
	print("[WantedManager] State: SEARCH Last known: ", last_known_position, " Duration: ", search_duration)

func _end_pursuit(escaped: bool):
	var was_active = is_pursuit_active or current_state != PursuitState.STATE_NONE
	current_state = PursuitState.STATE_NONE
	is_pursuit_active = false
	search_timer = 0.0
	escape_timer = 0.0
	is_player_in_los = false
	
	if was_active:
		emit_signal("pursuit_ended", escaped)
		if escaped:
			emit_signal("police_alert", "ESCAPED - WANTED LEVEL CLEARING", 4.0)
			print("[WantedManager] State: ESCAPED - Pursuit ended")
			# Start decay timer
			wanted_decay_timer = 0.0
		else:
			emit_signal("police_alert", "PURSUIT ENDED", 2.5)
	
	# Despawn police after delay
	await get_tree().create_timer(5.0).timeout
	_despawn_police()

func _spawn_police_if_needed():
	# Spawn police only under defined conditions, not on top of player
	if active_police_vehicles.size() >= current_wanted_level + 1:
		return # Enough police already
	
	var player_pos = _get_player_position()
	if player_pos == Vector3.ZERO:
		return
	
	# Don't spawn too close
	var spawn_attempts = 0
	while spawn_attempts < 5:
		var angle = randf() * TAU
		var distance = randf_range(police_spawn_distance_min, police_spawn_distance_max)
		var spawn_pos = player_pos + Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		
		# Check if spawn pos is valid (not inside building, has ground)
		var space_state = get_world_3d().direct_space_state
		var ground_query = PhysicsRayQueryParameters3D.create(spawn_pos + Vector3(0, 10, 0), spawn_pos + Vector3(0, -10, 0))
		ground_query.collision_mask = 1
		var ground_result = space_state.intersect_ray(ground_query)
		if not ground_result:
			spawn_attempts += 1
			continue
		
		spawn_pos = ground_result.position
		spawn_pos.y += 0.8
		
		# Check not too close to player
		if spawn_pos.distance_to(player_pos) < police_spawn_distance_min:
			spawn_attempts += 1
			continue
		
		# Spawn police vehicle
		_spawn_police_vehicle(spawn_pos)
		break

func _spawn_police_vehicle(position: Vector3):
	# Try to load police vehicle scene
	var police_scene_path = "res://scenes/police_vehicle.tscn"
	if not ResourceLoader.exists(police_scene_path):
		print("[WantedManager] Police vehicle scene not found: ", police_scene_path)
		return
	
	var police_scene = load(police_scene_path)
	if not police_scene:
		return
	
	var police_vehicle = police_scene.instantiate()
	if not police_vehicle:
		return
	
	get_tree().current_scene.add_child(police_vehicle)
	police_vehicle.global_position = position
	
	if police_vehicle.has_method("set_target_position"):
		police_vehicle.set_target_position(last_known_position)
	
	active_police_vehicles.append(police_vehicle)
	
	# Connect to police signals if any
	if police_vehicle.has_signal("police_lost_target"):
		police_vehicle.police_lost_target.connect(_on_police_lost_target)
	
	print("[WantedManager] Spawned police vehicle at ", position, " total: ", active_police_vehicles.size())
	emit_signal("police_alert", "POLICE UNIT DISPATCHED", 2.0)

func _despawn_police():
	for police in active_police_vehicles:
		if is_instance_valid(police):
			# Fade out or queue free
			var tween = create_tween()
			tween.tween_property(police, "modulate:a", 0.0, 1.0)
			await tween.finished
			police.queue_free()
	
	active_police_vehicles.clear()
	print("[WantedManager] Despawned all police vehicles")

func _on_police_lost_target():
	print("[WantedManager] Police lost target")

# Crime event triggers - called from gameplay
func on_vehicle_theft():
	increase_wanted_level(1, "vehicle theft")

func on_speeding(speed_kmh: float):
	if speed_kmh > 100.0 and current_wanted_level < 2:
		increase_wanted_level(1, "speeding %d km/h" % int(speed_kmh))

func on_collision_with_police():
	increase_wanted_level(1, "collision with police")

func on_hit_and_run():
	increase_wanted_level(1, "hit and run")

func on_player_in_restricted_area():
	if current_wanted_level == 0:
		increase_wanted_level(1, "trespassing")

func get_wanted_level() -> int:
	return current_wanted_level

func get_pursuit_state() -> int:
	return current_state

func get_last_known_position() -> Vector3:
	return last_known_position

func is_in_pursuit() -> bool:
	return is_pursuit_active

func get_search_time_remaining() -> float:
	return search_timer

func get_escape_time() -> float:
	return escape_timer
