extends Node2D

var _obj_key: int
var _obj_hostiles: int
var _remaining_enemies: int = 0


func _ready() -> void:
	SceneManager.current_level = 2

	ObjectiveManager.clear_objectives()
	_obj_key      = ObjectiveManager.add_objective("Find the access key to the bore shaft")
	_obj_hostiles = ObjectiveManager.add_objective("Eliminate all hostiles [optional]")

	Inventory.item_added.connect(_on_item_added)

	var enemies: Array = []
	_collect_enemies($Enemies, enemies)
	_remaining_enemies = enemies.size()
	for enemy in enemies:
		enemy.died.connect(_on_enemy_died)


func _collect_enemies(node: Node, result: Array) -> void:
	for child in node.get_children():
		if child.has_signal("died"):
			result.append(child)
		_collect_enemies(child, result)


func _on_item_added(item: ItemData, _qty: int) -> void:
	if item.id == "level2_key":
		ObjectiveManager.complete_objective(_obj_key)


func _on_enemy_died() -> void:
	_remaining_enemies -= 1
	if _remaining_enemies <= 0:
		ObjectiveManager.complete_objective(_obj_hostiles)
