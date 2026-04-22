extends Node

var _players: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func play(paths: Array, volume_db: float = 0.0) -> void:
	stop()
	for path in paths:
		var asp := AudioStreamPlayer.new()
		asp.stream = load(path)
		asp.volume_db = volume_db
		asp.process_mode = Node.PROCESS_MODE_ALWAYS
		asp.finished.connect(asp.play)
		add_child(asp)
		asp.play()
		_players.append(asp)


func stop() -> void:
	for p in _players:
		if is_instance_valid(p):
			p.queue_free()
	_players.clear()
