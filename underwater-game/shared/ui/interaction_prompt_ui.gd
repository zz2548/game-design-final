# interaction_prompt_ui.gd
# Attach to a Label or Panel in your HUD CanvasLayer.
# Connect to InteractionSystem signals to show/hide the [E] prompt.
#
# Node path assumes: HUD > InteractionPrompt (this Label)

extends Label

# Drag your Player's InteractionSystem node here in the Inspector
@export var interaction_system: InteractionSystem

func _ready() -> void:
	hide()
	if not interaction_system:
		push_warning("InteractionPromptUI: No InteractionSystem assigned.")
		return

	interaction_system.interactable_focused.connect(_on_focused)
	interaction_system.interactable_unfocused.connect(_on_unfocused)


func _on_focused(interactable: Interactable) -> void:
	text = interactable.get_prompt_text()
	show()


func _on_unfocused() -> void:
	hide()
