extends Node
## Global noise / alert bus for stealth reactions.

signal noise_emitted(position: Vector3, loudness: float, source: Node)
signal alert_raised(position: Vector3)


func emit_noise(position: Vector3, loudness: float, source: Node = null) -> void:
	noise_emitted.emit(position, loudness, source)
	if loudness >= 0.7:
		alert_raised.emit(position)
