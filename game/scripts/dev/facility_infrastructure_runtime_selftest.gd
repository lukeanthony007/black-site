extends Node
## Headless: staffed, station-local, independently verified infrastructure recovery.

var _fails: int = 0


func _ready() -> void:
	print("=== facility_infrastructure_runtime_selftest ===")
	_test_acknowledgement_cannot_restore_service()
	_test_recovery_requires_owner_presence_remediation_and_independent_verification()
	print("=== facility_infrastructure_runtime_selftest done fails=%d ===" % _fails)
	await get_tree().process_frame
	get_tree().quit(0 if _fails == 0 else 1)


func _fixture() -> Dictionary:
	var paths := [
		"res://scripts/facility/facility_operation_graph.gd",
		"res://scripts/facility/facility_operation_runtime.gd",
		"res://scripts/facility/facility_infrastructure_runtime.gd",
		"res://scripts/facility/facility_staffing_runtime.gd",
		"res://scripts/facility/facility_control_room_runtime.gd",
		"res://scripts/facility/facility_custody_runtime.gd",
		"res://scripts/facility/facility_personnel_security_runtime.gd",
	]
	var scripts: Array[Script] = []
	for path in paths:
		var script: Script = load(path)
		if script == null or not script.can_instantiate():
			return {}
		scripts.append(script)
	var graph: RefCounted = scripts[0].new()
	graph.configure_cyber_archives(7319)
	var operation: RefCounted = scripts[1].new()
	var mission: Dictionary = operation.start_mission(graph, "infrastructure-recovery")
	operation.advance_mission(graph, mission, 3)
	var infrastructure: RefCounted = scripts[2].new()
	var infrastructure_state: Dictionary = infrastructure.start_services(graph)
	var staffing: RefCounted = scripts[3].new()
	var roster: Dictionary = staffing.build_schedule(graph)
	return {
		"graph": graph,
		"operation": operation,
		"mission": mission,
		"infrastructure": infrastructure,
		"infrastructure_state": infrastructure_state,
		"staffing": staffing,
		"roster": roster,
		"control": scripts[4].new(),
		"custody": scripts[5].new().receive_material("infrastructure-material"),
		"personnel_runtime": scripts[6].new(),
	}


func _test_acknowledgement_cannot_restore_service() -> void:
	var f := _fixture()
	if f.is_empty():
		_fail("infrastructure runtime dependency cannot instantiate")
		return
	var failure: Dictionary = f.infrastructure.declare_service_failure(f.graph, f.infrastructure_state, "cooling")
	f.infrastructure.apply_mission_snapshot(f.graph, f.infrastructure_state, f.operation, f.mission)
	f.operation.advance_mission(f.graph, f.mission)
	var console: Dictionary = f.control.start_console("infrastructure-console")
	var person: Dictionary = f.personnel_runtime.register_person("observer", 5, ["facilities_engineer"])
	var snapshot: Dictionary = f.control.compile_status(f.graph, console, f.mission, f.custody, person, f.roster, f.staffing)
	var occurrence := ""
	for condition in snapshot["conditions"]:
		if condition["key"] == "service:cooling":
			occurrence = condition["occurrence_id"]
	var acknowledgement: Dictionary = f.control.acknowledge(console, snapshot, occurrence, {"roles": ["facilities_engineer"]})
	if not failure.get("accepted", false) or not acknowledgement.get("accepted", false):
		_fail("failure or owner acknowledgement setup failed")
		return
	if bool(f.infrastructure_state["services"]["cooling"]) or f.mission["status"] != "blocked":
		_fail("acknowledgement substituted for physical service restoration")
		return
	_ok("acknowledgement cannot restore infrastructure")


func _test_recovery_requires_owner_presence_remediation_and_independent_verification() -> void:
	var f := _fixture()
	if f.is_empty():
		_fail("infrastructure recovery fixture unavailable")
		return
	var failure: Dictionary = f.infrastructure.declare_service_failure(f.graph, f.infrastructure_state, "cooling")
	f.infrastructure.apply_mission_snapshot(f.graph, f.infrastructure_state, f.operation, f.mission)
	f.operation.advance_mission(f.graph, f.mission)
	var owner_staff: Array[String] = f.staffing.active_primary_staff_ids(f.roster, "facilities_engineer")
	var duty_staff: Array[String] = f.staffing.active_primary_staff_ids(f.roster, "duty_officer")
	var actor := {
		"person_id": owner_staff[0],
		"roles": ["facilities_engineer"],
		"current_room": "cyber_ops",
	}
	var verifier := {
		"person_id": duty_staff[0],
		"roles": ["duty_officer"],
		"current_room": "cyber_ops",
	}
	if f.infrastructure.service_phase(f.infrastructure_state, "cooling") != "safe_hold":
		_fail("cooling failure did not enter safe hold")
		return
	if not f.infrastructure.room_has_service(f.infrastructure_state, "compute_core", "cooling") or f.infrastructure.room_has_service(f.infrastructure_state, "contained_lab", "cooling"):
		_fail("safe hold did not preserve only declared cooling consumers")
		return
	var premature_owner := actor.duplicate(true)
	premature_owner["current_room"] = "plant"
	var premature_recovery: Dictionary = f.infrastructure.begin_recovery(
		f.graph, f.infrastructure_state, "cooling_failure", failure["failure_id"], premature_owner, f.roster, f.staffing
	)
	if premature_recovery.get("accepted", true):
		_fail("repair began before controlled shutdown and isolation")
		return
	var shutdown: Dictionary = f.infrastructure.advance_failure_response(
		f.graph, f.infrastructure_state, failure["failure_id"], "enter_controlled_shutdown", verifier, f.roster, f.staffing
	)
	if not shutdown.get("accepted", false) or f.infrastructure.service_phase(f.infrastructure_state, "cooling") != "controlled_shutdown":
		_fail("duty watch could not command cooling shutdown")
		return
	var isolation: Dictionary = f.infrastructure.advance_failure_response(
		f.graph, f.infrastructure_state, failure["failure_id"], "isolate_for_repair", premature_owner, f.roster, f.staffing
	)
	if not isolation.get("accepted", false) or f.infrastructure.service_phase(f.infrastructure_state, "cooling") != "repair_pending":
		_fail("plant owner could not isolate cooling for repair")
		return
	var wrong_station: Dictionary = f.infrastructure.begin_recovery(
		f.graph, f.infrastructure_state, "cooling_failure", failure["failure_id"], actor, f.roster, f.staffing
	)
	if wrong_station.get("accepted", true):
		_fail("procedure owner began recovery away from procedure station")
		return
	var absent_roster: Dictionary = f.staffing.build_schedule(f.graph)
	f.staffing.apply_shortage(f.graph, absent_roster, f.staffing.all_staff_ids_for_job(absent_roster, "facilities_engineer"))
	actor["current_room"] = "plant"
	var absent_owner: Dictionary = f.infrastructure.begin_recovery(
		f.graph, f.infrastructure_state, "cooling_failure", failure["failure_id"], actor, absent_roster, f.staffing
	)
	if absent_owner.get("accepted", true):
		_fail("uncovered owner job began infrastructure recovery")
		return
	var receipt: Dictionary = f.infrastructure.begin_recovery(
		f.graph, f.infrastructure_state, "cooling_failure", failure["failure_id"], actor, f.roster, f.staffing
	)
	if not receipt.get("accepted", false):
		_fail("present procedure owner could not reserve recovery")
		return
	var source_before: Dictionary = f.infrastructure_state.duplicate(true)
	var premature: Dictionary = f.infrastructure.verify_and_restore(
		f.graph, f.infrastructure_state, receipt, verifier, f.roster, f.staffing
	)
	if premature.get("accepted", true) or f.infrastructure_state != source_before:
		_fail("verification without remediation mutated infrastructure")
		return
	var remediation: Dictionary = f.infrastructure.record_remediation(f.infrastructure_state, receipt, actor, {
		"action": "repair_completed",
		"service": "cooling",
		"station": "plant",
	})
	if not remediation.get("accepted", false) or bool(f.infrastructure_state["services"]["cooling"]):
		_fail("remediation record failed or directly restored service")
		return
	if f.infrastructure.service_phase(f.infrastructure_state, "cooling") != "testing":
		_fail("repair did not advance cooling into testing")
		return
	var untested_verify: Dictionary = f.infrastructure.verify_and_restore(
		f.graph, f.infrastructure_state, receipt, verifier, f.roster, f.staffing
	)
	if untested_verify.get("accepted", true):
		_fail("independent verifier restored untested cooling")
		return
	var tested: Dictionary = f.infrastructure.record_service_test(f.infrastructure_state, receipt, actor, {
		"action": "functional_test_passed",
		"service": "cooling",
		"station": "plant",
	})
	if not tested.get("accepted", false) or f.infrastructure.service_phase(f.infrastructure_state, "cooling") != "reconstitution_pending":
		_fail("functional test did not advance cooling to reconstitution")
		return
	var self_verify: Dictionary = f.infrastructure.verify_and_restore(
		f.graph, f.infrastructure_state, receipt, actor, f.roster, f.staffing
	)
	if self_verify.get("accepted", true) or bool(f.infrastructure_state["services"]["cooling"]):
		_fail("repair actor self-verified critical restoration")
		return
	var verified: Dictionary = f.infrastructure.verify_and_restore(
		f.graph, f.infrastructure_state, receipt, verifier, f.roster, f.staffing
	)
	if not verified.get("accepted", false) or not bool(f.infrastructure_state["services"]["cooling"]):
		_fail("independent duty verification did not restore service")
		return
	if f.mission["status"] != "blocked":
		_fail("infrastructure restoration bypassed explicit mission snapshot coupling")
		return
	f.infrastructure.apply_mission_snapshot(f.graph, f.infrastructure_state, f.operation, f.mission)
	var completed: Dictionary = f.operation.advance_mission(f.graph, f.mission)
	if completed.get("status", "") != "completed":
		_fail("verified infrastructure snapshot did not release mission")
		return
	if f.infrastructure.verify_and_restore(
		f.graph, f.infrastructure_state, receipt, verifier, f.roster, f.staffing
	).get("accepted", true):
		_fail("consumed recovery receipt replayed")
		return
	_ok("staged recovery requires safe hold, shutdown, repair, test, and independent reconstitution")


func _fail(message: String) -> void:
	_fails += 1
	print("FAIL: ", message)


func _ok(message: String) -> void:
	print("OK: ", message)
