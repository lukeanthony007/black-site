extends Node
## Live proof that a secondary utility loss suspends panel work before phase mutation.

var _fails := 0


func _ready() -> void:
	print("=== generated_facility_work_condition_selftest ===")
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
	facility.set_service_available("power", false)
	var tick_result: Dictionary = facility.tick_procedure_work()
	var task: Dictionary = facility.get("procedure_work_state")["tasks"].get(task_id, {})
	var panel := _panel_for(facility.get_node("ProcedurePanels"), "cooling", "enter_controlled_shutdown")
	if not requested.get("accepted", false) or tick_result.get("suspended", []).size() != 1 or not tick_result.get("commits", []).is_empty():
		_fail("secondary power loss did not suspend active cooling command")
		_finish()
		return
	if task.get("status", "") != "interrupted" or int(task.get("remaining_ticks", 0)) != 1 or task.get("interruptions", [])[-1].get("reason", "") != "required_service_unavailable:power":
		_fail("live suspension lost reason or remaining work")
		_finish()
		return
	if facility.infrastructure_runtime.service_phase(facility.infrastructure_state, "cooling") != "safe_hold" or facility.infrastructure_runtime.service_phase(facility.infrastructure_state, "power") != "ride_through":
		_fail("suspended work mutated either authoritative failure phase")
		_finish()
		return
	if panel == null or panel.get_meta("work_status", "") != "interrupted" or panel.get_meta("work_reason", "") != "required_service_unavailable:power":
		_fail("physical panel did not project secondary-condition suspension")
		_finish()
		return
	var resume: Dictionary = facility.resume_procedure_work(task_id)
	if resume.get("accepted", true) or resume.get("reason", "") != "required_service_unavailable:power":
		_fail("live work resumed while required power remained unavailable")
		_finish()
		return
	var fallback_id := "cooling:enter_controlled_shutdown@security_control"
	var response_plan: Dictionary = facility.compile_degraded_response_plan()
	if response_plan.get("recommended", {}).get("panel_id", "") != fallback_id:
		_fail("cascade planner did not select the oldest failure's available hardwired control")
		_finish()
		return
	var fallback_panel := _panel_for_id(facility.get_node("ProcedurePanels"), fallback_id)
	if not facility.procedure_panel_definitions.has(fallback_id) or fallback_panel == null or not bool(fallback_panel.get_meta("available", false)):
		_fail("declared cooling fallback was not generated or available")
		_finish()
		return
	var fallback_request: Dictionary = facility.call("_request_procedure_work", facility.procedure_panel_definitions[fallback_id], "scheduled_watch")
	var fallback_commit: Dictionary = _run_to_commit(facility)
	if not fallback_request.get("accepted", false) or fallback_commit.get("control_mode", "") != "hardwired_emergency_control" or not (fallback_commit.get("superseded_task_ids", []) as Array).has(task_id):
		_fail("hardwired cooling control did not supersede blocked primary work")
		_finish()
		return
	if facility.procedure_work_state["tasks"][task_id]["status"] != "superseded" or facility.infrastructure_runtime.service_phase(facility.infrastructure_state, "cooling") != "controlled_shutdown":
		_fail("fallback command left stale primary authority or wrong cooling phase")
		_finish()
		return
	var cooling_plan: Dictionary = facility.compile_degraded_response_plan()
	if cooling_plan.get("recommended", {}).get("panel_id", "") != "cooling:isolate_for_repair":
		_fail("cascade planner did not continue the older cooling response to isolation")
		_finish()
		return
	var cooling_isolation: Dictionary = facility.call("_request_procedure_work", facility.procedure_panel_definitions[cooling_plan["recommended"]["panel_id"]], "scheduled_watch")
	var cooling_isolated: Dictionary = _run_to_commit(facility)
	if not cooling_isolation.get("accepted", false) or not cooling_isolated.get("accepted", false) or facility.infrastructure_runtime.service_phase(facility.infrastructure_state, "cooling") != "repair_pending" or facility.infrastructure_runtime.service_phase(facility.infrastructure_state, "power") != "ride_through":
		_fail("ordered cascade did not isolate cooling before later power work")
		_finish()
		return
	var repair_plan: Dictionary = facility.compile_degraded_response_plan()
	if repair_plan.get("recommended", {}).get("panel_id", "") != "cooling:begin_repair":
		_fail("cascade planner did not retain older cooling ownership through repair")
		_finish()
		return
	var durable_snapshot: Dictionary = facility.export_procedure_work_snapshot()
	var durable_recovery: Dictionary = facility.procedure_work_runtime.recover_snapshot(durable_snapshot)
	if not durable_recovery.get("accepted", false) or durable_recovery["state"]["tasks"][task_id]["status"] != "superseded":
		_fail("superseded primary authority was not restart-durable")
		_finish()
		return
	var cascade_commits: Array[Dictionary] = []
	var reconstitution_commits: Array[Dictionary] = []
	for _step in 16:
		if facility.infrastructure_state["active_failures"].is_empty():
			break
		var plan: Dictionary = facility.compile_degraded_response_plan()
		var recommended: Dictionary = plan.get("recommended", {})
		if recommended.is_empty():
			_fail("cascade planner stalled before full reconstitution")
			_finish()
			return
		var request: Dictionary = facility.call("_request_procedure_work", facility.procedure_panel_definitions[recommended["panel_id"]], "scheduled_watch")
		var commit: Dictionary = _run_to_commit(facility)
		if not request.get("accepted", false) or not commit.get("accepted", false):
			_fail("planned repair/reconstitution work did not commit")
			_finish()
			return
		cascade_commits.append(commit)
		if recommended["action"] == "verify_reconstitution":
			reconstitution_commits.append(commit)
	if not facility.infrastructure_state["active_failures"].is_empty() or not bool(facility.infrastructure_state["services"]["cooling"]) or not bool(facility.infrastructure_state["services"]["power"]):
		_fail("ordered cascade did not restore both services")
		_finish()
		return
	var cooling_verification: Dictionary = {}
	var power_verification: Dictionary = {}
	var power_primary_response: bool = false
	for commit in cascade_commits:
		if commit.get("service", "") == "power" and commit.get("action", "") == "shed_noncritical_load" and commit.get("control_mode", "") == "primary_control":
			power_primary_response = true
	for commit in reconstitution_commits:
		if commit.get("service", "") == "cooling":
			cooling_verification = commit
		elif commit.get("service", "") == "power":
			power_verification = commit
	if not power_primary_response:
		_fail("planner did not return power response to its primary control after cooling restoration")
		_finish()
		return
	if cooling_verification.get("control_mode", "") != "hardwired_reconstitution_authority" or cooling_verification.get("verified_by_job", "") != "security_officer" or cooling_verification.get("repair_actor", "") == cooling_verification.get("verified_by", ""):
		_fail("cooling degraded verification collapsed evidence or actor separation")
		_finish()
		return
	if power_verification.get("control_mode", "") != "primary_reconstitution_authority" or power_verification.get("verified_by_job", "") != "duty_officer" or power_verification.get("repair_actor", "") == power_verification.get("verified_by", ""):
		_fail("power did not return through independent primary verification after cooling restoration")
		_finish()
		return
	_ok("secondary loss uses ordered controls and independent verification through full restoration")
	_finish()


func _panel_for_id(group: Node, panel_id: String) -> Node:
	for panel in group.get_children():
		if panel.get_meta("panel_id", "") == panel_id:
			return panel
	return null


func _run_to_commit(facility: Node) -> Dictionary:
	for _tick in 12:
		var result: Dictionary = facility.tick_procedure_work()
		if not (result.get("failures", []) as Array).is_empty():
			return result["failures"][0]["result"]
		if not (result.get("commits", []) as Array).is_empty():
			return result["commits"][0]
	return {"accepted": false, "reason": "bounded work did not commit"}


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
	print("=== generated_facility_work_condition_selftest done fails=%d ===" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
