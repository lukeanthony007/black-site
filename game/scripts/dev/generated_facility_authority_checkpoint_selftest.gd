extends Node
## Real journal restart with active archive incident, occupied interlock, and acknowledged control occurrence.

const JOURNAL_DIR := "user://generated_facility_authority_checkpoint_selftest"
const CHILD_MARKER := "authority-restart-child"
var _fails := 0


func _ready() -> void:
	if OS.get_cmdline_user_args().has(CHILD_MARKER):
		await _run_child()
	else:
		await _run_parent()


func _new_facility() -> Node:
	var packed: PackedScene = load("res://scenes/dev_generated_facility.tscn")
	if packed == null:
		_fail("generated facility scene could not load")
		return null
	var facility: Node = packed.instantiate()
	add_child(facility)
	for _frame in 4:
		await get_tree().process_frame
	return facility


func _run_parent() -> void:
	print("=== generated_facility_authority_checkpoint_selftest ===")
	var facility: Node = await _new_facility()
	if facility == null:
		_finish()
		return
	facility.scene_journal_runtime.clear_journal(JOURNAL_DIR)
	var all_roles: Array = facility.operation_graph.jobs.keys()
	for room_id in ["material_screening", "archive_accession", "quarantine"]:
		_check(facility.transfer_material(room_id, all_roles).get("accepted", false), "custody fixture could not reach %s" % room_id)
	_check(facility.declare_custody_incident("archive_fire_water").get("accepted", false), "custody incident did not become authoritative")
	var occurrence_id := ""
	for condition in facility.control_snapshot["conditions"]:
		if condition["kind"] == "custody":
			occurrence_id = condition["occurrence_id"]
			break
	_check(not occurrence_id.is_empty(), "control room did not project custody occurrence")
	_check(facility.acknowledge_condition(occurrence_id, ["records_officer"]).get("accepted", false), "custody occurrence was not acknowledged")
	var interlock_receipt: Dictionary = facility.personnel_security_runtime.begin_transition(facility.operation_graph, facility.personnel_state, "staff_control")
	_check(interlock_receipt.get("accepted", false), "personnel interlock fixture was not reserved")
	facility.call("_refresh_control_status_board")
	var checkpoint: Dictionary = facility.export_scene_checkpoint()
	_check(checkpoint.get("accepted", false), "authority checkpoint export failed: %s" % checkpoint.get("reason", ""))
	if not checkpoint.get("accepted", false):
		_finish()
		return
	var owners: Dictionary = checkpoint["owners"]
	for owner_id in ["custody", "personnel_security", "control_room"]:
		_check(owners.has(owner_id) and int(owners[owner_id]["epoch"]) == int(checkpoint["epoch"]), "authority owner lacks shared checkpoint epoch: %s" % owner_id)
	var before := _live_signature(facility)
	var forged_custody: Dictionary = checkpoint.duplicate(true)
	forged_custody["owners"]["custody"]["state"]["current_room"] = "archive_stack"
	_check(not facility.recover_scene_checkpoint(forged_custody).get("accepted", true), "custody state/history contradiction was admitted")
	_check(before == _live_signature(facility), "custody rejection mutated live authority")
	var forged_interlock: Dictionary = checkpoint.duplicate(true)
	forged_interlock["owners"]["personnel_security"]["runtime_state"]["interlock_occupancy"] = {}
	_check(not facility.recover_scene_checkpoint(forged_interlock).get("accepted", true), "personnel receipt without interlock occupancy was admitted")
	_check(before == _live_signature(facility), "interlock rejection mutated live authority")
	var forged_control: Dictionary = checkpoint.duplicate(true)
	for condition in forged_control["owners"]["control_room"]["snapshot"]["conditions"]:
		if condition["occurrence_id"] == occurrence_id:
			condition["acknowledged"] = false
	_check(not facility.recover_scene_checkpoint(forged_control).get("accepted", true), "control projection disagreeing with acknowledgement history was admitted")
	_check(before == _live_signature(facility), "control projection rejection mutated live authority")
	var committed: Dictionary = facility.scene_journal_runtime.commit_checkpoint(JOURNAL_DIR, checkpoint)
	_check(committed.get("accepted", false), "authority checkpoint did not commit to journal")
	var output: Array = []
	var exit_code := OS.execute(OS.get_executable_path(), PackedStringArray([
		"--path", ProjectSettings.globalize_path("res://"), "--headless",
		"res://scenes/dev_generated_facility_authority_checkpoint_selftest.tscn",
		"--", CHILD_MARKER, occurrence_id, interlock_receipt["receipt_id"],
	]), output, true)
	var child_output := "\n".join(output)
	_check(exit_code == 0, "authority restart child failed with exit %d\n%s" % [exit_code, child_output])
	_check(child_output.contains("OK: custody incident, interlock authority, and awareness survived one journal epoch"), "authority restart child emitted no success proof")
	facility.scene_journal_runtime.clear_journal(JOURNAL_DIR)
	if _fails == 0:
		_ok("custody, personnel security, and control awareness fail closed as one journal epoch")
	_finish()


func _run_child() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var marker_index := args.find(CHILD_MARKER)
	var occurrence_id: String = args[marker_index + 1] if marker_index >= 0 and marker_index + 1 < args.size() else ""
	var receipt_id: String = args[marker_index + 2] if marker_index >= 0 and marker_index + 2 < args.size() else ""
	var facility: Node = await _new_facility()
	var recovered: Dictionary = facility.recover_scene_journal(JOURNAL_DIR)
	_check(recovered.get("accepted", false), "journal rejected valid authority checkpoint: %s" % recovered.get("reason", ""))
	if not recovered.get("accepted", false):
		_finish()
		return
	_check(facility.custody_state["current_room"] == "quarantine" and facility.custody_state["active_incident"] == "archive_fire_water", "custody incident or location changed across restart")
	var blocked_transfer: Dictionary = facility.transfer_material("archive_processing", ["records_officer"])
	_check(not blocked_transfer.get("accepted", true), "active custody incident stopped blocking transfer after restart")
	_check(facility.personnel_state["current_room"] == "screened_entry" and facility.personnel_state["active_receipt"] == receipt_id, "personnel interlock receipt changed across restart")
	_check(facility.personnel_security_runtime.active_receipts.has(receipt_id) and facility.personnel_security_runtime.interlock_occupancy.size() == 1, "interlock runtime authority was not restored")
	var custody_condition: Dictionary = {}
	for condition in facility.control_snapshot["conditions"]:
		if condition["occurrence_id"] == occurrence_id:
			custody_condition = condition
			break
	_check(not custody_condition.is_empty() and custody_condition["acknowledged"], "control occurrence or acknowledgement was lost")
	var authoritative_receipt: Dictionary = facility.personnel_security_runtime.active_receipts.get(receipt_id, {})
	var transition: Dictionary = facility.personnel_security_runtime.complete_transition(facility.personnel_state, authoritative_receipt)
	var replay: Dictionary = facility.personnel_security_runtime.complete_transition(facility.personnel_state, authoritative_receipt)
	_check(transition.get("accepted", false) and facility.personnel_state["current_room"] == "staff_control", "recovered interlock could not commit once")
	_check(not replay.get("accepted", true), "recovered interlock receipt replay was admitted")
	var containment_request: Dictionary = facility._request_procedure_work(facility.procedure_panel_definitions["custody:contain_incident"], "authority-checkpoint-test")
	_check(containment_request.get("accepted", false), "recovered custody incident could not enter durable containment")
	for _tick in 4:
		facility.tick_procedure_work()
	_check(facility.custody_state["active_incident"].is_empty(), "durable containment did not resolve recovered incident")
	var disposition_request: Dictionary = facility._request_procedure_work(facility.procedure_panel_definitions["custody:record_quarantine_disposition"], "authority-checkpoint-test")
	_check(disposition_request.get("accepted", false), "recovered quarantine could not enter durable disposition")
	for _tick in 6:
		facility.tick_procedure_work()
	_check(facility.custody_state["quarantine_cleared"], "durable quarantine disposition did not commit")
	_check(facility.transfer_material("archive_processing", ["records_officer"]).get("accepted", false), "material could not resume processing after incident resolution")
	_check(facility.transfer_material("archive_stack", ["archive_custodian"]).get("accepted", false), "material could not reach archive stack after restart")
	_check(facility.custody_runtime.can_archive(facility.custody_state), "recovered custody chain did not finish authoritatively")
	facility.call("_refresh_control_status_board")
	var still_active := false
	for condition in facility.control_snapshot["conditions"]:
		if condition["occurrence_id"] == occurrence_id:
			still_active = true
	_check(not still_active and facility.control_console_state["acknowledgements"].size() == 1, "resolved occurrence stayed active or lost acknowledgement history")
	var next_commit: Dictionary = facility.commit_scene_journal(JOURNAL_DIR)
	_check(next_commit.get("accepted", false) and next_commit.get("epoch", 0) == 2, "resolved authority state did not commit as next epoch")
	if _fails == 0:
		_ok("custody incident, interlock authority, and awareness survived one journal epoch")
	_finish()


func _live_signature(facility: Node) -> String:
	return JSON.stringify({
		"custody": facility.custody_state,
		"personnel": facility.personnel_state,
		"occupancy": facility.personnel_security_runtime.interlock_occupancy,
		"receipts": facility.personnel_security_runtime.active_receipts,
		"console": facility.control_console_state,
		"snapshot": facility.control_snapshot,
	})


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _ok(message: String) -> void:
	print("OK: %s" % message)


func _fail(message: String) -> void:
	_fails += 1
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if not OS.get_cmdline_user_args().has(CHILD_MARKER):
		print("=== generated_facility_authority_checkpoint_selftest done fails=%d ===" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
