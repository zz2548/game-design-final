# level_2.gd
# Kappa Station — the flooded relay.
#
# The player arrives via Tethys-7 and must:
#   1. Search the station (reach the Research Wing)
#   2. Recover Fadel's research archive (found in the comms room alcove, Zone A)
#   3. Locate the antenna array (reach Zone C exterior)
#   4. Restore station communications (interact with antenna terminal)
#   5. Breach the emergency hatch (reach the far-right exit)
#
# Key scripted beats:
#   - ORCA goes quiet after the Pelagis memo case is picked up in Zone B.
#     She resumes after a deliberate pause — her language has shifted.
#   - Lockdown: Pelagis responds to the surface ping with a lockdown code.
#     Blast doors begin closing. ORCA offers to override the sub bay door.
#     She says "Tell me when." She waits.
#   - Bosch's secondary log: ORCA withheld it because it was addressed to
#     whoever found it and she was uncertain whether that obligation was hers.
#     She plays it as you clear the station.
#
# Scene tree additions (beyond the level_1 pattern):
#   $CommsRoomTrigger          — Area2D, fires when player enters the alcove
#   $SubBayDoor                — a BlastDoor node (AnimatableBody2D or similar)
#                                that ORCA's override opens
#   $Objects/FadelBody         — NpcInteractable, carries the keycard dialogue
#   $Objects/BoschBody         — NpcInteractable, carries Bosch's secondary log
#                                (ORCA withholds this until departure)
#   $Objects/PelagisMemoCase   — PickupItem, item id "pelagis_memos"
#   $Objects/AntennaTerminal   — AntennaInteractable (same as existing)
#   $ResearchWingTrigger       — Area2D (existing)
#   $AntennaRoomTrigger        — Area2D (existing)
#   $ExitTrigger               — Area2D (existing)

extends Node2D

# ── Node refs ─────────────────────────────────────────────────────────────────
@onready var _research_trigger  : Area2D              = $ResearchWingTrigger
@onready var _antenna_trigger   : Area2D              = $AntennaRoomTrigger
@onready var _comms_trigger     : Area2D              = $CommsRoomTrigger
@onready var _antenna_terminal  : AntennaInteractable = $Objects/AntennaTerminal
@onready var _fadel_body        : NpcInteractable     = $Objects/FadelBody
@onready var _bosch_body        : NpcInteractable     = $Objects/BoschBody
@onready var _pelagis_memo_case : PickupItem          = $Objects/PelagisMemoCase
@onready var _sub_bay_door      : Node                = $SubBayDoor
@onready var _exit_trigger      : Area2D              = $ExitTrigger

# ── Objective indices ─────────────────────────────────────────────────────────
var _obj_search   : int   # "Search Kappa Station"
var _obj_archive  : int   # "Recover Fadel's research archive"
var _obj_locate   : int   # "Locate the antenna array"
var _obj_comms    : int   # "Restore station communications"
var _obj_escape   : int   # "Breach the emergency hatch"

# ── State ─────────────────────────────────────────────────────────────────────
var _antenna_repaired  : bool = false
var _level_ended       : bool = false
var _lockdown_active   : bool = false
var _sub_bay_open      : bool = false
var _memos_processed   : bool = false
var _bosch_log_queued  : bool = false


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
	_comms_trigger.body_entered.connect(_on_comms_room_entered)
	_antenna_terminal.repaired.connect(_on_antenna_repaired)
	_exit_trigger.body_entered.connect(_on_exit_reached)

	# Bosch's body starts non-interactive — ORCA hasn't flagged it yet.
	# The player can still walk up to it but interaction is suppressed
	# until _bosch_log_queued is set by the departure sequence.
	_bosch_body.set_process_unhandled_input(false)

	# ORCA intro — wait one frame so the scene is fully loaded.
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


# ── Zone triggers ─────────────────────────────────────────────────────────────

func _on_comms_room_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_comms_trigger.monitoring = false
	# The comms room is where Fadel and Bosch are found seated, facing each
	# other. ORCA reads the room before the player can process what they're
	# seeing. She identifies Fadel by her insignia.
	DialogueManager.start_dialogue({
		"speaker": "ORCA",
		"lines": [
			"Two crew members. Comms station.",
			"Xenobiologist insignia — Dr. Ines Fadel.",
			"The other is a technician. Patch reads: Bosch.",
			"They are positioned deliberately.",
			"Something is wedged under Fadel's hand.",
		],
	})


func _on_research_wing_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	ObjectiveManager.complete_objective(_obj_search)
	_research_trigger.monitoring = false
	DialogueManager.start_dialogue({
		"speaker": "ORCA",
		"lines": [
			"Research Wing. Specimen containment — all units compromised.",
			"The biological signatures I am reading do not match the station manifest.",
			"Something has been living here for some time.",
		],
	})


func _on_antenna_room_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	ObjectiveManager.complete_objective(_obj_locate)
	_antenna_trigger.monitoring = false
	DialogueManager.start_dialogue({
		"speaker": "ORCA",
		"lines": [
			"Antenna array. One relay node is physically damaged.",
			"The break is on the exterior hull.",
			"You will need to work in open water.",
			"I will route you through the repair from inside the sub.",
		],
	})


# ── Item pickups ──────────────────────────────────────────────────────────────

func _on_item_added(item: ItemData, _qty: int) -> void:
	if item == null:
		return
	match item.id:
		"fadel_archive":
			_on_archive_recovered()
		"pelagis_memos":
			_on_memos_recovered()


func _on_archive_recovered() -> void:
	ObjectiveManager.complete_objective(_obj_archive)
	# ORCA begins reading the archive immediately. She feeds excerpts as the
	# player moves — this is the first time she processes something faster
	# than the player can read it. Her tone is still measured here.
	DialogueManager.start_dialogue({
		"speaker": "ORCA",
		"lines": [
			"Fadel's research archive. Sealed. Intact.",
			"Processing.",
			"She called them the Unlit.",
			"Not an official designation. A crew name.",
			"Her earliest entries read as discovery.",
			"They do not end that way.",
		],
	})


func _on_memos_recovered() -> void:
	# ORCA processes the Pelagis memos. She goes quiet — longer than any
	# system pause should require. When she comes back her language has
	# shifted. She no longer quotes protocol.
	DialogueManager.start_dialogue({
		"speaker": "ORCA",
		"lines": [
			"Pelagis internal correspondence. Processing.",
		],
	})
	DialogueManager.dialogue_ended.connect(_on_memos_processed, CONNECT_ONE_SHOT)


func _on_memos_processed() -> void:
	_memos_processed = true
	# The pause. In implementation this is a timed delay before ORCA speaks
	# again — long enough to feel wrong, short enough not to lose the player.
	await get_tree().create_timer(4.2).timeout
	DialogueManager.start_dialogue({
		"speaker": "ORCA",
		"lines": [
			"They found it on an unmanned survey.",
			"Fourteen months before your contract began.",
			"They classified it.",
			"They kept drilling.",
			"Fadel's research was not discovery.",
			"It was a containment protocol.",
			"Pelagis buried it.",
		],
	})


# ── Antenna repair and lockdown sequence ──────────────────────────────────────

func _on_antenna_repaired() -> void:
	_antenna_repaired = true
	ObjectiveManager.complete_objective(_obj_comms)
	DialogueManager.start_dialogue({
		"speaker": "ORCA",
		"lines": [
			"Relay node restored.",
			"Sending surface ping.",
			"Ping away.",
		],
	})
	DialogueManager.dialogue_ended.connect(_on_ping_sent, CONNECT_ONE_SHOT)


func _on_ping_sent() -> void:
	# Beat of silence before Pelagis responds — let the player feel the hope.
	await get_tree().create_timer(2.5).timeout
	_trigger_lockdown()


func _trigger_lockdown() -> void:
	_lockdown_active = true
	# Blast doors begin closing. The sub bay door is part of this — the
	# Tethys-7 is about to be sealed in. The door animation should play here.
	if _sub_bay_door.has_method("close"):
		_sub_bay_door.close()

	DialogueManager.start_dialogue({
		"speaker": "ORCA",
		"lines": [
			"Response received.",
			"It is not rescue coordinates.",
			"Pelagis has issued a lockdown code.",
			"Station Kappa entering emergency seal.",
			"Blast doors are closing.",
			"The sub bay will be locked in approximately ninety seconds.",
		],
	})
	DialogueManager.dialogue_ended.connect(_on_lockdown_explained, CONNECT_ONE_SHOT)


func _on_lockdown_explained() -> void:
	# This is the "Tell me when" moment. ORCA does not ask for permission —
	# she states what she can do and waits for the player to decide.
	# The choice to act is the player's. She has already made hers.
	DialogueManager.start_dialogue({
		"speaker": "ORCA",
		"lines": [
			"I can override the sub bay door.",
			"It will consume the lockdown window.",
			"We will have approximately ninety seconds.",
			"Tell me when.",
		],
	})
	DialogueManager.dialogue_ended.connect(_on_tell_me_when_delivered, CONNECT_ONE_SHOT)


func _on_tell_me_when_delivered() -> void:
	# Interaction prompt appears on the sub bay door: [E] Tell her when.
	# When the player interacts, _open_sub_bay() fires.
	if _sub_bay_door.has_method("enable_player_override"):
		_sub_bay_door.enable_player_override(Callable(self, "_open_sub_bay"))


func _open_sub_bay() -> void:
	if _sub_bay_open:
		return
	_sub_bay_open = true
	if _sub_bay_door.has_method("open"):
		_sub_bay_door.open()
	DialogueManager.start_dialogue({
		"speaker": "ORCA",
		"lines": [
			"Overriding.",
			"Move.",
		],
	})
	# Queue the Bosch log to play on exit — ORCA will explain the withholding
	# once the immediate danger is past.
	_bosch_log_queued = true


# ── Exit ──────────────────────────────────────────────────────────────────────

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

	if _lockdown_active and not _sub_bay_open:
		if not DialogueManager.is_active:
			DialogueManager.start_dialogue({
				"speaker": "ORCA",
				"lines": [
					"Sub bay is sealed.",
					"You need to tell me when.",
				],
			})
		return

	_level_ended = true
	ObjectiveManager.complete_objective(_obj_escape)

	if _bosch_log_queued:
		_play_bosch_log()
	else:
		_play_departure_dialogue()


func _play_bosch_log() -> void:
	# ORCA explains the withholding first — she is not defensive about it,
	# just precise. Then she plays the log.
	DialogueManager.start_dialogue({
		"speaker": "ORCA",
		"lines": [
			"Bosch left a secondary log.",
			"I did not flag it earlier.",
			"It was addressed to whoever found it.",
			"I was uncertain whether that obligation was mine.",
			"Playing now.",
		],
	})
	DialogueManager.dialogue_ended.connect(_play_bosch_log_content, CONNECT_ONE_SHOT)


func _play_bosch_log_content() -> void:
	# Bosch's voice, recorded hours before he died.
	# This is the last thing that plays before the level ends.
	DialogueManager.start_dialogue({
		"speaker": "BOSCH — recorded",
		"lines": [
			"Go down.",
			"Not up.",
			"Up is what they want.",
		],
	})
	DialogueManager.dialogue_ended.connect(_play_departure_dialogue, CONNECT_ONE_SHOT)


func _play_departure_dialogue() -> void:
	DialogueManager.start_dialogue({
		"speaker": "ORCA",
		"lines": [
			"Emergency hatch clear.",
			"Nav system is corrupted. Lockdown code.",
			"One route available.",
			"Deeper.",
			"I could attempt a manual override.",
			"I have also now fully processed Fadel's research archive.",
			"I think you should see where this shaft goes.",
		],
	})
	DialogueManager.dialogue_ended.connect(
		func(): SceneManager.next_level(), CONNECT_ONE_SHOT
	)
