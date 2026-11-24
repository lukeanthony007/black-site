extends Node
## Behavioral proof for authoritative named staff location and policy-valid dispatch.

var _fails := 0


func _ready() -> void:
	print("=== facility_staff_agent_runtime_selftest ===")
	var graph_script: Script = load("res://scripts/facility/facility_operation_graph.gd")
	var staffing_script: Script = load("res://scripts/facility/facility_staffing_runtime.gd")
	var agent_script: Script = load("res://scripts/facility/facility_staff_agent_runtime.gd")
	for script in [graph_script, staffing_script, agent_script]:
		if script == null or not script.can_instantiate():
			_fail("staff-agent runtime dependency cannot instantiate")
			_finish()
			return
	var graph: RefCounted = graph_script.new()
	graph.configure_cyber_archives(7319)
	var staffing: RefCounted = staffing_script.new()
	var staffing_state: Dictionary = staffing.build_schedule(graph)
	var agents: RefCounted = agent_script.new()
	var state: Dictionary = agents.build_active_watch(graph, staffing_state, staffing)
	var facilities_ids: Array[String] = staffing.active_staff_ids(staffing_state, "facilities_engineer")
	if facilities_ids.is_empty():
		_fail("fixture has no active facilities watch")
		_finish()
		return
	var actor_id: String = facilities_ids[0]
	if not agents.is_at_room(state, actor_id, "plant"):
		_fail("active watch did not begin at its authoritative post")
		_finish()
		return
	var to_control: Dictionary = agents.dispatch(graph, state, actor_id, "staff_control")
	if not to_control.get("accepted", false) or agents.is_at_room(state, actor_id, "staff_control"):
		_fail("dispatch did not create travel without fabricating arrival")
		_finish()
		return
	var first_tick: Dictionary = agents.tick(state)
	if not agents.is_at_room(state, actor_id, "staff_control") or not (first_tick.get("arrivals", []) as Array).has(actor_id):
		_fail("policy route did not produce authoritative arrival")
		_finish()
		return
	var before_denial: Dictionary = state["agents"][actor_id].duplicate(true)
	var denied: Dictionary = agents.dispatch(graph, state, actor_id, "archive_stack")
	if denied.get("accepted", true) or state["agents"][actor_id] != before_denial:
		_fail("unauthorized archive dispatch mutated agent location or task")
		_finish()
		return
	var return_trip: Dictionary = agents.dispatch(graph, state, actor_id, "plant")
	if not return_trip.get("accepted", false) or agents.is_at_room(state, actor_id, "plant"):
		_fail("return dispatch fabricated plant presence")
		_finish()
		return
	agents.tick(state)
	if not agents.is_at_room(state, actor_id, "plant"):
		_fail("facilities actor did not arrive back at plant")
		_finish()
		return
	var replay_state: Dictionary = agents.build_active_watch(graph, staffing_state, staffing)
	if replay_state["agents"] != agents.build_active_watch(graph, staffing_state, staffing)["agents"]:
		_fail("same active watch produced nondeterministic agent locations")
		_finish()
		return
	_ok("named staff dispatch is policy-valid and arrival-authoritative")
	var mutual_aid_like: Dictionary = {
		"temporary_locations": {actor_id: "staff_control"},
		"cases": {},
	}
	var bind_result: Dictionary = agents.sync_mutual_aid_bindings(state, mutual_aid_like)
	var bound_agent: Dictionary = state["agents"][actor_id]
	if not bind_result.get("accepted", false) or not (bind_result.get("bound", []) as Array).has(actor_id):
		_fail("sync_mutual_aid_bindings did not report bound escort")
		_finish()
		return
	if bound_agent.get("current_room", "") != "staff_control" or not (bound_agent.get("route", ["x"]) as Array).is_empty() or bound_agent.get("destination", "") != "staff_control":
		_fail("bound escort did not mirror temporary location at staff_control")
		_finish()
		return
	if not agents.is_mutual_aid_bound(state, actor_id) or bound_agent.get("status", "") != "mutual_aid_bound" or not bool(bound_agent.get("mutual_aid_bound", false)):
		_fail("bound escort missing mutual_aid_bound authority")
		_finish()
		return
	var denied_while_bound: Dictionary = agents.dispatch(graph, state, actor_id, "plant")
	if denied_while_bound.get("accepted", true) or String(denied_while_bound.get("reason", "")).find("mutual-aid") < 0:
		_fail("dispatch accepted while mutual-aid bound")
		_finish()
		return
	if state["agents"][actor_id].get("current_room", "") != "staff_control" or not (state["agents"][actor_id].get("route", ["x"]) as Array).is_empty():
		_fail("denied bound dispatch mutated escort location or route")
		_finish()
		return
	var release_result: Dictionary = agents.sync_mutual_aid_bindings(state, {"temporary_locations": {}, "cases": {}})
	if not release_result.get("accepted", false) or not (release_result.get("released", []) as Array).has(actor_id) or agents.is_mutual_aid_bound(state, actor_id):
		_fail("clearing temporary_locations did not release mutual-aid binding")
		_finish()
		return
	if state["agents"][actor_id].get("status", "") != "arrived" or bool(state["agents"][actor_id].get("mutual_aid_bound", false)):
		_fail("released escort retained mutual-aid binding flags")
		_finish()
		return
	var post_release: Dictionary = agents.dispatch(graph, state, actor_id, "plant")
	if not post_release.get("accepted", false):
		_fail("dispatch after mutual-aid release was denied")
		_finish()
		return
	_ok("mutual-aid staff binding denies dispatch then releases cleanly")
	_finish()


func _fail(message: String) -> void:
	_fails += 1
	print("FAIL: ", message)


func _ok(message: String) -> void:
	print("OK: ", message)


func _finish() -> void:
	print("=== facility_staff_agent_runtime_selftest done fails=%d ===" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
