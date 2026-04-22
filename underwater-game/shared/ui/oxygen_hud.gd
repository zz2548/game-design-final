# oxygen_hud.gd
# Attach to a CanvasLayer node named "OxygenHUD".
# Displays current oxygen as a colour-coded progress bar in the bottom-left.
#
# Required scene tree:
#
# OxygenHUD (CanvasLayer)           ← this script
#   └── Panel (PanelContainer)      ← anchored to bottom-left
#         └── Margin (MarginContainer)
#               └── VBox (VBoxContainer)
#                     ├── TitleRow (HBoxContainer)
#                     │     ├── TitleLabel (Label)    "O₂ SUPPLY"  (expand)
#                     │     └── SecondsLabel (Label)  "42s"        (shrink-right)
#                     ├── Divider (HSeparator)
#                     └── Bar (ProgressBar)

extends CanvasLayer

@onready var panel         : PanelContainer = $Panel
@onready var title_label   : Label          = $Panel/Margin/VBox/TitleRow/TitleLabel
@onready var seconds_label : Label          = $Panel/Margin/VBox/TitleRow/SecondsLabel
@onready var bar           : ProgressBar    = $Panel/Margin/VBox/Bar

const COLOR_FULL := Color(0.3,  0.85, 0.6)   # green  > 50 %
const COLOR_LOW  := Color(1.0,  0.75, 0.1)   # amber  25–50 %
const COLOR_CRIT := Color(1.0,  0.25, 0.25)  # red    < 25 %

var _ratio : float = 1.0
var _poison_overlay : ColorRect


func _ready() -> void:
	_apply_style()
	_build_poison_overlay()

	await get_tree().process_frame

	var player : Node = get_tree().get_first_node_in_group("player")
	if player == null:
		push_warning("OxygenHUD: no node found in group 'player'")
		return

	player.oxygen_changed.connect(_on_oxygen_changed)
	player.poison_changed.connect(_on_poison_changed)
	_on_oxygen_changed(player.oxygen, player.MAX_OXYGEN)


func _process(_delta: float) -> void:
	# Pulse both labels when oxygen is critical
	if _ratio < 0.25:
		var alpha := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.007)
		title_label.modulate.a   = alpha
		seconds_label.modulate.a = alpha
	else:
		title_label.modulate.a   = 1.0
		seconds_label.modulate.a = 1.0


func _apply_style() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color     = Color(0.06, 0.12, 0.18, 0.85)
	panel_style.border_color = Color(0.15, 0.45, 0.6,  0.7)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", panel_style)

	title_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.9))
	title_label.add_theme_font_size_override("font_size", 12)

	seconds_label.add_theme_font_size_override("font_size", 12)

	# Progress bar background
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.08, 0.15, 0.22)
	bg_style.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", bg_style)

	bar.show_percentage = false
	bar.min_value       = 0.0
	bar.max_value       = 1.0


func _build_poison_overlay() -> void:
	_poison_overlay = ColorRect.new()
	_poison_overlay.color = Color(0.0, 1.0, 0.2, 0.18)
	_poison_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_poison_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_poison_overlay.visible = false
	panel.add_child(_poison_overlay)


func _on_poison_changed(is_poisoned: bool) -> void:
	_poison_overlay.visible = is_poisoned


func _on_oxygen_changed(current: float, maximum: float) -> void:
	_ratio    = current / maximum
	bar.value = _ratio

	var fill_style := StyleBoxFlat.new()
	fill_style.set_corner_radius_all(2)
	var bar_color : Color
	if _ratio > 0.5:
		bar_color = COLOR_FULL
	elif _ratio > 0.25:
		bar_color = COLOR_LOW
	else:
		bar_color = COLOR_CRIT
	fill_style.bg_color = bar_color
	bar.add_theme_stylebox_override("fill", fill_style)

	seconds_label.text = "%ds" % ceili(current)
	seconds_label.add_theme_color_override("font_color", bar_color)
