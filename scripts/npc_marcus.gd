extends Interactable

# Marcus Reed - First contact in Blackwater City (Phase 2 Improved)
# Part of mission "A NEW BEGINNING" with dialogue UI integration

@export var npc_name: String = "Marcus Reed"
@export var dialogue_lines: Array[String] = [
	"Alex... you actually came back. I didn't think you would.",
	"Blackwater isn't the same city you left. It's worse. Much worse.",
	"The old garage is still ours. For now. The Vultures want it.",
	"Listen, I got a job. Simple courier run. You in? Good money.",
	"Every choice leaves a trace, kid. Remember that. Welcome home."
]
@export var is_mission_critical: bool = true
@export var dialogue_ui_path: NodePath = NodePath("../../DialogueUI")

var current_dialogue_index: int = 0
var has_talked: bool = false
var is_in_dialogue: bool = false

var dialogue_ui: CanvasLayer = null
var speaker_label: Label = null
var dialogue_label: Label = null
var mission_manager = null

signal dialogue_started(npc_name: String)
signal dialogue_line_shown(line: String, index: int)
signal dialogue_finished(npc_name: String)
signal mission_trigger_completed

func _ready():
	super._ready()
	prompt_text = "Talk to Marcus Reed"
	interaction_id = "marcus_reed"
	one_shot = false
	
	# Find dialogue UI
	if dialogue_ui_path != NodePath(""):
		dialogue_ui = get_node_or_null(dialogue_ui_path)
	else:
		dialogue_ui = get_node_or_null("../../DialogueUI") or get_node_or_null("../../../DialogueUI")
		if not dialogue_ui:
			dialogue_ui = get_tree().get_first_node_in_group("dialogue_ui")
	
	if dialogue_ui:
		speaker_label = dialogue_ui.find_child("SpeakerLabel", true, false) as Label
		dialogue_label = dialogue_ui.find_child("DialogueLabel", true, false) as Label
		print("[Marcus] Dialogue UI found")
	
	# Find mission manager
	mission_manager = get_tree().get_first_node_in_group("mission_manager")
	if not mission_manager:
		mission_manager = get_node_or_null("../../MissionManager") or get_node_or_null("../../../MissionManager")
	
	print("[Marcus] NPC ready at position: ", global_position, " - Phase 2")

func interact():
	# Check if mission allows interaction
	if mission_manager and mission_manager.has_method("can_interact_with_marcus"):
		if not mission_manager.can_interact_with_marcus() and not has_talked:
			print("[Marcus] Interaction blocked by mission manager")
			return
	
	if is_in_dialogue:
		# Advance dialogue on second press
		advance_dialogue()
		return
	
	if has_talked and not is_mission_critical:
		# Already talked, show last line again briefly
		_show_dialogue_line(dialogue_lines[-1], dialogue_lines.size() - 1, 2.0)
		return
	
	super.interact()
	if not is_mission_critical and has_talked:
		return
	
	has_talked = true
	_start_dialogue()

func _start_dialogue():
	if is_in_dialogue:
		return
	is_in_dialogue = true
	emit_signal("dialogue_started", npc_name)
	current_dialogue_index = 0
	
	# Disable player movement during dialogue
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("disable_movement"):
		player.disable_movement()
	
	print("[Marcus] Starting dialogue sequence")
	_show_next_line()

func _show_next_line():
	if current_dialogue_index >= dialogue_lines.size():
		_finish_dialogue()
		return
	
	var line = dialogue_lines[current_dialogue_index]
	emit_signal("dialogue_line_shown", line, current_dialogue_index)
	_show_dialogue_line(line, current_dialogue_index, 0)
	print("[Marcus] Dialogue ", current_dialogue_index, ": ", line)
	
	# For Phase 2, we wait for player input or auto-advance after delay
	# We'll auto-advance but also allow press to skip
	# Auto timer handled in dialogue UI or via await in previous version
	# Now we use timer but can be interrupted by interact press
	await get_tree().create_timer(3.2).timeout
	if is_in_dialogue and current_dialogue_index < dialogue_lines.size():
		# Only auto-advance if still in same index (not manually advanced)
		if current_dialogue_index < dialogue_lines.size():
			current_dialogue_index += 1
			_show_next_line()

func _show_dialogue_line(line: String, index: int, auto_hide_duration: float = 0):
	if dialogue_ui:
		dialogue_ui.visible = true
		if speaker_label:
			speaker_label.text = npc_name.to_upper()
		if dialogue_label:
			dialogue_label.text = line
		
		# Animate in
		if dialogue_ui.has_node("DialoguePanel"):
			var panel = dialogue_ui.get_node("DialoguePanel")
			panel.modulate.a = 0.0
			var tween = create_tween()
			tween.tween_property(panel, "modulate:a", 1.0, 0.25)
	
	if auto_hide_duration > 0:
		await get_tree().create_timer(auto_hide_duration).timeout
		if dialogue_ui:
			dialogue_ui.visible = false

func advance_dialogue():
	# Called when player presses interact during dialogue
	if not is_in_dialogue:
		return
	
	print("[Marcus] Advancing dialogue manually")
	current_dialogue_index += 1
	if current_dialogue_index < dialogue_lines.size():
		_show_next_line()
	else:
		_finish_dialogue()

func _finish_dialogue():
	is_in_dialogue = false
	emit_signal("dialogue_finished", npc_name)
	
	if dialogue_ui:
		# Fade out dialogue UI after delay
		await get_tree().create_timer(1.0).timeout
		if dialogue_ui.has_node("DialoguePanel"):
			var panel = dialogue_ui.get_node("DialoguePanel")
			var tween = create_tween()
			tween.tween_property(panel, "modulate:a", 0.0, 0.3)
			await tween.finished
		dialogue_ui.visible = false
	
	# Re-enable player movement
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("enable_movement"):
		player.enable_movement()
	
	if is_mission_critical:
		emit_signal("mission_trigger_completed")
		print("[Marcus] Mission trigger completed - A NEW BEGINNING")
	
	# Update prompt after first talk
	prompt_text = "Talk to Marcus Reed [Done]"

func reset_dialogue():
	has_talked = false
	current_dialogue_index = 0
	is_in_dialogue = false
	prompt_text = "Talk to Marcus Reed"
	has_been_used = false
	monitoring = true
	if dialogue_ui:
		dialogue_ui.visible = false
