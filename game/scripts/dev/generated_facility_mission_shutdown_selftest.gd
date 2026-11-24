extends Node
## Mission shutdown projection, forgery rejection, and second-process journal proof.
const JOURNAL_DIR := "user://generated_facility_mission_shutdown_selftest"
const CHILD_FLAG := "--mission-shutdown-child"
var fails := 0
func _ready() -> void:
	var facility: Node = load("res://scenes/dev_generated_facility.tscn").instantiate()
	add_child(facility)
	for _frame in 4: await get_tree().process_frame
	if OS.get_cmdline_user_args().has(CHILD_FLAG):
		var recovered: Dictionary = facility.recover_scene_journal(JOURNAL_DIR)
		_check(recovered.get("accepted", false), "mission shutdown journal recovery failed")
		_check(facility.mission_state.get("continuity_shutdowns", []).is_empty() and facility.operations_queue_state["reactivation_receipts"].size() == 1, "reactivation authority was lost across restart")
		_check(not facility.infrastructure_state["services"]["cooling"] and facility.infrastructure_state["active_failures"].has("cooling"), "restart fabricated cooling restoration")
		_check(facility.control_status_board.text.contains("SHUT 0"), "recovered board retained cleared shutdown projection")
		_finish(); return
	var absolute := ProjectSettings.globalize_path(JOURNAL_DIR)
	if DirAccess.dir_exists_absolute(absolute): OS.execute("/bin/rm", PackedStringArray(["-rf", absolute]))
	_check(facility.set_service_available("cooling", false).get("accepted", false), "cooling incident setup failed")
	facility.autonomous_operations_tick(false)
	var entry: Dictionary = facility.operations_queue_state["entries"].values()[0]
	var job_id: String = entry["actor_job"]
	for staff_id in facility.staffing_state["assignments"][facility.staffing_state["active_shift"]][job_id]: facility.staffing_state["unavailable"][staff_id] = true
	for staff_id in facility.staffing_state["relief"][job_id]: facility.staffing_state["unavailable"][staff_id] = true
	for _tick in 12: facility.autonomous_operations_tick(false)
	entry = facility.operations_queue_state["entries"].values()[0]
	_check(entry["status"] == "mission_shutdown", "relief exhaustion did not command mission shutdown")
	_check(facility.operations_queue_state["continuity_decisions"].size() == 2, "shutdown did not preserve separate relief and command decisions")
	_check(facility.mission_state.get("continuity_shutdowns", []).size() == 1 and facility.mission_state["status"] == "blocked", "shutdown did not propagate into mission authority")
	_check(not facility.infrastructure_state["services"]["cooling"] and facility.infrastructure_state["active_failures"].has("cooling"), "mission shutdown fabricated cooling restoration")
	_check(facility.control_status_board.text.contains("SHUT 1"), "control board omitted mission shutdown")
	var forged: Dictionary = facility.export_scene_checkpoint()
	_check(forged.get("accepted", false), "live shutdown checkpoint export failed: %s" % forged.get("reason", ""))
	if not forged.get("accepted", false): _finish(); return
	forged["owners"]["mission"]["state"]["continuity_shutdowns"] = []
	var probe: Node = load("res://scenes/dev_generated_facility.tscn").instantiate()
	add_child(probe)
	for _frame in 4: await get_tree().process_frame
	_check(not probe.recover_scene_checkpoint(forged).get("accepted", true), "forged mission/queue shutdown disagreement replaced live authority")
	probe.queue_free()
	var entry_id: String = entry["entry_id"]
	_check(not facility.authorize_mission_reactivation(entry_id).get("accepted", true), "reactivation opened while response capacity remained uncovered")
	var relief_id: String = facility.staffing_state["relief"][entry["actor_job"]][0]
	facility.staffing_state["unavailable"].erase(relief_id)
	var mobilized: Dictionary = facility.staffing_runtime.mobilize_qualified_relief(facility.operation_graph, facility.staffing_state, entry["actor_job"])
	_check(mobilized.get("accepted", false), "replacement response capacity could not be mobilized")
	var rebuilt: Dictionary = facility.staff_agent_runtime.build_active_watch(facility.operation_graph, facility.staffing_state, facility.staffing_runtime)
	for staff_id in mobilized.get("mobilized_staff", []): facility.staff_agent_state["agents"][staff_id] = rebuilt["agents"][staff_id]
	facility.staffing_runtime.apply_mission_availability(facility.operation_graph, facility.staffing_state, facility.operation_runtime, facility.mission_state)
	var reactivated: Dictionary = facility.authorize_mission_reactivation(entry_id)
	_check(reactivated.get("accepted", false), "named security-control authority could not reopen response")
	_check(not facility.authorize_mission_reactivation(entry_id).get("accepted", true), "reactivation receipt replay was accepted")
	_check(facility.mission_state["continuity_shutdowns"].is_empty() and facility.operations_queue_state["entries"][entry_id]["status"] == "waiting", "reactivation did not reopen only the queue occurrence")
	_check(not facility.infrastructure_state["services"]["cooling"] and facility.infrastructure_state["active_failures"].has("cooling"), "reactivation fabricated cooling restoration")
	var committed: Dictionary = facility.commit_scene_journal(JOURNAL_DIR)
	if not committed.get("accepted", false): print("REACTIVATION_COMMIT_REJECTED ", committed)
	_check(committed.get("accepted", false), "mission shutdown did not commit to journal")
	var output: Array = []
	var args := PackedStringArray(["--path", ProjectSettings.globalize_path("res://"), "--headless", "res://scenes/dev_generated_facility_mission_shutdown_selftest.tscn", "--", CHILD_FLAG])
	var code := OS.execute(OS.get_executable_path(), args, output, true)
	if code != 0:
		for line in output: print(line)
	_check(code == 0, "mission shutdown child process failed")
	_finish()
func _finish() -> void:
	print("=== generated_facility_mission_shutdown_selftest done fails=%d ===" % fails)
	get_tree().quit(0 if fails == 0 else 1)
func _check(value: bool, message: String) -> void:
	if not value: fails += 1; push_error("FAIL: %s" % message)
