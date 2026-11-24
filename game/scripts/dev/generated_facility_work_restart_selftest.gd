extends Node
## Live adapter proof that restored work is visible, frozen, and explicitly reconciled.

var _fails := 0


func _ready() -> void:
	print("=== generated_facility_work_restart_selftest ===")
	var packed: PackedScene = load("res://scenes/dev_generated_facility.tscn")
	if packed == null:
		_fail("generated facility scene unavailable")
		_finish()
		return
	var facility: Node = packed.instantiate()
	add_child(facility)
	for _frame in 8:
		await get_tree().process_frame
	facility.set_service_available("cooling", false)
	var definition: Dictionary = facility.get("procedure_panel_definitions")["cooling:enter_controlled_shutdown"]
	var requested: Dictionary = facility.call("_request_procedure_work", definition, "scheduled_watch")
	var task_id: String = requested.get("task_id", "")
	var snapshot: Dictionary = facility.export_procedure_work_snapshot()
	if not requested.get("accepted", false) or not snapshot.get("accepted", false):
		_fail("live procedure work was not snapshot-ready")
		_finish()
		return
	var corrupt: Dictionary = snapshot.duplicate(true)
	corrupt["state"]["active_panel_tasks"].erase("cooling:enter_controlled_shutdown")
	var before_corrupt: Dictionary = facility.get("procedure_work_state").duplicate(true)
	if facility.recover_procedure_work_snapshot(corrupt).get("accepted", true) or facility.get("procedure_work_state") != before_corrupt:
		_fail("live corrupt snapshot changed authoritative work")
		_finish()
		return
	var recovered: Dictionary = facility.recover_procedure_work_snapshot(snapshot)
	var task: Dictionary = facility.get("procedure_work_state")["tasks"].get(task_id, {})
	var panel := _panel_for(facility.get_node("ProcedurePanels"), "cooling", "enter_controlled_shutdown")
	if not recovered.get("accepted", false) or task.get("status", "") != "interrupted" or int(task.get("remaining_ticks", 0)) != 1:
		_fail("live restart did not recover interrupted exact-duration work")
		_finish()
		return
	if panel == null or panel.get_meta("work_status", "") != "interrupted" or int(panel.get_meta("remaining_ticks", 0)) != 1:
		_fail("physical panel did not project recovered interruption")
		_finish()
		return
	var frozen_tick: Dictionary = facility.tick_procedure_work()
	if not frozen_tick["commits"].is_empty() or facility.infrastructure_runtime.service_phase(facility.infrastructure_state, "cooling") != "safe_hold":
		_fail("live recovered work advanced without reconciliation")
		_finish()
		return
	if not facility.resume_procedure_work(task_id).get("accepted", false):
		_fail("live recovered work could not be explicitly resumed")
		_finish()
		return
	var commit_tick: Dictionary = facility.tick_procedure_work()
	if commit_tick["commits"].size() != 1 or facility.infrastructure_runtime.service_phase(facility.infrastructure_state, "cooling") != "controlled_shutdown":
		_fail("reconciled live work did not commit exactly once")
		_finish()
		return
	_ok("generated panels fail closed across work snapshot recovery")
	_finish()


func _panel_for(group: Node, service_id: String, action: String) -> Node:
	for panel in group.get_children():
		if panel.get_meta("service", "") == service_id and panel.get_meta("action", "") == action:
			return panel
	return null


func _ok(message: String) -> void:
	print("OK: %s" % message)


func _fail(message: String) -> void:
	_fails += 1
	push_error("FAIL: %s" % message)
	print("FAIL: %s" % message)


func _finish() -> void:
	print("=== generated_facility_work_restart_selftest done fails=%d ===" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
