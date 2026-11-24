extends Node
## Headless: instantiate real facility builder, assert measured geometry + AI layout.
## Run: godot --path game --headless res://scenes/dev_gym_layout_selftest.tscn

var _fails: int = 0


func _ready() -> void:
	print("=== gym_layout_selftest ===")
	var fac_script: Script = load("res://scripts/world/facility_builder.gd")
	var fac: Node3D = Node3D.new()
	fac.set_script(fac_script)
	add_child(fac)
	# _ready already ran on add_child
	await get_tree().process_frame

	if fac.movement_wing_guard_count != 0:
		_fail("movement_wing_guard_count=%d want 0" % fac.movement_wing_guard_count)
	else:
		_ok("movement wings have 0 guards")

	if fac.systems_guard_count < 1:
		_fail("systems_guard_count=%d want >= 1" % fac.systems_guard_count)
	else:
		_ok("systems wings guards=%d" % fac.systems_guard_count)

	var tol := 0.05
	if fac.measured_gaps.is_empty():
		_fail("no measured_gaps recorded")
	else:
		for g in fac.measured_gaps:
			var d: float = absf(float(g["gap"]) - float(g["expected"]))
			if d > tol:
				_fail("gap %s actual=%.3f expected=%.3f" % [g["id"], g["gap"], g["expected"]])
			else:
				_ok("gap %s=%.2f" % [g["id"], g["gap"]])

	if fac.measured_steps.is_empty():
		_fail("no measured_steps recorded")
	else:
		var checked := 0
		for s in fac.measured_steps:
			var d: float = absf(float(s["rise"]) - float(s["expected"]))
			if d > tol:
				_fail("step %s actual=%.3f expected=%.3f" % [s["id"], s["rise"], s["expected"]])
			else:
				checked += 1
		_ok("steps ok count=%d" % checked)

	# Spot-check MotorConstants used
	var found_easy := false
	for g in fac.measured_gaps:
		if absf(float(g["expected"]) - MotorConstants.GAP_EASY) < 0.001:
			found_easy = true
	if not found_easy:
		_fail("no gap uses MotorConstants.GAP_EASY")
	else:
		_ok("geometry references GAP_EASY")

	# Checkpoints optional (visual pads removed for cleaner gym)
	var cps := get_tree().get_nodes_in_group("zone_checkpoints")
	_ok("checkpoints=%d (pads optional)" % cps.size())

	# Systems entities: doors, cameras
	var doors := get_tree().get_nodes_in_group("doors")
	if doors.size() < 1:
		_fail("no doors in systems wing")
	else:
		_ok("doors=%d" % doors.size())

	print("=== gym_layout_selftest done fails=%d ===" % _fails)
	await get_tree().process_frame
	get_tree().quit(0 if _fails == 0 else 1)


func _fail(msg: String) -> void:
	_fails += 1
	print("FAIL: ", msg)


func _ok(msg: String) -> void:
	print("OK: ", msg)
