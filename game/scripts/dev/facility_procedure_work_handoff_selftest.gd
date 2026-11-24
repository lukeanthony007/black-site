extends Node
## Proof that active procedure work crosses shift turnover by explicit one-use handoff.

var _fails := 0


func _ready() -> void:
	print("=== facility_procedure_work_handoff_selftest ===")
	var graph_script: Script = load("res://scripts/facility/facility_operation_graph.gd")
	var staffing_script: Script = load("res://scripts/facility/facility_staffing_runtime.gd")
	var agent_script: Script = load("res://scripts/facility/facility_staff_agent_runtime.gd")
	var work_script: Script = load("res://scripts/facility/facility_procedure_work_runtime.gd")
	for script in [graph_script, staffing_script, agent_script, work_script]:
		_check(script != null and script.can_instantiate(), "handoff dependency cannot instantiate")
	if _fails > 0:
		_finish()
		return
	var graph: RefCounted = graph_script.new()
	graph.configure_cyber_archives(7319)
	var staffing: RefCounted = staffing_script.new()
	var agents: RefCounted = agent_script.new()
	var work: RefCounted = work_script.new()
	var blocked_staffing_state: Dictionary = staffing.build_schedule(graph)
	var blocked_agent_state: Dictionary = agents.build_active_watch(graph, blocked_staffing_state, staffing)
	var blocked_work_state: Dictionary = work.start_scheduler()
	var blocked_definition := {
		"panel_id": "inspection:business_cycle_work",
		"service": "inspection",
		"action": "business_cycle_work",
		"station": "contained_lab",
		"actor_job": "cyber_researcher",
		"duration_ticks": 2,
	}
	var blocked_task: Dictionary = work.request_work(graph, blocked_work_state, blocked_definition, "inspection_player", blocked_staffing_state, staffing, blocked_agent_state, agents)
	var blocked_turnover: Dictionary = staffing.begin_shift_turnover(graph, blocked_staffing_state, "swing")
	var blocked_handoff: Dictionary = work.begin_shift_handoffs(blocked_work_state, blocked_turnover)
	var cancelled_turnover: Dictionary = staffing.cancel_shift_turnover(blocked_staffing_state, blocked_turnover, blocked_handoff.get("reason", "handoff unavailable"))
	_check(blocked_task.get("accepted", false) and not blocked_handoff.get("accepted", true), "business-cycle work incorrectly acquired an incoming continuous-watch handoff")
	_check(cancelled_turnover.get("accepted", false) and blocked_staffing_state["active_shift"] == "day" and blocked_staffing_state["pending_turnover"].is_empty() and blocked_staffing_state["turnover_cancellation_log"].size() == 1, "rejected work handoff did not cancel staffing turnover cleanly")
	var staffing_state: Dictionary = staffing.build_schedule(graph)
	var agent_state: Dictionary = agents.build_active_watch(graph, staffing_state, staffing)
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
	_check(requested.get("accepted", false), "repair task was not admitted")
	var task_id: String = requested.get("task_id", "")
	var outgoing_id: String = requested.get("actor_person_id", "")
	work.tick(work_state, agent_state, agents)
	_check(int(work_state["tasks"][task_id]["remaining_ticks"]) == 2, "pre-turnover progress was not recorded")
	var staffing_receipt: Dictionary = staffing.begin_shift_turnover(graph, staffing_state, "swing")
	_check(staffing_receipt.get("accepted", false), "staffing turnover receipt was not issued")
	var handoff: Dictionary = work.begin_shift_handoffs(work_state, staffing_receipt)
	_check(handoff.get("accepted", false) and handoff.get("receipts", []).size() == 1, "active work handoff was not prepared")
	var work_receipt: Dictionary = handoff.get("receipts", [{}])[0]
	var incoming_id: String = work_receipt.get("incoming_actor_person_id", "")
	_check(not incoming_id.is_empty() and incoming_id != outgoing_id, "handoff did not bind distinct incoming relief")
	_check(work_state["tasks"][task_id]["status"] == "handoff_pending", "task was not frozen for turnover")
	work.tick(work_state, agent_state, agents)
	_check(int(work_state["tasks"][task_id]["remaining_ticks"]) == 2, "turnover-pending work advanced")
	var pending_snapshot: Dictionary = work.export_snapshot(work_state)
	var pending_recovery: Dictionary = work.recover_snapshot(pending_snapshot)
	_check(pending_recovery.get("accepted", false) and pending_recovery["state"]["tasks"][task_id]["status"] == "interrupted" and int(pending_recovery["state"]["tasks"][task_id]["remaining_ticks"]) == 2 and pending_recovery["state"]["pending_handoffs"].is_empty(), "restart did not invalidate uncommitted staffing handoff authority")
	var forged: Dictionary = work_receipt.duplicate(true)
	forged["incoming_actor_person_id"] = outgoing_id
	_check(not work.complete_shift_handoff(graph, work_state, forged, agent_state, agents).get("accepted", true), "forged work handoff was accepted")
	_check(work_state["tasks"][task_id]["actor_person_id"] == outgoing_id, "forged handoff changed task ownership")
	var turnover: Dictionary = staffing.complete_shift_turnover(graph, staffing_state, staffing_receipt)
	_check(turnover.get("accepted", false), "staffing turnover did not commit")
	agent_state = agents.build_active_watch(graph, staffing_state, staffing)
	var accepted: Dictionary = work.complete_shift_handoff(graph, work_state, work_receipt, agent_state, agents)
	_check(accepted.get("accepted", false), "valid work handoff did not commit")
	_check(work_state["tasks"][task_id]["actor_person_id"] == incoming_id, "task authority did not move to incoming relief")
	_check(int(work_state["tasks"][task_id]["remaining_ticks"]) == 2, "handoff replayed or lost completed work")
	_check(work_state["tasks"][task_id]["status"] == "working", "incoming relief did not resume station-local work")
	_check(not work.complete_shift_handoff(graph, work_state, work_receipt, agent_state, agents).get("accepted", true), "work handoff receipt replay was accepted")
	var tick_one: Dictionary = work.tick(work_state, agent_state, agents)
	_check(tick_one["completions"].is_empty() and int(work_state["tasks"][task_id]["remaining_ticks"]) == 1, "incoming relief did not continue exact remaining duration")
	var tick_two: Dictionary = work.tick(work_state, agent_state, agents)
	_check(tick_two["completions"].size() == 1, "incoming relief did not complete handed-off work exactly once")
	_check(work_state["tasks"][task_id]["handoffs"].size() == 1, "task lost handoff provenance")
	_ok("active procedure work hands off across shifts without replaying completed ticks")
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
	print("=== facility_procedure_work_handoff_selftest done fails=%d ===" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
