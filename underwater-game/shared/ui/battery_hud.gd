# battery_hud.gd
# Attach to a CanvasLayer node named "BatteryHUD".
# Displays flashlight battery as a colour-coded bar in the bottom-left,
# stacked directly above the OxygenHUD.
#
# Required scene tree:
#
# BatteryHUD (CanvasLayer)          ← this script
#   └── Panel (PanelContainer)      ← anchored to bottom-left
#         └── Margin (MarginContainer)
#               └── VBox (VBoxContainer)
#                     ├── TitleRow (HBoxContainer)
#                     │     ├── TitleLabel (Label)    "TORCH"  (expand)
#                     │     └── SecondsLabel (Label)  "120s"   (shrink-right)
#                     ├── Divider (HSeparator)
#                     └── Bar (ProgressBar)

extends CanvasLayer

@onready var panel         : PanelContainer = $Panel
@onready var title_label   : Label          = $Panel/Margin/VBox/TitleRow/TitleLabel
@onready var seconds_label : Label          = $Panel/Margin/VBox/TitleRow/SecondsLabel
@onready var bar           : ProgressBar    = $Panel/Margin/VBox/Bar

const COLOR_FULL := Color(0.95, 0.88, 0.25)  # bright yellow  > 50 %
const COLOR_LOW  := Color(1.0,  0.55, 0.1)   # amber-orange   25–50 %
const COLOR_CRIT := Color(1.0,  0.25, 0.25)  # red            < 25 %

var _ratio      : float = 1.0
var _warn_label : Label = null


func _ready() -> void:
	_apply_style()

	await get_tree().process_frame

	var player : Node = get_tree().get_first_node_in_group("player")
	if player == null:
		push_warning("BatteryHUD: no node found in group 'player'")
		return

	# Warning icon — injected into TitleRow before the seconds label
	_warn_label = Label.new()
	_warn_label.text = "⚠"
	_warn_label.add_theme_font_size_override("font_size", 12)
	_warn_label.add_theme_color_override("font_color", COLOR_CRIT)
	_warn_label.visible = false
	$Panel/Margin/VBox/TitleRow.add_child(_warn_label)
	$Panel/Margin/VBox/TitleRow.move_child(_warn_label, 1)

	player.battery_changed.connect(_on_battery_changed)
	_on_battery_changed(player.battery, player.MAX_BATTERY)


func _process(_delta: float) -> void:
	if _ratio < 0.1:
		# Critical: pulse the warning icon rapidly
		var alpha := 0.4 + 0.6 * sin(Time.get_ticks_msec() * 0.012)
		if _warn_label:
			_warn_label.modulate.a = alpha
	elif _warn_label:
		_warn_label.modulate.a = 1.0


func _apply_style() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color     = Color(0.06, 0.12, 0.18, 0.85)
	panel_style.border_color = Color(0.15, 0.45, 0.6,  0.7)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", panel_style)

	title_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.4))
	title_label.add_theme_font_size_override("font_size", 12)

	seconds_label.add_theme_font_size_override("font_size", 12)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.08, 0.15, 0.22)
	bg_style.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", bg_style)

	bar.show_percentage = false
	bar.min_value       = 0.0
	bar.max_value       = 1.0


func _on_battery_changed(current: float, maximum: float) -> void:
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

	if _warn_label:
		_warn_label.visible = _ratio <= 0.25
		_warn_label.add_theme_color_override("font_color",
				COLOR_CRIT if _ratio < 0.1 else COLOR_LOW)
