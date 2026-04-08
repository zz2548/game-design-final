# level_2.gd
# Kappa Station — the flooded relay.
#
# The player arrives via Tethys-7 and must:
#   1. Search the station (reach the Research Wing)
#   2. Recover Fadel's research archive
#   3. Locate the antenna array (reach the lower bore shaft)
#   4. Restore station communications (interact with antenna terminal)
#   5. Breach the emergency hatch (reach the far-right exit)

extends Node2D

# ── Node refs ─────────────────────────────────────────────────────────────────
@onready var _research_trigger : Area2D           = $ResearchWingTrigger
@onready var _antenna_trigger  : Area2D           = $AntennaRoomTrigger
@onready var _antenna_terminal : AntennaInteractable = $Objects/AntennaTerminal
@onready var _exit_trigger     : Area2D           = $ExitTrigger

# ── Objective indices ─────────────────────────────────────────────────────────
var _obj_search  : int   # "Search Kappa Station"
var _obj_archive : int   # "Recover Fadel's research archive"
var _obj_locate  : int   # "Locate the antenna array"
var _obj_comms   : int   # "Restore station communications"
var _obj_escape  : int   # "Breach the emergency hatch"

var _antenna_repaired : bool = false
var _level_ended      : bool = false


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	ObjectiveManager.clear_objectives()
	_obj_search  = ObjectiveManager.add_objective("Search Kappa Station")
	_obj_archive = ObjectiveManager.add_objective("Recover Fadel's research archive")
	_obj_locate  = ObjectiveManager.add_objective("Locate the antenna array")
	_obj_comms   = ObjectiveManager.add_objective("Restore station communications")
	_obj_escape  = ObjectiveManager.add_objective("Breach the emergency hatch")

	Inventory.item_added.connect(_on_item_added)
	_research_trigger.body_entered.connect(_on_research_wing_entered)
	_antenna_trigger.body_entered.connect(_on_antenna_room_entered)
	_antenna_terminal.repaired.connect(_on_antenna_repaired)
	_exit_trigger.body_entered.connect(_on_exit_reached)

	# ORCA intro — plays on the first frame so the scene is fully loaded
	await get_tree().process_frame
	DialogueManager.start_dialogue({
		"speaker": "ORCA",
		"lines": [
			"Tethys-7 docking at Kappa Station.",
			"Emergency systems only. Life support offline.",
			"This station went dark fourteen months ago.",
			"I am detecting movement inside.",
		],
	})


# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_item_added(item, _qty: int) -> void:
	if item != null and item.id == "fadel_archive":
		ObjectiveManager.complete_objective(_obj_archive)


func _on_research_wing_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	ObjectiveManager.complete_objective(_obj_search)
	_research_trigger.monitoring = false


func _on_antenna_room_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	ObjectiveManager.complete_objective(_obj_locate)
	_antenna_trigger.monitoring = false


func _on_antenna_repaired() -> void:
	_antenna_repaired = true
	ObjectiveManager.complete_objective(_obj_comms)


func _on_exit_reached(body: Node2D) -> void:
	if _level_ended:
		return
	if not body.is_in_group("player"):
		return

	if not _antenna_repaired:
		if not DialogueManager.is_active:
			DialogueManager.start_dialogue({
				"speaker": "ORCA",
				"lines": [
					"Emergency hatch is sealed.",
					"Station communications must be restored before departure.",
				],
			})
		return

	_level_ended = true
	ObjectiveManager.complete_objective(_obj_escape)
	DialogueManager.start_dialogue({
		"speaker": "ORCA",
		"lines": [
			"Emergency hatch clear.",
			"Coordinates triangulated — Station Hadal is the next relay point.",
			"Fadel's last entry was timestamped eighteen months ago.",
			"She mentions something she calls the Bloom.",
		],
	})
	DialogueManager.dialogue_ended.connect(
		func(): SceneManager.next_level(), CONNECT_ONE_SHOT
	)
