extends Node
## Headless: personnel screening, interlocks, role access, and egress.

var _fails: int = 0


func _ready() -> void:
	print("=== facility_personnel_security_selftest ===")
	_test_screening_interlock_and_denial_non_authority()
	_test_role_clearance_and_emergency_egress()
	print("=== facility_personnel_security_selftest done fails=%d ===" % _fails)
	await get_tree().process_frame
	get_tree().quit(0 if _fails == 0 else 1)


func _test_screening_interlock_and_denial_non_authority() -> void:
	var runtime_path := "res://scripts/facility/facility_personnel_security_runtime.gd"
	if not ResourceLoader.exists(runtime_path):
		_fail("personnel security runtime production script is missing")
		return
	var graph_script: Script = load("res://scripts/facility/facility_operation_graph.gd")
	var runtime_script: Script = load(runtime_path)
	var graph: RefCounted = graph_script.new()
	var runtime: RefCounted = runtime_script.new()
	graph.configure_cyber_archives(7319)
	var alice: Dictionary = runtime.register_person("alice", 3, ["duty_officer"])
	var denied: Dictionary = runtime.begin_transition(graph, alice, "screened_entry")
	if denied.get("accepted", true) or alice["screened"] or alice["current_room"] != "perimeter":
		_fail("unscreened denial changed authorization or location")
		return
	if runtime.complete_screening(alice, {"roles": ["records_officer"]}).get("accepted", true):
		_fail("non-security role completed entry screening")
		return
	if not runtime.complete_screening(alice, {"roles": ["security_officer"]}).get("accepted", false):
		_fail("security officer could not complete screening")
		return
	var receipt: Dictionary = runtime.begin_transition(graph, alice, "screened_entry")
	if not receipt.get("accepted", false):
		_fail("screened person could not reserve entry interlock")
		return
	var bob: Dictionary = runtime.register_person("bob", 3, ["cyber_analyst"])
	runtime.complete_screening(bob, {"roles": ["security_officer"]})
	if runtime.begin_transition(graph, bob, "screened_entry").get("accepted", true):
		_fail("occupied interlock admitted a second person")
		return
	if not runtime.complete_transition(alice, receipt).get("accepted", false):
		_fail("reserved interlock did not complete")
		return
	if runtime.complete_transition(alice, receipt).get("accepted", true):
		_fail("completed interlock receipt replayed")
		return
	if alice["current_room"] != "screened_entry" or int(alice["clearance_tier"]) != 3:
		_fail("interlock completion corrupted credential state")
		return
	_ok("screening and interlock denial do not create authority")


func _test_role_clearance_and_emergency_egress() -> void:
	var graph_script: Script = load("res://scripts/facility/facility_operation_graph.gd")
	var runtime_script: Script = load("res://scripts/facility/facility_personnel_security_runtime.gd")
	var graph: RefCounted = graph_script.new()
	var runtime: RefCounted = runtime_script.new()
	graph.configure_cyber_archives(7319)
	var duty: Dictionary = runtime.register_person("duty", 3, ["duty_officer"])
	runtime.complete_screening(duty, {"roles": ["security_officer"]})
	if not _transition(runtime, graph, duty, "screened_entry") or not _transition(runtime, graph, duty, "staff_control") or not _transition(runtime, graph, duty, "cyber_ops"):
		_fail("authorized duty officer could not reach cyber operations")
		return
	var records: Dictionary = runtime.register_person("records", 5, ["records_officer"])
	runtime.complete_screening(records, {"roles": ["security_officer"]})
	_transition(runtime, graph, records, "screened_entry")
	_transition(runtime, graph, records, "staff_control")
	var denial_count: int = records["denials"].size()
	if runtime.begin_transition(graph, records, "cyber_ops").get("accepted", true):
		_fail("clearance tier bypassed missing room role")
		return
	if records["current_room"] != "staff_control" or records["denials"].size() != denial_count + 1:
		_fail("role denial failed closed or was not audited")
		return
	if runtime.begin_transition(graph, duty, "emergency_exit", false).get("accepted", true):
		_fail("emergency egress opened as ordinary circulation")
		return
	var egress: Dictionary = runtime.begin_transition(graph, duty, "emergency_exit", true)
	if not egress.get("accepted", false) or not runtime.complete_transition(duty, egress).get("accepted", false):
		_fail("declared emergency did not release egress")
		return
	if duty["current_room"] != "emergency_exit" or duty["screened"]:
		_fail("egress failed to clear inside screening state")
		return
	if runtime.begin_transition(graph, duty, "cyber_ops", true).get("accepted", true):
		_fail("emergency exit became ingress")
		return
	_ok("role clearance and emergency egress fail closed")


func _transition(runtime: RefCounted, graph: RefCounted, state: Dictionary, to_room: String) -> bool:
	var receipt: Dictionary = runtime.begin_transition(graph, state, to_room)
	return receipt.get("accepted", false) and runtime.complete_transition(state, receipt).get("accepted", false)


func _fail(msg: String) -> void:
	_fails += 1
	print("FAIL: ", msg)


func _ok(msg: String) -> void:
	print("OK: ", msg)
