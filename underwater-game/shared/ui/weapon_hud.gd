# weapon_hud.gd
# Attach to a CanvasLayer node named "WeaponHUD".
# Displays the currently equipped weapon name and ammo count in a bottom-right panel.
#
# Required scene tree:
#
# WeaponHUD (CanvasLayer)             ← this script
#   └── Panel (PanelContainer)        ← anchored to bottom-right
#         └── Margin (MarginContainer)
#               └── VBox (VBoxContainer)
#                     ├── WeaponLabel (Label)    gun name
#                     ├── Divider (HSeparator)
#                     └── AmmoLabel (Label)      "12 / 30"

extends CanvasLayer

@onready var panel        : PanelContainer = $Panel
@onready var weapon_label : Label          = $Panel/Margin/VBox/WeaponLabel
@onready var ammo_label   : Label          = $Panel/Margin/VBox/AmmoLabel


func _ready() -> void:
	_apply_style()

	# The player adds itself to the "player" group on spawn.
	# Defer one frame so the player node is guaranteed to be in the tree.
	await get_tree().process_frame

	var player : Node = get_tree().get_first_node_in_group("player")
	if player == null:
		push_warning("WeaponHUD: no node found in group 'player'")
		return

	player.ammo_changed.connect(_on_ammo_changed)

	# Show the initial weapon state immediately
	if player.current_weapon != null:
		var id : String = player.current_weapon.id
		_on_ammo_changed(
			player.current_weapon.display_name,
			player._ammo.get(id, 0),
			player.current_weapon.max_ammo
		)


func _apply_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.06, 0.12, 0.18, 0.85)
	style.border_color = Color(0.15, 0.45, 0.6, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)

	weapon_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.9))
	weapon_label.add_theme_font_size_override("font_size", 12)

	ammo_label.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0))
	ammo_label.add_theme_font_size_override("font_size", 10)


func _on_ammo_changed(weapon_name: String, current: int, maximum: int) -> void:
	weapon_label.text = weapon_name
	ammo_label.text   = "%d / %d" % [current, maximum]
	# Turn ammo count red when empty
	var ammo_color := Color(1.0, 0.3, 0.3) if current == 0 else Color(0.75, 0.92, 1.0)
	ammo_label.add_theme_color_override("font_color", ammo_color)
