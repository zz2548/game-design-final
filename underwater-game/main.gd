# main.gd
extends Node

func _ready() -> void:
	# get_tree().change_scene_to_file.call_deferred("res://cutscene/opening_cinematic.tscn")
	
	# get_tree().change_scene_to_file.call_deferred("res://levels/level_1/level_1.tscn")
	# get_tree().change_scene_to_file.call_deferred("res://levels/level_2/level_2.tscn")
	get_tree().change_scene_to_file.call_deferred("res://levels/level_3/level_3.tscn")
