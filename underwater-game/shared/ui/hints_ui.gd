# hints_ui.gd
# Attach to a CanvasLayer node named "HintsUI".
# Displays current objectives from ObjectiveManager in a top-right panel.
#
# Required scene tree:
#
# HintsUI (CanvasLayer)              ← this script
#   └── Panel (PanelContainer)       ← anchored to top-right
#         └── Margin (MarginContainer)
#               └── VBox (VBoxContainer)
#                     ├── Title (Label)      "OBJECTIVES"
#                     ├── Divider (HSeparator)
#                     └── List (VBoxContainer)

extends CanvasLayer

@onready var panel: PanelContainer  = $Panel
@onready var title_label: Label     = $Panel/Margin/VBox/Title
@onready var list: VBoxContainer    = $Panel/Margin/VBox/List


func _ready() -> void:
	_apply_style()
	ObjectiveManager.objectives_changed.connect(_refresh)
	_refresh()


func _apply_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color             = Color(0.06, 0.12, 0.18, 0.85)
	style.border_color         = Color(0.15, 0.45, 0.6, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)

	title_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.9))
	title_label.add_theme_font_size_override("font_size", 12)


func _refresh() -> void:
	for child in list.get_children():
		child.queue_free()

	for obj in ObjectiveManager.objectives:
		var row := Label.new()
		var prefix := "[x] " if obj["completed"] else "[ ] "
		row.text = prefix + obj["text"]
		var col := Color(0.4, 0.85, 0.65) if obj["completed"] else Color(0.75, 0.92, 1.0)
		row.add_theme_color_override("font_color", col)
		row.add_theme_font_size_override("font_size", 10)
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(row)
