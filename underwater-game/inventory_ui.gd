# inventory_ui.gd
# Attach to a CanvasLayer node named "InventoryUI"
#
# Required scene tree:
#
# InventoryUI (CanvasLayer)          ← this script
#   └── Root (Control, full rect)
#         ├── Backdrop (ColorRect)   ← dark overlay behind panel
#         └── Panel (PanelContainer)
#               └── VBox (VBoxContainer)
#                     ├── Header (HBoxContainer)
#                     │     ├── Title (Label)        "INVENTORY"
#                     │     └── Count (Label)        "0 / 20"
#                     ├── Divider (HSeparator)
#                     └── Grid (GridContainer)       columns = 5

extends CanvasLayer

@onready var root: Control           = $Root
@onready var grid: GridContainer     = $Root/Panel/VBox/Grid
@onready var count_label: Label      = $Root/Panel/VBox/Header/Count

const SLOT_SIZE   := Vector2(72, 72)
const GRID_COLS   := 5

var _is_open: bool = false

func _ready() -> void:
	# Add Tab to input map in Project Settings if not already there
	root.hide()
	Inventory.inventory_changed.connect(_refresh)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		_toggle()
		get_viewport().set_input_as_handled()

# ─── Open / Close ────────────────────────────────────────────────────────────

func _toggle() -> void:
	_is_open = !_is_open
	if _is_open:
		_refresh()
		root.show()
		# Pause player input while inventory is open (optional)
		get_tree().paused = false  # set true if your game uses pause mode
	else:
		root.hide()

# ─── Build Grid ──────────────────────────────────────────────────────────────

func _refresh() -> void:
	# Clear existing slots
	for child in grid.get_children():
		child.queue_free()

	var filled := Inventory.get_all_items()
	var total  := Inventory.MAX_SLOTS

	count_label.text = "%d / %d" % [filled.size(), total]

	# Draw all slots (empty + filled)
	for i in total:
		var slot_data: Dictionary = Inventory.slots[i]
		grid.add_child(_make_slot(slot_data))

# ─── Slot Builder ─────────────────────────────────────────────────────────────

func _make_slot(slot_data: Dictionary) -> Control:
	var container := PanelContainer.new()
	container.custom_minimum_size = SLOT_SIZE

	# Style the slot box
	var style := StyleBoxFlat.new()
	style.bg_color         = Color(0.06, 0.12, 0.18, 0.85)
	style.border_color     = Color(0.15, 0.45, 0.6, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	container.add_theme_stylebox_override("panel", style)

	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_top",    4)
	inner.add_theme_constant_override("margin_bottom", 4)
	inner.add_theme_constant_override("margin_left",   4)
	inner.add_theme_constant_override("margin_right",  4)
	container.add_child(inner)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_child(vbox)

	if slot_data.is_empty():
		# Empty slot — just show a dim cross
		var empty_label := Label.new()
		empty_label.text = "·"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.2, 0.35, 0.45, 0.5))
		vbox.add_child(empty_label)
		return container

	var item: ItemData = slot_data["item"]
	var qty:  int      = slot_data["quantity"] as int

	# Icon
	if item.icon:
		var tex := TextureRect.new()
		tex.texture             = item.icon
		tex.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.custom_minimum_size = Vector2(40, 40)
		vbox.add_child(tex)
	else:
		# Placeholder if no icon assigned
		var placeholder := Label.new()
		placeholder.text = "?"
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.add_theme_color_override("font_color", Color(0.4, 0.8, 0.9))
		placeholder.add_theme_font_size_override("font_size", 22)
		vbox.add_child(placeholder)

	# Item name
	var name_label := Label.new()
	name_label.text = item.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 9)
	name_label.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_label)

	# Quantity badge (only if stackable)
	if item.max_stack > 1:
		var qty_label := Label.new()
		qty_label.text = "x%d" % qty
		qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		qty_label.add_theme_font_size_override("font_size", 9)
		qty_label.add_theme_color_override("font_color", Color(0.4, 0.85, 0.65))
		vbox.add_child(qty_label)

	# Hover highlight
	container.mouse_entered.connect(func():
		style.border_color = Color(0.3, 0.75, 1.0, 1.0)
		style.bg_color     = Color(0.08, 0.18, 0.28, 0.95)
	)
	container.mouse_exited.connect(func():
		style.border_color = Color(0.15, 0.45, 0.6, 0.7)
		style.bg_color     = Color(0.06, 0.12, 0.18, 0.85)
	)

	return container
