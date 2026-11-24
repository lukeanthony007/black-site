extends Node
## Rendered proof of the graph-declared hardwired emergency control path.

const SHOT_PATH := "/tmp/blacksite_shots/generated_alternate_control.png"
const FALLBACK_ID := "cooling:enter_controlled_shutdown@security_control"


func _ready() -> void:
	var packed: PackedScene = load("res://scenes/dev_generated_facility.tscn")
	if packed == null:
		push_error("alternate-control shot cannot load generated facility")
		get_tree().quit(1)
		return
	var facility: Node = packed.instantiate()
	add_child(facility)
	for _frame in 8:
		await get_tree().process_frame
	facility.set_service_available("cooling", false)
	var primary: Dictionary = facility.procedure_panel_definitions["cooling:enter_controlled_shutdown"]
	var primary_request: Dictionary = facility.call("_request_procedure_work", primary, "scheduled_watch")
	facility.set_service_available("power", false)
	facility.tick_procedure_work()
	var fallback: Dictionary = facility.procedure_panel_definitions[FALLBACK_ID]
	var fallback_request: Dictionary = facility.call("_request_procedure_work", fallback, "scheduled_watch")
	var panel_group: Node = facility.get_node("ProcedurePanels")
	var panel := _panel_for_id(panel_group, FALLBACK_ID)
	for other_panel in panel_group.get_children():
		if other_panel != panel:
			other_panel.visible = false
	var control_board := facility.get_node_or_null("ControlStatusBoard")
	if control_board != null:
		control_board.visible = false
	if panel == null or not primary_request.get("accepted", false) or not fallback_request.get("accepted", false) or panel.get_meta("control_mode", "") != "hardwired_emergency_control" or panel.get_meta("work_status", "") != "working" or int(panel.get_meta("remaining_ticks", 0)) != 1:
		push_error("alternate-control shot has false hardwired work state")
		get_tree().quit(1)
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		push_error("alternate-control shot has no camera")
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
		push_error("alternate-control screenshot save failed: %s" % error_string(error))
		get_tree().quit(1)
		return
	print("ALTERNATE_CONTROL_SHOT path=%s station=security_control mode=hardwired_emergency_control status=working remaining_ticks=1" % SHOT_PATH)
	get_tree().quit()


func _panel_for_id(group: Node, panel_id: String) -> Node:
	for panel in group.get_children():
		if panel.get_meta("panel_id", "") == panel_id:
			return panel
	return null
