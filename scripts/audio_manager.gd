extends Node

# Audio Manager - Phase 4 Lightweight Immersion
# Handles engine, tire, ambience, footsteps, interaction, mission audio
# All asset paths optional, documented, no missing file refs

signal audio_played(event: String)

@export_group("Audio Buses")
@export var master_bus: String = "Master"
@export var sfx_bus: String = "SFX"
@export var music_bus: String = "Music"
@export var ambience_bus: String = "Ambience"

@export_group("Optional Asset Paths")
@export var engine_loop_path: String = "res://assets/audio/engine_loop.ogg"
@export var engine_start_path: String = "res://assets/audio/engine_start.ogg"
@export var tire_squeal_path: String = "res://assets/audio/tire_squeal.ogg"
@export var city_ambience_path: String = "res://assets/audio/city_ambience.ogg"
@export var footsteps_walk_path: String = "res://assets/audio/footstep_walk.ogg"
@export var footsteps_run_path: String = "res://assets/audio/footstep_run.ogg"
@export var interaction_click_path: String = "res://assets/audio/interaction_click.ogg"
@export var mission_complete_path: String = "res://assets/audio/mission_complete.ogg"
@export var police_siren_path: String = "res://assets/audio/police_siren.ogg"
@export var wanted_alert_path: String = "res://assets/audio/wanted_alert.ogg"

# Players
var city_ambience_player: AudioStreamPlayer = null
var footsteps_player: AudioStreamPlayer = null
var sfx_player: AudioStreamPlayer = null
var mission_player: AudioStreamPlayer = null
var ui_player: AudioStreamPlayer = null

# Footstep state
var footstep_timer: float = 0.0
var footstep_interval_walk: float = 0.5
var footstep_interval_run: float = 0.32
var is_walking: bool = false
var is_running: bool = false
var last_footstep_position: Vector3 = Vector3.ZERO

# Cache loaded streams
var audio_cache: Dictionary = {}

func _ready():
	add_to_group("audio_manager")
	print("[AudioManager] Phase 4 - Lightweight audio system initialized")
	print("[AudioManager] All asset paths optional - documented in assets/audio/README.md")
	
	_setup_players()
	_preload_optional_audio()

func _setup_players():
	# City ambience - 2D for global
	city_ambience_player = AudioStreamPlayer.new()
	city_ambience_player.name = "CityAmbiencePlayer"
	city_ambience_player.bus = ambience_bus if AudioServer.get_bus_index(ambience_bus) != -1 else master_bus
	city_ambience_player.volume_db = -18.0
	add_child(city_ambience_player)
	
	# Footsteps
	footsteps_player = AudioStreamPlayer.new()
	footsteps_player.name = "FootstepsPlayer"
	footsteps_player.bus = sfx_bus if AudioServer.get_bus_index(sfx_bus) != -1 else master_bus
	footsteps_player.volume_db = -8.0
	add_child(footsteps_player)
	
	# Generic SFX
	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "SFXPlayer"
	sfx_player.bus = sfx_bus if AudioServer.get_bus_index(sfx_bus) != -1 else master_bus
	add_child(sfx_player)
	
	# Mission audio
	mission_player = AudioStreamPlayer.new()
	mission_player.name = "MissionPlayer"
	mission_player.bus = sfx_bus if AudioServer.get_bus_index(sfx_bus) != -1 else master_bus
	mission_player.volume_db = -2.0
	add_child(mission_player)
	
	# UI feedback
	ui_player = AudioStreamPlayer.new()
	ui_player.name = "UIPlayer"
	ui_player.bus = sfx_bus if AudioServer.get_bus_index(sfx_bus) != -1 else master_bus
	ui_player.volume_db = -4.0
	add_child(ui_player)

func _preload_optional_audio():
	# Try to load each optional path, cache if exists
	var paths = [
		engine_loop_path, engine_start_path, tire_squeal_path,
		city_ambience_path, footsteps_walk_path, footsteps_run_path,
		interaction_click_path, mission_complete_path,
		police_siren_path, wanted_alert_path
	]
	
	var loaded_count = 0
	for path in paths:
		if ResourceLoader.exists(path):
			var stream = load(path)
			if stream:
				audio_cache[path] = stream
				loaded_count += 1
				print("[AudioManager] Loaded: ", path)
	
	if loaded_count == 0:
		print("[AudioManager] No audio assets found - system ready, all paths optional")
	else:
		print("[AudioManager] Loaded ", loaded_count, "/", paths.size(), " optional assets")
	
	# Start city ambience if available
	if audio_cache.has(city_ambience_path):
		play_city_ambience()

func _process(delta):
	_handle_footsteps(delta)

func _handle_footsteps(delta):
	if not is_walking:
		return
	
	footstep_timer -= delta
	if footstep_timer <= 0:
		play_footstep(is_running)
		footstep_timer = footstep_interval_run if is_running else footstep_interval_walk

func play_city_ambience():
	if audio_cache.has(city_ambience_path):
		city_ambience_player.stream = audio_cache[city_ambience_path]
		city_ambience_player.play()
		print("[AudioManager] City ambience playing")
	else:
		print("[AudioManager] City ambience not found (optional): ", city_ambience_path)

func play_footstep(running: bool = false):
	var path = footsteps_run_path if running else footsteps_walk_path
	if audio_cache.has(path):
		footsteps_player.stream = audio_cache[path]
		footsteps_player.pitch_scale = randf_range(0.9, 1.1)
		footsteps_player.play()
		emit_signal("audio_played", "footstep")
	elif audio_cache.has(footsteps_walk_path):
		# Fallback to walk
		footsteps_player.stream = audio_cache[footsteps_walk_path]
		footsteps_player.pitch_scale = randf_range(0.9, 1.1) if not running else randf_range(1.1, 1.3)
		footsteps_player.play()

func set_walking(walking: bool, running: bool = false, position: Vector3 = Vector3.ZERO):
	is_walking = walking
	is_running = running
	if walking and footstep_timer <= 0:
		footstep_timer = 0.1 # Immediate first step
	if not walking:
		footstep_timer = 0.0
	last_footstep_position = position

func play_interaction_feedback():
	if audio_cache.has(interaction_click_path):
		ui_player.stream = audio_cache[interaction_click_path]
		ui_player.play()
		emit_signal("audio_played", "interaction")
	else:
		# Fallback - print for debug, no missing ref error
		print("[AudioManager] Interaction feedback (no audio asset - optional): ", interaction_click_path)

func play_mission_complete():
	if audio_cache.has(mission_complete_path):
		mission_player.stream = audio_cache[mission_complete_path]
		mission_player.play()
		emit_signal("audio_played", "mission_complete")
		print("[AudioManager] Mission complete audio")
	else:
		print("[AudioManager] Mission complete (no asset - optional): ", mission_complete_path)

func play_wanted_alert():
	if audio_cache.has(wanted_alert_path):
		sfx_player.stream = audio_cache[wanted_alert_path]
		sfx_player.play()
		emit_signal("audio_played", "wanted_alert")

func play_police_siren(position: Vector3):
	if audio_cache.has(police_siren_path):
		# Create temporary 3D player for siren
		var siren_player = AudioStreamPlayer3D.new()
		siren_player.stream = audio_cache[police_siren_path]
		siren_player.global_position = position
		siren_player.bus = sfx_bus if AudioServer.get_bus_index(sfx_bus) != -1 else master_bus
		siren_player.max_distance = 80.0
		get_tree().current_scene.add_child(siren_player)
		siren_player.play()
		# Auto free after
		await siren_player.finished
		siren_player.queue_free()

func play_engine_sound(_vehicle: VehicleBody3D):
	# Handled by vehicle_controller directly with its own players
	pass

# Utility - check if asset exists
func has_audio(path: String) -> bool:
	return audio_cache.has(path)

func get_audio_cache() -> Dictionary:
	return audio_cache

func list_optional_paths() -> Array:
	return [
		engine_loop_path,
		engine_start_path,
		tire_squeal_path,
		city_ambience_path,
		footsteps_walk_path,
		footsteps_run_path,
		interaction_click_path,
		mission_complete_path,
		police_siren_path,
		wanted_alert_path
	]
