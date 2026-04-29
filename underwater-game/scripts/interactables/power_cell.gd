class_name PowerCell
extends Interactable

@export var charge_amount : float = 40.0


func _ready() -> void:
	interaction_label = "Power Cell"
	var tween := create_tween().set_loops()
	tween.tween_property(self, "position:y", position.y - 4.0, 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "position:y", position.y,       0.8).set_trans(Tween.TRANS_SINE)


func _on_interact(player: Node) -> void:
	if not player.has_method("add_battery"):
		return
	player.add_battery(charge_amount)
	var snd := AudioStreamPlayer.new()
	snd.stream = load("res://assets/sounds/item.mp3")
	snd.finished.connect(snd.queue_free)
	get_parent().add_child(snd)
	snd.play()
	queue_free()
