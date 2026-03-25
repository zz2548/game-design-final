# pickup_item.gd
# Attach to an Area3D with a CollisionShape3D.
# Drag an ItemData resource into the `item` export field in the Inspector.

class_name PickupItem
extends Interactable

@export var item: ItemData
@export var quantity: int = 1

func _ready() -> void:
	print("PickupItem ready: ", item)
	if not item:
		push_warning("PickupItem has no item assigned!")


func _on_interact(player: Node) -> void:
	print("_on_interact called, item: ", item)
	if not item:
		push_warning("PickupItem has no item assigned!")
		return
	var success := Inventory.add_item(item, quantity)
	if success:
		queue_free()
	else:
		# Inventory full — could trigger a UI message
		pass
		
