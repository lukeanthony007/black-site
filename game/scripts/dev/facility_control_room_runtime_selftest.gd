extends Node
## Headless: authoritative control-room projection and non-authoritative acknowledgements.

var _fails: int = 0


func _ready() -> void:
	print("=== facility_control_room_runtime_selftest ===")
	_test_acknowledgement_never_resolves_conditions()
	_test_condition_recurrence_requires_new_acknowledgement()
	print("=== facility_control_room_runtime_selftest done fails=%d ===" % _fails)
	await get_tree().process_frame
	get_tree().quit(0 if _fails == 0 else 1)


func _fixture() -> Dictionary:
	var graph_script: Script = load("res://scripts/facility/facility_operation_graph.gd")
	var operation_script: Script = load("res://scripts/facility/facility_operation_runtime.gd")
	var custody_script: Script = load("res://scripts/facility/facility_custody_runtime.gd")
	var personnel_script: Script = load("res://scripts/facility/facility_personnel_security_runtime.gd")
	var staffing_script: Script = load("res://scripts/facility/facility_staffing_runtime.gd")
	var control_script: Script = load("res://scripts/facility/facility_control_room_runtime.gd")
	for script in [graph_script, operation_script, custody_script, personnel_script, staffing_script, control_script]:
		if script == null or not script.can_instantiate():
			return {}
	var graph: RefCounted = graph_script.new()
	graph.configure_cyber_archives(7319)
	var operation: RefCounted = operation_script.new()
	var mission: Dictionary = operation.start_mission(graph, "control-room-mission")
	operation.advance_mission(graph, mission, 3)
	var custody: RefCounted = custody_script.new()
	var material: Dictionary = custody.receive_material("control-room-material")
	var personnel: RefCounted = personnel_script.new()
	var person: Dictionary = personnel.register_person("control-room-person", 5, ["duty_officer"])
	var staffing: RefCounted = staffing_script.new()
	var roster: Dictionary = staffing.build_schedule(graph)
	var control: RefCounted = control_script.new()
	var console: Dictionary = control.start_console("duty-console")
	return {
		"graph": graph,
		"operation": operation,
		"mission": mission,
		"custody": custody,
		"material": material,
		"personnel": personnel,
		"person": person,
		"staffing": staffing,
		"roster": roster,
		"control": control,
		"console": console,
	}


func _test_acknowledgement_never_resolves_conditions() -> void:
	var f := _fixture()
	if f.is_empty():
		_fail("control-room runtime dependency cannot instantiate")
		return
	var research_staff: Array[String] = f.staffing.all_staff_ids_for_job(f.roster, "cyber_researcher")
	f.staffing.apply_shortage(f.graph, f.roster, research_staff)
	f.staffing.apply_mission_availability(f.graph, f.roster, f.operation, f.mission)
	f.operation.set_service_available(f.mission, "cooling", false)
	f.operation.advance_mission(f.graph, f.mission)
	f.custody.declare_incident(f.graph, f.material, "archive_fire_water")
	var snapshot: Dictionary = f.control.compile_status(f.graph, f.console, f.mission, f.material, f.person, f.roster, f.staffing)
	if snapshot.get("severity", "") != "alarm" or snapshot.get("conditions", []).size() < 3:
		_fail("control board omitted active cross-domain conditions")
		return
	if snapshot.get("mission", {}).get("next_step", "") != "conduct_research" or snapshot.get("staffing", {}).get("active_shift", "") != "day":
		_fail("control board lost mission or staffing provenance")
		return
	var cooling: Dictionary = _condition(snapshot, "service:cooling")
	if cooling.is_empty() or cooling.get("procedure", "") != "cooling_failure" or cooling.get("owner_job", "") != "facilities_engineer":
		_fail("control board did not expose cooling procedure ownership")
		return
	var denied: Dictionary = f.control.acknowledge(f.console, snapshot, cooling["occurrence_id"], {"roles": ["cyber_researcher"]})
	if denied.get("accepted", true):
		_fail("non-owner acknowledged control-room condition")
		return
	var mission_before: Dictionary = f.mission.duplicate(true)
	var material_before: Dictionary = f.material.duplicate(true)
	var person_before: Dictionary = f.person.duplicate(true)
	var roster_before: Dictionary = f.roster.duplicate(true)
	var accepted: Dictionary = f.control.acknowledge(f.console, snapshot, cooling["occurrence_id"], {"roles": ["facilities_engineer"]})
	if not accepted.get("accepted", false):
		_fail("procedure owner could not acknowledge active condition")
		return
	if f.mission != mission_before or f.material != material_before or f.person != person_before or f.roster != roster_before:
		_fail("acknowledgement mutated an authoritative source state")
		return
	var acknowledged: Dictionary = f.control.compile_status(f.graph, f.console, f.mission, f.material, f.person, f.roster, f.staffing)
	var cooling_after: Dictionary = _condition(acknowledged, "service:cooling")
	if acknowledged["severity"] != "alarm" or not cooling_after.get("acknowledged", false) or cooling_after.get("active", false) != true:
		_fail("acknowledgement cleared or downgraded an underlying alarm")
		return
	_ok("acknowledgement never resolves authoritative conditions")


func _test_condition_recurrence_requires_new_acknowledgement() -> void:
	var f := _fixture()
	if f.is_empty():
		_fail("control-room recurrence fixture unavailable")
		return
	f.operation.set_service_available(f.mission, "cooling", false)
	var first: Dictionary = f.control.compile_status(f.graph, f.console, f.mission, f.material, f.person, f.roster, f.staffing)
	var first_condition: Dictionary = _condition(first, "service:cooling")
	f.control.acknowledge(f.console, first, first_condition["occurrence_id"], {"roles": ["duty_officer"]})
	f.operation.set_service_available(f.mission, "cooling", true)
	var clear: Dictionary = f.control.compile_status(f.graph, f.console, f.mission, f.material, f.person, f.roster, f.staffing)
	if not _condition(clear, "service:cooling").is_empty():
		_fail("resolved service remained active on control board")
		return
	f.operation.set_service_available(f.mission, "cooling", false)
	var recurrence: Dictionary = f.control.compile_status(f.graph, f.console, f.mission, f.material, f.person, f.roster, f.staffing)
	var second_condition: Dictionary = _condition(recurrence, "service:cooling")
	if second_condition.get("occurrence_id", "") == first_condition.get("occurrence_id", "") or second_condition.get("acknowledged", true):
		_fail("recurrent condition inherited stale acknowledgement")
		return
	_ok("condition recurrence requires new acknowledgement")


func _condition(snapshot: Dictionary, condition_key: String) -> Dictionary:
	for condition in snapshot.get("conditions", []):
		if condition.get("key", "") == condition_key:
			return condition
	return {}


func _fail(message: String) -> void:
	_fails += 1
	print("FAIL: ", message)


func _ok(message: String) -> void:
	print("OK: ", message)
