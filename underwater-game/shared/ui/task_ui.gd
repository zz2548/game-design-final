# task_ui.gd
# Among Us-style drag-and-drop repair task.
# Shows all 3 component slots at once. Items (left, shuffled) must be dragged
# into their matching labeled bays (right). Works while the game tree is paused.
class_name TaskUI
extends CanvasLayer

var _slots: Array          # Array[ComponentSlotInteractable]
var _drag_item_map: Dictionary = {}   # item_id -> DragItem
var _filled_in_session: int = 0
var _needed_in_session: int = 0
var _done: bool = false


# ── Inner: draggable component icon ──────────────────────────────────────────

class DragItem extends PanelContainer:
	var item_id: String
	var icon: Texture2D
	var available: bool = true

	func _ready() -> void:
		custom_minimum_size = Vector2(88, 88)
		if available:
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_refresh_style()
		if icon:
			var tex := TextureRect.new()
			tex.texture = icon
			tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(tex)
		if not available:
			modulate = Color(1, 1, 1, 0.35)

	func _refresh_style() -> void:
		var s := StyleBoxFlat.new()
		s.bg_color     = Color(0.10, 0.22, 0.32) if available else Color(0.05, 0.08, 0.12)
		s.border_color = Color(0.28, 0.65, 0.90) if available else Color(0.18, 0.22, 0.28)
		s.set_border_width_all(2)
		s.set_corner_radius_all(6)
		add_theme_stylebox_override("panel", s)

	func _get_drag_data(_pos: Vector2) -> Variant:
		if not available:
			return null
		# Wrap the visual in an offset Control so the cursor hits the center,
		# not the top-left corner (set_drag_preview anchors at the cursor origin).
		const SIZE := 88.0
		var wrapper := Control.new()
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(SIZE, SIZE)
		panel.position = Vector2(-SIZE * 0.5, -SIZE * 0.5)
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.10, 0.22, 0.32, 0.85)
		s.border_color = Color(0.28, 0.65, 0.90)
		s.set_border_width_all(2)
		s.set_corner_radius_all(6)
		panel.add_theme_stylebox_override("panel", s)
		if icon:
			var tex := TextureRect.new()
			tex.texture = icon
			tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			panel.add_child(tex)
		wrapper.add_child(panel)
		set_drag_preview(wrapper)
		modulate = Color(1, 1, 1, 0.35)
		return {"type": "component", "item_id": item_id}

	func _notification(what: int) -> void:
		# Restore opacity when drag ends without a successful drop
		if what == NOTIFICATION_DRAG_END and available:
			modulate = Color(1, 1, 1, 1.0)

	func set_installed() -> void:
		available = false
		modulate = Color(1, 1, 1, 0.35)
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		_refresh_style()


# ── Inner: drop target bay ────────────────────────────────────────────────────

class DropSlot extends PanelContainer:
	var required_item_id: String
	var icon: Texture2D
	var task: TaskUI
	var slot_ref: ComponentSlotInteractable
	var prefilled: bool = false
	var _check_label: Label

	func _ready() -> void:
		custom_minimum_size = Vector2(88, 88)
		_apply_style(prefilled)
		# Faint ghost icon as hint
		if icon:
			var tex := TextureRect.new()
			tex.texture = icon
			tex.modulate = Color(1, 1, 1, 0.18 if not prefilled else 1.0)
			tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(tex)
		_check_label = Label.new()
		_check_label.text = "✓" if prefilled else ""
		_check_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_check_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_check_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_check_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_check_label.add_theme_font_size_override("font_size", 28)
		_check_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.55))
		add_child(_check_label)

	func _apply_style(filled: bool) -> void:
		var s := StyleBoxFlat.new()
		s.bg_color     = Color(0.08, 0.38, 0.18) if filled else Color(0.04, 0.10, 0.15)
		s.border_color = Color(0.28, 1.00, 0.50) if filled else Color(0.28, 0.65, 0.90, 0.55)
		s.set_border_width_all(3 if filled else 2)
		s.set_corner_radius_all(6)
		add_theme_stylebox_override("panel", s)

	func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
		return (not prefilled
			and data is Dictionary
			and data.get("type") == "component"
			and data.get("item_id") == required_item_id)

	func _drop_data(_pos: Vector2, data: Variant) -> void:
		prefilled = true
		_apply_style(true)
		_check_label.text = "✓"
		# Brighten the ghost icon
		for child in get_children():
			if child is TextureRect:
				child.modulate = Color(1, 1, 1, 1.0)
		slot_ref.complete_installation()
		task.on_item_installed(data.get("item_id", ""))


# ── Factory ───────────────────────────────────────────────────────────────────

static func create_for_slots(slots: Array) -> TaskUI:
	var ui := TaskUI.new()
	ui._slots = slots.duplicate()
	return ui


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	for slot in _slots:
		if not slot.is_filled and Inventory.has_item(slot.required_item_id):
			_needed_in_session += 1
	_build_ui()
	get_tree().paused = true


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(root)

	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.72)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(540, 0)
	center.add_child(panel)

	var ps := StyleBoxFlat.new()
	ps.bg_color     = Color(0.05, 0.10, 0.16, 0.97)
	ps.border_color = Color(0.18, 0.52, 0.72, 1.0)
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(8)
	ps.content_margin_left   = 28
	ps.content_margin_right  = 28
	ps.content_margin_top    = 22
	ps.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", ps)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	# Header
	var header := Label.new()
	header.text = "TASK: REPAIR TETHYS-7"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", Color(0.35, 0.75, 0.95))
	header.add_theme_font_size_override("font_size", 14)
	vbox.add_child(header)

	var sub := Label.new()
	sub.text = "Drag each component into its matching installation bay"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.55, 0.70, 0.80))
	sub.add_theme_font_size_override("font_size", 10)
	vbox.add_child(sub)

	vbox.add_child(HSeparator.new())

	# Column headers
	var col_row := HBoxContainer.new()
	vbox.add_child(col_row)

	var lh := Label.new()
	lh.text = "COMPONENTS"
	lh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lh.add_theme_color_override("font_color", Color(0.45, 0.65, 0.80))
	lh.add_theme_font_size_override("font_size", 10)
	col_row.add_child(lh)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(48, 0)
	col_row.add_child(spacer)

	var rh := Label.new()
	rh.text = "INSTALLATION BAYS"
	rh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rh.add_theme_color_override("font_color", Color(0.45, 0.65, 0.80))
	rh.add_theme_font_size_override("font_size", 10)
	col_row.add_child(rh)

	# Main area: items | arrows | slots
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	vbox.add_child(row)

	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.add_theme_constant_override("separation", 10)
	row.add_child(left_col)

	var arrow_col := VBoxContainer.new()
	arrow_col.custom_minimum_size = Vector2(48, 0)
	arrow_col.add_theme_constant_override("separation", 10)
	row.add_child(arrow_col)

	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 10)
	row.add_child(right_col)

	# Shuffled items on the left
	var shuffled := _slots.duplicate()
	shuffled.shuffle()
	for slot_data in shuffled:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 4)
		left_col.add_child(cell)

		var c := CenterContainer.new()
		cell.add_child(c)

		var drag_item := DragItem.new()
		drag_item.item_id = slot_data.required_item_id
		drag_item.icon    = slot_data.item_icon
		drag_item.available = (not slot_data.is_filled
				and Inventory.has_item(slot_data.required_item_id))
		c.add_child(drag_item)
		_drag_item_map[slot_data.required_item_id] = drag_item

		var nm := Label.new()
		nm.text = slot_data.component_display_name
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.add_theme_font_size_override("font_size", 10)
		nm.add_theme_color_override("font_color",
			Color(0.85, 0.95, 1.0) if drag_item.available else Color(0.38, 0.40, 0.43))
		cell.add_child(nm)

	# Arrows
	for _i in _slots.size():
		var ac := CenterContainer.new()
		ac.size_flags_vertical = Control.SIZE_EXPAND_FILL
		arrow_col.add_child(ac)
		var a := Label.new()
		a.text = "→"
		a.add_theme_color_override("font_color", Color(0.35, 0.55, 0.70))
		a.add_theme_font_size_override("font_size", 22)
		ac.add_child(a)

	# Fixed slots on the right
	for slot_data in _slots:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 4)
		right_col.add_child(cell)

		var c := CenterContainer.new()
		cell.add_child(c)

		var drop := DropSlot.new()
		drop.required_item_id = slot_data.required_item_id
		drop.icon     = slot_data.item_icon
		drop.task     = self
		drop.slot_ref = slot_data
		drop.prefilled = slot_data.is_filled
		c.add_child(drop)

		var bay := Label.new()
		bay.text = slot_data.component_display_name + " Bay"
		bay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bay.add_theme_font_size_override("font_size", 10)
		bay.add_theme_color_override("font_color", Color(0.55, 0.72, 0.85))
		cell.add_child(bay)

	vbox.add_child(HSeparator.new())

	var cancel_label := Label.new()
	cancel_label.text = "[ESC] Close"
	cancel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cancel_label.add_theme_color_override("font_color", Color(0.40, 0.45, 0.50))
	cancel_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(cancel_label)


# ── Callbacks ─────────────────────────────────────────────────────────────────

func on_item_installed(item_id: String) -> void:
	if _drag_item_map.has(item_id):
		_drag_item_map[item_id].set_installed()
	_filled_in_session += 1
	if _needed_in_session > 0 and _filled_in_session >= _needed_in_session:
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	# Don't unpause if a dialogue was triggered by the last slot_filled signal
	if not DialogueManager.is_active:
		get_tree().paused = false
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	if _done:
		return
	_done = true
	if not DialogueManager.is_active:
		get_tree().paused = false
	queue_free()
