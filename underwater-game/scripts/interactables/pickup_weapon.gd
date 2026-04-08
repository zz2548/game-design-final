# pickup_weapon.gd
# Place on an Area2D in the level. Assign a WeaponData resource in the inspector.
# When the player interacts, the weapon is equipped and the pickup disappears.

class_name PickupWeapon
extends Interactable

@export var weapon : WeaponData = null


func _ready() -> void:
	interaction_label = "Pick Up"


func _on_interact(player: Node) -> void:
	if weapon == null:
		push_warning("PickupWeapon: no WeaponData assigned on " + name)
		return
	player.equip_weapon(weapon)
	queue_free()
