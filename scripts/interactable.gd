extends Area3D
class_name Interactable

# Base class for all interactable objects
# Provides prompt text and interaction signal

@export var prompt_text: String = "Interact"
@export var interaction_id: String = "generic"
@export var auto_interact: bool = false
@export var one_shot: bool = false
@export var highlight_enabled: bool = true

signal interacted(id: String, interactable: Interactable)
signal player_entered_range(interactable: Interactable)
signal player_exited_range(interactable: Interactable)

var is_player_in_range: bool = false
var has_been_used: bool = false
var original_material: Material = null

@onready var highlight_mesh: MeshInstance3D = null

func _ready():
	# Setup collision layers - Interactable layer 4 = bitmask 8, detects Player layer 2 = bitmask 2
	collision_layer = 8
	collision_mask = 2
	# We use Area to detect player
	monitoring = true
	monitorable = true
	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Try to find highlight mesh
	for child in get_children():
		if child is MeshInstance3D:
			highlight_mesh = child
			break
	
	print("[Interactable] Ready: ", interaction_id, " - ", prompt_text)

func _on_body_entered(body):
	if body.is_in_group("player") or body.name == "Player" or body is CharacterBody3D:
		if one_shot and has_been_used:
			return
		is_player_in_range = true
		emit_signal("player_entered_range", self)
		_set_highlight(true)
		print("[Interactable] Player entered range: ", interaction_id)

func _on_body_exited(body):
	if body.is_in_group("player") or body.name == "Player" or body is CharacterBody3D:
		is_player_in_range = false
		emit_signal("player_exited_range", self)
		_set_highlight(false)
		print("[Interactable] Player exited range: ", interaction_id)

func interact():
	if one_shot and has_been_used:
		return
	if not is_player_in_range and not auto_interact:
		return
	
	has_been_used = true
	emit_signal("interacted", interaction_id, self)
	print("[Interactable] Interacted: ", interaction_id)
	
	if one_shot:
		_set_highlight(false)
		# Disable after use if one shot
		set_deferred("monitoring", false)

func _set_highlight(enabled: bool):
	if not highlight_enabled:
		return
	if highlight_mesh == null:
		return
	# Simple emissive highlight effect
	if enabled:
		if highlight_mesh.material_override == null:
			original_material = highlight_mesh.get_active_material(0)
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.647, 0.122, 0.169, 1.0) # Muted crimson
		mat.emission_enabled = true
		mat.emission = Color(0.647, 0.122, 0.169, 1.0)
		mat.emission_energy_multiplier = 0.5
		highlight_mesh.material_override = mat
	else:
		highlight_mesh.material_override = null

func get_prompt() -> String:
	return prompt_text

func can_interact() -> bool:
	if one_shot and has_been_used:
		return false
	return is_player_in_range or auto_interact
