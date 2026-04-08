# weapon_data.gd
# Define a gun's stats. Create instances via: Resource > New Resource > WeaponData
# Place weapon resources in res://shared/weapons/

@tool
class_name WeaponData
extends Resource

@export var id            : String      = ""
@export var display_name  : String      = ""
@export var bullet_scene  : PackedScene = null
@export var bullet_count  : int         = 1      # pellets per shot (1 = pistol, 4 = shotgun)
@export var spread_angle  : float       = 0.0    # total arc in degrees (0 = no spread)
@export var fire_cooldown : float       = 0.20   # seconds between shots
@export var max_ammo      : int         = 30
@export var bullet_offset : float       = 12.0   # px ahead of player centre to spawn bullet
