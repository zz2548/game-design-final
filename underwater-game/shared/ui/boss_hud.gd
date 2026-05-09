# boss_hud.gd
# Boss health bar + vulnerability indicator shown at the top-centre of the
# screen whenever the boss is visible in the viewport.
#
# Wire-up (done by level_3.gd):
#   hud.connect_boss(boss_node)
#
# The HUD is hidden by default and shown/hidden via the boss's
# became_visible / became_hidden signals.

extends CanvasLayer

# ── Colour palette (matches existing HUD style) ───────────────────────────────
const COLOR_FULL   := Color(0.9,  0.25, 0.25)  # red    > 50 %
const COLOR_LOW    := Color(1.0,  0.55, 0.15)  # orange 25–50 %
const COLOR_CRIT   := Color(1.0,  0.9,  0.1)   # yellow < 25 %

const VULN_COLOR   := Color(1.0,  0.9,  0.15)  # yellow  — exposed / can be hit
const SHIELD_COLOR := Color(0.45, 0.75, 1.4)   # blue    — shielded

# ── Nodes built in _ready ─────────────────────────────────────────────────────
var _panel       : PanelContainer
var _vuln_label  : Label          # "●" indicator
var _name_label  : Label          # "THE SERPENT"
var _count_label : Label          # "30 / 30"
var _bar         : ProgressBar

# ── State ─────────────────────────────────────────────────────────────────────
var _ratio        : float = 1.0
var _shielded     : bool  = true
var _pulse_t      : float = 0.0


func _ready() -> void:
	layer = 6   # above most HUD layers (health = default 1, dialogue = 100)
	_build_ui()
	hide()


func _process(delta: float) -> void:
	if not visible:
		return
	# Pulse the vulnerability dot when the boss is exposed
	if not _shielded:
		_pulse_t += delta
		_vuln_label.modulate.a = 0.55 + 0.45 * sin(_pulse_t * 5.0)
	else:
		_pulse_t = 0.0
		_vuln_label.modulate.a = 1.0


# ── Public API ────────────────────────────────────────────────────────────────

func connect_boss(boss: Node) -> void:
	boss.health_changed.connect(_on_health_changed)
	boss.vulnerability_changed.connect(_on_vulnerability_changed)
	boss.became_visible.connect(_on_boss_screen_entered)
	boss.became_hidden.connect(_on_boss_screen_exited)
	boss.died.connect(_on_boss_died)
	# Initialise from current state
	_on_health_changed(boss.max_health, boss.max_health)
	_on_vulnerability_changed(true)  # boss starts shielded


# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_boss_screen_entered() -> void:
	show()


func _on_boss_screen_exited() -> void:
	hide()


func _on_boss_died() -> void:
	hide()


func _on_health_changed(current: int, maximum: int) -> void:
	_ratio    = float(current) / float(maximum) if maximum > 0 else 0.0
	_bar.value = _ratio

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
	_bar.add_theme_stylebox_override("fill", fill_style)

	_count_label.text = "%d / %d" % [current, maximum]
	_count_label.add_theme_color_override("font_color", bar_color)


func _on_vulnerability_changed(is_shielded: bool) -> void:
	_shielded = is_shielded
	if is_shielded:
		_vuln_label.text = "■"
		_vuln_label.add_theme_color_override("font_color", SHIELD_COLOR)
		_vuln_label.tooltip_text = "SHIELDED"
	else:
		_vuln_label.text = "▲"
		_vuln_label.add_theme_color_override("font_color", VULN_COLOR)
		_vuln_label.tooltip_text = "EXPOSED"


# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	# ── Outer panel — top-centre ──────────────────────────────────────────────
	_panel = PanelContainer.new()
	_panel.name = "Panel"

	_panel.anchor_left   = 0.5
	_panel.anchor_right  = 0.5
	_panel.anchor_top    = 0.0
	_panel.anchor_bottom = 0.0
	_panel.offset_left   = -110.0
	_panel.offset_right  = 110.0
	_panel.offset_top    = 10.0
	_panel.grow_vertical = Control.GROW_DIRECTION_END

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color     = Color(0.06, 0.12, 0.18, 0.88)
	panel_style.border_color = Color(0.15, 0.45, 0.6,  0.7)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(4)
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	# ── Margin ────────────────────────────────────────────────────────────────
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left",   8)
	margin.add_theme_constant_override("margin_right",  8)
	margin.add_theme_constant_override("margin_top",    5)
	margin.add_theme_constant_override("margin_bottom", 5)
	_panel.add_child(margin)

	# ── VBox ──────────────────────────────────────────────────────────────────
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)

	# ── Title row ─────────────────────────────────────────────────────────────
	var title_row := HBoxContainer.new()
	title_row.name = "TitleRow"
	title_row.add_theme_constant_override("separation", 5)
	vbox.add_child(title_row)

	# Vulnerability indicator dot
	_vuln_label = Label.new()
	_vuln_label.name = "VulnLabel"
	_vuln_label.text = "■"
	_vuln_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_vuln_label.add_theme_font_size_override("font_size", 10)
	title_row.add_child(_vuln_label)

	# Boss name
	_name_label = Label.new()
	_name_label.name = "NameLabel"
	_name_label.text = "THE SERPENT"
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.add_theme_color_override("font_color", Color(0.75, 0.35, 0.35))
	_name_label.add_theme_font_size_override("font_size", 12)
	title_row.add_child(_name_label)

	# HP count
	_count_label = Label.new()
	_count_label.name = "CountLabel"
	_count_label.text = "30 / 30"
	_count_label.add_theme_font_size_override("font_size", 12)
	title_row.add_child(_count_label)

	# ── Divider ───────────────────────────────────────────────────────────────
	var divider := HSeparator.new()
	divider.name = "Divider"
	vbox.add_child(divider)

	# ── HP bar ────────────────────────────────────────────────────────────────
	_bar = ProgressBar.new()
	_bar.name = "Bar"
	_bar.show_percentage = false
	_bar.min_value       = 0.0
	_bar.max_value       = 1.0
	_bar.value           = 1.0
	_bar.custom_minimum_size = Vector2(0, 8)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.08, 0.15, 0.22)
	bg_style.set_corner_radius_all(2)
	_bar.add_theme_stylebox_override("background", bg_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.set_corner_radius_all(2)
	fill_style.bg_color = COLOR_FULL
	_bar.add_theme_stylebox_override("fill", fill_style)

	vbox.add_child(_bar)
