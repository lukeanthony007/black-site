extends Node
## Behavioral proof for durable, interruptible, receipt-bound procedure work.

var _fails := 0


func _ready() -> void:
	print("=== facility_procedure_work_runtime_selftest ===")
	var graph_script: Script = load("res://scripts/facility/facility_operation_graph.gd")
	var staffing_script: Script = load("res://scripts/facility/facility_staffing_runtime.gd")
	var agent_script: Script = load("res://scripts/facility/facility_staff_agent_runtime.gd")
	var work_script: Script = load("res://scripts/facility/facility_procedure_work_runtime.gd")
	for script in [graph_script, staffing_script, agent_script, work_script]:
		if script == null or not script.can_instantiate():
			_fail("procedure-work dependency cannot instantiate")
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
	var facilities_ids: Array[String] = staffing.active_staff_ids(staffing_state, "facilities_engineer")
	for staff_id in facilities_ids:
		agents.dispatch(graph, agent_state, staff_id, "staff_control")
	agents.tick(agent_state)
	var definition := {
		"panel_id": "cooling:isolate_for_repair",
		"service": "cooling",
		"action": "isolate_for_repair",
		"station": "plant",
		"actor_job": "facilities_engineer",
		"duration_ticks": 3,
	}
	var requested: Dictionary = work.request_work(
		graph, work_state, definition, "inspection_player",
		staffing_state, staffing, agent_state, agents
	)
	if not requested.get("accepted", false) or requested.get("status", "") != "dispatched":
		_fail("work request did not dispatch a named facilities actor")
		_finish()
		return
	var task_id: String = requested["task_id"]
	var actor_id: String = requested["actor_person_id"]
	var duplicate: Dictionary = work.request_work(
		graph, work_state, definition, "inspection_player",
		staffing_state, staffing, agent_state, agents
	)
	if duplicate.get("accepted", true):
		_fail("duplicate active panel work was admitted")
		_finish()
		return
	var arrival_tick: Dictionary = work.tick(work_state, agent_state, agents)
	if not arrival_tick.get("completions", []).is_empty() or work_state["tasks"][task_id]["status"] != "working" or work_state["tasks"][task_id]["remaining_ticks"] != 3:
		_fail("arrival fabricated work progress or completion")
		_finish()
		return
	var work_tick: Dictionary = work.tick(work_state, agent_state, agents)
	if not work_tick.get("completions", []).is_empty() or work_state["tasks"][task_id]["remaining_ticks"] != 2:
		_fail("timed work did not consume exactly one tick")
		_finish()
		return
	var interrupted: Dictionary = work.interrupt(work_state, task_id, "shift_boundary", agent_state, agents)
	if not interrupted.get("accepted", false) or work_state["tasks"][task_id]["status"] != "interrupted":
		_fail("active procedure work could not be interrupted")
		_finish()
		return
	var frozen_remaining: int = work_state["tasks"][task_id]["remaining_ticks"]
	if not work.tick(work_state, agent_state, agents).get("completions", []).is_empty() or work_state["tasks"][task_id]["remaining_ticks"] != frozen_remaining:
		_fail("interrupted work advanced without resumption")
		_finish()
		return
	var resumed: Dictionary = work.resume(work_state, task_id, agent_state, agents)
	if not resumed.get("accepted", false) or resumed.get("actor_person_id", "") != actor_id:
		_fail("work did not resume under its bound actor")
		_finish()
		return
	work.tick(work_state, agent_state, agents)
	var completion_tick: Dictionary = work.tick(work_state, agent_state, agents)
	if completion_tick.get("completions", []).size() != 1:
		_fail("resumed duration did not emit exactly one completion")
		_finish()
		return
	var receipt: Dictionary = completion_tick["completions"][0]
	if receipt.get("actor_person_id", "") != actor_id or receipt.get("panel_id", "") != definition["panel_id"]:
		_fail("completion receipt lost actor or panel provenance")
		_finish()
		return
	var consumed: Dictionary = work.consume_completion(work_state, receipt)
	if not consumed.get("accepted", false) or work.consume_completion(work_state, receipt).get("accepted", true):
		_fail("procedure-work completion was not one-use")
		_finish()
		return
	_ok("procedure work is arrival-bound, timed, interruptible, and one-use")
	_finish()


func _fail(message: String) -> void:
	_fails += 1
	print("FAIL: ", message)


func _ok(message: String) -> void:
	print("OK: ", message)


func _finish() -> void:
	print("=== facility_procedure_work_runtime_selftest done fails=%d ===" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
