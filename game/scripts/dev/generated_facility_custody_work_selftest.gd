extends Node
## Durable named-actor custody containment and quarantine disposition across journal restart.

const JOURNAL_DIR := "user://generated_facility_custody_work_selftest"
const CHILD_FLAG := "--custody-work-child"

var _fails := 0


func _ready() -> void:
	print("=== generated_facility_custody_work_selftest ===")
	if OS.get_cmdline_user_args().has(CHILD_FLAG):
		await _run_child()
	else:
		await _run_parent()
	print("=== generated_facility_custody_work_selftest done fails=%d ===" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _spawn_facility() -> Node:
	var packed: PackedScene = load("res://scenes/dev_generated_facility.tscn")
	var facility: Node = packed.instantiate()
	add_child(facility)
	return facility


func _all_roles(facility: Node) -> Array:
	return facility.operation_graph.jobs.keys()


func _request_panel(facility: Node, panel_id: String) -> Dictionary:
	return facility._request_procedure_work(facility.procedure_panel_definitions[panel_id], "custody-operations-controller")


func _drive_task(facility: Node, task_id: String, limit: int = 12) -> Dictionary:
	for _tick in limit:
		var result: Dictionary = facility.tick_procedure_work()
		for commit in result["commits"]:
			if commit.get("work_receipt_id", "") != "":
				var task: Dictionary = facility.procedure_work_state["tasks"][task_id]
				if task["status"] == "committed":
					return commit
	return {"accepted": false, "reason": "task did not commit before tick limit"}


func _run_parent() -> void:
	_remove_tree(JOURNAL_DIR)
	var facility := _spawn_facility()
	for _frame in 4:
		await get_tree().process_frame
	var quarantine_route := false
	for edge in facility.operation_graph.circulation_edges:
		if edge["flow"] == "personnel" and edge["from"] == "archive_accession" and edge["to"] == "quarantine":
			quarantine_route = true
	_check(quarantine_route, "accession staff have no personnel route to quarantine")
	for panel_id in ["custody:contain_incident", "custody:record_quarantine_disposition"]:
		_check(facility.procedure_panel_definitions.has(panel_id), "generated facility lacks custody work panel %s" % panel_id)
	for room_id in ["material_screening", "archive_accession", "quarantine"]:
		_check(facility.transfer_material(room_id, _all_roles(facility)).get("accepted", false), "custody setup failed at %s" % room_id)
	_check(facility.declare_custody_incident("archive_fire_water").get("accepted", false), "custody incident declaration failed")
	_check(not facility.resolve_custody_incident(["records_officer"]).get("accepted", true), "live custody incident still bypasses durable work")
	var plan: Dictionary = facility.compile_custody_response_plan()
	_check(plan.get("recommended", {}).get("panel_id", "") == "custody:contain_incident", "custody planner did not recommend containment")
	var requested: Dictionary = _request_panel(facility, "custody:contain_incident")
	_check(requested.get("accepted", false), "containment work request failed: %s" % requested.get("reason", ""))
	var task_id: String = requested.get("task_id", "")
	var first_tick: Dictionary = facility.tick_procedure_work()
	_check(first_tick["commits"].is_empty(), "containment committed before its duration elapsed")
	_check(facility.procedure_work_state["tasks"][task_id]["remaining_ticks"] == 2, "containment did not preserve two ticks at checkpoint")
	_check(not facility.transfer_material("archive_processing", _all_roles(facility)).get("accepted", true), "active custody incident stopped blocking transfer")
	var forged: Dictionary = facility.export_scene_checkpoint()
	_check(forged.get("accepted", false), "live custody work checkpoint could not export: %s" % forged.get("reason", ""))
	if not forged.get("accepted", false):
		return
	forged["owners"]["custody"]["state"]["active_incident"] = ""
	forged["owners"]["custody"]["state"]["history"].append({"event": "incident_resolved", "procedure": "archive_fire_water", "room": "quarantine", "sequence": forged["owners"]["custody"]["state"]["history"].size() + 1})
	var rejected: Dictionary = facility.recover_scene_checkpoint(forged)
	_check(not rejected.get("accepted", true) and facility.custody_state["active_incident"] == "archive_fire_water", "checkpoint admitted custody work without its incident")
	var committed: Dictionary = facility.commit_scene_journal(JOURNAL_DIR)
	_check(committed.get("accepted", false) and committed.get("epoch", 0) == 2, "mid-containment authority did not journal")
	var output: Array = []
	var executable := OS.get_executable_path()
	var args := PackedStringArray(["--path", ProjectSettings.globalize_path("res://"), "--headless", "res://scenes/dev_generated_facility_custody_work_selftest.tscn", "--", CHILD_FLAG])
	var child_code := OS.execute(executable, args, output, true)
	for line in output:
		print(line)
	_check(child_code == 0, "custody work child restart failed with exit %d" % child_code)
	if _fails == 0:
		print("OK: custody work restarted mid-containment and completed through disposition")


func _run_child() -> void:
	var facility := _spawn_facility()
	for _frame in 4:
		await get_tree().process_frame
	var recovered: Dictionary = facility.recover_scene_journal(JOURNAL_DIR)
	_check(recovered.get("accepted", false), "journal rejected custody work checkpoint: %s" % recovered.get("reason", ""))
	if not recovered.get("accepted", false):
		return
	var task_id := "procedure-task-1"
	var task: Dictionary = facility.procedure_work_state["tasks"].get(task_id, {})
	_check(task.get("service", "") == "custody" and task.get("action", "") == "contain_incident", "recovered wrong custody work identity")
	_check(task.get("status", "") == "interrupted" and task.get("remaining_ticks", -1) == 2, "custody work did not recover frozen at exact progress")
	_check(task.get("interruptions", [])[-1].get("reason", "") == "restart_reconciliation_required", "custody work lacks explicit restart barrier")
	_check(facility.custody_state["active_incident"] == "archive_fire_water", "custody incident vanished across work restart")
	_check(not facility.transfer_material("archive_processing", _all_roles(facility)).get("accepted", true), "restart bypassed custody hold")
	_check(facility.resume_procedure_work(task_id).get("accepted", false), "explicit containment reconciliation failed")
	var contained: Dictionary = _drive_task(facility, task_id)
	_check(contained.get("accepted", false), "containment work did not commit: %s" % contained.get("reason", ""))
	_check(facility.custody_state["active_incident"].is_empty(), "completed containment did not resolve exact incident")
	_check(not facility.clear_material_quarantine(["accession_technician"]).get("accepted", true), "quarantine disposition still has an immediate bypass")
	_check(not facility.transfer_material("archive_processing", _all_roles(facility)).get("accepted", true), "material left quarantine before disposition work")
	var plan: Dictionary = facility.compile_custody_response_plan()
	_check(plan.get("recommended", {}).get("panel_id", "") == "custody:record_quarantine_disposition", "planner did not advance to quarantine disposition")
	var disposition_request: Dictionary = _request_panel(facility, "custody:record_quarantine_disposition")
	_check(disposition_request.get("accepted", false), "disposition work request failed: %s" % disposition_request.get("reason", ""))
	var disposition_id: String = disposition_request.get("task_id", "")
	var disposition: Dictionary = _drive_task(facility, disposition_id)
	_check(disposition.get("accepted", false), "disposition work did not commit: %s" % disposition.get("reason", ""))
	_check(facility.custody_state["quarantine_cleared"], "completed disposition did not clear quarantine")
	_check(facility.transfer_material("archive_processing", ["records_officer"]).get("accepted", false), "material could not resume processing")
	_check(facility.transfer_material("archive_stack", _all_roles(facility)).get("accepted", false), "material could not complete canonical custody")
	_check(facility.custody_runtime.can_archive(facility.custody_state), "durable custody work did not restore archive eligibility")
	var next_commit: Dictionary = facility.commit_scene_journal(JOURNAL_DIR)
	_check(next_commit.get("accepted", false) and next_commit.get("epoch", 0) == 3, "resolved custody work did not commit next epoch")


func _remove_tree(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if DirAccess.dir_exists_absolute(absolute):
		OS.execute("/bin/rm", PackedStringArray(["-rf", absolute]))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fails += 1
		push_error("FAIL: %s" % message)
