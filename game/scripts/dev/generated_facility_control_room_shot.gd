extends Node
## Rendered proof for generated control-room board placement and alarm legibility.

const SHOT_PATH := "/tmp/blacksite_shots/generated_control_room.png"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/blacksite_shots")
	var packed: PackedScene = load("res://scenes/dev_generated_facility.tscn")
	var facility: Node3D = packed.instantiate()
	add_child(facility)
	for _frame in 12:
		await get_tree().process_frame
	facility.exhaust_job_staffing("cyber_researcher")
	facility.set_service_available("cooling", false)
	facility.advance_mission()
	for _tick in 4:
		facility.autonomous_operations_tick(false)
	var board: Label3D = facility.get_node_or_null("ControlStatusBoard")
	var camera := get_viewport().get_camera_3d()
	if board == null or camera == null:
		push_error("control-room shot lacks board or camera")
		get_tree().quit(1)
		return
	if not board.text.contains("OPS  WAIT 1  ESC 1  RESERVED 0"):
		push_error("control-room shot lacks escalated operations queue projection")
		get_tree().quit(1)
		return
	var snapshot: Dictionary = board.get_meta("snapshot", {})
	var cooling_phase := ""
	for condition in snapshot.get("conditions", []):
		if condition.get("key", "") == "service:cooling":
			cooling_phase = condition.get("phase", "")
			facility.acknowledge_condition(condition["occurrence_id"], ["facilities_engineer"])
			break
	if cooling_phase != "safe_hold":
		push_error("control-room shot lacks canonical cooling safe-hold phase")
		get_tree().quit(1)
		return
	camera.global_position = board.global_position + Vector3(0.0, 0.15, 5.5)
	camera.look_at(board.global_position - Vector3(0.0, 0.9, 0.0), Vector3.UP)
	for _frame in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var screen_position: Vector2 = camera.unproject_position(board.global_position)
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var normalized := Vector2(screen_position.x / viewport_size.x, screen_position.y / viewport_size.y)
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(SHOT_PATH)
	if error != OK:
		push_error("control-room screenshot save failed: %s" % error_string(error))
		get_tree().quit(1)
		return
	print("CONTROL_ROOM_SHOT path=%s board_ndc=%s conditions=%d severity=%s" % [
		SHOT_PATH,
		normalized,
		board.get_meta("condition_count", -1),
		board.get_meta("severity", ""),
	])
	get_tree().quit()
