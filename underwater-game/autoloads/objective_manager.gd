# objective_manager.gd
# AUTOLOAD: Add to Project Settings > Autoload as "ObjectiveManager"
#
# Usage:
#   var idx = ObjectiveManager.add_objective("Find the engine part")
#   ObjectiveManager.complete_objective(idx)
#   ObjectiveManager.clear_objectives()

extends Node

signal objectives_changed

# Each entry: { "text": String, "completed": bool }
var objectives: Array = []


func add_objective(text: String) -> int:
	objectives.append({ "text": text, "completed": false })
	emit_signal("objectives_changed")
	return objectives.size() - 1


func complete_objective(index: int) -> void:
	if index < 0 or index >= objectives.size():
		return
	if objectives[index]["completed"]:
		return
	objectives[index]["completed"] = true
	emit_signal("objectives_changed")


func clear_objectives() -> void:
	objectives.clear()
	emit_signal("objectives_changed")
