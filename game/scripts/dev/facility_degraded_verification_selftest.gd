extends Node
## Degraded reconstitution proof: independent authorization after owner test evidence.

var _fails := 0


func _ready() -> void:
	print("=== facility_degraded_verification_selftest ===")
	var graph_script: Script = load("res://scripts/facility/facility_operation_graph.gd")
	var infrastructure_script: Script = load("res://scripts/facility/facility_infrastructure_runtime.gd")
	var staffing_script: Script = load("res://scripts/facility/facility_staffing_runtime.gd")
	if graph_script == null or infrastructure_script == null or staffing_script == null or not graph_script.can_instantiate() or not infrastructure_script.can_instantiate() or not staffing_script.can_instantiate():
		_fail("degraded-verification dependencies cannot instantiate")
		_finish()
		return
	var graph: RefCounted = graph_script.new()
	graph.configure_cyber_archives(7319)
	for service_id in ["cooling", "power", "communications"]:
		var controls: Array = graph.service_continuity_profiles[service_id].get("verification_controls", [])
		_check(controls.size() == 1 and controls[0].get("station", "") == "security_control" and controls[0].get("actor_job", "") == "security_officer" and controls[0].get("mode", "") == "hardwired_reconstitution_authority" and controls[0].get("required_evidence", "") == "passed_functional_test", "%s lacks exact degraded verification authority" % service_id)
	var mutated: RefCounted = graph_script.new()
	mutated.configure_cyber_archives(7319)
	mutated.service_continuity_profiles["cooling"].erase("verification_controls")
	_check((mutated.validate() as Array).has("service continuity profile cooling has no degraded independent verification control"), "graph accepted cooling without degraded independent verification")
	var infrastructure: RefCounted = infrastructure_script.new()
	var state: Dictionary = infrastructure.start_services(graph)
	var staffing: RefCounted = staffing_script.new()
	var roster: Dictionary = staffing.build_schedule(graph)
	var facilities_id: String = staffing.active_primary_staff_ids(roster, "facilities_engineer")[0]
	var security_id: String = staffing.active_primary_staff_ids(roster, "security_officer")[0]
	var owner := {"person_id": facilities_id, "roles": ["facilities_engineer"], "current_room": "plant"}
	var verifier := {"person_id": security_id, "roles": ["security_officer"], "current_room": "security_control"}
	var failure: Dictionary = infrastructure.declare_service_failure(graph, state, "cooling")
	infrastructure.advance_failure_response(graph, state, failure["failure_id"], "enter_controlled_shutdown", verifier, roster, staffing)
	infrastructure.advance_failure_response(graph, state, failure["failure_id"], "isolate_for_repair", owner, roster, staffing)
	var receipt: Dictionary = infrastructure.begin_recovery(graph, state, "cooling_failure", failure["failure_id"], owner, roster, staffing)
	infrastructure.record_remediation(state, receipt, owner, {"action": "repair_completed", "service": "cooling", "station": "plant"})
	infrastructure.record_service_test(state, receipt, owner, {"action": "functional_test_passed", "service": "cooling", "station": "plant"})
	var before_forgery: Dictionary = state.duplicate(true)
	var forged := owner.duplicate(true)
	forged["current_room"] = "security_control"
	var denied: Dictionary = infrastructure.verify_and_restore(graph, state, receipt, forged, roster, staffing)
	_check(not denied.get("accepted", true) and state == before_forgery, "repair actor or undeclared verifier restored cooling")
	var restored: Dictionary = infrastructure.verify_and_restore(graph, state, receipt, verifier, roster, staffing)
	_check(restored.get("accepted", false) and restored.get("control_mode", "") == "hardwired_reconstitution_authority" and restored.get("station", "") == "security_control" and restored.get("verified_by_job", "") == "security_officer" and infrastructure.service_phase(state, "cooling") == "normal", "declared independent degraded verifier did not restore tested cooling")
	_ok("degraded verifier authorizes only tested owner remediation")
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
	print("=== facility_degraded_verification_selftest done fails=%d ===" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
