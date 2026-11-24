extends Node
## Registers InputMap actions at boot so project.godot stays simple.


func _ready() -> void:
	_ensure_key("move_forward", KEY_W)
	_ensure_key("move_back", KEY_S)
	_ensure_key("move_left", KEY_A)
	_ensure_key("move_right", KEY_D)
	_ensure_key("jump", KEY_SPACE)
	_ensure_crouch()
	_ensure_key("sprint", KEY_SHIFT)
	_ensure_key("interact", KEY_E)
	_ensure_key("reload", KEY_R)
	_ensure_key("restart", KEY_P)
	_ensure_key("takedown", KEY_F)
	_ensure_key("knockout", KEY_Q)
	_ensure_key("lockpick", KEY_G)
	_ensure_key("gadget", KEY_C)
	_ensure_key("throw_decoy", KEY_V)
	_ensure_key("demand_surrender", KEY_1)
	_ensure_key("demand_keycard", KEY_2)
	_ensure_key("demand_door", KEY_3)
	_ensure_mouse("fire", MOUSE_BUTTON_LEFT)
	_ensure_mouse("aim", MOUSE_BUTTON_RIGHT)


func _ensure_crouch() -> void:
	## Ctrl is flaky as physical_keycode-only on some Linux setups — register several ways
	## plus alternate crouch key (Ctrl is primary; C is gadget so use Comma as backup).
	if not InputMap.has_action("crouch"):
		InputMap.add_action("crouch")
	_add_key_event("crouch", KEY_CTRL)
	# Godot may report left/right control differently; KEY_CTRL covers the modifier.
	# Also bind Capslock-free alternate: KEY_C is gadget — use KEY_X as backup crouch.
	_add_key_event("crouch", KEY_X)


func _add_key_event(action: String, keycode: Key) -> void:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var k := event as InputEventKey
			if int(k.physical_keycode) == int(keycode) or int(k.keycode) == int(keycode):
				return
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)


func _ensure_key(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	_add_key_event(action, keycode)


func _ensure_mouse(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event in InputMap.action_get_events(action):
		if event is InputEventMouseButton and event.button_index == button:
			return
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
