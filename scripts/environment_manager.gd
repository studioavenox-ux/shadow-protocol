extends Node

# Environment Manager - Phase 4 Visual Immersion
# Streetlight variation, fog, nighttime ambience, optimized for Android

@export_group("Fog")
@export var fog_enabled: bool = true
@export var fog_density: float = 0.008
@export var fog_color: Color = Color(0.12, 0.14, 0.18, 1.0)
@export var fog_height_falloff: float = 0.5

@export_group("Streetlights")
@export var streetlight_flicker_enabled: bool = true
@export var flicker_intensity: float = 0.15
@export var flicker_speed: float = 2.0
@export var variation_count: int = 3 # Different streetlight colors/warmth

@export_group("Night Ambience")
@export var nighttime_enabled: bool = true
@export var ambient_light_color: Color = Color(0.15, 0.18, 0.28, 1.0)
@export var moon_light_intensity: float = 0.6

var streetlights: Array = []
var fog_material: FogMaterial = null
var world_env: WorldEnvironment = null

func _ready():
	add_to_group("environment_manager")
	print("[Environment] Phase 4 - Visual immersion initialized")
	
	await get_tree().process_frame
	_setup_fog()
	_collect_streetlights()
	_setup_night_ambience()

func _setup_fog():
	if not fog_enabled:
		return
	
	world_env = get_tree().get_first_node_in_group("world_environment")
	if not world_env:
		# Try to find WorldEnvironment in scene
		var root = get_tree().current_scene
		if root:
			world_env = _find_world_env(root)
	
	if world_env and world_env.environment:
		var env = world_env.environment
		env.fog_enabled = true
		env.fog_light_color = fog_color
		env.fog_light_energy = 0.35
		env.fog_sun_scatter = 0.15
		env.fog_density = fog_density
		env.fog_height = 0.0
		env.fog_height_density = fog_height_falloff
		env.fog_sky_affect = 0.3
		print("[Environment] Fog enabled - density ", fog_density, " color ", fog_color)
	else:
		print("[Environment] No WorldEnvironment found - fog skipped (optional)")

func _find_world_env(node: Node) -> WorldEnvironment:
	if node is WorldEnvironment:
		return node
	for child in node.get_children():
		var result = _find_world_env(child)
		if result:
			return result
	return null

func _collect_streetlights():
	streetlights = get_tree().get_nodes_in_group("streetlight")
	if streetlights.is_empty():
		# Also search for OmniLight or SpotLight in world
		var lights = get_tree().get_nodes_in_group("light")
		streetlights.append_array(lights)
	
	if streetlights.is_empty():
		print("[Environment] No streetlights found - variation skipped")
		return
	
	# Apply variation
	for i in range(streetlights.size()):
		var light = streetlights[i]
		if light is Light3D:
			# Vary color temperature
			var variation = i % variation_count
			match variation:
				0:
					light.light_color = Color(1.0, 0.85, 0.6) # Warm sodium
					light.light_energy = randf_range(0.9, 1.1)
				1:
					light.light_color = Color(1.0, 0.92, 0.8) # Neutral warm
					light.light_energy = randf_range(0.85, 1.05)
				2:
					light.light_color = Color(0.85, 0.9, 1.0) # Cool white
					light.light_energy = randf_range(0.8, 1.0)
			
			# Android optimization - disable shadows for streetlights
			light.shadow_enabled = false
			
			# Add slight position jitter for realism
			light.light_energy = light.light_energy * randf_range(0.95, 1.05)
	
	print("[Environment] Applied variation to ", streetlights.size(), " streetlights")

func _setup_night_ambience():
	if not nighttime_enabled:
		return
	
	# Find DirectionalLight (moon)
	var moon = get_tree().get_first_node_in_group("moon_light")
	if not moon:
		# Find any DirectionalLight3D
		var lights = []
		_find_directional_lights(get_tree().current_scene, lights)
		if lights.size() > 0:
			moon = lights[0]
	
	if moon and moon is DirectionalLight3D:
		moon.light_color = Color(0.85, 0.9, 1.1)
		moon.light_energy = moon_light_intensity
		moon.shadow_enabled = true # Only moon casts shadows for performance
		print("[Environment] Moon light configured - intensity ", moon_light_intensity)

func _find_directional_lights(node: Node, result: Array):
	if node is DirectionalLight3D:
		result.append(node)
	for child in node.get_children():
		_find_directional_lights(child, result)

func _process(delta):
	if streetlight_flicker_enabled and not streetlights.is_empty():
		_update_flicker(delta)

func _update_flicker(delta):
	# Subtle flicker for realism - only 10% of lights flicker at a time for performance
	for i in range(streetlights.size()):
		if i % 10 != 0: # Only every 10th light flickers
			continue
		var light = streetlights[i]
		if not is_instance_valid(light):
			continue
		if light is Light3D:
			var flicker = sin(Time.get_ticks_msec() / 1000.0 * flicker_speed + i) * flicker_intensity
			light.light_energy = clamp(light.light_energy + flicker * delta, 0.5, 1.5)

func set_fog_density(density: float):
	fog_density = density
	if world_env and world_env.environment:
		world_env.environment.fog_density = density

func set_night_intensity(intensity: float):
	moon_light_intensity = intensity
	var moon = get_tree().get_first_node_in_group("moon_light")
	if moon and moon is DirectionalLight3D:
		moon.light_energy = intensity
