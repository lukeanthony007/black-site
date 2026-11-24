extends Node
## Behavioral proof that generated procedure panels are physical, local, provenance-bound controls.

var _fails := 0


func _ready() -> void:
	print("=== facility_procedure_panel_selftest ===")
	var packed: PackedScene = load("res://scenes/dev_generated_facility.tscn")
	if packed == null:
		_fail("generated facility scene unavailable")
		_finish()
		return
	var facility: Node = packed.instantiate()
	facility.operator_run = false
	facility.physical_staff_near_distance = 0.0
	add_child(facility)
	for _frame in 8:
		await get_tree().process_frame
	var panels := facility.get_node_or_null("ProcedurePanels")
	if panels == null or panels.get_child_count() < 6:
		_fail("generated facility has no complete physical cooling panel chain")
		_finish()
		return
	var command_panel := _panel_for(panels, "cooling", "enter_controlled_shutdown")
	var isolate_panel := _panel_for(panels, "cooling", "isolate_for_repair")
	var begin_panel := _panel_for(panels, "cooling", "begin_repair")
	var repair_panel := _panel_for(panels, "cooling", "record_repair")
	var test_panel := _panel_for(panels, "cooling", "functional_test")
	var verify_panel := _panel_for(panels, "cooling", "verify_reconstitution")
	for panel in [command_panel, isolate_panel, begin_panel, repair_panel, test_panel, verify_panel]:
		if panel == null or not panel.has_method("interact"):
			_fail("generated cooling procedure panel is missing or non-interactive")
			_finish()
			return
	var failure: Dictionary = facility.set_service_available("cooling", false)
	if not failure.get("accepted", false):
		_fail("could not declare panel-test cooling failure")
		_finish()
		return
	if not bool(command_panel.get_meta("available", false)) or bool(isolate_panel.get_meta("available", false)):
		_fail("safe hold did not expose only the command-phase panel")
		_finish()
		return
	var player: Node = facility.get_node("Player")
	command_panel.interact(player)
	if command_panel.last_result.get("accepted", true) or facility.infrastructure_runtime.service_phase(facility.infrastructure_state, "cooling") != "safe_hold":
		_fail("remote command-panel interaction advanced cooling")
		_finish()
		return
	if not _move(facility, "staff_control") or not _move(facility, "cyber_ops"):
		_fail("inspection player could not reach command station through personnel policy")
		_finish()
		return
	command_panel.interact(player)
	if not command_panel.last_result.get("accepted", false) or facility.infrastructure_runtime.service_phase(facility.infrastructure_state, "cooling") != "safe_hold":
		_fail("local command panel did not queue nonzero work without premature phase advance")
		_finish()
		return
	var command_commit: Dictionary = _complete_panel_work(facility)
	if not command_commit.get("accepted", false) or facility.infrastructure_runtime.service_phase(facility.infrastructure_state, "cooling") != "controlled_shutdown":
		_fail("completed command work did not advance exactly one phase")
		_finish()
		return
	if bool(command_panel.get_meta("available", true)) or not bool(isolate_panel.get_meta("available", false)):
		_fail("accepted command did not hand panel availability to plant isolation")
		_finish()
		return
	command_panel.interact(player)
	if command_panel.last_result.get("accepted", true) or facility.infrastructure_runtime.service_phase(facility.infrastructure_state, "cooling") != "controlled_shutdown":
		_fail("wrong-phase panel replay advanced cooling")
		_finish()
		return
	if not _move(facility, "staff_control") or not _move(facility, "plant"):
		_fail("inspection player could not reach plant through personnel policy")
		_finish()
		return
	var facilities_staff: Array[String] = facility.staffing_runtime.active_staff_ids(facility.staffing_state, "facilities_engineer")
	for staff_id in facilities_staff:
		if not facility.dispatch_staff_agent(staff_id, "staff_control").get("accepted", false):
			_fail("could not dispatch facilities watch away from plant")
			_finish()
			return
	facility.tick_staff_agents()
	var facilities_arrived := false
	for _frame in 900:
		var all_at_control := true
		for staff_id in facilities_staff:
			var agent: Dictionary = facility.staff_agent_state["agents"].get(staff_id, {})
			if agent.get("current_room", "") != "staff_control" or not (agent.get("route", ["x"]) as Array).is_empty():
				all_at_control = false
				break
		if all_at_control:
			facilities_arrived = true
			break
		await get_tree().physics_frame
	if not facilities_arrived:
		_fail("facilities watch did not embody-arrive at staff_control with empty route within 900 physics frames")
		_finish()
		return
	if not bool(isolate_panel.get_meta("available", false)):
		_fail("dispatch-capable panel did not remain requestable with watch away")
		_finish()
		return
	isolate_panel.interact(player)
	if not isolate_panel.last_result.get("accepted", false) or isolate_panel.last_result.get("status", "") not in ["dispatched", "working"] or facility.infrastructure_runtime.service_phase(facility.infrastructure_state, "cooling") != "controlled_shutdown":
		_fail("panel did not dispatch remote watch without fabricating phase progress")
		_finish()
		return
	var facilities_actor: String = isolate_panel.last_result["actor_person_id"]
	isolate_panel.interact(player)
	if isolate_panel.last_result.get("accepted", true):
		_fail("duplicate panel work was admitted while dispatch was active")
		_finish()
		return
	var arrival_tick: Dictionary = facility.tick_procedure_work()
	if not arrival_tick["commits"].is_empty() or facility.infrastructure_runtime.service_phase(facility.infrastructure_state, "cooling") != "controlled_shutdown":
		_fail("actor arrival fabricated isolation completion")
		_finish()
		return
	if not _marker_at_room(facility.get_node("Staffing"), facilities_actor, "plant"):
		_fail("staff presentation did not follow scheduler arrival")
		_finish()
		return
	var isolation_commit: Dictionary = _complete_panel_work(facility)
	if not isolation_commit.get("accepted", false) or facility.infrastructure_runtime.service_phase(facility.infrastructure_state, "cooling") != "repair_pending":
		_fail("timed isolation work did not commit after arrival and duration")
		_finish()
		return
	for panel in [begin_panel, repair_panel, test_panel]:
		panel.interact(player)
		if not panel.last_result.get("accepted", false):
			_fail("plant panel rejected valid local action %s: %s" % [panel.get_meta("action", ""), panel.last_result.get("reason", "")])
			_finish()
			return
		if panel == repair_panel:
			var repair_task_id: String = panel.last_result["task_id"]
			var progress_tick: Dictionary = facility.tick_procedure_work()
			if not progress_tick["commits"].is_empty() or facility.infrastructure_runtime.service_phase(facility.infrastructure_state, "cooling") != "repair_pending":
				_fail("partial repair work advanced infrastructure")
				_finish()
				return
			if not facility.interrupt_procedure_work(repair_task_id, "security_pause").get("accepted", false):
				_fail("live repair work could not be interrupted")
				_finish()
				return
			if not facility.tick_procedure_work()["commits"].is_empty() or facility.infrastructure_runtime.service_phase(facility.infrastructure_state, "cooling") != "repair_pending":
				_fail("interrupted repair committed infrastructure")
				_finish()
				return
			if not facility.resume_procedure_work(repair_task_id).get("accepted", false):
				_fail("live repair work could not resume")
				_finish()
				return
		var plant_commit: Dictionary = _complete_panel_work(facility)
		if not plant_commit.get("accepted", false):
			_fail("plant work did not commit after duration: %s" % panel.get_meta("action", ""))
			_finish()
			return
		if panel == begin_panel and (bool(begin_panel.get_meta("available", true)) or not bool(repair_panel.get_meta("available", false))):
			_fail("repair receipt did not transfer availability from reservation to repair")
			_finish()
			return
	if facility.infrastructure_runtime.service_phase(facility.infrastructure_state, "cooling") != "reconstitution_pending":
		_fail("plant panel chain did not stop at reconstitution pending")
		_finish()
		return
	verify_panel.interact(player)
	if verify_panel.last_result.get("accepted", true):
		_fail("remote command verification restored cooling")
		_finish()
		return
	if not _move(facility, "staff_control") or not _move(facility, "cyber_ops"):
		_fail("inspection player could not return to command station")
		_finish()
		return
	verify_panel.interact(player)
	if not verify_panel.last_result.get("accepted", false) or facility.infrastructure_runtime.service_phase(facility.infrastructure_state, "cooling") != "reconstitution_pending":
		_fail("local command verification did not queue without premature restoration")
		_finish()
		return
	var verification_commit: Dictionary = _complete_panel_work(facility)
	if not verification_commit.get("accepted", false) or facility.infrastructure_runtime.service_phase(facility.infrastructure_state, "cooling") != "normal":
		_fail("completed command verification did not reconstitute cooling")
		_finish()
		return
	var log: Array = facility.get("procedure_panel_log")
	if log.size() != 6:
		_fail("panel chain did not produce exactly six accepted provenance records")
		_finish()
		return
	for record in log:
		if record.get("panel_id", "").is_empty() or record.get("station", "").is_empty() or record.get("initiator", "") != "inspection_player" or record.get("actor_person_id", "").is_empty():
			_fail("panel activation log lost physical or staffing provenance")
			_finish()
			return
	_ok("physical panels dispatch named agents and commit only after timed work")
	_finish()


func _complete_panel_work(facility: Node) -> Dictionary:
	for _tick in 16:
		var result: Dictionary = facility.tick_procedure_work()
		if not (result["failures"] as Array).is_empty():
			return result["failures"][0]["result"]
		if not (result["commits"] as Array).is_empty():
			return result["commits"][0]
	return {"accepted": false, "reason": "panel work did not complete within test bound"}


func _marker_at_room(group: Node, staff_id: String, room_id: String) -> bool:
	for marker in group.get_children():
		if marker.get_meta("staff_id", "") == staff_id:
			return marker.get_meta("current_room", "") == room_id
	return false


func _panel_for(group: Node, service_id: String, action: String) -> Node:
	var first_match: Node = null
	for panel in group.get_children():
		if panel.get_meta("service", "") == service_id and panel.get_meta("action", "") == action:
			if first_match == null:
				first_match = panel
			if panel.get_meta("control_mode", "") == "primary_control":
				return panel
	return first_match


func _move(facility: Node, destination: String) -> bool:
	return facility.request_personnel_transition(destination).get("accepted", false)


func _fail(message: String) -> void:
	_fails += 1
	print("FAIL: ", message)


func _ok(message: String) -> void:
	print("OK: ", message)


func _finish() -> void:
	print("=== facility_procedure_panel_selftest done fails=%d ===" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
