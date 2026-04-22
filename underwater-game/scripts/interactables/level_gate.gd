class_name LevelGate
extends Interactable

const KEY_ID := "level2_key"


func _ready() -> void:
	interaction_label = "Gate (Locked)"
	queue_redraw()


func _draw() -> void:
	var locked := not Inventory.has_item(KEY_ID, 1)
	var frame_color := Color(0.25, 0.35, 0.5, 0.95) if locked else Color(0.2, 0.7, 0.3, 0.95)
	var bar_color  := Color(0.5,  0.6,  0.75)        if locked else Color(0.3, 0.9, 0.4)

	# Gate frame
	draw_rect(Rect2(-18, -40, 36, 80), Color(0.1, 0.15, 0.22, 0.9))
	draw_rect(Rect2(-18, -40, 36, 80), frame_color, false, 2.0)

	# Vertical bars
	for i in 4:
		var x := -11.0 + i * 7.5
		draw_line(Vector2(x, -34), Vector2(x, 34), bar_color, 3.0)

	# Lock icon (hidden once key is collected)
	if locked:
		draw_arc(Vector2(0, 4), 6.0, PI, TAU, 10, Color(0.95, 0.8, 0.2), 2.5)
		draw_rect(Rect2(-6, 4, 12, 9), Color(0.95, 0.8, 0.2))


func _on_interact(player: Node) -> void:
	if Inventory.has_item(KEY_ID, 1):
		Inventory.remove_item(KEY_ID, 1)
		interaction_label = "Gate (Open)"
		queue_redraw()
		DialogueManager.start_dialogue({
			"speaker": "ORCA",
			"lines": ["Access key accepted.", "Proceeding to next sector."],
		})
		DialogueManager.dialogue_ended.connect(
			func(): get_tree().change_scene_to_file("res://cutscene/transit_cinematic.tscn"),
			CONNECT_ONE_SHOT
		)
	else:
		DialogueManager.start_dialogue({
			"speaker": "ORCA",
			"lines": ["Gate is locked.", "An access key is required."],
		})
