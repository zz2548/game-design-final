extends Node

const LEVELS = {
	1: "res://levels/level_1/level_1.tscn",
	2: "res://levels/level_2/level_2.tscn",
	3: "res://levels/level_3/level_3.tscn",
}

var current_level: int = 1

func go_to_level(n: int) -> void:
	current_level = n
	get_tree().change_scene_to_file(LEVELS[n])

func next_level() -> void:
	go_to_level(current_level + 1)
