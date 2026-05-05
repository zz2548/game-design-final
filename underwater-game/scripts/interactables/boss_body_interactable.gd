# boss_body_interactable.gd
#
# Drop this as a child node inside your boss scene.
# Level3 will enable it automatically after the boss dies,
# then connect to the `examined` signal to start story cutscenes.
#
# Setup:
#   1. Add as Area2D child of the boss scene root
#   2. Add a CollisionShape2D child with an appropriate shape
#   3. Set interaction_label in the Inspector (e.g. "Examine APEX-7")
#   4. Assign to the Boss Body export on the Level3 node

class_name BossBodyInteractable
extends Interactable

## Emitted once when the player examines the dead boss.
signal examined

func _ready() -> void:
	## TODO: Set this to the boss's name, e.g. "Examine APEX-7"
	interaction_label = "Examine"


func _on_interact(_player: Node) -> void:
	emit_signal("examined")
