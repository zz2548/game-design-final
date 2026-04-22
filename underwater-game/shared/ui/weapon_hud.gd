extends CanvasLayer

@onready var panel        : PanelContainer = $Panel
@onready var weapon_label : Label          = $Panel/Margin/VBox/WeaponLabel
@onready var hint_label   : Label          = $Panel/Margin/VBox/HintLabel


func _ready() -> void:
	_apply_style()
	await get_tree().process_frame

	var player : Node = get_tree().get_first_node_in_group("player")
	if player == null:
		push_warning("WeaponHUD: no node in group 'player'")
		return

	player.weapon_changed.connect(_on_weapon_changed)
	if player.current_weapon != null:
		_on_weapon_changed(player.current_weapon.display_name)


func _apply_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.06, 0.12, 0.18, 0.85)
	style.border_color = Color(0.15, 0.45, 0.6, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)

	weapon_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.9))
	weapon_label.add_theme_font_size_override("font_size", 12)

	hint_label.add_theme_color_override("font_color", Color(0.4, 0.55, 0.65))
	hint_label.add_theme_font_size_override("font_size", 10)


func _on_weapon_changed(weapon_name: String) -> void:
	weapon_label.text = weapon_name
	var player : Node = get_tree().get_first_node_in_group("player")
	var has_multiple : bool = player != null and player._weapons.size() > 1
	hint_label.text    = "[X] swap" if has_multiple else ""
	hint_label.visible = has_multiple
