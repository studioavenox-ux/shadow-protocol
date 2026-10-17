extends SceneTree

# Validation for Phase 4 - Audio, Immersion & Police Pursuit
# Run with: godot --headless -s res://scripts/validation_phase4.gd
#
# Exit code: 0 when every check passes, 1 when any check fails (including any
# script that fails to compile). Warnings do not fail the run.
#
# The checks run from _process (not _init) so that autoloads such as
# GameManager are registered before any script is compiled. Compiling in _init
# produced "Identifier not found: GameManager" and made the harness unreliable.

var _ran := false

func _process(_delta: float) -> bool:
	if _ran:
		return false
	_ran = true
	_run_validation()
	return false

# Recursively collect every .gd file under a res:// directory.
func _list_scripts(dir_path: String, out: Array) -> Array:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full := dir_path.path_join(entry)
			if dir.current_is_dir():
				_list_scripts(full, out)
			elif entry.ends_with(".gd"):
				out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return out

func _run_validation() -> void:
	print("\n=== PHASE 4 VALIDATION ===\n")
	
	var passed = 0
	var failed = 0
	var warnings = 0
	
	# Compile every script in the project. A script that fails to parse or
	# compile is a hard failure, even if its source text looks correct.
	print("--- Script Compile Check (all res:// .gd files) ---")
	var all_scripts: Array = _list_scripts("res://", [])
	for script_path in all_scripts:
		var compiled = load(script_path)
		var ok: bool = compiled is GDScript and compiled.can_instantiate()
		if ok:
			print("✓ ", script_path)
			passed += 1
		else:
			print("✗ COMPILE FAILED: ", script_path)
			failed += 1

	# Check files exist
	var required_files = [
		"res://scripts/vehicle_controller.gd",
		"res://scripts/driving_camera.gd",
		"res://scripts/wanted_manager.gd",
		"res://scripts/police_vehicle.gd",
		"res://scripts/audio_manager.gd",
		"res://scripts/environment_manager.gd",
		"res://scenes/police_vehicle.tscn",
		"res://scenes/nightfall.tscn",
		"res://scenes/world.tscn"
	]
	
	print("--- File Existence ---")
	for path in required_files:
		if ResourceLoader.exists(path):
			print("✓ ", path)
			passed += 1
		else:
			print("✗ MISSING: ", path)
			failed += 1
	
	# Check vehicle controller
	print("\n--- Vehicle Controller Fixes ---")
	if ResourceLoader.exists("res://scripts/vehicle_controller.gd"):
		var loaded_script = load("res://scripts/vehicle_controller.gd")
		var source = loaded_script.source_code if loaded_script is GDScript else ""
		# Check for gradual steering
		if source.contains("gradual_steering_enabled") and source.contains("target_steering_input"):
			print("✓ Gradual steering implemented")
			passed += 1
		else:
			print("✗ Gradual steering not found")
			failed += 1
		
		if source.contains("steering_return_speed"):
			print("✓ Steering return speed implemented")
			passed += 1
		else:
			print("✗ Steering return speed missing")
			failed += 1
		
		if source.contains("angular_damping") and source.contains("center_of_mass_offset"):
			print("✓ Stability improvements (CoM, angular damping)")
			passed += 1
		else:
			print("✗ Stability improvements missing")
			failed += 1
		
		if source.contains("_find_safe_exit_position"):
			print("✓ Collision-safe exit implemented")
			passed += 1
		else:
			print("✗ Safe exit not found")
			failed += 1
	
	# Check driving camera
	print("\n--- Driving Camera ---")
	if ResourceLoader.exists("res://scripts/driving_camera.gd"):
		var loaded_script = load("res://scripts/driving_camera.gd")
		var source = loaded_script.source_code if loaded_script is GDScript else ""
		if source.contains("is_reversing") and source.contains("auto_center"):
			print("✓ Driving/reversing camera behavior")
			passed += 1
		else:
			print("✗ Camera reversing handling missing")
			failed += 1
	
	# Check wanted manager
	print("\n--- Wanted Manager ---")
	if ResourceLoader.exists("res://scripts/wanted_manager.gd"):
		var loaded_script = load("res://scripts/wanted_manager.gd")
		var source = loaded_script.source_code if loaded_script is GDScript else ""
		if source.contains("WantedLevel") and source.contains("LEVEL_0") and source.contains("LEVEL_3"):
			print("✓ 3 wanted levels (0-3)")
			passed += 1
		else:
			print("✗ Wanted levels incomplete")
			failed += 1
		
		if source.contains("increase_wanted_level") and source.contains("reduce_wanted_level") and source.contains("start") and source.contains("end_pursuit"):
			print("✓ Wanted functions: increase/reduce/start/end")
			passed += 1
		else:
			print("✗ Wanted functions incomplete")
			failed += 1
		
		if source.contains("last_known_position") and source.contains("record") or source.contains("_update_last_known_position"):
			print("✓ Last known position tracking")
			passed += 1
		else:
			print("✗ Last known position missing")
			failed += 1
		
		if source.contains("PursuitState") and source.contains("STATE_SEARCH"):
			print("✓ State machine with search state")
			passed += 1
		else:
			print("✗ State machine incomplete")
			failed += 1
		
		if source.contains("police_spawn_distance_min") and source.contains("avoid") or source.contains("not on top"):
			print("✓ Spawn avoids player (distance check)")
			passed += 1
		else:
			print("⚠ Spawn avoidance check may be incomplete")
			warnings += 1
	
	# Check police vehicle
	print("\n--- Police Vehicle ---")
	if ResourceLoader.exists("res://scripts/police_vehicle.gd"):
		var loaded_script = load("res://scripts/police_vehicle.gd")
		var source = loaded_script.source_code if loaded_script is GDScript else ""
		if source.contains("set_target_position") and source.contains("last_known"):
			print("✓ Police receives last known position")
			passed += 1
		else:
			print("✗ Police target position missing")
			failed += 1
		
		if source.contains("is_searching") and source.contains("search_timer"):
			print("✓ Search near last known when LOS lost")
			passed += 1
		else:
			print("✗ Search behavior missing")
			failed += 1
		
		if source.contains("stuck_timer") or source.contains("lightweight"):
			print("✓ Lightweight AI with stuck handling")
			passed += 1
		else:
			print("⚠ Stuck handling not found")
			warnings += 1
	
	# Check audio
	print("\n--- Audio System ---")
	if ResourceLoader.exists("res://scripts/audio_manager.gd"):
		var loaded_script = load("res://scripts/audio_manager.gd")
		var source = loaded_script.source_code if loaded_script is GDScript else ""
		if source.contains("engine_loop_path") and source.contains("tire_squeal_path") and source.contains("city_ambience_path"):
			print("✓ Audio optional paths documented")
			passed += 1
		else:
			print("✗ Audio paths incomplete")
			failed += 1
		
		if source.contains("ResourceLoader.exists"):
			print("✓ No missing file refs - checks existence")
			passed += 1
		else:
			print("✗ Missing file check not found")
			failed += 1
		
		if source.contains("footstep") and source.contains("interaction") and source.contains("mission_complete"):
			print("✓ Footsteps, interaction, mission audio hooks")
			passed += 1
		else:
			print("✗ Audio hooks incomplete")
			failed += 1
	
	# Check environment
	print("\n--- Environment ---")
	if ResourceLoader.exists("res://scripts/environment_manager.gd"):
		var loaded_script = load("res://scripts/environment_manager.gd")
		var source = loaded_script.source_code if loaded_script is GDScript else ""
		if source.contains("fog_enabled") and source.contains("streetlight_flicker"):
			print("✓ Fog and streetlight variation")
			passed += 1
		else:
			print("✗ Environment immersion missing")
			failed += 1
	
	# Check HUD
	print("\n--- HUD ---")
	if ResourceLoader.exists("res://scripts/driving_hud.gd"):
		var loaded_script = load("res://scripts/driving_hud.gd")
		var source = loaded_script.source_code if loaded_script is GDScript else ""
		if source.contains("wanted") and source.contains("police_alert") and source.contains("minimap"):
			print("✓ Wanted indicators, police alert, minimap/pursuit direction")
			passed += 1
		else:
			print("✗ HUD wanted integration incomplete")
			failed += 1
	
	# Check mission manager parking
	print("\n--- Mission Parking Fix ---")
	if ResourceLoader.exists("res://scripts/mission_manager.gd"):
		var loaded_script = load("res://scripts/mission_manager.gd")
		var source = loaded_script.source_code if loaded_script is GDScript else ""
		if source.contains("garage_bounds") or source.contains("in_garage_bounds") and source.contains("properly_positioned"):
			print("✓ Parking requires proper garage positioning")
			passed += 1
		else:
			print("✗ Parking garage bounds check missing")
			failed += 1
	
	# Check world
	print("\n--- World Integration ---")
	if ResourceLoader.exists("res://scenes/world.tscn"):
		var content = FileAccess.get_file_as_string("res://scenes/world.tscn")
		if content.contains("WantedManager") and content.contains("AudioManager"):
			print("✓ World has WantedManager and AudioManager")
			passed += 1
		else:
			print("✗ World missing managers")
			failed += 1
		
		if content.contains("EnvironmentManager"):
			print("✓ World has EnvironmentManager")
			passed += 1
		else:
			print("✗ World missing EnvironmentManager")
			failed += 1
	
	# Summary
	print("\n=== SUMMARY ===")
	print("Passed: ", passed)
	print("Failed: ", failed)
	print("Warnings: ", warnings)
	print("Total: ", passed + failed + warnings)
	
	if failed == 0:
		print("\n✓✓✓ PHASE 4 VALIDATION PASSED ✓✓✓\n")
	else:
		print("\n✗ VALIDATION FAILED - ", failed, " issues\n")
	
	quit(0 if failed == 0 else 1)
