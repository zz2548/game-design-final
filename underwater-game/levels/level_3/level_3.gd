extends Node


func _ready() -> void:
	MusicManager.stop()

	var cl := CanvasLayer.new()
	cl.layer = 10
	add_child(cl)

	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	cl.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	cl.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 24)
	center.add_child(vbox)

	var label := Label.new()
	label.text = "Coming soon."
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 36)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 32)
	vbox.add_child(hbox)

	var restart_btn := Button.new()
	restart_btn.text = "Restart"
	restart_btn.pressed.connect(_on_restart)
	hbox.add_child(restart_btn)

	var exit_btn := Button.new()
	exit_btn.text = "Exit"
	exit_btn.pressed.connect(_on_exit)
	hbox.add_child(exit_btn)


func _on_restart() -> void:
	get_tree().change_scene_to_file("res://main.tscn")


func _on_exit() -> void:
	get_tree().quit()
