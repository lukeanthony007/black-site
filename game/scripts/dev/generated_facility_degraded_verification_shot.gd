extends Node
## Rendered proof of independent degraded reconstitution authority.

const SHOT_PATH := "/tmp/blacksite_shots/generated_degraded_verification.png"
const VERIFY_ID := "cooling:verify_reconstitution@security_control"


func _ready() -> void:
	var packed: PackedScene = load("res://scenes/dev_generated_facility.tscn")
	if packed == null:
		push_error("degraded-verification shot cannot load generated facility")
		get_tree().quit(1)
		return
	var facility: Node = packed.instantiate()
	add_child(facility)
	for _frame in 8:
		await get_tree().process_frame
	facility.set_service_available("cooling", false)
	facility.set_service_available("power", false)
	for _step in 8:
		if facility.infrastructure_runtime.service_phase(facility.infrastructure_state, "cooling") == "reconstitution_pending":
			break
		var plan: Dictionary = facility.compile_degraded_response_plan()
		var recommended: Dictionary = plan.get("recommended", {})
		if recommended.is_empty() or recommended.get("service", "") != "cooling":
			push_error("degraded-verification shot planner stalled before cooling evidence")
			get_tree().quit(1)
			return
		var request: Dictionary = facility.call("_request_procedure_work", facility.procedure_panel_definitions[recommended["panel_id"]], "scheduled_watch")
		var commit: Dictionary = _run_to_commit(facility)
		if not request.get("accepted", false) or not commit.get("accepted", false):
			push_error("degraded-verification shot setup work failed")
			get_tree().quit(1)
			return
	var plan: Dictionary = facility.compile_degraded_response_plan()
	if plan.get("recommended", {}).get("panel_id", "") != VERIFY_ID:
		push_error("degraded-verification shot did not select hardened verifier")
		get_tree().quit(1)
		return
	var request: Dictionary = facility.call("_request_procedure_work", facility.procedure_panel_definitions[VERIFY_ID], "scheduled_watch")
	var panel_group: Node = facility.get_node("ProcedurePanels")
	var panel := _panel_for_id(panel_group, VERIFY_ID)
	for other_panel in panel_group.get_children():
		if other_panel != panel:
			other_panel.visible = false
	var control_board := facility.get_node_or_null("ControlStatusBoard")
	if control_board != null:
		control_board.visible = false
	if panel == null or not request.get("accepted", false) or panel.get_meta("control_mode", "") != "hardwired_reconstitution_authority" or panel.get_meta("work_status", "") != "working" or int(panel.get_meta("remaining_ticks", 0)) != 1:
		push_error("degraded-verification shot has false verification state")
		get_tree().quit(1)
		return
	var camera := get_viewport().get_camera_3d()
	var target: Vector3 = panel.global_position + Vector3(0.0, 0.1, 0.0)
	camera.global_position = target + Vector3(0.0, 0.1, 2.6)
	camera.look_at(target, Vector3.UP)
	for _frame in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(SHOT_PATH)
	if error != OK:
		push_error("degraded-verification screenshot save failed: %s" % error_string(error))
		get_tree().quit(1)
		return
	print("DEGRADED_VERIFICATION_SHOT path=%s service=cooling phase=reconstitution_pending mode=hardwired_reconstitution_authority status=working remaining_ticks=1" % SHOT_PATH)
	get_tree().quit()


func _run_to_commit(facility: Node) -> Dictionary:
	for _tick in 12:
		var result: Dictionary = facility.tick_procedure_work()
		if not (result.get("failures", []) as Array).is_empty():
			return result["failures"][0]["result"]
		if not (result.get("commits", []) as Array).is_empty():
			return result["commits"][0]
	return {"accepted": false}


func _panel_for_id(group: Node, panel_id: String) -> Node:
	for panel in group.get_children():
		if panel.get_meta("panel_id", "") == panel_id:
			return panel
	return null
