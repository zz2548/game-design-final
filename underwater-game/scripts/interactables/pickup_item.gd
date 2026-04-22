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
		return
	interaction_label = item.display_name


func _on_interact(player: Node) -> void:
	print("_on_interact called, item: ", item)
	if not item:
		push_warning("PickupItem has no item assigned!")
		return
	var success := Inventory.add_item(item, quantity)
	if success:
		var snd := AudioStreamPlayer.new()
		snd.stream = load("res://assets/sounds/item.mp3")
		snd.finished.connect(snd.queue_free)
		get_parent().add_child(snd)
		snd.play()
		queue_free()
	else:
		# Inventory full — could trigger a UI message
		pass
		
