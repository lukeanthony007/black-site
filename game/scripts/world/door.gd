extends StaticBody3D
## Locked door with keycard tier, lockpick (tier 1), and guard bash.

@export var requires_keycard: bool = true
@export var required_tier: int = 1 ## 1 = facility, 2 = server
@export var bashable: bool = true
@export var lockpickable: bool = true
@export var open_offset: Vector3 = Vector3(0, 3.2, 0)
@export var open_time: float = 0.8

var _open: bool = false
var _player_near: Node = null
var _bash_progress: float = 0.0
var _pick_progress: float = 0.0
var _pick_target: float = 0.55 ## sweet-spot center 0-1
var _pick_active: bool = false

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var collision: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	add_to_group("doors")
	if required_tier >= 2:
		lockpickable = false
	for child in get_children():
		if child is Area3D:
			child.body_entered.connect(_on_enter)
			child.body_exited.connect(_on_exit)


func _unhandled_input(event: InputEvent) -> void:
	if _open or _player_near == null:
		return
	if event.is_action_pressed("interact"):
		interact(_player_near)
	if event.is_action_pressed("lockpick"):
		if _pick_active:
			_try_set_pin(_player_near)
		else:
			_try_start_lockpick(_player_near)


func _process(delta: float) -> void:
	if not _pick_active:
		return
	if _player_near == null or _open:
		_cancel_lockpick()
		return
	# Oscillating needle
	var t := Time.get_ticks_msec() / 1000.0
	var needle := 0.5 + 0.48 * sin(t * 3.2)
	var dist := absf(needle - _pick_target)
	ObjectiveTracker.set_prompt("LOCKPICK  [%s]  G=set pin · sweet spot" % _pick_bar(needle))
	if not Input.is_action_pressed("lockpick") and dist > 0.01:
		# Must stay near door; allow releasing hold on G after start — use continuous presence
		pass


func _pick_bar(needle: float) -> String:
	var chars := PackedStringArray()
	for i in 21:
		var pos := float(i) / 20.0
		if absf(pos - _pick_target) < 0.06:
			chars.append("O" if absf(needle - pos) < 0.06 else "=")
		elif absf(needle - pos) < 0.04:
			chars.append("|")
		else:
			chars.append("-")
	return "".join(chars)


func _on_enter(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_near = body
		ObjectiveTracker.set_prompt(_player_prompt(body))


func _on_exit(body: Node3D) -> void:
	if body == _player_near:
		_player_near = null
		_cancel_lockpick()


func _player_prompt(player: Node) -> String:
	if not requires_keycard:
		return "E — open door"
	var tier := _player_tier(player)
	if tier >= required_tier:
		return "E — unlock door (tier %d)" % required_tier
	if required_tier >= 2:
		return "Door locked — need SERVER keycard"
	var picks := 0
	if "lockpicks" in player:
		picks = int(player.lockpicks)
	if lockpickable and picks > 0:
		return "E needs card · G lockpick (%d left)" % picks
	return "Door locked — need facility keycard"


func _player_tier(player: Node) -> int:
	if "keycard_tier" in player:
		return int(player.keycard_tier)
	if "has_keycard" in player and player.has_keycard:
		return 1
	return 0


func interact(player: Node) -> void:
	if _open:
		return
	if requires_keycard:
		if _player_tier(player) < required_tier:
			ObjectiveTracker.set_prompt(_player_prompt(player))
			return
	_open_door("Door unlocked")


func _try_start_lockpick(player: Node) -> void:
	if _open or not lockpickable or required_tier >= 2:
		return
	if _player_tier(player) >= required_tier:
		interact(player)
		return
	var picks := 0
	if "lockpicks" in player:
		picks = int(player.lockpicks)
	if picks <= 0:
		ObjectiveTracker.set_prompt("No lockpicks")
		return
	_pick_active = true
	_pick_progress = 0.0
	_pick_target = randf_range(0.25, 0.75)
	ObjectiveTracker.set_prompt("Lockpicking… press G when needle hits O")


func _try_set_pin(player: Node) -> void:
	if not _pick_active:
		return
	var t := Time.get_ticks_msec() / 1000.0
	var needle := 0.5 + 0.48 * sin(t * 3.2)
	var dist := absf(needle - _pick_target)
	if dist <= 0.07:
		_pick_progress += 1.0
		GameAudio.play_pickup()
		if _pick_progress >= 3.0:
			if player.has_method("consume_lockpick"):
				player.consume_lockpick()
			_pick_active = false
			NoiseBus.emit_noise(global_position, 0.15, player)
			_open_door("Lockpicked")
		else:
			_pick_target = randf_range(0.2, 0.8)
			ObjectiveTracker.set_prompt("Pin set (%d/3) — next sweet spot" % int(_pick_progress))
	else:
		# Fail — noise, lose pick chance
		NoiseBus.emit_noise(global_position, 0.55, player)
		AlertPhase.raise_caution(4.0)
		GameAudio.play_hurt()
		if randf() < 0.35 and player.has_method("consume_lockpick"):
			player.consume_lockpick()
			ObjectiveTracker.set_prompt("Lockpick broke")
			_cancel_lockpick()
		else:
			ObjectiveTracker.set_prompt("Missed — try again (noise!)")


func _cancel_lockpick() -> void:
	_pick_active = false
	_pick_progress = 0.0


func try_bash(from: Node3D, delta: float) -> bool:
	if _open or not bashable:
		return _open
	if AlertPhase.phase != AlertPhase.Phase.ALERT and AlertPhase.phase != AlertPhase.Phase.CAUTION:
		_bash_progress = 0.0
		return false
	if global_position.distance_to(from.global_position) > 2.2:
		_bash_progress = 0.0
		return false
	_bash_progress += delta
	if _bash_progress >= 1.1:
		force_open()
		return true
	return false


func force_open() -> void:
	if _open:
		return
	requires_keycard = false
	_cancel_lockpick()
	NoiseBus.emit_noise(global_position, 0.75, self)
	GameAudio.play_gunshot()
	_open_door("Door forced")


func unlock_and_open() -> void:
	requires_keycard = false
	_open_door("Door unlocked")


func is_open() -> bool:
	return _open


func _open_door(prompt: String) -> void:
	_open = true
	_cancel_lockpick()
	GameAudio.play_interact()
	ObjectiveTracker.set_prompt(prompt)
	var tween := create_tween()
	tween.tween_property(self, "position", position + open_offset, open_time)
	tween.tween_callback(func() -> void:
		collision.disabled = true
	)
