# level_1.gd
# Attached to the Level1 node.
# Sets up objectives, marks them complete as the player progresses,
# and orchestrates the submarine driving sequence at the end.

extends Node2D

# ── Objective indices ─────────────────────────────────────────────────────────
var _obj_engine: int
var _obj_hull: int
var _obj_nav: int
var _obj_repair: int
var _obj_escape: int

# ── Scene refs ────────────────────────────────────────────────────────────────
@onready var _submarine        : SubmarineInteractable    = $Objects/Submarine
@onready var _submarine_sprite : AnimatedSprite2D         = $Objects/Submarine/Sub
@onready var _exit_trigger     : Area2D                   = $ExitTrigger
@onready var _corridor_trigger : Area2D                   = $CorridorTrigger
@onready var _camera           : Camera2D                 = $player/Camera2D

@onready var _slot_engine      : ComponentSlotInteractable = $Objects/SlotEngine
@onready var _slot_hull        : ComponentSlotInteractable = $Objects/SlotHull
@onready var _slot_nav         : ComponentSlotInteractable = $Objects/SlotNav
@onready var _canvas_modulate  : CanvasModulate             = $CanvasModulate

var _level_ended: bool = false


func _ready() -> void:
	# ── Ambient music ─────────────────────────────────────────────────────────
	MusicManager.play(["res://assets/sounds/ambient_l1.mp3", "res://assets/sounds/ambient_l1_2.mp3"], -10.0)

	# ── Objectives ────────────────────────────────────────────────────────────
	ObjectiveManager.clear_objectives()
	_obj_engine = ObjectiveManager.add_objective("Recover the Drive Coupling")
	_obj_hull   = ObjectiveManager.add_objective("Recover the Pressure Seal")
	_obj_nav    = ObjectiveManager.add_objective("Recover the Nav Core")
	_obj_repair = ObjectiveManager.add_objective("Restore the Tethys-7")
	_obj_escape = ObjectiveManager.add_objective("Proceed to Kappa Station")

	# ── Inventory signals (mark collect objectives) ───────────────────────────
	Inventory.item_added.connect(_on_item_added)

	# ── Component slot signals ────────────────────────────────────────────────
	_slot_engine.slot_filled.connect(_on_slot_filled)
	_slot_hull.slot_filled.connect(_on_slot_filled)
	_slot_nav.slot_filled.connect(_on_slot_filled)

	# ── Submarine boarding ────────────────────────────────────────────────────
	_submarine.boarded.connect(_on_submarine_boarded)

	# ── Exit trigger ──────────────────────────────────────────────────────────
	_exit_trigger.body_entered.connect(_on_exit_reached)

	# ── Corridor boundary (block until sub is repaired) ───────────────────────
	_corridor_trigger.body_entered.connect(_on_corridor_entered)

	# ── Camera limits ─────────────────────────────────────────────────────────
	_camera.limit_left   = -50
	_camera.limit_top    = -50
	_camera.limit_right  = 1025
	_camera.limit_bottom = 655

	# ── Submarine sprite ──────────────────────────────────────────────────────
	_setup_sub_sprite()


func _setup_sub_sprite() -> void:
	var sheet: Texture2D = load("res://assets/player/sub_upgraded.png")
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 8.0)
	for i in 5:
		var atlas := AtlasTexture.new()
		atlas.atlas  = sheet
		atlas.region = Rect2(i * 126, 0, 126, 112)
		frames.add_frame("idle", atlas)
	_submarine_sprite.sprite_frames = frames
	_submarine_sprite.scale = Vector2(0.5, 0.5)
	_submarine_sprite.play("idle")


# ── Objective helpers ─────────────────────────────────────────────────────────

func _on_item_added(item: ItemData, _qty: int) -> void:
	match item.id:
		"drive_coupling":
			ObjectiveManager.complete_objective(_obj_engine)
		"pressure_seal":
			ObjectiveManager.complete_objective(_obj_hull)
		"nav_core":
			ObjectiveManager.complete_objective(_obj_nav)


func _on_slot_filled() -> void:
	if not (_slot_engine.is_filled and _slot_hull.is_filled and _slot_nav.is_filled):
		return
	var snd := AudioStreamPlayer.new()
	snd.stream = load("res://assets/sounds/repair.mp3")
	snd.finished.connect(snd.queue_free)
	add_child(snd)
	snd.play()
	GameState.submarine_fixed = true
	# Disable slot detection so only the submarine interactable is focusable.
	_slot_engine.monitoring = false
	_slot_hull.monitoring   = false
	_slot_nav.monitoring    = false
	ObjectiveManager.complete_objective(_obj_repair)
	DialogueManager.start_dialogue({
		"speaker": "ORCA",
		"lines": [
			"Drive coupling installed.",
			"Pressure seal nominal.",
			"Nav core online.",
			"Tethys-7 is operational.",
			"Approach the helm to depart.",
		],
	})


# ── Submarine driving sequence ────────────────────────────────────────────────

func _on_submarine_boarded(player: Node) -> void:
	player.global_position = _submarine.global_position
	_submarine_sprite.reparent(player)
	_submarine_sprite.position = Vector2.ZERO
	player._sub_sprite = _submarine_sprite
	player.enter_submarine_mode()
	var tw := create_tween()
	tw.tween_property(_canvas_modulate, "color", Color(0.12, 0.13, 0.15, 1.0), 0.6)


func _on_corridor_entered(body: Node) -> void:
	if not body.is_in_group("player") or GameState.submarine_fixed:
		return
	body.global_position = Vector2(1530.0, 480.0)
	body.velocity        = Vector2.ZERO
	if not DialogueManager.is_active:
		DialogueManager.start_dialogue({
			"speaker": "ORCA",
			"lines": [
				"Tethys-7 is non-operational. The corridor ahead leads to open ocean.",
				"Install all three components into the hull bays, then board the submarine.",
			],
		})


func _on_exit_reached(body: Node) -> void:
	if _level_ended:
		return
	if "submarine_mode" in body and body.submarine_mode:
		_level_ended = true
		ObjectiveManager.complete_objective(_obj_escape)
		DialogueManager.start_dialogue({
			"speaker": "ORCA",
			"lines": [
				"Tethys-7 clear of the trench.",
				"Auto-routing to Station Kappa — the only pressurized structure in range.",
				"Pulling Kappa's last status report.",
				"Most of it is redacted.",
			],
		})
		DialogueManager.dialogue_ended.connect(
			func():
				# Snapshot all completed Level 1 objectives into GameState
				# before the scene is destroyed.
				GameState.save_objectives_from_level_1()
				get_tree().change_scene_to_file("res://cutscene/transit_cinematic.tscn"),
			CONNECT_ONE_SHOT
		)
