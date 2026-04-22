# main.gd
extends Node

func _ready() -> void:
	# get_tree().change_scene_to_file.call_deferred("res://cutscene/cutscene.tscn")
	get_tree().change_scene_to_file.call_deferred("res://levels/level_2/level_2.tscn")  # testing: skip to level 2
