extends Node
## Facility-wide alert phases (MGS-lite).

enum Phase { NORMAL, CAUTION, ALERT }

signal phase_changed(phase: Phase, label: String)

var phase: Phase = Phase.NORMAL
# Guards stay non-violent until the player attacks one (shot, takedown,
# or a held-up guard resisting). Chase/shoot paths check this.
var player_hostile: bool = false
var _timer: float = 0.0


func _ready() -> void:
	reset()
	NoiseBus.alert_raised.connect(_on_loud_alert)
	NoiseBus.noise_emitted.connect(_on_noise)


func reset() -> void:
	phase = Phase.NORMAL
	player_hostile = false
	_timer = 0.0
	phase_changed.emit(phase, "CLEAR")


func mark_player_hostile() -> void:
	player_hostile = true


func _process(delta: float) -> void:
	if phase == Phase.NORMAL:
		return
	_timer -= delta
	if _timer <= 0.0:
		if phase == Phase.ALERT:
			_set_phase(Phase.CAUTION, 8.0)
		else:
			_set_phase(Phase.NORMAL, 0.0)


func raise_caution(seconds: float = 6.0) -> void:
	if phase == Phase.ALERT:
		_timer = maxf(_timer, seconds)
		return
	_set_phase(Phase.CAUTION, seconds)


func raise_alert(seconds: float = 14.0) -> void:
	var was_alert := phase == Phase.ALERT
	_set_phase(Phase.ALERT, seconds)
	if not was_alert:
		ObjectiveTracker.alerts_raised += 1


func _on_loud_alert(_position: Vector3) -> void:
	raise_alert(14.0)


func _on_noise(_position: Vector3, loudness: float, _source: Node) -> void:
	if loudness >= 0.7:
		raise_alert(12.0)
	elif loudness >= 0.4:
		raise_caution(6.0)


func notify_body_found(position: Vector3) -> void:
	raise_alert(16.0)
	NoiseBus.emit_noise(position, 0.85, null)
	ObjectiveTracker.record_body_found()
	ObjectiveTracker.set_prompt("Body discovered — facility alert")


func _set_phase(next: Phase, seconds: float) -> void:
	phase = next
	_timer = seconds
	var label := "CLEAR"
	match phase:
		Phase.CAUTION:
			label = "CAUTION"
		Phase.ALERT:
			label = "ALERT"
	phase_changed.emit(phase, label)


func phase_label() -> String:
	match phase:
		Phase.CAUTION:
			return "CAUTION"
		Phase.ALERT:
			return "ALERT"
		_:
			return "CLEAR"
