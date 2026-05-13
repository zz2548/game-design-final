# game_state.gd
# AUTOLOAD: Add to Project Settings > Autoload as "GameState"
# Tracks global progression flags across scenes.
extends Node

enum Difficulty { EASY, HARD }

## Set from the difficulty select screen before the game begins.
var difficulty : Difficulty = Difficulty.HARD

var submarine_fixed        : bool   = false
var death_return_scene     : String = ""   # set by player.gd before going to death screen
var melee_tutorial_shown   : bool   = false

# Persisted weapon state across level transitions.
var saved_weapons         : Array[String] = []   # resource_path of each collected weapon
var saved_current_weapon  : String        = ""   # resource_path of equipped weapon

# Persisted player stats across level transitions (-1 = not saved, restore to max).
var saved_health  : int   = -1
var saved_oxygen  : float = -1.0

# Persisted objective snapshots: Array of { "text": String, "completed": bool }
var level_1_objectives  : Array  = []
var level_2_objectives  : Array  = []
var level_3_objectives  : Array  = []


func save_player_stats(player: Node) -> void:
	saved_health = player.health
	saved_oxygen = player.oxygen


# Call this before leaving Level 1 to snapshot the current objective list.
func save_objectives_from_level_1() -> void:
	level_1_objectives = ObjectiveManager.objectives.duplicate(true)


# Call this before leaving Level 2 to snapshot the current objective list.
func save_objectives_from_level_2() -> void:
	level_2_objectives = ObjectiveManager.objectives.duplicate(true)


# Call this before leaving Level 3 to snapshot the current objective list.
func save_objectives_from_level_3() -> void:
	level_3_objectives = ObjectiveManager.objectives.duplicate(true)
