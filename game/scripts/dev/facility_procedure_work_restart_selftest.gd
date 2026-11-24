extends Node
## Cross-process proof for fail-closed procedure-work restart recovery.

const SNAPSHOT_PATH := "user://facility_procedure_work_restart_selftest.json"
var _fails := 0


func _ready() -> void:
	if OS.get_cmdline_user_args().has("restart-child"):
		_run_restart_child()
		return
	print("=== facility_procedure_work_restart_selftest ===")
	var dependencies: Dictionary = _dependencies()
	if dependencies.is_empty():
		_finish()
		return
	var fixture: Dictionary = _build_fixture(dependencies)
	var work: RefCounted = fixture["work"]
	var work_state: Dictionary = fixture["work_state"]
	var task_id: String = fixture["task_id"]
	var snapshot: Dictionary = work.export_snapshot(work_state)
	_check(snapshot.get("accepted", false), "scheduler snapshot was not exported")
	var corrupt: Dictionary = snapshot.duplicate(true)
	corrupt["state"]["tasks"][task_id]["remaining_ticks"] = 99
	_check(not work.recover_snapshot(corrupt).get("accepted", true), "corrupt remaining duration was admitted")
	var file := FileAccess.open(SNAPSHOT_PATH, FileAccess.WRITE)
	_check(file != null, "restart snapshot file could not be opened")
	if file != null:
		file.store_string(JSON.stringify(snapshot))
		file.close()
	var output: Array = []
	var executable := OS.get_executable_path()
	var project_path := ProjectSettings.globalize_path("res://")
	var exit_code := OS.execute(executable, PackedStringArray([
		"--path", project_path,
		"--headless",
		"res://scenes/dev_facility_procedure_work_restart_selftest.tscn",
		"--", "restart-child",
	]), output, true)
	var child_output := "\n".join(output)
	_check(exit_code == 0, "restart child failed with exit %d\n%s" % [exit_code, child_output])
	_check(child_output.contains("OK: cross-process work recovery preserves ticks and requires reconciliation"), "restart child emitted no success proof")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SNAPSHOT_PATH))
	_ok("procedure work survives a real process restart without fabricated progress")
	_finish()


func _run_restart_child() -> void:
	var dependencies: Dictionary = _dependencies()
	if dependencies.is_empty():
		get_tree().quit(1)
		return
	var file := FileAccess.open(SNAPSHOT_PATH, FileAccess.READ)
	if file == null:
		_fail("restart child could not read snapshot")
		_finish()
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		_fail("restart child snapshot is not a dictionary")
		_finish()
		return
	var graph: RefCounted = dependencies["graph_script"].new()
	graph.configure_cyber_archives(7319)
	var staffing: RefCounted = dependencies["staffing_script"].new()
	var staffing_state: Dictionary = staffing.build_schedule(graph)
	var agents: RefCounted = dependencies["agent_script"].new()
	var agent_state: Dictionary = agents.build_active_watch(graph, staffing_state, staffing)
	var work: RefCounted = dependencies["work_script"].new()
	var recovered: Dictionary = work.recover_snapshot(parsed)
	_check(recovered.get("accepted", false), "restart snapshot did not recover")
	if not recovered.get("accepted", false):
		_finish()
		return
	var state: Dictionary = recovered["state"]
	var task_id := ""
	var completed_task_id := ""
	for candidate_id in state["tasks"]:
		if state["tasks"][candidate_id]["action"] == "record_repair":
			task_id = candidate_id
		elif state["tasks"][candidate_id]["action"] == "restart_receipt_probe":
			completed_task_id = candidate_id
	var task: Dictionary = state["tasks"][task_id]
	_check(not completed_task_id.is_empty() and state["tasks"][completed_task_id]["status"] == "completed", "unconsumed completion did not survive restart")
	var existing_receipts: Array = state["completion_receipts"].values()
	_check(existing_receipts.size() == 1 and work.consume_completion(state, existing_receipts[0]).get("accepted", false), "pre-restart completion receipt was not consumable after recovery")
	_check(not work.consume_completion(state, existing_receipts[0]).get("accepted", true), "pre-restart completion receipt replay was accepted")
	_check(task["status"] == "interrupted" and int(task["remaining_ticks"]) == 2, "restart fabricated status or work progress")
	_check(task["interruptions"].size() == 1 and task["interruptions"][0]["reason"] == "restart_reconciliation_required", "restart interruption provenance is missing")
	var frozen_tick: Dictionary = work.tick(state, agent_state, agents)
	_check(frozen_tick["completions"].is_empty() and int(state["tasks"][task_id]["remaining_ticks"]) == 2, "recovered interrupted work progressed automatically")
	var resumed: Dictionary = work.resume(state, task_id, agent_state, agents)
	_check(resumed.get("accepted", false), "station-local actor could not explicitly reconcile restart work")
	var first_tick: Dictionary = work.tick(state, agent_state, agents)
	var second_tick: Dictionary = work.tick(state, agent_state, agents)
	_check(first_tick["completions"].is_empty() and second_tick["completions"].size() == 1, "recovered work did not complete at exact remaining duration")
	var receipt: Dictionary = second_tick.get("completions", [{}])[0]
	_check(work.consume_completion(state, receipt).get("accepted", false), "recovered completion receipt was not consumable")
	_check(not work.consume_completion(state, receipt).get("accepted", true), "recovered completion receipt replay was accepted")
	_ok("cross-process work recovery preserves ticks and requires reconciliation")
	_finish()


func _dependencies() -> Dictionary:
	var result := {
		"graph_script": load("res://scripts/facility/facility_operation_graph.gd"),
		"staffing_script": load("res://scripts/facility/facility_staffing_runtime.gd"),
		"agent_script": load("res://scripts/facility/facility_staff_agent_runtime.gd"),
		"work_script": load("res://scripts/facility/facility_procedure_work_runtime.gd"),
	}
	for script in result.values():
		if script == null or not script.can_instantiate():
			_fail("restart dependency cannot instantiate")
			return {}
	return result


func _build_fixture(dependencies: Dictionary) -> Dictionary:
	var graph: RefCounted = dependencies["graph_script"].new()
	graph.configure_cyber_archives(7319)
	var staffing: RefCounted = dependencies["staffing_script"].new()
	var staffing_state: Dictionary = staffing.build_schedule(graph)
	var agents: RefCounted = dependencies["agent_script"].new()
	var agent_state: Dictionary = agents.build_active_watch(graph, staffing_state, staffing)
	var work: RefCounted = dependencies["work_script"].new()
	var work_state: Dictionary = work.start_scheduler()
	var definition := {
		"panel_id": "cooling:record_repair",
		"service": "cooling",
		"action": "record_repair",
		"station": "plant",
		"actor_job": "facilities_engineer",
		"duration_ticks": 3,
	}
	var requested: Dictionary = work.request_work(graph, work_state, definition, "inspection_player", staffing_state, staffing, agent_state, agents)
	_check(requested.get("accepted", false), "restart fixture work was not admitted")
	var receipt_probe := {
		"panel_id": "cooling:restart_receipt_probe",
		"service": "cooling",
		"action": "restart_receipt_probe",
		"station": "cyber_ops",
		"actor_job": "duty_officer",
		"duration_ticks": 1,
	}
	var probe_requested: Dictionary = work.request_work(graph, work_state, receipt_probe, "inspection_player", staffing_state, staffing, agent_state, agents)
	_check(probe_requested.get("accepted", false), "restart completion-receipt probe was not admitted")
	var fixture_tick: Dictionary = work.tick(work_state, agent_state, agents)
	_check(fixture_tick["completions"].size() == 1, "restart fixture did not preserve one unconsumed completion")
	_check(int(work_state["tasks"][requested.get("task_id", "")]["remaining_ticks"]) == 2, "restart fixture did not record one completed tick")
	return {"work": work, "work_state": work_state, "task_id": requested.get("task_id", "")}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _ok(message: String) -> void:
	print("OK: %s" % message)


func _fail(message: String) -> void:
	_fails += 1
	push_error("FAIL: %s" % message)
	print("FAIL: %s" % message)


func _finish() -> void:
	print("=== facility_procedure_work_restart_selftest done fails=%d ===" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
