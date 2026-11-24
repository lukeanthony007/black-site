extends Node
## Rendered proof of a real generated security patrol crossing a policy boundary.

const SHOT_PATH := "/tmp/blacksite_shots/generated_facility_patrol.png"
const NAVIGATION_TIMEOUT_FRAMES := 1800
const GUARD_TIMEOUT_FRAMES := 600
const PATROL_EDGE_TIMEOUT_FRAMES := 7200


func _ready() -> void:
	var directory_error := DirAccess.make_dir_recursive_absolute("/tmp/blacksite_shots")
	if directory_error != OK:
		_fail("facility-patrol shot cannot create output directory: %s" % error_string(directory_error))
		return
	if FileAccess.file_exists(SHOT_PATH):
		var remove_error := DirAccess.remove_absolute(SHOT_PATH)
		if remove_error != OK:
			_fail("facility-patrol shot cannot replace output: %s" % error_string(remove_error))
			return

	var packed := load("res://scenes/dev_generated_facility.tscn") as PackedScene
	if packed == null:
		_fail("facility-patrol shot cannot load generated facility")
		return
	var facility := packed.instantiate() as Node3D
	if facility == null:
		_fail("facility-patrol shot cannot instantiate generated facility")
		return
	facility.set("operator_run", false)
	add_child(facility)

	var navigation: Node = null
	for _frame in NAVIGATION_TIMEOUT_FRAMES:
		navigation = facility.get("navigation_runtime") as Node
		if navigation != null:
			var navigation_error := String(navigation.get("error_message"))
			if not navigation_error.is_empty():
				_fail("facility-patrol shot navigation failed: %s" % navigation_error)
				return
			if bool(navigation.call("is_ready")):
				break
		await get_tree().process_frame
	if navigation == null or not bool(navigation.call("is_ready")):
		_fail("facility-patrol shot timed out waiting for navigation")
		return

	var generated_facility := facility.get("generated_facility") as Node3D
	if generated_facility == null:
		_fail("facility-patrol shot has no generated facility geometry")
		return
	var doors := generated_facility.get_node_or_null("Doors")
	if doors == null:
		_fail("facility-patrol shot has no generated policy doors")
		return
	var patrol_door: Node3D = null
	for candidate in doors.get_children():
		var from_room := String(candidate.get_meta("from_room", ""))
		var to_room := String(candidate.get_meta("to_room", ""))
		if (
			String(candidate.get_meta("flow", "")) == "personnel"
			and (
				(from_room == "staff_control" and to_room == "screened_entry")
				or (from_room == "screened_entry" and to_room == "staff_control")
			)
		):
			patrol_door = candidate as Node3D
			break
	if patrol_door == null:
		_fail("facility-patrol shot lacks the staff_control/screened_entry policy door")
		return

	var initial_guard_positions: Dictionary = {}
	var first_moving_guard: Node3D = null
	for _frame in GUARD_TIMEOUT_FRAMES:
		var guard_bodies: Dictionary = facility.get("physical_staff_bodies")
		var guard_agents: Dictionary = (facility.get("staff_agent_state") as Dictionary).get("agents", {})
		var guard_ids: Array = guard_bodies.keys()
		guard_ids.sort()
		for staff_id in guard_ids:
			var guard := guard_bodies[staff_id] as Node3D
			var agent: Dictionary = guard_agents.get(staff_id, {})
			if guard == null or String(agent.get("job_id", "")) != "security_officer":
				continue
			if not initial_guard_positions.has(staff_id):
				initial_guard_positions[staff_id] = guard.global_position
			elif (
				bool(guard.call("is_facility_moving"))
				and guard.global_position.distance_to(initial_guard_positions[staff_id]) > 0.15
			):
				first_moving_guard = guard
				break
		if first_moving_guard != null:
			break
		await get_tree().physics_frame
	if first_moving_guard == null:
		_fail("facility-patrol shot has no physical security guard beginning patrol movement")
		return

	var framed_guard: Node3D = null
	for _frame in PATROL_EDGE_TIMEOUT_FRAMES:
		var edge_bodies: Dictionary = facility.get("physical_staff_bodies")
		var edge_agents: Dictionary = (facility.get("staff_agent_state") as Dictionary).get("agents", {})
		var edge_guard_ids: Array = edge_bodies.keys()
		edge_guard_ids.sort()
		for staff_id in edge_guard_ids:
			var guard := edge_bodies[staff_id] as Node3D
			var agent: Dictionary = edge_agents.get(staff_id, {})
			if (
				guard == null
				or String(agent.get("job_id", "")) != "security_officer"
				or not bool(guard.call("is_facility_moving"))
			):
				continue
			var current_room := String(guard.get_meta("authoritative_room", ""))
			var target_room := String(guard.get_meta("facility_target_room", ""))
			if not (
				(current_room == "staff_control" and target_room == "screened_entry")
				or (current_room == "screened_entry" and target_room == "staff_control")
			):
				continue
			var planar_offset := guard.global_position - patrol_door.global_position
			planar_offset.y = 0.0
			if planar_offset.length() <= 1.8:
				framed_guard = guard
				break
		if framed_guard != null:
			break
		await get_tree().physics_frame
	if framed_guard == null:
		_fail("facility-patrol shot timed out waiting for a guard at the staff_control/screened_entry edge")
		return
	if not patrol_door.has_method("is_navigation_open") or not bool(patrol_door.call("is_navigation_open")):
		_fail("facility-patrol shot policy door is not open for the physical patrol")
		return

	facility.set_process(false)
	for body in (facility.get("physical_staff_bodies") as Dictionary).values():
		if is_instance_valid(body):
			(body as Node).set_physics_process(false)
	for clutter_name in [
		"MissionHUD",
		"TestingBanner",
		"Staffing",
		"ProcedurePanels",
		"ControlStatusBoard",
		"CustodyMaterial",
	]:
		var clutter := facility.get_node_or_null(clutter_name)
		if clutter is CanvasLayer:
			(clutter as CanvasLayer).visible = false
		elif clutter is CanvasItem:
			(clutter as CanvasItem).visible = false
		elif clutter is Node3D:
			(clutter as Node3D).visible = false
	var player := facility.get_node_or_null("Player") as Node3D
	if player != null:
		player.visible = false
		player.set_physics_process(false)

	var camera := get_viewport().get_camera_3d()
	var door_leaf := patrol_door.get_node_or_null("Marker") as Node3D
	if camera == null or door_leaf == null:
		_fail("facility-patrol shot lacks camera or opened door leaf")
		return
	var approach := framed_guard.global_position - patrol_door.global_position
	approach.y = 0.0
	if approach.length() < 0.1:
		_fail("facility-patrol shot cannot establish the guard side of the policy door")
		return
	approach = approach.normalized()
	var lateral := Vector3(-approach.z, 0.0, approach.x)
	var guard_center := framed_guard.global_position + Vector3.UP * 0.95
	var target := door_leaf.global_position.lerp(guard_center, 0.5)
	camera.fov = 72.0
	camera.global_position = patrol_door.global_position + approach * 3.2 + lateral * 1.2 + Vector3.UP * 0.45
	camera.look_at(target, Vector3.UP)
	for _frame in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if (
		camera.is_position_behind(door_leaf.global_position)
		or camera.is_position_behind(guard_center)
		or not camera.is_position_in_frustum(door_leaf.global_position)
		or not camera.is_position_in_frustum(guard_center)
	):
		_fail("facility-patrol shot camera does not frame both guard and opened policy door")
		return

	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		_fail("facility-patrol shot viewport produced no image")
		return
	var save_error := image.save_png(SHOT_PATH)
	if save_error != OK:
		_fail("facility-patrol screenshot save failed: %s" % error_string(save_error))
		return
	if not FileAccess.file_exists(SHOT_PATH) or FileAccess.get_file_as_bytes(SHOT_PATH).is_empty():
		_fail("facility-patrol screenshot output is unavailable or empty")
		return
	print(
		"FACILITY_PATROL_SHOT path=%s edge=staff_control/screened_entry guard=%s door=%s open=true"
		% [SHOT_PATH, framed_guard.name, patrol_door.name]
	)
	get_tree().quit()


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
