extends Node
## Cross-process proof for one epoch-coupled facility scene checkpoint.

const CHECKPOINT_PATH := "user://generated_facility_scene_checkpoint_selftest.json"
const CHILD_MARKER := "restart-child"
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
	await get_tree().process_frame
	await get_tree().process_frame
	return facility


func _run_parent() -> void:
	print("=== generated_facility_scene_checkpoint_selftest ===")
	var facility: Node = await _new_facility()
	if facility == null or facility.infrastructure_state.is_empty():
		_finish()
		return
	facility.set_service_available("cooling", false)
	facility.set_service_available("power", false)
	var record_request: Dictionary = {}
	for _step in 8:
		var plan: Dictionary = facility.compile_degraded_response_plan()
		var recommended: Dictionary = plan.get("recommended", {})
		if recommended.get("service", "") == "cooling" and recommended.get("action", "") == "record_repair":
			record_request = facility.call("_request_procedure_work", facility.procedure_panel_definitions[recommended["panel_id"]], "scheduled_watch")
			break
		if recommended.is_empty():
			break
		var request: Dictionary = facility.call("_request_procedure_work", facility.procedure_panel_definitions[recommended["panel_id"]], "scheduled_watch")
		var commit: Dictionary = _run_to_commit(facility)
		_check(request.get("accepted", false) and commit.get("accepted", false), "could not stage checkpoint cascade")
	if not record_request.get("accepted", false):
		_fail("checkpoint did not reach owner remediation work")
		_finish()
		return
	var progress: Dictionary = facility.tick_procedure_work()
	var task_id: String = record_request["task_id"]
	_check(facility.procedure_work_state["tasks"][task_id]["remaining_ticks"] == 2 and progress.get("commits", []).is_empty(), "checkpoint boundary lacks partial remediation progress")
	var traveling_staff := ""
	for staff_id in facility.staff_agent_state["agents"]:
		if staff_id == facility.procedure_work_state["tasks"][task_id]["actor_person_id"]:
			continue
		var job_id: String = facility.staff_agent_state["agents"][staff_id]["job_id"]
		for room_id in facility.operation_graph.rooms:
			if not (facility.operation_graph.rooms[room_id].get("access_roles", []) as Array).has(job_id):
				continue
			var dispatched: Dictionary = facility.dispatch_staff_agent(staff_id, room_id)
			if dispatched.get("accepted", false) and not dispatched.get("route", []).is_empty():
				traveling_staff = staff_id
				break
		if not traveling_staff.is_empty():
			break
	_check(not traveling_staff.is_empty(), "checkpoint fixture lacks an unrelated in-flight agent")
	if traveling_staff.is_empty():
		_finish()
		return
	var checkpoint: Dictionary = facility.export_scene_checkpoint()
	_check(checkpoint.get("accepted", false), "scene checkpoint export failed: %s" % checkpoint.get("reason", ""))
	if not checkpoint.get("accepted", false):
		_finish()
		return
	checkpoint["probe_task_id"] = task_id
	checkpoint["probe_traveling_staff"] = traveling_staff
	checkpoint["probe_agent_room"] = facility.staff_agent_state["agents"][traveling_staff]["current_room"]
	var before: String = JSON.stringify({
		"infrastructure": facility.infrastructure_state,
		"staffing": facility.staffing_state,
		"agents": facility.staff_agent_state,
		"work": facility.procedure_work_state,
		"receipts": facility.procedure_receipts,
	})
	var mixed_epoch: Dictionary = checkpoint.duplicate(true)
	mixed_epoch["owners"]["agents"]["epoch"] = int(mixed_epoch["epoch"]) + 1
	_check(not facility.recover_scene_checkpoint(mixed_epoch).get("accepted", true), "mixed owner epoch was admitted")
	_check(before == _live_signature(facility), "mixed-epoch rejection mutated live state")
	var forged_receipt: Dictionary = checkpoint.duplicate(true)
	var service_id: String = forged_receipt["owners"]["procedure_receipts"]["state"].keys()[0]
	forged_receipt["owners"]["procedure_receipts"]["state"][service_id]["receipt_id"] = "receipt-forged"
	_check(not facility.recover_scene_checkpoint(forged_receipt).get("accepted", true), "mixed receipt provenance was admitted")
	_check(before == _live_signature(facility), "receipt rejection mutated live state")
	var forged_plan: Dictionary = checkpoint.duplicate(true)
	forged_plan["owners"]["response_plan"]["signature"]["recommended_panel_id"] = "forged:panel"
	_check(not facility.recover_scene_checkpoint(forged_plan).get("accepted", true), "mixed response-plan identity was admitted")
	_check(before == _live_signature(facility), "plan rejection mutated live state")
	var forged_agent: Dictionary = checkpoint.duplicate(true)
	forged_agent["owners"]["agents"]["state"]["agents"][traveling_staff]["route"].append("nonexistent_room")
	forged_agent["owners"]["agents"]["state"]["agents"][traveling_staff]["destination"] = "nonexistent_room"
	_check(not facility.recover_scene_checkpoint(forged_agent).get("accepted", true), "invalid persisted agent route was sanitized instead of rejected")
	_check(before == _live_signature(facility), "agent rejection mutated live state")
	var forged_support: Dictionary = checkpoint.duplicate(true)
	forged_support["owners"]["procedure_work"]["snapshot"]["state"]["tasks"][task_id]["required_services"] = []
	_check(not facility.recover_scene_checkpoint(forged_support).get("accepted", true), "mixed work/panel support provenance was admitted")
	_check(before == _live_signature(facility), "work provenance rejection mutated live state")
	var wrong_generation: Dictionary = checkpoint.duplicate(true)
	wrong_generation["graph_fingerprint"] = "seed=forged"
	_check(not facility.recover_scene_checkpoint(wrong_generation).get("accepted", true), "wrong graph generation was admitted")
	var file := FileAccess.open(CHECKPOINT_PATH, FileAccess.WRITE)
	_check(file != null, "scene checkpoint file could not be created")
	if file != null:
		file.store_string(JSON.stringify(checkpoint))
		file.close()
	var output: Array = []
	var exit_code := OS.execute(OS.get_executable_path(), PackedStringArray([
		"--path", ProjectSettings.globalize_path("res://"), "--headless",
		"res://scenes/dev_generated_facility_scene_checkpoint_selftest.tscn",
		"--", CHILD_MARKER,
	]), output, true)
	var child_output := "\n".join(output)
	_check(exit_code == 0, "scene-checkpoint restart child failed with exit %d\n%s" % [exit_code, child_output])
	_check(child_output.contains("OK: epoch-coupled scene checkpoint resumed the cascade to normal"), "restart child emitted no continuation proof")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CHECKPOINT_PATH))
	_ok("mixed owner snapshots fail closed and a real restart preserves one operational epoch")
	_finish()


func _run_child() -> void:
	var file := FileAccess.open(CHECKPOINT_PATH, FileAccess.READ)
	if file == null:
		_fail("restart child could not read scene checkpoint")
		_finish()
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		_fail("restart child scene checkpoint is malformed")
		_finish()
		return
	var facility: Node = await _new_facility()
	var recovered: Dictionary = facility.recover_scene_checkpoint(parsed)
	_check(recovered.get("accepted", false), "restart child rejected valid scene checkpoint: %s" % recovered.get("reason", ""))
	if not recovered.get("accepted", false):
		_finish()
		return
	var task_id: String = parsed["probe_task_id"]
	var task: Dictionary = facility.procedure_work_state["tasks"][task_id]
	_check(task["status"] == "interrupted" and task["remaining_ticks"] == 2, "partial work was advanced or discarded across restart")
	_check(facility.infrastructure_runtime.service_phase(facility.infrastructure_state, "cooling") == "repair_pending", "cooling phase changed across restart")
	_check(facility.infrastructure_runtime.service_phase(facility.infrastructure_state, "power") == "ride_through", "secondary power phase changed across restart")
	var traveling_staff: String = parsed["probe_traveling_staff"]
	var recovered_agent: Dictionary = facility.staff_agent_state["agents"][traveling_staff]
	_check(recovered_agent["current_room"] == parsed["probe_agent_room"] and recovered_agent["route"].is_empty() and recovered_agent["status"] == "arrived", "agent location was lost or stale route authority survived restart")
	_check(not facility.recover_scene_checkpoint(parsed).get("accepted", true), "scene checkpoint replay was admitted")
	var resumed: Dictionary = facility.resume_procedure_work(task_id)
	var repair_commit: Dictionary = _run_to_commit(facility)
	_check(resumed.get("accepted", false) and repair_commit.get("accepted", false), "recovered remediation could not reconcile and commit")
	for _step in 16:
		if facility.infrastructure_state["active_failures"].is_empty():
			break
		var plan: Dictionary = facility.compile_degraded_response_plan()
		var recommended: Dictionary = plan.get("recommended", {})
		if recommended.is_empty():
			break
		var request: Dictionary = facility.call("_request_procedure_work", facility.procedure_panel_definitions[recommended["panel_id"]], "scheduled_watch")
		var commit: Dictionary = _run_to_commit(facility)
		_check(request.get("accepted", false) and commit.get("accepted", false), "restarted cascade could not commit planned work")
	_check(facility.infrastructure_state["active_failures"].is_empty(), "restarted cascade retained active failures")
	_check(facility.procedure_receipts.is_empty() and facility.infrastructure_state["active_receipts"].is_empty(), "restarted cascade retained recovery receipts")
	_check(facility.infrastructure_runtime.service_phase(facility.infrastructure_state, "cooling") == "normal" and facility.infrastructure_runtime.service_phase(facility.infrastructure_state, "power") == "normal", "restarted cascade did not restore both services")
	if _fails == 0:
		_ok("epoch-coupled scene checkpoint resumed the cascade to normal")
	_finish()


func _run_to_commit(facility: Node) -> Dictionary:
	for _tick in 12:
		var result: Dictionary = facility.tick_procedure_work()
		if not (result.get("failures", []) as Array).is_empty():
			return result["failures"][0]["result"]
		if not (result.get("commits", []) as Array).is_empty():
			return result["commits"][0]
	return {"accepted": false, "reason": "bounded work did not commit"}


func _live_signature(facility: Node) -> String:
	return JSON.stringify({
		"infrastructure": facility.infrastructure_state,
		"staffing": facility.staffing_state,
		"agents": facility.staff_agent_state,
		"work": facility.procedure_work_state,
		"receipts": facility.procedure_receipts,
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
	if OS.get_cmdline_user_args().has(CHILD_MARKER):
		get_tree().quit(0 if _fails == 0 else 1)
	else:
		print("=== generated_facility_scene_checkpoint_selftest done fails=%d ===" % _fails)
		get_tree().quit(0 if _fails == 0 else 1)
