# item_data.gd
# Attach to a Resource. Create new items via: Resource > New Resource > ItemData
# Place item resources in res://items/

@tool
class_name ItemData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var icon: Texture2D = null
@export var max_stack: int = 1
@export var is_usable: bool = false
@export var is_key_item: bool = false  # Key items can't be dropped

# Optional: custom data for item-specific logic (e.g., heal amount, oxygen restored)
@export var custom_data: Dictionary = {}
