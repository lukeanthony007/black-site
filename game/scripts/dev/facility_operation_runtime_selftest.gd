extends Node
## Headless: execute the normal Cyber/Archives mission through real stations.

var _fails: int = 0


func _ready() -> void:
	print("=== facility_operation_runtime_selftest ===")
	_test_normal_mission_executes_station_handoffs()
	_test_missing_equipment_fails_at_owning_station()
	_test_cooling_failure_pauses_and_resumes_without_duplication()
	_test_combined_blockers_require_independent_recovery()
	print("=== facility_operation_runtime_selftest done fails=%d ===" % _fails)
	await get_tree().process_frame
	get_tree().quit(0 if _fails == 0 else 1)


func _test_normal_mission_executes_station_handoffs() -> void:
	var runtime_path := "res://scripts/facility/facility_operation_runtime.gd"
	if not ResourceLoader.exists(runtime_path):
		_fail("FacilityOperationRuntime production script is missing")
		return
	var graph_script: Script = load("res://scripts/facility/facility_operation_graph.gd")
	var runtime_script: Script = load(runtime_path)
	if runtime_script == null or not runtime_script.can_instantiate():
		_fail("FacilityOperationRuntime cannot instantiate")
		return
	var graph: RefCounted = graph_script.new()
	var runtime: RefCounted = runtime_script.new()
	graph.configure_cyber_archives(7319)
	var graph_errors: Array[String] = graph.validate()
	if not graph_errors.is_empty():
		_fail("inhabited operational graph invalid: %s" % "; ".join(graph_errors))
		return
	var result: Dictionary = runtime.run_normal_mission(graph, "mission-alpha")
	if not bool(result.get("completed", false)):
		_fail("normal mission failed: %s" % result.get("failure", "unknown"))
		return
	if (result.get("trace", []) as Array).size() != graph.mission_steps.size():
		_fail("normal mission did not execute every authoritative step")
		return
	var artifacts: Dictionary = result.get("artifacts", {})
	if not artifacts.has("preserved_record") or not artifacts.has("restored_baseline"):
		_fail("normal mission did not preserve evidence and restore compute baseline")
		return
	_ok("normal mission executes station handoffs")


func _test_missing_equipment_fails_at_owning_station() -> void:
	var graph_script: Script = load("res://scripts/facility/facility_operation_graph.gd")
	var runtime_script: Script = load("res://scripts/facility/facility_operation_runtime.gd")
	var graph: RefCounted = graph_script.new()
	var runtime: RefCounted = runtime_script.new()
	graph.configure_cyber_archives(7319)
	graph.remove_equipment("contained_analysis_bench")
	var result: Dictionary = runtime.run_normal_mission(graph, "mission-equipment-failure")
	if bool(result.get("completed", false)):
		_fail("mission completed without contained analysis equipment")
		return
	if result.get("failed_step", "") != "conduct_research":
		_fail("missing equipment failed at wrong operational step")
		return
	_ok("missing equipment fails at owning station")


func _test_cooling_failure_pauses_and_resumes_without_duplication() -> void:
	var graph_script: Script = load("res://scripts/facility/facility_operation_graph.gd")
	var runtime_script: Script = load("res://scripts/facility/facility_operation_runtime.gd")
	var graph: RefCounted = graph_script.new()
	var runtime: RefCounted = runtime_script.new()
	graph.configure_cyber_archives(7319)
	if not runtime.has_method("start_mission") or not runtime.has_method("advance_mission"):
		_fail("runtime has no resumable degraded-operation state")
		return
	var state: Dictionary = runtime.start_mission(graph, "mission-cooling-recovery")
	var staged: Dictionary = runtime.advance_mission(graph, state, 3)
	if staged.get("status", "") != "running" or int(state["next_step_index"]) != 3:
		_fail("mission did not stop after committed staging steps")
		return
	runtime.set_service_available(state, "cooling", false)
	var before_block: Dictionary = (state["artifacts"] as Dictionary).duplicate(true)
	var blocked: Dictionary = runtime.advance_mission(graph, state)
	if blocked.get("status", "") != "blocked" or blocked.get("failed_step", "") != "conduct_research":
		_fail("cooling loss did not block contained research")
		return
	if blocked.get("active_procedure", "") != "cooling_failure":
		_fail("cooling loss did not invoke owned failure procedure")
		return
	if state["artifacts"] != before_block or int(state["next_step_index"]) != 3:
		_fail("blocked attempt mutated committed mission state")
		return
	runtime.set_service_available(state, "cooling", true)
	var recovered: Dictionary = runtime.advance_mission(graph, state)
	if recovered.get("status", "") != "completed":
		_fail("mission failed to complete after cooling recovery")
		return
	var seen_steps: Dictionary = {}
	for trace_item in state["trace"]:
		var step_id: String = trace_item["step"]
		if seen_steps.has(step_id):
			_fail("recovery duplicated committed step %s" % step_id)
			return
		seen_steps[step_id] = true
	if seen_steps.size() != graph.mission_steps.size():
		_fail("recovery lost authoritative mission steps")
		return
	if not state["artifacts"].has("preserved_record") or not state["artifacts"].has("restored_baseline"):
		_fail("recovery lost final mission artifacts")
		return
	_ok("cooling failure pauses and resumes without duplication")


func _test_combined_blockers_require_independent_recovery() -> void:
	var graph_script: Script = load("res://scripts/facility/facility_operation_graph.gd")
	var runtime_script: Script = load("res://scripts/facility/facility_operation_runtime.gd")
	var graph: RefCounted = graph_script.new()
	var runtime: RefCounted = runtime_script.new()
	graph.configure_cyber_archives(7319)
	var state: Dictionary = runtime.start_mission(graph, "mission-combined-recovery")
	runtime.advance_mission(graph, state, 3)
	runtime.set_job_available(state, "cyber_researcher", false)
	runtime.set_service_available(state, "cooling", false)
	var artifacts_before: Dictionary = (state["artifacts"] as Dictionary).duplicate(true)
	var blocked: Dictionary = runtime.advance_mission(graph, state)
	if blocked.get("status", "") != "blocked" or not state.has("active_blockers"):
		_fail("combined failure produced no authoritative blocker set")
		return
	var blockers: Array = state["active_blockers"]
	if blockers.size() != 2 or blockers[0].get("kind", "") != "service" or blockers[0].get("id", "") != "cooling":
		_fail("combined failure did not apply utility-first safety priority")
		return
	if blocked.get("active_procedure", "") != "cooling_failure":
		_fail("combined failure did not activate highest-priority procedure")
		return
	runtime.set_service_available(state, "cooling", true)
	if state["status"] != "blocked" or state["active_procedure"] != "staffing_shortage":
		_fail("restoring cooling silently resumed through staffing blocker")
		return
	if state["artifacts"] != artifacts_before or int(state["next_step_index"]) != 3:
		_fail("partial combined recovery mutated committed mission state")
		return
	runtime.set_job_available(state, "cyber_researcher", true)
	if state["status"] != "running":
		_fail("clearing final blocker did not release mission")
		return
	var recovered: Dictionary = runtime.advance_mission(graph, state)
	if recovered.get("status", "") != "completed":
		_fail("mission did not complete after independent blocker recovery")
		return
	_ok("combined blockers require independent recovery")


func _fail(msg: String) -> void:
	_fails += 1
	print("FAIL: ", msg)


func _ok(msg: String) -> void:
	print("OK: ", msg)
