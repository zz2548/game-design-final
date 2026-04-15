# game_state.gd
# AUTOLOAD: Add to Project Settings > Autoload as "GameState"
# Tracks global progression flags across scenes.
extends Node

var submarine_fixed     : bool   = false
var death_return_scene  : String = ""   # set by player.gd before going to death screen
