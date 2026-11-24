extends Node
## Rendered proof that a secondary utility loss is visible on the physical command panel.

const SHOT_PATH := "/tmp/blacksite_shots/generated_work_suspension.png"


func _ready() -> void:
	var packed: PackedScene = load("res://scenes/dev_generated_facility.tscn")
	if packed == null:
		push_error("work-suspension shot cannot load generated facility")
		get_tree().quit(1)
		return
	var facility: Node = packed.instantiate()
	add_child(facility)
	for _frame in 8:
		await get_tree().process_frame
	facility.set_service_available("cooling", false)
	var definition: Dictionary = facility.procedure_panel_definitions["cooling:enter_controlled_shutdown"]
	var requested: Dictionary = facility.call("_request_procedure_work", definition, "scheduled_watch")
	facility.set_service_available("power", false)
	var tick_result: Dictionary = facility.tick_procedure_work()
	var panel_group: Node = facility.get_node("ProcedurePanels")
	var panel := _panel_for(panel_group, "cooling", "enter_controlled_shutdown")
	for other_panel in panel_group.get_children():
		if other_panel != panel:
			other_panel.visible = false
	var control_board := facility.get_node_or_null("ControlStatusBoard")
	if control_board != null:
		control_board.visible = false
	if panel == null or not requested.get("accepted", false) or tick_result.get("suspended", []).size() != 1 or panel.get_meta("work_status", "") != "interrupted" or panel.get_meta("work_reason", "") != "required_service_unavailable:power":
		push_error("work-suspension shot has false panel state")
		get_tree().quit(1)
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		push_error("work-suspension shot has no camera")
		get_tree().quit(1)
		return
	var target: Vector3 = panel.global_position + Vector3(0.0, 0.1, 0.0)
	camera.global_position = target + Vector3(0.0, 0.1, 2.6)
	camera.look_at(target, Vector3.UP)
	for _frame in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(SHOT_PATH)
	if error != OK:
		push_error("work-suspension screenshot save failed: %s" % error_string(error))
		get_tree().quit(1)
		return
	print("WORK_SUSPENSION_SHOT path=%s cooling=safe_hold power=ride_through status=interrupted remaining_ticks=1 reason=power" % SHOT_PATH)
	get_tree().quit()


func _panel_for(group: Node, service_id: String, action: String) -> Node:
	for panel in group.get_children():
		if panel.get_meta("service", "") == service_id and panel.get_meta("action", "") == action:
			return panel
	return null
