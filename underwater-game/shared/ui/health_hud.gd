# health_hud.gd
# Displays player HP as a colour-coded bar in the top-left.
#
# Required scene tree:
#
# HealthHUD (CanvasLayer)            ← this script
#   └── Panel (PanelContainer)       ← anchored to top-left
#         └── Margin (MarginContainer)
#               └── VBox (VBoxContainer)
#                     ├── TitleRow (HBoxContainer)
#                     │     ├── TitleLabel (Label)   "HULL"   (expand)
#                     │     └── CountLabel (Label)   "5 / 5"  (shrink-right)
#                     ├── Divider (HSeparator)
#                     └── Bar (ProgressBar)

extends CanvasLayer

@onready var panel       : PanelContainer = $Panel
@onready var title_label : Label          = $Panel/Margin/VBox/TitleRow/TitleLabel
@onready var count_label : Label          = $Panel/Margin/VBox/TitleRow/CountLabel
@onready var bar         : ProgressBar    = $Panel/Margin/VBox/Bar

const COLOR_FULL := Color(0.9,  0.25, 0.25)  # red    > 50 %
const COLOR_LOW  := Color(1.0,  0.55, 0.15)  # orange 25–50 %
const COLOR_CRIT := Color(1.0,  0.9,  0.1)   # yellow < 25 %

var _ratio : float = 1.0


func _ready() -> void:
	_apply_style()

	await get_tree().process_frame

	var player : Node = get_tree().get_first_node_in_group("player")
	if player == null:
		push_warning("HealthHUD: no node in group 'player'")
		return

	player.health_changed.connect(_on_health_changed)
	_on_health_changed(player.health, player.MAX_HEALTH)


func _process(_delta: float) -> void:
	if _ratio < 0.25:
		var alpha := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.007)
		title_label.modulate.a = alpha
		count_label.modulate.a = alpha
	else:
		title_label.modulate.a = 1.0
		count_label.modulate.a = 1.0


func _apply_style() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color     = Color(0.06, 0.12, 0.18, 0.85)
	panel_style.border_color = Color(0.15, 0.45, 0.6,  0.7)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", panel_style)

	title_label.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35))
	title_label.add_theme_font_size_override("font_size", 12)
	count_label.add_theme_font_size_override("font_size", 12)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.08, 0.15, 0.22)
	bg_style.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", bg_style)

	bar.show_percentage = false
	bar.min_value       = 0.0
	bar.max_value       = 1.0


func _on_health_changed(current: int, maximum: int) -> void:
	_ratio    = float(current) / float(maximum)
	bar.value = _ratio

	var bar_color : Color
	if _ratio > 0.5:
		bar_color = COLOR_FULL
	elif _ratio > 0.25:
		bar_color = COLOR_LOW
	else:
		bar_color = COLOR_CRIT

	var fill_style := StyleBoxFlat.new()
	fill_style.set_corner_radius_all(2)
	fill_style.bg_color = bar_color
	bar.add_theme_stylebox_override("fill", fill_style)

	count_label.text = "%d / %d" % [current, maximum]
	count_label.add_theme_color_override("font_color", bar_color)
