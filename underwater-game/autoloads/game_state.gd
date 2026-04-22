# game_state.gd
# AUTOLOAD: Add to Project Settings > Autoload as "GameState"
# Tracks global progression flags across scenes.
extends Node

var submarine_fixed     : bool   = false
var death_return_scene  : String = ""   # set by player.gd before going to death screen

# Persisted objective snapshots: Array of { "text": String, "completed": bool }
var level_1_objectives  : Array  = []
var level_2_objectives  : Array  = []


# Call this before leaving Level 1 to snapshot the current objective list.
func save_objectives_from_level_1() -> void:
	level_1_objectives = ObjectiveManager.objectives.duplicate(true)


# Call this before leaving Level 2 to snapshot the current objective list.
func save_objectives_from_level_2() -> void:
	level_2_objectives = ObjectiveManager.objectives.duplicate(true)
