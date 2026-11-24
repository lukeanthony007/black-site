extends Node
## Live restart proof: infrastructure mobilizes named relief; custody enters safe hold.
const JOURNAL_DIR := "user://generated_facility_continuity_action_selftest"
const CHILD_FLAG := "--continuity-action-child"
var fails := 0
func _ready() -> void:
	var facility: Node = load("res://scenes/dev_generated_facility.tscn").instantiate()
	add_child(facility)
	for _frame in 4: await get_tree().process_frame
	if OS.get_cmdline_user_args().has(CHILD_FLAG):
		var recovered: Dictionary = facility.recover_scene_journal(JOURNAL_DIR)
		if not recovered.get("accepted", false): print("CHILD_RECOVERY_REJECTED ", recovered)
		_check(recovered.get("accepted", false), "continuity journal did not recover in second process")
		_check(facility.operations_queue_state["continuity_decisions"].size() == 2, "continuity decisions were lost across restart")
		_finish(); return
	var roles: Array = facility.operation_graph.jobs.keys()
	for room_id in ["material_screening", "archive_accession", "quarantine"]:
		_check(facility.transfer_material(room_id, roles).get("accepted", false), "custody setup failed")
	_check(facility.declare_custody_incident("archive_fire_water").get("accepted", false), "custody incident failed")
	_check(facility.set_service_available("cooling", false).get("accepted", false), "cooling incident failed")
	facility.autonomous_operations_tick(false)
	var infrastructure_entry: Dictionary = {}
	for entry in facility.operations_queue_state["entries"].values():
		if entry["domain"] == "infrastructure": infrastructure_entry = entry
	var primary: Array[String] = facility.staffing_runtime.active_primary_staff_ids(facility.staffing_state, infrastructure_entry["actor_job"])
	for staff_id in primary: facility.staffing_state["unavailable"][staff_id] = true
	var action_count := 0
	for _tick in 12:
		var result: Dictionary = facility.autonomous_operations_tick(false)
		action_count += result["continuity_actions"].size()
	_check(action_count == 2, "both over-limit domains did not produce continuity decisions")
	var saw_hold := false
	var saw_mobilization := false
	for decision in facility.operations_queue_state["continuity_decisions"]:
		if decision["action"] == "mission_safe_hold": saw_hold = decision["accepted"] and decision["evidence"]["mode"] == "mission_safe_hold"
		if decision["action"] == "mobilize_qualified_relief": saw_mobilization = decision["accepted"] and not decision["evidence"]["mobilized_staff"].is_empty()
	_check(saw_hold, "custody continuity did not enter incident-bound safe hold")
	_check(saw_mobilization, "infrastructure continuity did not mobilize named qualified relief")
	var cooling_entry: Dictionary = {}
	var custody_entry: Dictionary = {}
	for entry in facility.operations_queue_state["entries"].values():
		if entry["domain"] == "infrastructure": cooling_entry = entry
		if entry["domain"] == "custody": custody_entry = entry
	_check(cooling_entry.get("status", "") == "waiting" and cooling_entry.get("reassignments", 0) == 1, "mobilized infrastructure occurrence did not receive a fresh retry window")
	_check(custody_entry.get("status", "") == "safe_hold", "custody occurrence remained dispatchable after safe hold")
	var forged: Dictionary = facility.export_scene_checkpoint()
	forged["owners"]["operations_queue"]["state"]["continuity_decisions"][0]["action"] = "forged_action"
	var probe: Node = load("res://scenes/dev_generated_facility.tscn").instantiate()
	add_child(probe)
	for _frame in 4: await get_tree().process_frame
	_check(not probe.recover_scene_checkpoint(forged).get("accepted", true), "forged continuity decision replaced fresh live authority")
	probe.queue_free()
	var absolute := ProjectSettings.globalize_path(JOURNAL_DIR)
	if DirAccess.dir_exists_absolute(absolute): OS.execute("/bin/rm", PackedStringArray(["-rf", absolute]))
	_check(facility.commit_scene_journal(JOURNAL_DIR).get("accepted", false), "continuity decisions did not pass composite journal validation")
	var output: Array = []
	var args := PackedStringArray(["--path", ProjectSettings.globalize_path("res://"), "--headless", "res://scenes/dev_generated_facility_continuity_action_selftest.tscn", "--", CHILD_FLAG])
	var child_code := OS.execute(OS.get_executable_path(), args, output, true)
	if child_code != 0:
		for line in output: print(line)
	_check(child_code == 0, "continuity journal child process failed")
	_finish()
func _finish() -> void:
	print("=== generated_facility_continuity_action_selftest done fails=%d ===" % fails)
	get_tree().quit(0 if fails == 0 else 1)
func _check(value: bool, message: String) -> void:
	if not value: fails += 1; push_error("FAIL: %s" % message)
