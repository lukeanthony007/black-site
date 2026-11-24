extends Node
## Cross-domain autonomous queue priority, escalation, dispatch, and journal restart proof.

const JOURNAL_DIR := "user://generated_facility_operations_queue_selftest"
const CHILD_FLAG := "--operations-queue-child"
var _fails := 0

func _ready() -> void:
	print("=== generated_facility_operations_queue_selftest ===")
	if OS.get_cmdline_user_args().has(CHILD_FLAG): await _child()
	else: await _parent()
	print("=== generated_facility_operations_queue_selftest done fails=%d ===" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)

func _facility() -> Node:
	var node: Node = load("res://scenes/dev_generated_facility.tscn").instantiate()
	add_child(node)
	return node

func _setup_incidents(facility: Node) -> void:
	var roles: Array = facility.operation_graph.jobs.keys()
	for room_id in ["material_screening", "archive_accession", "quarantine"]:
		_check(facility.transfer_material(room_id, roles).get("accepted", false), "custody setup failed")
	_check(facility.declare_custody_incident("archive_fire_water").get("accepted", false), "custody incident failed")
	_check(facility.set_service_available("cooling", false).get("accepted", false), "cooling incident failed")

func _parent() -> void:
	var absolute := ProjectSettings.globalize_path(JOURNAL_DIR)
	if DirAccess.dir_exists_absolute(absolute): OS.execute("/bin/rm", PackedStringArray(["-rf", absolute]))
	var facility := _facility()
	for _frame in 4: await get_tree().process_frame
	_setup_incidents(facility)
	var first: Dictionary = facility.autonomous_operations_tick(false)
	_check(first["selected"].get("domain", "") == "custody", "custody life-safety hold did not outrank cooling")
	facility.autonomous_operations_tick(false)
	var dispatch: Dictionary = facility.autonomous_operations_tick(true)
	_check(dispatch["selected"].get("domain", "") == "custody" and dispatch["selected"].get("escalated", false), "overdue custody work was not escalated and selected")
	_check(dispatch["dispatch"].get("accepted", false), "autonomous custody dispatch failed")
	facility.tick_procedure_work()
	var cooling_wait: Dictionary = facility.autonomous_operations_tick(false)
	_check(cooling_wait["selected"].get("domain", "") == "infrastructure" and cooling_wait["selected"].get("escalated", false), "cooling did not age and escalate behind dispatched custody work")
	var forged: Dictionary = facility.export_scene_checkpoint()
	for entry_id in forged["owners"]["operations_queue"]["state"]["entries"]:
		var entry: Dictionary = forged["owners"]["operations_queue"]["state"]["entries"][entry_id]
		if entry["domain"] == "infrastructure":
			entry["status"] = "dispatched"
			entry["task_id"] = "forged-task"
			forged["owners"]["operations_queue"]["state"]["entries"][entry_id] = entry
	var rejected: Dictionary = facility.recover_scene_checkpoint(forged)
	_check(not rejected.get("accepted", true) and facility.operations_queue_state["clock"] == 4, "forged queue dispatch replaced live authority")
	var committed: Dictionary = facility.commit_scene_journal(JOURNAL_DIR)
	_check(committed.get("accepted", false), "operations queue checkpoint did not journal: %s" % committed.get("reason", ""))
	var output: Array = []
	var args := PackedStringArray(["--path", ProjectSettings.globalize_path("res://"), "--headless", "res://scenes/dev_generated_facility_operations_queue_selftest.tscn", "--", CHILD_FLAG])
	var code := OS.execute(OS.get_executable_path(), args, output, true)
	for line in output: print(line)
	_check(code == 0, "operations queue child failed: %d" % code)
	if _fails == 0: print("OK: autonomous cross-domain queue survived restart with age and escalation")

func _child() -> void:
	var facility := _facility()
	for _frame in 4: await get_tree().process_frame
	var recovered: Dictionary = facility.recover_scene_journal(JOURNAL_DIR)
	_check(recovered.get("accepted", false), "queue journal recovery failed: %s" % recovered.get("reason", ""))
	if not recovered.get("accepted", false): return
	_check(facility.operations_queue_state["clock"] == 4, "queue clock reset across restart")
	var cooling_entry: Dictionary = {}
	for entry in facility.operations_queue_state["entries"].values():
		if entry["domain"] == "infrastructure": cooling_entry = entry
	_check(cooling_entry.get("status", "") == "waiting" and cooling_entry.get("escalated", false), "waiting cooling escalation was lost")
	var custody_task: Dictionary = facility.procedure_work_state["tasks"].get("procedure-task-1", {})
	_check(custody_task.get("status", "") == "interrupted" and custody_task.get("remaining_ticks", -1) == 2, "dispatched custody work did not recover behind reconciliation")
	var next: Dictionary = facility.autonomous_operations_tick(true)
	_check(next["selected"].get("domain", "") == "infrastructure", "recovered arbiter did not select overdue cooling")
	_check(next["dispatch"].get("accepted", false), "recovered arbiter did not autonomously dispatch cooling")
	_check(facility.procedure_work_state["tasks"].size() == 2, "arbiter dispatched more or fewer than one additional task")
	_check(facility.resume_procedure_work("procedure-task-1").get("accepted", false), "custody reconciliation failed after queue restart")
	for _tick in 4:
		facility.tick_procedure_work()
	var committed_outcomes := 0
	for event in facility.operations_queue_state["history"]:
		if event.get("event", "") == "task_committed": committed_outcomes += 1
	_check(committed_outcomes == 2, "task completion did not close both queue dispatches directly")
	_check(facility.operations_queue_state["reservations"]["actors"].is_empty() and facility.operations_queue_state["reservations"]["stations"].is_empty(), "completion did not release queue resources")
	_check(facility.control_status_board.text.contains("OPS  WAIT 0  ESC 0  RESERVED 0"), "control board did not expose closed queue state")
	var second_commit: Dictionary = facility.commit_scene_journal(JOURNAL_DIR)
	_check(second_commit.get("accepted", false), "post-arbitration queue state did not journal")

func _check(value: bool, message: String) -> void:
	if not value:
		_fails += 1
		push_error("FAIL: %s" % message)
