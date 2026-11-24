extends Node
## Real-process proof that the durable journal selects one committed cascade epoch.

const JOURNAL_DIR := "user://generated_facility_scene_journal_selftest"
const CHILD_MARKER := "journal-restart-child"
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
	print("=== generated_facility_scene_journal_selftest ===")
	var facility: Node = await _new_facility()
	if facility == null:
		_finish()
		return
	facility.scene_journal_runtime.clear_journal(JOURNAL_DIR)
	facility.set_service_available("cooling", false)
	facility.set_service_available("power", false)
	var record_request: Dictionary = {}
	for _step in 8:
		var recommended: Dictionary = facility.compile_degraded_response_plan().get("recommended", {})
		if recommended.get("action", "") == "record_repair" and recommended.get("service", "") == "cooling":
			record_request = facility.call("_request_procedure_work", facility.procedure_panel_definitions[recommended["panel_id"]], "scheduled_watch")
			break
		if recommended.is_empty():
			break
		var request: Dictionary = facility.call("_request_procedure_work", facility.procedure_panel_definitions[recommended["panel_id"]], "scheduled_watch")
		var commit: Dictionary = _run_to_commit(facility)
		_check(request.get("accepted", false) and commit.get("accepted", false), "could not stage journal cascade")
	if not record_request.get("accepted", false):
		_fail("journal fixture did not reach cooling remediation")
		_finish()
		return
	var task_id: String = record_request["task_id"]
	facility.tick_procedure_work()
	_check(facility.procedure_work_state["tasks"][task_id]["remaining_ticks"] == 2, "epoch one fixture has wrong work duration")
	var first: Dictionary = facility.commit_scene_journal(JOURNAL_DIR)
	_check(first.get("accepted", false) and first.get("epoch", 0) == 1, "journal epoch one did not commit")
	facility.tick_procedure_work()
	_check(facility.procedure_work_state["tasks"][task_id]["remaining_ticks"] == 1, "epoch two fixture has wrong work duration")
	var second: Dictionary = facility.commit_scene_journal(JOURNAL_DIR)
	_check(second.get("accepted", false) and second.get("epoch", 0) == 2, "journal epoch two did not commit")
	_check(not facility.scene_journal_runtime.load_committed(JOURNAL_DIR, 1).get("accepted", true), "journal allowed explicit rollback below committed head")
	var torn_path := ProjectSettings.globalize_path(JOURNAL_DIR).path_join("epoch-00000000000000000003.json")
	var torn := FileAccess.open(torn_path, FileAccess.WRITE)
	_check(torn != null, "could not create torn post-head record")
	if torn != null:
		torn.store_string("{\"journal_version\":\"facility-scene-journal/v1\",")
		torn.flush()
		torn.close()
	var output: Array = []
	var exit_code := OS.execute(OS.get_executable_path(), PackedStringArray([
		"--path", ProjectSettings.globalize_path("res://"), "--headless",
		"res://scenes/dev_generated_facility_scene_journal_selftest.tscn",
		"--", CHILD_MARKER, task_id,
	]), output, true)
	var child_output := "\n".join(output)
	_check(exit_code == 0, "journal restart child failed with exit %d\n%s" % [exit_code, child_output])
	_check(child_output.contains("OK: durable journal resumed committed epoch two through full restoration"), "journal child emitted no restoration proof")
	facility.scene_journal_runtime.clear_journal(JOURNAL_DIR)
	if _fails == 0:
		_ok("journal head excludes torn newer data and prevents stale rollback")
	_finish()


func _run_child() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var marker_index := args.find(CHILD_MARKER)
	var task_id := args[marker_index + 1] if marker_index >= 0 and marker_index + 1 < args.size() else ""
	var facility: Node = await _new_facility()
	var recovered: Dictionary = facility.recover_scene_journal(JOURNAL_DIR)
	_check(recovered.get("accepted", false) and recovered.get("journal_epoch", 0) == 2, "restart did not select committed journal epoch two")
	if not recovered.get("accepted", false) or task_id.is_empty():
		_finish()
		return
	var task: Dictionary = facility.procedure_work_state["tasks"][task_id]
	_check(task["status"] == "interrupted" and task["remaining_ticks"] == 1, "journal recovery advanced or rolled back remediation work")
	_check(facility.infrastructure_runtime.service_phase(facility.infrastructure_state, "cooling") == "repair_pending" and facility.infrastructure_runtime.service_phase(facility.infrastructure_state, "power") == "ride_through", "journal recovery mixed infrastructure phases")
	var resumed: Dictionary = facility.resume_procedure_work(task_id)
	var repair_commit: Dictionary = _run_to_commit(facility)
	_check(resumed.get("accepted", false) and repair_commit.get("accepted", false), "journal-restored remediation could not reconcile")
	for _step in 16:
		if facility.infrastructure_state["active_failures"].is_empty():
			break
		var recommended: Dictionary = facility.compile_degraded_response_plan().get("recommended", {})
		if recommended.is_empty():
			break
		var request: Dictionary = facility.call("_request_procedure_work", facility.procedure_panel_definitions[recommended["panel_id"]], "scheduled_watch")
		var commit: Dictionary = _run_to_commit(facility)
		_check(request.get("accepted", false) and commit.get("accepted", false), "journal-restored cascade stalled")
	_check(facility.infrastructure_state["active_failures"].is_empty(), "journal-restored cascade retained active failures")
	_check(facility.procedure_receipts.is_empty() and facility.infrastructure_state["active_receipts"].is_empty(), "journal-restored cascade retained receipts")
	_check(facility.infrastructure_runtime.service_phase(facility.infrastructure_state, "cooling") == "normal" and facility.infrastructure_runtime.service_phase(facility.infrastructure_state, "power") == "normal", "journal-restored services did not return to normal")
	if _fails == 0:
		_ok("durable journal resumed committed epoch two through full restoration")
	_finish()


func _run_to_commit(facility: Node) -> Dictionary:
	for _tick in 12:
		var result: Dictionary = facility.tick_procedure_work()
		if not (result.get("failures", []) as Array).is_empty():
			return result["failures"][0]["result"]
		if not (result.get("commits", []) as Array).is_empty():
			return result["commits"][0]
	return {"accepted": false, "reason": "bounded work did not commit"}


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
		print("=== generated_facility_scene_journal_selftest done fails=%d ===" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
