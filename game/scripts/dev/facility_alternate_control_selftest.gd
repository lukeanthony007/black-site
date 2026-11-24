extends Node
## Graph and authority proof for hardened degraded-service controls.

var _fails := 0


func _ready() -> void:
	print("=== facility_alternate_control_selftest ===")
	var graph_script: Script = load("res://scripts/facility/facility_operation_graph.gd")
	var infrastructure_script: Script = load("res://scripts/facility/facility_infrastructure_runtime.gd")
	var staffing_script: Script = load("res://scripts/facility/facility_staffing_runtime.gd")
	if graph_script == null or infrastructure_script == null or staffing_script == null or not graph_script.can_instantiate() or not infrastructure_script.can_instantiate() or not staffing_script.can_instantiate():
		_fail("alternate-control dependencies cannot instantiate")
		_finish()
		return
	var graph: RefCounted = graph_script.new()
	graph.configure_cyber_archives(7319)
	for service_id in ["cooling", "power", "communications"]:
		var transition: Dictionary = graph.service_continuity_profiles[service_id]["transitions"][0]
		var alternates: Array = transition.get("alternate_controls", [])
		_check(alternates.size() == 1 and alternates[0].get("station", "") == "security_control" and alternates[0].get("actor_job", "") == "security_officer" and alternates[0].get("mode", "") == "hardwired_emergency_control", "%s lacks declared hardened alternate" % service_id)
	var mutated: RefCounted = graph_script.new()
	mutated.configure_cyber_archives(7319)
	mutated.service_continuity_profiles["cooling"]["transitions"][0].erase("alternate_controls")
	_check((mutated.validate() as Array).has("service continuity profile cooling initial response has no degraded alternate control"), "graph accepted a critical response without fallback control")
	var infrastructure: RefCounted = infrastructure_script.new()
	var staffing: RefCounted = staffing_script.new()
	var roster: Dictionary = staffing.build_schedule(graph)
	var state: Dictionary = infrastructure.start_services(graph)
	var cooling_failure: Dictionary = infrastructure.declare_service_failure(graph, state, "cooling")
	var security_ids: Array[String] = staffing.active_primary_staff_ids(roster, "security_officer")
	var security_actor := {"person_id": security_ids[0], "roles": ["security_officer"], "current_room": "security_control"}
	var forged_actor := security_actor.duplicate(true)
	forged_actor["roles"] = ["duty_officer"]
	var before_forgery: Dictionary = state.duplicate(true)
	var forged: Dictionary = infrastructure.advance_failure_response(graph, state, cooling_failure["failure_id"], "enter_controlled_shutdown", forged_actor, roster, staffing)
	_check(not forged.get("accepted", true) and state == before_forgery, "undeclared alternate actor mutated cooling response")
	var alternate: Dictionary = infrastructure.advance_failure_response(graph, state, cooling_failure["failure_id"], "enter_controlled_shutdown", security_actor, roster, staffing)
	_check(alternate.get("accepted", false) and alternate.get("control_mode", "") == "hardwired_emergency_control" and alternate.get("station", "") == "security_control" and infrastructure.service_phase(state, "cooling") == "controlled_shutdown", "declared alternate control did not advance cooling")
	_ok("critical responses require and authorize exact degraded controls")
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
	print("=== facility_alternate_control_selftest done fails=%d ===" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
