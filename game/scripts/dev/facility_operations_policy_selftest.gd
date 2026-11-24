extends Node
var fails := 0
func _ready() -> void:
	var graph: RefCounted = load("res://scripts/facility/facility_operation_graph.gd").new()
	graph.configure_cyber_archives(7319)
	_check(graph.validate().is_empty(), "canonical operations graph is invalid: %s" % [graph.validate()])
	var policies: Variant = graph.get("operations_response_policies")
	_check(policies is Dictionary and policies.size() >= 5, "graph lacks operations response policies")
	if policies is Dictionary and not policies.is_empty():
		var mutated: RefCounted = load("res://scripts/facility/facility_operation_graph.gd").new()
		mutated.configure_cyber_archives(7319)
		mutated.operations_response_policies["cooling"]["retry_backoff_ticks"] = 0
		_check(not mutated.validate().is_empty(), "graph admitted zero retry backoff")
		var forged: RefCounted = load("res://scripts/facility/facility_operation_graph.gd").new()
		forged.configure_cyber_archives(7319)
		forged.operations_response_policies["cooling"]["reactivation_station"] = "archive_stack"
		_check(not forged.validate().is_empty(), "graph admitted reactivation authority at an undeclared station")
		var unsafe_aid: RefCounted = load("res://scripts/facility/facility_operation_graph.gd").new()
		unsafe_aid.configure_cyber_archives(7319)
		unsafe_aid.mutual_aid_policy["staging_room"] = "archive_stack"
		_check(not unsafe_aid.validate().is_empty(), "graph admitted mutual aid directly into protected archive storage")
		var weak_controls: RefCounted = load("res://scripts/facility/facility_operation_graph.gd").new()
		weak_controls.configure_cyber_archives(7319)
		weak_controls.facility_control_system_policy["minimum_cia_categorization"]["availability"] = "low"
		_check(not weak_controls.validate().is_empty(), "graph admitted mission-critical controls below Moderate availability")
		var omitted_controls: RefCounted = load("res://scripts/facility/facility_operation_graph.gd").new()
		omitted_controls.configure_cyber_archives(7319)
		omitted_controls.facility_control_system_policy["applies_to"].erase("access_control")
		_check(not omitted_controls.validate().is_empty(), "graph omitted access control from facility-control cybersecurity policy")
		var missing_local_recovery: RefCounted = load("res://scripts/facility/facility_operation_graph.gd").new()
		missing_local_recovery.configure_cyber_archives(7319)
		missing_local_recovery.service_continuity_profiles["power"]["recovery_controls"].pop_back()
		_check(not missing_local_recovery.validate().is_empty(), "graph admitted incomplete degraded power recovery controls")
		var forged_local_recovery: RefCounted = load("res://scripts/facility/facility_operation_graph.gd").new()
		forged_local_recovery.configure_cyber_archives(7319)
		forged_local_recovery.service_continuity_profiles["power"]["recovery_controls"][0]["equipment"] = ""
		forged_local_recovery.service_continuity_profiles["power"]["recovery_controls"][0]["mode"] = "primary_control"
		_check(not forged_local_recovery.validate().is_empty(), "graph admitted remote or unowned degraded power recovery control")
		var overstated_recovery: RefCounted = load("res://scripts/facility/facility_operation_graph.gd").new()
		overstated_recovery.configure_cyber_archives(7319)
		overstated_recovery.service_continuity_profiles.erase("environmental_monitoring")
		_check(not overstated_recovery.validate().is_empty(), "graph claimed executable environmental-monitoring recovery without lifecycle authority")
		var incomplete_rounds: RefCounted = load("res://scripts/facility/facility_operation_graph.gd").new()
		incomplete_rounds.configure_cyber_archives(7319)
		var broken_obligations: Array = incomplete_rounds.service_continuity_profiles["environmental_monitoring"]["degraded_obligations"].duplicate(true)
		var broken_round: Dictionary = broken_obligations[0]
		broken_round["room_assignments"] = [{"room": "compute_core", "actor_job": "systems_administrator"}, {"room": "security_control", "actor_job": "security_officer"}]
		broken_round["observations"] = ["temperature", "relative_humidity", "smoke_or_local_alarm"]
		broken_obligations[0] = broken_round
		var broken_profile: Dictionary = incomplete_rounds.service_continuity_profiles["environmental_monitoring"]
		broken_profile["degraded_obligations"] = broken_obligations
		incomplete_rounds.service_continuity_profiles["environmental_monitoring"] = broken_profile
		_check(not incomplete_rounds.validate().is_empty(), "graph admitted manual environmental rounds that omit protected archives and water-intrusion observation")
		var unsafe_round_deadline: RefCounted = load("res://scripts/facility/facility_operation_graph.gd").new()
		unsafe_round_deadline.configure_cyber_archives(7319)
		var unsafe_profile: Dictionary = unsafe_round_deadline.service_continuity_profiles["environmental_monitoring"].duplicate(true)
		unsafe_profile["degraded_obligations"][0]["max_round_ticks"] = 1
		unsafe_profile["degraded_obligations"][0]["escalation"]["action"] = "automatic_shutdown"
		unsafe_round_deadline.service_continuity_profiles["environmental_monitoring"] = unsafe_profile
		_check(not unsafe_round_deadline.validate().is_empty(), "graph admitted impossible environmental deadline or automatic unowned shutdown")
	print("=== facility_operations_policy_selftest done fails=%d ===" % fails)
	get_tree().quit(0 if fails == 0 else 1)
func _check(value: bool, message: String) -> void:
	if not value: fails += 1; push_error("FAIL: %s" % message)
