# level_1.gd
# Attached to the Level1 node.
# Sets up objectives, marks them complete as the player progresses,
# and orchestrates the submarine driving sequence at the end.

extends Node2D

const PART_IDS := ["drive_coupling", "pressure_seal", "nav_core"]

# ── Objective indices ─────────────────────────────────────────────────────────
var _obj_engine: int
var _obj_hull: int
var _obj_nav: int
var _obj_repair: int
var _obj_escape: int

# ── Scene refs ────────────────────────────────────────────────────────────────
@onready var _submarine        : SubmarineInteractable = $Objects/Submarine
@onready var _submarine_sprite : AnimatedSprite2D      = $Objects/Submarine/Sub
@onready var _exit_trigger     : Area2D               = $ExitTrigger
@onready var _corridor_trigger : Area2D               = $CorridorTrigger
@onready var _camera           : Camera2D             = $player/Camera2D

var _level_ended: bool = false


func _ready() -> void:
	# ── Objectives ────────────────────────────────────────────────────────────
	ObjectiveManager.clear_objectives()
	_obj_engine = ObjectiveManager.add_objective("Recover the Drive Coupling")
	_obj_hull   = ObjectiveManager.add_objective("Recover the Pressure Seal")
	_obj_nav    = ObjectiveManager.add_objective("Recover the Nav Core")
	_obj_repair = ObjectiveManager.add_objective("Restore the Tethys-7")
	_obj_escape = ObjectiveManager.add_objective("Breach into open ocean")

	# ── Inventory signals ─────────────────────────────────────────────────────
	Inventory.item_added.connect(_on_item_added)
	Inventory.inventory_changed.connect(_on_inventory_changed)

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


func _on_inventory_changed() -> void:
	# Repair objective: all 3 parts collected but now gone = submarine was repaired.
	# (inventory.gd emits item_removed with null after clearing the slot, so we
	#  use inventory_changed + a state check instead of the item_removed signal.)
	var all_collected: bool = (
		ObjectiveManager.objectives[_obj_engine]["completed"] and
		ObjectiveManager.objectives[_obj_hull]["completed"] and
		ObjectiveManager.objectives[_obj_nav]["completed"]
	)
	if not all_collected:
		return
	for part_id: String in PART_IDS:
		if Inventory.has_item(part_id):
			return
	ObjectiveManager.complete_objective(_obj_repair)


# ── Submarine driving sequence ────────────────────────────────────────────────

func _on_submarine_boarded(player: Node) -> void:
	# Snap player to submarine, swap visuals, hand off controls
	player.global_position = _submarine.global_position

	# Reparent the submarine sprite onto the player so it moves with them.
	# reparent() preserves global_transform by default, so the local offset
	# becomes (0, 0) since both nodes share the same global position.
	_submarine_sprite.reparent(player)
	_submarine_sprite.position = Vector2.ZERO
	player._sub_sprite = _submarine_sprite

	player.enter_submarine_mode()


func _on_corridor_entered(body: Node) -> void:
	if not body.is_in_group("player") or GameState.submarine_fixed:
		return
	# Push the player back into the cave before dialogue fires so that
	# the position-restore on dialogue_ended lands them safely here.
	body.global_position = Vector2(1530.0, 480.0)
	body.velocity        = Vector2.ZERO
	if not DialogueManager.is_active:
		DialogueManager.start_dialogue({
			"speaker": "ORCA",
			"lines": [
				"Tethys-7 is non-operational. The corridor ahead leads to open ocean.",
				"Without propulsion, that is unsurvivable. Repair the submarine first.",
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
			func(): get_tree().change_scene_to_file("res://cutscene/transit_cinematic.tscn"),
			CONNECT_ONE_SHOT
		)
