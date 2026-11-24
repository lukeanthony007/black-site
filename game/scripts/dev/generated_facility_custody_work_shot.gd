extends Node
## Rendered proof of named, timed archive-incident containment control.

const SHOT_PATH := "/tmp/blacksite_shots/generated_custody_work.png"
const PANEL_ID := "custody:contain_incident"


func _hide_laser_nodes(node: Node) -> void:
	if node.name.begins_with("Laser") and node is CanvasItem:
		(node as CanvasItem).visible = false
	elif node.name.begins_with("Laser") and node is Node3D:
		(node as Node3D).visible = false
	for child in node.get_children():
		_hide_laser_nodes(child)


func _ready() -> void:
	var packed: PackedScene = load("res://scenes/dev_generated_facility.tscn")
	var facility: Node = packed.instantiate()
	add_child(facility)
	for _frame in 8:
		await get_tree().process_frame
	var roles: Array = facility.operation_graph.jobs.keys()
	for room_id in ["material_screening", "archive_accession", "quarantine"]:
		if not facility.transfer_material(room_id, roles).get("accepted", false):
			push_error("custody-work shot setup transfer failed")
			get_tree().quit(1)
			return
	if not facility.declare_custody_incident("archive_fire_water").get("accepted", false):
		push_error("custody-work shot incident declaration failed")
		get_tree().quit(1)
		return
	var request: Dictionary = facility.call("_request_procedure_work", facility.procedure_panel_definitions[PANEL_ID], "archive-watch-controller")
	var panel_group: Node = facility.get_node("ProcedurePanels")
	var panel: Node = null
	for candidate in panel_group.get_children():
		if candidate.get_meta("panel_id", "") == PANEL_ID:
			panel = candidate
		else:
			candidate.visible = false
	var control_board := facility.get_node_or_null("ControlStatusBoard")
	if control_board != null:
		control_board.visible = false
	facility.player.visible = false
	var weapon: Node = facility.player.get_node_or_null("CameraPivot/Camera3D/Weapon")
	if weapon != null:
		weapon.set_physics_process(false)
		_hide_laser_nodes(weapon)
	if panel == null or not request.get("accepted", false) or panel.get_meta("work_status", "") != "working" or int(panel.get_meta("remaining_ticks", 0)) != 3:
		push_error("custody-work shot has false containment state")
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
		push_error("custody-work screenshot save failed: %s" % error_string(error))
		get_tree().quit(1)
		return
	print("CUSTODY_WORK_SHOT path=%s room=archive_processing incident=archive_fire_water actor_job=records_officer status=working remaining_ticks=3" % SHOT_PATH)
	get_tree().quit()
