extends Node

# Interaction System - Reusable system for player interactions
# Manages detection, prompts, and execution of interactions

signal interactable_entered(interactable: Interactable)
signal interactable_exited(interactable: Interactable)
signal interaction_started(interactable: Interactable)
signal interaction_completed(interactable: Interactable)

var player: CharacterBody3D = null
var current_interactable: Interactable = null
var interactables_in_range: Array[Interactable] = []
var interaction_cooldown: float = 0.3
var last_interaction_time: float = 0.0

@export var auto_sort_by_distance: bool = true
@export var interaction_range: float = 3.0

func _ready():
	print("[InteractionSystem] Initialized")
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	if player == null:
		player = get_node_or_null("../Player") or get_node_or_null("../../Player")
	
	# Find all interactables
	_scan_for_interactables()

func _scan_for_interactables():
	var all_nodes = get_tree().get_nodes_in_group("interactable")
	for node in all_nodes:
		if node is Interactable:
			_connect_interactable(node)
	
	# Recursive search
	if get_tree().current_scene:
		_recursive_search(get_tree().current_scene)

func _recursive_search(node: Node):
	for child in node.get_children():
		if child is Interactable:
			_connect_interactable(child)
		_recursive_search(child)

func _connect_interactable(interactable: Interactable):
	if not interactable.player_entered_range.is_connected(_on_entered):
		interactable.player_entered_range.connect(_on_entered)
	if not interactable.player_exited_range.is_connected(_on_exited):
		interactable.player_exited_range.connect(_on_exited)
	if not interactable.interacted.is_connected(_on_interacted):
		interactable.interacted.connect(_on_interacted)

func _on_entered(interactable: Interactable):
	if interactable in interactables_in_range:
		return
	interactables_in_range.append(interactable)
	emit_signal("interactable_entered", interactable)
	_update_current()
	print("[InteractionSystem] Entered range: ", interactable.interaction_id)

func _on_exited(interactable: Interactable):
	interactables_in_range.erase(interactable)
	emit_signal("interactable_exited", interactable)
	_update_current()
	print("[InteractionSystem] Exited range: ", interactable.interaction_id)

func _on_interacted(id: String, interactable: Interactable):
	emit_signal("interaction_started", interactable)
	print("[InteractionSystem] Interaction started: ", id)
	# Small delay to allow handling
	await get_tree().create_timer(0.1).timeout
	emit_signal("interaction_completed", interactable)

func _update_current():
	if interactables_in_range.is_empty():
		current_interactable = null
		return
	
	if not auto_sort_by_distance or player == null:
		current_interactable = interactables_in_range[0]
		return
	
	# Find closest
	var closest = null
	var min_dist = INF
	for inter in interactables_in_range:
		if not is_instance_valid(inter):
			continue
		var dist = player.global_position.distance_to(inter.global_position)
		if dist < min_dist and dist <= interaction_range:
			min_dist = dist
			closest = inter
	
	current_interactable = closest

func try_interact() -> bool:
	var now = Time.get_ticks_msec() / 1000.0
	if now - last_interaction_time < interaction_cooldown:
		return false
	
	if current_interactable == null:
		return false
	
	if not current_interactable.can_interact():
		return false
	
	last_interaction_time = now
	current_interactable.interact()
	return true

func get_current_interactable() -> Interactable:
	return current_interactable

func has_interactable_in_range() -> bool:
	return current_interactable != null

func get_prompt_text() -> String:
	if current_interactable:
		return current_interactable.get_prompt()
	return ""

func _process(delta):
	# Update current interactable periodically if multiple in range
	if interactables_in_range.size() > 1:
		_update_current()

func _input(event):
	if event.is_action_pressed("interact"):
		try_interact()
