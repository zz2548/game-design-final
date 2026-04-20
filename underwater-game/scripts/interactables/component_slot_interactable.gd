# component_slot_interactable.gd
# World-space installation bay on the submarine hull.
# Pressing E opens the shared multi-slot repair task UI (same as the submarine).
class_name ComponentSlotInteractable
extends Interactable

signal slot_filled

@export var required_item_id: String = ""
@export var component_display_name: String = ""
@export var item_icon: Texture2D = null

var is_filled: bool = false


func _ready() -> void:
	add_to_group("component_slot")
	_update_label()


func _on_interact(player: Node) -> void:
	if GameState.submarine_fixed:
		# Slots can still capture focus after repair; forward to the submarine.
		var subs := get_tree().get_nodes_in_group("submarine_interactable")
		if subs.size() > 0:
			subs[0]._on_interact(player)
		return
	var slots := get_tree().get_nodes_in_group("component_slot")
	get_tree().root.add_child(TaskUI.create_for_slots(slots))


func complete_installation() -> void:
	is_filled = true
	Inventory.remove_item(required_item_id, 1)
	_update_label()
	modulate = Color(0.35, 1.0, 0.55, 1.0)
	emit_signal("slot_filled")


func _update_label() -> void:
	if is_filled:
		interaction_label = component_display_name + " [Installed]"
	else:
		interaction_label = "Install " + component_display_name
