extends Node
## Proof that work freezes when station authority or required support disappears.

var _fails := 0


func _ready() -> void:
	print("=== facility_procedure_work_condition_selftest ===")
	var graph_script: Script = load("res://scripts/facility/facility_operation_graph.gd")
	var staffing_script: Script = load("res://scripts/facility/facility_staffing_runtime.gd")
	var agent_script: Script = load("res://scripts/facility/facility_staff_agent_runtime.gd")
	var work_script: Script = load("res://scripts/facility/facility_procedure_work_runtime.gd")
	for script in [graph_script, staffing_script, agent_script, work_script]:
		if script == null or not script.can_instantiate():
			_fail("condition dependency cannot instantiate")
			_finish()
			return
	var graph: RefCounted = graph_script.new()
	graph.configure_cyber_archives(7319)
	var staffing: RefCounted = staffing_script.new()
	var staffing_state: Dictionary = staffing.build_schedule(graph)
	var agents: RefCounted = agent_script.new()
	var agent_state: Dictionary = agents.build_active_watch(graph, staffing_state, staffing)
	var work: RefCounted = work_script.new()
	var work_state: Dictionary = work.start_scheduler()
	var definition := {
		"panel_id": "cooling:record_repair",
		"service": "cooling",
		"action": "record_repair",
		"station": "plant",
		"actor_job": "facilities_engineer",
		"required_services": ["maintenance"],
		"duration_ticks": 4,
	}
	var requested: Dictionary = work.request_work(graph, work_state, definition, "inspection_player", staffing_state, staffing, agent_state, agents)
	_check(requested.get("accepted", false), "condition fixture work was not admitted")
	var task_id: String = requested.get("task_id", "")
	var original_access: Array = graph.rooms["plant"]["access_roles"].duplicate()
	graph.rooms["plant"]["access_roles"] = []
	var access_suspension: Dictionary = work.reconcile_conditions(graph, work_state, {"maintenance": true}, agent_state, agents)
	_check(access_suspension.get("suspended", []).size() == 1, "revoked station authority did not suspend work")
	_check(work_state["tasks"][task_id]["status"] == "interrupted" and work_state["tasks"][task_id]["interruptions"][-1]["reason"] == "station_access_revoked", "station suspension lost authoritative reason")
	work.tick(work_state, agent_state, agents)
	_check(int(work_state["tasks"][task_id]["remaining_ticks"]) == 4, "access-suspended work progressed")
	graph.rooms["plant"]["access_roles"] = original_access
	_check(work.task_conditions(graph, work_state["tasks"][task_id], {"maintenance": true}).get("available", false), "restored station access remained invalid")
	_check(work.resume(work_state, task_id, agent_state, agents).get("accepted", false), "access-restored work could not resume")
	work.tick(work_state, agent_state, agents)
	_check(int(work_state["tasks"][task_id]["remaining_ticks"]) == 3, "resumed work did not consume exactly one tick")
	var service_suspension: Dictionary = work.reconcile_conditions(graph, work_state, {"maintenance": false}, agent_state, agents)
	_check(service_suspension.get("suspended", []).size() == 1, "maintenance loss did not suspend active work")
	_check(work_state["tasks"][task_id]["interruptions"][-1]["reason"] == "required_service_unavailable:maintenance", "service suspension lost exact support identity")
	work.tick(work_state, agent_state, agents)
	_check(int(work_state["tasks"][task_id]["remaining_ticks"]) == 3, "service-suspended work progressed")
	_check(not work.task_conditions(graph, work_state["tasks"][task_id], {"maintenance": false}).get("available", true), "unavailable maintenance passed resume preflight")
	_check(work.task_conditions(graph, work_state["tasks"][task_id], {"maintenance": true}).get("available", false), "restored maintenance failed resume preflight")
	_check(work.resume(work_state, task_id, agent_state, agents).get("accepted", false), "support-restored work could not resume")
	var completions: Array[Dictionary] = []
	for _tick in 3:
		completions.append_array(work.tick(work_state, agent_state, agents)["completions"])
	_check(completions.size() == 1, "resumed condition-safe work did not complete exactly once")
	var facilities_ids: Array[String] = staffing.active_staff_ids(staffing_state, "facilities_engineer")
	for staff_id in facilities_ids:
		agents.dispatch(graph, agent_state, staff_id, "staff_control")
	agents.tick(agent_state)
	var dispatched_definition: Dictionary = definition.duplicate(true)
	dispatched_definition["panel_id"] = "cooling:isolate_dispatch_probe"
	var dispatched: Dictionary = work.request_work(graph, work_state, dispatched_definition, "inspection_player", staffing_state, staffing, agent_state, agents)
	var dispatched_task_id: String = dispatched.get("task_id", "")
	var dispatched_actor: String = dispatched.get("actor_person_id", "")
	var dispatch_suspension: Dictionary = work.reconcile_conditions(graph, work_state, {"maintenance": false}, agent_state, agents)
	_check(dispatched.get("status", "") == "dispatched" and dispatch_suspension.get("suspended", []).size() == 1, "support loss did not suspend dispatched work")
	_check((agent_state["agents"][dispatched_actor]["route"] as Array).is_empty() and agent_state["agents"][dispatched_actor]["current_room"] == "staff_control" and work_state["tasks"][dispatched_task_id]["status"] == "interrupted", "suspension allowed stale agent dispatch to continue")
	_ok("procedure work suspends on access/support loss without losing progress")
	_finish()


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
	print("=== facility_procedure_work_condition_selftest done fails=%d ===" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
