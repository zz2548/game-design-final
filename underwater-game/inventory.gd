# inventory.gd
extends Node

signal item_added(item: ItemData, quantity: int)
signal item_removed(item: ItemData, quantity: int)
signal inventory_changed

const MAX_SLOTS: int = 20

var slots: Array[Dictionary] = []

func _ready() -> void:
	slots.resize(MAX_SLOTS)
	for i in MAX_SLOTS:
		slots[i] = {}

func add_item(item: ItemData, quantity: int = 1) -> bool:
	var remaining: int = quantity

	if item.max_stack > 1:
		for slot in slots:
			if slot.is_empty():
				continue
			if slot["item"].id == item.id and slot["quantity"] < item.max_stack:
				var space: int = item.max_stack - slot["quantity"]
				var to_add: int = mini(space, remaining)
				slot["quantity"] = (slot["quantity"] as int) + to_add
				remaining -= to_add
				if remaining == 0:
					break

	while remaining > 0:
		var empty_idx: int = _find_empty_slot()
		if empty_idx == -1:
			push_warning("Inventory full! Could not add %s." % item.display_name)
			return false
		var to_add: int = mini(item.max_stack, remaining)
		slots[empty_idx] = { "item": item, "quantity": to_add }
		remaining -= to_add

	emit_signal("item_added", item, quantity - remaining)
	emit_signal("inventory_changed")
	return remaining == 0

func remove_item(item_id: String, quantity: int = 1) -> bool:
	if not has_item(item_id, quantity):
		return false

	var remaining: int = quantity
	for slot in slots:
		if slot.is_empty() or slot["item"].id != item_id:
			continue
		var to_remove: int = mini(slot["quantity"] as int, remaining)
		slot["quantity"] = (slot["quantity"] as int) - to_remove
		remaining -= to_remove
		if (slot["quantity"] as int) == 0:
			slot.clear()
		if remaining == 0:
			break

	emit_signal("item_removed", _find_item_data(item_id), quantity)
	emit_signal("inventory_changed")
	return true

func has_item(item_id: String, quantity: int = 1) -> bool:
	return get_item_count(item_id) >= quantity

func get_item_count(item_id: String) -> int:
	var total: int = 0
	for slot in slots:
		if not slot.is_empty() and slot["item"].id == item_id:
			total += slot["quantity"] as int
	return total

func get_all_items() -> Array[Dictionary]:
	var filled: Array[Dictionary] = []
	for slot in slots:
		if not slot.is_empty():
			filled.append(slot)
	return filled

func _find_empty_slot() -> int:
	for i in slots.size():
		if slots[i].is_empty():
			return i
	return -1

func _find_item_data(item_id: String) -> ItemData:
	for slot in slots:
		if not slot.is_empty() and slot["item"].id == item_id:
			return slot["item"]
	return null
