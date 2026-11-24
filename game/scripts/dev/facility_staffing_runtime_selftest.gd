extends Node
## Headless: deterministic staffing, relief, and responsibility-local shortage behavior.

var _fails: int = 0


func _ready() -> void:
	print("=== facility_staffing_runtime_selftest ===")
	_test_seeded_roster_is_deterministic_and_covers_continuous_posts()
	_test_shortage_uses_relief_and_degrades_only_uncovered_work()
	_test_shift_turnover_is_gapless_and_state_preserving()
	_test_on_call_mobilizes_business_cycle_job()
	print("=== facility_staffing_runtime_selftest done fails=%d ===" % _fails)
	await get_tree().process_frame
	get_tree().quit(0 if _fails == 0 else 1)


func _test_seeded_roster_is_deterministic_and_covers_continuous_posts() -> void:
	var runtime_path := "res://scripts/facility/facility_staffing_runtime.gd"
	if not ResourceLoader.exists(runtime_path):
		_fail("staffing runtime production script is missing")
		return
	var graph_script: Script = load("res://scripts/facility/facility_operation_graph.gd")
	var runtime_script: Script = load(runtime_path)
	var graph: RefCounted = graph_script.new()
	var runtime: RefCounted = runtime_script.new()
	graph.configure_cyber_archives(7319)
	var first: Dictionary = runtime.build_schedule(graph)
	var replay: Dictionary = runtime.build_schedule(graph)
	if first != replay:
		_fail("same seeded profile produced different staffing schedules")
		return
	if first["staff"].size() != int(graph.generation_profile["staff_capacity"]):
		_fail("staff schedule did not instantiate seeded capacity")
		return
	for job_id in graph.jobs:
		if not bool(graph.jobs[job_id]["continuous"]):
			continue
		for shift_id in first["shift_ids"]:
			if runtime.coverage_for_shift(first, job_id, shift_id) < int(graph.jobs[job_id]["minimum_on_shift"]):
				_fail("continuous job %s is uncovered on %s" % [job_id, shift_id])
				return
		if runtime.relief_staff_ids(first, job_id).is_empty():
			_fail("continuous job %s has no relief" % job_id)
			return
	_ok("seeded roster is deterministic and covers continuous posts")


func _test_shortage_uses_relief_and_degrades_only_uncovered_work() -> void:
	var graph_script: Script = load("res://scripts/facility/facility_operation_graph.gd")
	var runtime_script: Script = load("res://scripts/facility/facility_staffing_runtime.gd")
	var graph: RefCounted = graph_script.new()
	var runtime: RefCounted = runtime_script.new()
	graph.configure_cyber_archives(7319)
	var state: Dictionary = runtime.build_schedule(graph)
	runtime.set_active_shift(state, "day")
	var security_primary: Array[String] = runtime.active_primary_staff_ids(state, "security_officer")
	var security_shortage: Dictionary = runtime.apply_shortage(graph, state, security_primary)
	if security_shortage.get("procedure", "") != "staffing_shortage":
		_fail("shortage did not invoke authoritative staffing procedure")
		return
	if not runtime.is_job_covered(state, "security_officer") or security_shortage["relief_assignments"].is_empty():
		_fail("continuous security watch did not consume relief")
		return
	var cyber_all: Array[String] = runtime.all_staff_ids_for_job(state, "cyber_researcher")
	var research_shortage: Dictionary = runtime.apply_shortage(graph, state, cyber_all)
	if runtime.is_job_covered(state, "cyber_researcher"):
		_fail("exhausted cyber researcher role remained covered")
		return
	if runtime.mission_step_available(graph, state, "conduct_research"):
		_fail("uncovered research owner did not block owned mission step")
		return
	if not runtime.mission_step_available(graph, state, "review_findings"):
		_fail("research shortage incorrectly disabled analyst review")
		return
	if not runtime.security_function_available(state, "entry_screening"):
		_fail("research shortage incorrectly disabled relieved security watch")
		return
	if not runtime.custody_destination_available(graph, state, "archive_processing"):
		_fail("research shortage incorrectly disabled records custody")
		return
	var operation_script: Script = load("res://scripts/facility/facility_operation_runtime.gd")
	var operation_runtime: RefCounted = operation_script.new()
	var mission_state: Dictionary = operation_runtime.start_mission(graph, "staffing-coupled-mission")
	operation_runtime.advance_mission(graph, mission_state, 3)
	if not runtime.has_method("apply_mission_availability"):
		_fail("staffing state cannot couple to mission execution")
		return
	runtime.apply_mission_availability(graph, state, operation_runtime, mission_state)
	var blocked: Dictionary = operation_runtime.advance_mission(graph, mission_state)
	if blocked.get("status", "") != "blocked" or blocked.get("failed_step", "") != "conduct_research" or blocked.get("active_procedure", "") != "staffing_shortage":
		_fail("uncovered research responsibility did not block real mission runtime")
		return
	_ok("shortage uses relief and degrades only uncovered work")


func _test_shift_turnover_is_gapless_and_state_preserving() -> void:
	var graph_script: Script = load("res://scripts/facility/facility_operation_graph.gd")
	var staffing_script: Script = load("res://scripts/facility/facility_staffing_runtime.gd")
	var operation_script: Script = load("res://scripts/facility/facility_operation_runtime.gd")
	var custody_script: Script = load("res://scripts/facility/facility_custody_runtime.gd")
	var security_script: Script = load("res://scripts/facility/facility_personnel_security_runtime.gd")
	var graph: RefCounted = graph_script.new()
	var staffing: RefCounted = staffing_script.new()
	graph.configure_cyber_archives(7319)
	if not staffing.has_method("begin_shift_turnover"):
		_fail("staffing runtime has no explicit turnover receipt")
		return
	var state: Dictionary = staffing.build_schedule(graph)
	var operation: RefCounted = operation_script.new()
	var mission: Dictionary = operation.start_mission(graph, "turnover-mission")
	operation.advance_mission(graph, mission, 2)
	var custody: RefCounted = custody_script.new()
	var material: Dictionary = custody.receive_material("turnover-material")
	custody.transfer(graph, material, "material_screening", {"roles": ["security_officer"]})
	var security: RefCounted = security_script.new()
	var person: Dictionary = security.register_person("turnover-person", 3, ["duty_officer"])
	security.complete_screening(person, {"roles": ["security_officer"]})
	var entry: Dictionary = security.begin_transition(graph, person, "screened_entry")
	security.complete_transition(person, entry)
	var mission_before: Dictionary = mission.duplicate(true)
	var material_before: Dictionary = material.duplicate(true)
	var person_before: Dictionary = person.duplicate(true)
	var turnover: Dictionary = staffing.begin_shift_turnover(graph, state, "swing")
	if not turnover.get("accepted", false) or state["active_shift"] != "day":
		_fail("turnover changed shift before receipt completion")
		return
	if not staffing.complete_shift_turnover(graph, state, turnover).get("accepted", false):
		_fail("valid turnover receipt did not complete")
		return
	if state["active_shift"] != "swing" or staffing.complete_shift_turnover(graph, state, turnover).get("accepted", true):
		_fail("turnover did not advance once or receipt replayed")
		return
	for job_id in graph.jobs:
		if bool(graph.jobs[job_id]["continuous"]) and not staffing.is_job_covered(state, job_id):
			_fail("turnover left continuous job %s uncovered" % job_id)
			return
	if mission != mission_before or material != material_before or person != person_before:
		_fail("staff turnover mutated mission, custody, or personnel state")
		return
	var unsafe_state: Dictionary = staffing.build_schedule(graph)
	for staff_id in staffing.all_staff_ids_for_job(unsafe_state, "security_officer"):
		unsafe_state["unavailable"][staff_id] = true
	var rejected: Dictionary = staffing.begin_shift_turnover(graph, unsafe_state, "swing")
	if rejected.get("accepted", true) or unsafe_state["active_shift"] != "day":
		_fail("turnover crossed into an uncovered continuous watch")
		return
	_ok("shift turnover is gapless and state preserving")


func _test_on_call_mobilizes_business_cycle_job() -> void:
	var graph_script: Script = load("res://scripts/facility/facility_operation_graph.gd")
	var staffing_script: Script = load("res://scripts/facility/facility_staffing_runtime.gd")
	var graph: RefCounted = graph_script.new()
	var staffing: RefCounted = staffing_script.new()
	graph.configure_cyber_archives(7319)
	var state: Dictionary = staffing.build_schedule(graph)
	var turnover: Dictionary = staffing.begin_shift_turnover(graph, state, "swing")
	staffing.complete_shift_turnover(graph, state, turnover)
	if staffing.is_job_covered(state, "records_officer"):
		_fail("business-cycle records job remained ordinarily staffed on swing")
		return
	var mobilized: Dictionary = staffing.mobilize_on_call(graph, state, "records_officer")
	var active: Array[String] = staffing.active_staff_ids(state, "records_officer")
	if not mobilized.get("accepted", false) or active.is_empty() or not (state["relief"]["records_officer"] as Array).has(active[0]):
		_fail("on-call mobilization did not activate named relief")
		return
	if not staffing.is_job_covered(state, "records_officer") or state["on_call_log"].size() != 1:
		_fail("on-call mobilization did not establish auditable coverage")
		return
	_ok("on-call mobilizes business-cycle relief")


func _fail(msg: String) -> void:
	_fails += 1
	print("FAIL: ", msg)


func _ok(msg: String) -> void:
	print("OK: ", msg)
