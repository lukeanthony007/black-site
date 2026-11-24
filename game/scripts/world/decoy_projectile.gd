extends RigidBody3D
## Thrown sound decoy — lures guards via NoiseBus without full ALERT.

var _armed: bool = false
var _spent: bool = false
var _life: float = 5.0


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	continuous_cd = true
	body_entered.connect(_on_body_entered)
	# Arm after leaving the thrower's hands
	await get_tree().create_timer(0.12).timeout
	_armed = true


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		_detonate()


func _on_body_entered(_body: Node) -> void:
	if _armed:
		_detonate()


func _detonate() -> void:
	if _spent:
		return
	_spent = true
	# Mid loudness → Suspicious, not facility ALERT
	NoiseBus.emit_noise(global_position, 0.55, self)
	GameAudio.play_interact()
	queue_free()
