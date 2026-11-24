extends Node
## Rendered proof for mission-shutdown control-room projection.
const SHOT_PATH := "/tmp/blacksite_shots/generated_mission_shutdown.png"
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/blacksite_shots")
	var facility: Node3D = load("res://scenes/dev_generated_facility.tscn").instantiate()
	add_child(facility)
	for _frame in 12: await get_tree().process_frame
	facility.set_service_available("cooling", false)
	facility.autonomous_operations_tick(false)
	var entry: Dictionary = facility.operations_queue_state["entries"].values()[0]
	var job_id: String = entry["actor_job"]
	for staff_id in facility.staffing_state["assignments"][facility.staffing_state["active_shift"]][job_id]: facility.staffing_state["unavailable"][staff_id] = true
	for staff_id in facility.staffing_state["relief"][job_id]: facility.staffing_state["unavailable"][staff_id] = true
	for _tick in 12: facility.autonomous_operations_tick(false)
	var board: Label3D = facility.get_node_or_null("ControlStatusBoard")
	var camera := get_viewport().get_camera_3d()
	if board == null or camera == null or not board.text.contains("SHUT 1"):
		push_error("mission-shutdown shot lacks board, camera, or shutdown projection")
		get_tree().quit(1); return
	camera.global_position = board.global_position + Vector3(0.0, 0.15, 5.5)
	camera.look_at(board.global_position - Vector3(0.0, 0.9, 0.0), Vector3.UP)
	for _frame in 4: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(SHOT_PATH)
	if error != OK:
		push_error("mission-shutdown screenshot save failed: %s" % error_string(error)); get_tree().quit(1); return
	print("MISSION_SHUTDOWN_SHOT path=%s" % SHOT_PATH)
	get_tree().quit()
