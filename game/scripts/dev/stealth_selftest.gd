extends Node
## Headless: drive shipped guard evaluate_* detection APIs + gym AI layout.
## Run: godot --path game --headless res://scenes/dev_stealth_selftest.tscn

var _fails: int = 0


func _ready() -> void:
	print("=== stealth_selftest ===")
	_test_noise_response()
	_test_intrusion_policy()
	_test_sight_score()
	await _test_guard_instance_methods()
	await _test_gym_ai_layout()
	print("=== stealth_selftest done fails=%d ===" % _fails)
	await get_tree().process_frame
	get_tree().quit(0 if _fails == 0 else 1)


func _fail(msg: String) -> void:
	_fails += 1
	print("FAIL: ", msg)


func _ok(msg: String) -> void:
	print("OK: ", msg)


func _test_noise_response() -> void:
	var g: Node = load("res://scripts/ai/guard.gd").new()
	# Audible player noise triggers investigation before combat authority exists.
	var r: int = g.evaluate_noise_response(5.0, 0.9, true, false)
	if r != 2:
		_fail("loud pre-hostile player noise should SEARCH, got %d" % r)
	else:
		_ok("pre-hostile player noise triggers search")
	# Loud world noise → search
	r = g.evaluate_noise_response(5.0, 0.9, false, false)
	if r != 2:
		_fail("loud world noise should SEARCH, got %d" % r)
	else:
		_ok("loud world noise → SEARCH")
	# Soft world → suspicious
	r = g.evaluate_noise_response(5.0, 0.4, false, false)
	if r != 1:
		_fail("soft world noise should SUSPICIOUS, got %d" % r)
	else:
		_ok("soft world noise → SUSPICIOUS")
	# Out of range
	r = g.evaluate_noise_response(999.0, 1.0, false, true)
	if r != 0:
		_fail("out of range should IGNORE")
	else:
		_ok("out of range ignored")
	# Hostile player loud → search
	r = g.evaluate_noise_response(8.0, 0.85, true, true)
	if r != 2:
		_fail("hostile player gunshot should SEARCH")
	else:
		_ok("hostile player loud noise → SEARCH")
	g.free()


func _test_intrusion_policy() -> void:
	var g: Node = load("res://scripts/ai/guard.gd").new()
	var clear: int = g.evaluate_intrusion_context({"room_authorized": true})
	var challenge: int = g.evaluate_intrusion_context({"room_authorized": false})
	var contain: int = g.evaluate_intrusion_context({"room_authorized": true, "access_denied": true})
	var engage: int = g.evaluate_intrusion_context({"room_authorized": false, "custody_violation": true, "hostile_act": true})
	if clear != FacilityIntrusionPolicy.Response.CLEAR:
		_fail("authorized quiet presence should remain CLEAR")
	elif challenge != FacilityIntrusionPolicy.Response.CHALLENGE:
		_fail("unauthorized room presence should CHALLENGE")
	elif contain != FacilityIntrusionPolicy.Response.CONTAIN:
		_fail("access denial should CONTAIN")
	elif engage != FacilityIntrusionPolicy.Response.ENGAGE:
		_fail("hostile act should outrank violations and ENGAGE")
	else:
		_ok("institutional intrusion precedence is clear → challenge → contain → engage")
	g.free()


func _test_sight_score() -> void:
	var g: Node = load("res://scripts/ai/guard.gd").new()
	var direct: float = g.evaluate_sight_score(8.0, 20.0, false, false)
	var peri: float = g.evaluate_sight_score(6.0, 80.0, false, false)
	var none: float = g.evaluate_sight_score(5.0, 140.0, false, false)
	if direct < 0.55:
		_fail("direct cone should be full lock (>=0.55), got %.2f" % direct)
	else:
		_ok("direct sight score %.2f" % direct)
	if peri <= 0.0 or peri >= 0.55:
		_fail("peripheral should be partial (0,0.55), got %.2f" % peri)
	else:
		_ok("peripheral sight score %.2f" % peri)
	if none > 0.0:
		_fail("behind guard should score 0")
	else:
		_ok("rear angle score 0")
	var crouch: float = g.evaluate_sight_score(16.0, 10.0, true, false)
	var stand: float = g.evaluate_sight_score(16.0, 10.0, false, false)
	if crouch > stand:
		_fail("crouch should not increase far sight score")
	else:
		_ok("crouch reduces/far-equal sight vs stand")
	g.free()


func _test_guard_instance_methods() -> void:
	var scene: PackedScene = load("res://scenes/guard.tscn")
	var guard: Node = scene.instantiate()
	add_child(guard)
	await get_tree().process_frame
	if not guard.has_method("evaluate_noise_response"):
		_fail("guard scene missing evaluate_noise_response")
	else:
		var r: int = guard.evaluate_noise_response(3.0, 0.5, false, false)
		if r != 1:
			_fail("instanced guard soft noise expected SUSPICIOUS")
		else:
			_ok("instanced guard evaluate_noise_response works")
	if not guard.has_method("evaluate_sight_score"):
		_fail("guard scene missing evaluate_sight_score")
	else:
		var s: float = guard.evaluate_sight_score(5.0, 15.0, false, false)
		if s < 0.55:
			_fail("instanced guard direct sight low")
		else:
			_ok("instanced guard evaluate_sight_score works")
	guard.queue_free()
	await get_tree().process_frame


func _test_gym_ai_layout() -> void:
	var fac: Node3D = Node3D.new()
	fac.set_script(load("res://scripts/world/facility_builder.gd"))
	add_child(fac)
	await get_tree().process_frame
	if fac.movement_wing_guard_count != 0:
		_fail("movement wing guards=%d want 0" % fac.movement_wing_guard_count)
	else:
		_ok("movement wings empty of AI")
	if fac.systems_guard_count < 1:
		_fail("systems guards missing")
	else:
		_ok("systems guards=%d" % fac.systems_guard_count)
	fac.queue_free()
