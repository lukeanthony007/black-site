extends Node
## Headless: prove screened material custody and incident recovery.

var _fails: int = 0


func _ready() -> void:
	print("=== facility_custody_runtime_selftest ===")
	_test_custody_chain_rejects_bypass_and_role_misuse()
	_test_archive_incident_preserves_identity_through_recovery()
	print("=== facility_custody_runtime_selftest done fails=%d ===" % _fails)
	await get_tree().process_frame
	get_tree().quit(0 if _fails == 0 else 1)


func _test_custody_chain_rejects_bypass_and_role_misuse() -> void:
	var runtime_path := "res://scripts/facility/facility_custody_runtime.gd"
	if not ResourceLoader.exists(runtime_path):
		_fail("custody runtime production script is missing")
		return
	var graph_script: Script = load("res://scripts/facility/facility_operation_graph.gd")
	var runtime_script: Script = load(runtime_path)
	var graph: RefCounted = graph_script.new()
	var runtime: RefCounted = runtime_script.new()
	graph.configure_cyber_archives(7319)
	var state: Dictionary = runtime.receive_material("media-7319")
	var original_history: Array = (state["history"] as Array).duplicate(true)
	var bypass: Dictionary = runtime.transfer(graph, state, "archive_stack", _credentials(["archive_custodian"]))
	if bypass.get("accepted", true) or state["history"] != original_history:
		_fail("runtime admitted direct loading-to-storage bypass")
		return
	var wrong_role: Dictionary = runtime.transfer(graph, state, "material_screening", _credentials(["archive_custodian"]))
	if wrong_role.get("accepted", true):
		_fail("runtime admitted destination transition under wrong job role")
		return
	if not runtime.transfer(graph, state, "material_screening", _credentials(["security_officer"])).get("accepted", false):
		_fail("security officer could not accept material for screening")
		return
	if not runtime.transfer(graph, state, "archive_accession", _credentials(["accession_technician"])).get("accepted", false):
		_fail("screened material could not enter accession")
		return
	if not runtime.transfer(graph, state, "quarantine", _credentials(["accession_technician"])).get("accepted", false):
		_fail("accessioned material could not enter quarantine")
		return
	if runtime.transfer(graph, state, "archive_processing", _credentials(["records_officer"])).get("accepted", true):
		_fail("runtime released uncleared quarantine material")
		return
	if not runtime.clear_quarantine(state, _credentials(["accession_technician"])).get("accepted", false):
		_fail("quarantine owner could not clear material")
		return
	if not runtime.transfer(graph, state, "archive_processing", _credentials(["records_officer"])).get("accepted", false):
		_fail("cleared material could not enter records processing")
		return
	if not runtime.transfer(graph, state, "archive_stack", _credentials(["archive_custodian"])).get("accepted", false):
		_fail("processed material could not enter controlled storage")
		return
	if not runtime.can_archive(state):
		_fail("complete custody chain did not produce archivable material")
		return
	_ok("custody chain rejects bypass and role misuse")


func _test_archive_incident_preserves_identity_through_recovery() -> void:
	var graph_script: Script = load("res://scripts/facility/facility_operation_graph.gd")
	var runtime_script: Script = load("res://scripts/facility/facility_custody_runtime.gd")
	var graph: RefCounted = graph_script.new()
	var runtime: RefCounted = runtime_script.new()
	graph.configure_cyber_archives(7319)
	var state: Dictionary = runtime.receive_material("evidence-incident-7319")
	runtime.transfer(graph, state, "material_screening", _credentials(["security_officer"]))
	runtime.transfer(graph, state, "archive_accession", _credentials(["accession_technician"]))
	runtime.transfer(graph, state, "quarantine", _credentials(["accession_technician"]))
	var identity_before: String = state["custody_identity"]
	var history_before: int = state["history"].size()
	var incident: Dictionary = runtime.declare_incident(graph, state, "archive_fire_water")
	if not incident.get("accepted", false) or state["active_incident"] != "archive_fire_water":
		_fail("archive custody incident did not establish hold")
		return
	if runtime.clear_quarantine(state, _credentials(["accession_technician"])).get("accepted", true):
		_fail("quarantine cleared while custody incident remained active")
		return
	if runtime.resolve_incident(graph, state, _credentials(["archive_custodian"])).get("accepted", true):
		_fail("non-owner resolved archive incident")
		return
	if not runtime.resolve_incident(graph, state, _credentials(["records_officer"])).get("accepted", false):
		_fail("procedure owner could not resolve archive incident")
		return
	if state["custody_identity"] != identity_before or state["history"].size() <= history_before:
		_fail("incident recovery lost custody identity or history")
		return
	runtime.clear_quarantine(state, _credentials(["accession_technician"]))
	runtime.transfer(graph, state, "archive_processing", _credentials(["records_officer"]))
	runtime.transfer(graph, state, "archive_stack", _credentials(["archive_custodian"]))
	if not runtime.can_archive(state) or state["custody_identity"] != identity_before:
		_fail("recovered custody could not archive under original identity")
		return
	_ok("archive incident preserves custody identity through recovery")


func _credentials(roles: Array[String]) -> Dictionary:
	return {"roles": roles.duplicate()}


func _fail(msg: String) -> void:
	_fails += 1
	print("FAIL: ", msg)


func _ok(msg: String) -> void:
	print("OK: ", msg)
