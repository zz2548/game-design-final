# pickup_item.gd
# Attach to an Area3D with a CollisionShape3D.
# Drag an ItemData resource into the `item` export field in the Inspector.

class_name PickupItem
extends Interactable

@export var item: ItemData
@export var quantity: int = 1

func _ready() -> void:
	if item:
		interaction_label = item.display_name


func _on_interact(player: Node) -> void:
	if not item:
		push_warning("PickupItem has no ItemData assigned!")
		return

	var success := Inventory.add_item(item, quantity)
	if success:
		# Optional: play a pickup sound here
		queue_free()  # Remove from world
	else:
		# Inventory full — could trigger a UI message
		pass
