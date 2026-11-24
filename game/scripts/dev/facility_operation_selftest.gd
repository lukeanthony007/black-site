extends Node
## Headless: validate the pure Cyber/Archives operational graph before geometry.
## Run: godot --path . --headless res://scenes/dev_facility_operation_selftest.tscn

var _fails: int = 0


func _ready() -> void:
	print("=== facility_operation_selftest ===")
	_test_default_cyber_archives_graph_is_operational()
	_test_archive_custody_bypass_is_rejected()
	_test_seeded_profiles_are_deterministic_and_variable()
	_test_failure_procedures_cover_critical_services()
	print("=== facility_operation_selftest done fails=%d ===" % _fails)
	await get_tree().process_frame
	get_tree().quit(0 if _fails == 0 else 1)


func _test_default_cyber_archives_graph_is_operational() -> void:
	var path := "res://scripts/facility/facility_operation_graph.gd"
	if not ResourceLoader.exists(path):
		_fail("FacilityOperationGraph production script is missing")
		return
	var graph_script: Script = load(path)
	if graph_script == null or not graph_script.can_instantiate():
		_fail("FacilityOperationGraph script cannot instantiate")
		return
	var graph: RefCounted = graph_script.new()
	if graph == null:
		_fail("FacilityOperationGraph script returned null")
		return
	graph.configure_cyber_archives(7319)
	var errors: Array[String] = graph.validate()
	if not errors.is_empty():
		_fail("default graph invalid: %s" % "; ".join(errors))
		return
	for room_id in ["screened_entry", "cyber_ops", "contained_lab", "compute_core", "archive_accession", "archive_stack", "plant"]:
		if not graph.has_room(room_id):
			_fail("default graph missing room %s" % room_id)
			return
	if not graph.has_job("records_officer") or not graph.has_job("facilities_engineer"):
		_fail("default graph missing mission-critical jobs")
		return
	_ok("default Cyber/Archives graph is operational")


func _test_archive_custody_bypass_is_rejected() -> void:
	var graph_script: Script = load("res://scripts/facility/facility_operation_graph.gd")
	var graph: RefCounted = graph_script.new()
	graph.configure_cyber_archives(7319)
	graph.remove_room("quarantine")
	graph.connect_rooms("archive_accession", "archive_processing", "material", true, false)
	var errors: Array[String] = graph.validate()
	var found := false
	for error in errors:
		if "quarantine" in error or "custody" in error:
			found = true
			break
	if not found:
		_fail("validator accepted material path that bypasses quarantine")
	else:
		_ok("archive custody bypass is rejected")


func _test_seeded_profiles_are_deterministic_and_variable() -> void:
	var graph_script: Script = load("res://scripts/facility/facility_operation_graph.gd")
	var first: RefCounted = graph_script.new()
	var replay: RefCounted = graph_script.new()
	var different: RefCounted = graph_script.new()
	first.configure_cyber_archives(7319)
	replay.configure_cyber_archives(7319)
	different.configure_cyber_archives(7320)
	if not first.has_method("generation_fingerprint"):
		_fail("graph exposes no deterministic generation fingerprint")
		return
	var first_fingerprint: String = first.generation_fingerprint()
	var replay_fingerprint: String = replay.generation_fingerprint()
	var different_fingerprint: String = different.generation_fingerprint()
	if first_fingerprint != replay_fingerprint:
		_fail("same seed produced different operational profiles")
	elif first_fingerprint == different_fingerprint:
		_fail("different seeds produced identical operational profiles")
	elif not different.validate().is_empty():
		_fail("different seeded profile is invalid")
	else:
		_ok("seeded profiles are deterministic and variable")


func _test_failure_procedures_cover_critical_services() -> void:
	var graph_script: Script = load("res://scripts/facility/facility_operation_graph.gd")
	var graph: RefCounted = graph_script.new()
	graph.configure_cyber_archives(7319)
	if not graph.has_method("has_failure_procedure"):
		_fail("graph exposes no degraded-day procedures")
		return
	for procedure_id in ["power_loss", "cooling_failure", "communications_loss", "cyber_incident", "archive_fire_water", "staffing_shortage"]:
		if not graph.has_failure_procedure(procedure_id):
			_fail("missing failure procedure %s" % procedure_id)
			return
	graph.remove_failure_procedure("power_loss")
	var errors: Array[String] = graph.validate()
	var found := false
	for error in errors:
		if "power" in error:
			found = true
			break
	if not found:
		_fail("validator accepted facility with no power-loss procedure")
		return
	var missing_profile: RefCounted = graph_script.new()
	missing_profile.configure_cyber_archives(7319)
	missing_profile.service_continuity_profiles.erase("cooling")
	var profile_errors: Array[String] = missing_profile.validate()
	if not profile_errors.any(func(error: String) -> bool: return "cooling" in error and "continuity profile" in error):
		_fail("validator accepted critical service with no staged continuity profile")
	else:
		_ok("failure procedures and staged continuity profiles cover critical services")


func _fail(msg: String) -> void:
	_fails += 1
	print("FAIL: ", msg)


func _ok(msg: String) -> void:
	print("OK: ", msg)
