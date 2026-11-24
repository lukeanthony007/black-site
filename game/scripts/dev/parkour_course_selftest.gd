extends Node
## Headless: build Animus course, assert MotorConstants geometry + gates.
## Run: godot --path game --headless res://scenes/dev_parkour_course_selftest.tscn

var _fails: int = 0


func _ready() -> void:
	print("=== parkour_course_selftest ===")
	var course_script: Script = load("res://scripts/world/parkour_course_builder.gd")
	var course: Node3D = Node3D.new()
	course.set_script(course_script)
	add_child(course)
	await get_tree().process_frame

	if course.measured_gaps.is_empty():
		_fail("no measured_gaps")
	else:
		var tol := 0.05
		for g in course.measured_gaps:
			var d: float = absf(float(g["gap"]) - float(g["expected"]))
			if d > tol:
				_fail("gap %s actual=%.3f expected=%.3f" % [g["id"], g["gap"], g["expected"]])
			else:
				_ok("gap %s=%.2f" % [g["id"], g["gap"]])

	if course.measured_steps.is_empty():
		_fail("no measured_steps")
	else:
		_ok("steps=%d" % course.measured_steps.size())

	var cps := get_tree().get_nodes_in_group("zone_checkpoints")
	if cps.size() < 6:
		_fail("checkpoints=%d want >= 6" % cps.size())
	else:
		_ok("checkpoints=%d" % cps.size())

	var want_gaps := [MotorConstants.GAP_EASY, MotorConstants.GAP_EXTREME]
	for want in want_gaps:
		var found := false
		for g in course.measured_gaps:
			if absf(float(g["expected"]) - want) < 0.001:
				found = true
		if not found:
			_fail("missing gap expected=%.2f" % want)
		else:
			_ok("has gap %.2f" % want)

	print("=== parkour_course_selftest done fails=%d ===" % _fails)
	await get_tree().process_frame
	get_tree().quit(0 if _fails == 0 else 1)


func _fail(msg: String) -> void:
	_fails += 1
	print("FAIL: ", msg)


func _ok(msg: String) -> void:
	print("OK: ", msg)
