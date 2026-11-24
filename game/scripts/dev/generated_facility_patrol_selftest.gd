extends Node
## Headless integration proof for generated-facility physical security patrol.
## Run: godot --path game --headless res://scenes/dev_generated_facility_patrol_selftest.tscn

const TIME_LIMIT_MS := 20000
const GUARD_SCENE_PATH := "res://scenes/guard.tscn"

var _fails := 0
var _started_ms := 0


func _ready() -> void:
	print("=== generated_facility_patrol_selftest ===")
	_started_ms = Time.get_ticks_msec()
	await _run()
	_finish()


func _run() -> void:
	var packed: PackedScene = load("res://scenes/dev_generated_facility.tscn")
	if packed == null:
		_fail("generated facility scene could not load")
		return
	var facility: Node3D = packed.instantiate()
	facility.operator_run = false
	add_child(facility)

	# Keep the player clear of posts so only security embodiment stays forced.
	facility.player.process_mode = Node.PROCESS_MODE_DISABLED
	facility.player.global_position = Vector3(1000.0, 20.0, 1000.0)

	var security_ids: Array[String] = []
	var patrol_id := ""
	var patrol_guard: CharacterBody3D
	var patrol_origin_room := "security_control"
	var patrol_origin_position := Vector3.ZERO
	var next_room := ""
	var saw_dispatch := false
	var body_positions: Dictionary = {}

	# Await nav/bodies while catching the first automatic security_control→staff_control dispatch.
	for _frame in 720:
		if _timed_out():
			_fail("timed out waiting for navigation, embodiment, or automatic patrol dispatch")
			return
		await get_tree().physics_frame
		if facility.navigation_runtime == null or not facility.navigation_runtime.is_ready():
			continue
		security_ids = _active_security_ids(facility)
		if security_ids.size() < 2:
			continue
		var embodied := 0
		for staff_id in security_ids:
			if not facility.physical_staff_bodies.has(staff_id):
				continue
			var body: Node = facility.physical_staff_bodies[staff_id]
			if not is_instance_valid(body):
				continue
			embodied += 1
			if not body.is_in_group("guards"):
				_fail("security body %s is not in guards group" % staff_id)
				return
			if String(body.scene_file_path) != GUARD_SCENE_PATH:
				_fail("security body %s did not instantiate guard.tscn" % staff_id)
				return
			if _staffing_marker_present(facility, staff_id):
				_fail("embodied security %s retained a duplicate staffing marker" % staff_id)
				return
			var agent: Dictionary = facility.staff_agent_state["agents"][staff_id]
			if String(agent.get("current_room", "")) != patrol_origin_room:
				continue
			var route: Array = agent.get("route", [])
			var destination := String(agent.get("destination", ""))
			var route_room := String(facility.staff_agent_runtime.next_route_room(facility.staff_agent_state, staff_id))
			var prior_position: Vector3 = body_positions.get(staff_id, body.global_position)
			if route.is_empty() or (destination != "staff_control" and route_room != "staff_control"):
				body_positions[staff_id] = body.global_position
				continue
			if String(agent.get("current_room", "")) != patrol_origin_room:
				_fail("automatic patrol dispatch teleported the staff ledger")
				return
			var origin_room_node := _room_node(facility, patrol_origin_room)
			if (
				origin_room_node == null
				or body.global_position.distance_to(origin_room_node.global_position) > 3.0
				or body.global_position.distance_to(prior_position) > 1.0
			):
				_fail("automatic patrol dispatch teleported the physical body")
				return
			var before_room := String(agent.get("current_room", ""))
			var ticked: Dictionary = facility.tick_staff_agents()
			if String(facility.staff_agent_state["agents"][staff_id]["current_room"]) != before_room:
				_fail("ordinary tick advanced an embodied security ledger")
				return
			if (ticked.get("moved", []) as Array).has(staff_id):
				_fail("ordinary tick reported embodied security movement")
				return
			var matched_door := _personnel_door_between(facility, patrol_origin_room, route_room)
			if matched_door == null or not bool(matched_door.get("is_open")):
				_fail("patrol leg did not open the matching credentialed personnel door")
				return
			patrol_id = staff_id
			patrol_guard = body as CharacterBody3D
			patrol_origin_position = prior_position
			next_room = route_room
			saw_dispatch = true
			break
		if saw_dispatch:
			break
		if embodied < 2:
			continue

	if not saw_dispatch:
		_fail("automatic security_control→staff_control patrol dispatch never appeared")
		return
	if security_ids.size() < 2:
		_fail("active watch did not embody at least two security officers")
		return

	var arrived := false
	for _frame in 900:
		if _timed_out():
			_fail("timed out waiting for physical patrol room commit")
			return
		await get_tree().physics_frame
		if String(facility.staff_agent_state["agents"][patrol_id].get("current_room", "")) != patrol_origin_room:
			arrived = true
			break
	if not arrived:
		_fail("authoritative patrol room never committed after physical travel")
		return
	var committed_room := String(facility.staff_agent_state["agents"][patrol_id].get("current_room", ""))
	if committed_room != next_room:
		_fail("patrol committed unexpected room %s (expected %s)" % [committed_room, next_room])
		return
	if patrol_guard.global_position.distance_to(patrol_origin_position) < 1.0:
		_fail("authoritative room committed without measurable body displacement")
		return
	if _staffing_marker_present(facility, patrol_id):
		_fail("arrived security retained a duplicate staffing marker")
		return
	_ok("automatic security_control→staff_control patrol is embodied, non-teleporting, and arrival-authoritative")

	# Unauthorized visible intruder: CHALLENGE then CONTAIN, never hostility.
	facility.personnel_state["current_room"] = committed_room
	facility.personnel_state["clearance_tier"] = 0
	facility.personnel_state["roles"] = []
	facility.personnel_state["denials"] = []
	facility.player.process_mode = Node.PROCESS_MODE_INHERIT
	_place_player_in_guard_sight(facility.player, patrol_guard)
	var challenged := false
	for _frame in 300:
		if _timed_out():
			_fail("timed out waiting for CHALLENGE")
			return
		_place_player_in_guard_sight(facility.player, patrol_guard)
		await get_tree().physics_frame
		if int(patrol_guard.call("get_facility_response")) == FacilityIntrusionPolicy.Response.CHALLENGE:
			challenged = true
			break
	if not challenged:
		_fail("unauthorized visible player never produced CHALLENGE")
		return
	if bool(AlertPhase.player_hostile):
		_fail("CHALLENGE incorrectly marked the player hostile")
		return
	var contained := false
	for _frame in 360:
		if _timed_out():
			_fail("timed out waiting for CONTAIN")
			return
		_place_player_in_guard_sight(facility.player, patrol_guard)
		await get_tree().physics_frame
		if int(patrol_guard.call("get_facility_response")) == FacilityIntrusionPolicy.Response.CONTAIN:
			contained = true
			break
	if not contained:
		_fail("unresolved CHALLENGE never escalated to CONTAIN")
		return
	if bool(AlertPhase.player_hostile):
		_fail("CONTAIN incorrectly authorized combat hostility")
		return
	_ok("unauthorized presence challenges then contains without hostility")

	AlertPhase.mark_player_hostile()
	var engaged := false
	for _frame in 180:
		if _timed_out():
			_fail("timed out waiting for ENGAGE")
			return
		_place_player_in_guard_sight(facility.player, patrol_guard)
		await get_tree().physics_frame
		if int(patrol_guard.call("get_facility_response")) == FacilityIntrusionPolicy.Response.ENGAGE:
			engaged = true
			break
	if not engaged:
		_fail("hostile act never produced ENGAGE")
		return
	_ok("hostile act engages")

	# Loud world noise near a second guard drives SEARCH navigation and motion.
	facility.player.process_mode = Node.PROCESS_MODE_DISABLED
	facility.player.global_position = Vector3(1000.0, 20.0, 1000.0)
	var noise_id := ""
	for staff_id in security_ids:
		if staff_id != patrol_id:
			noise_id = staff_id
			break
	var noise_guard: CharacterBody3D = facility.physical_staff_bodies[noise_id]
	if not is_instance_valid(noise_guard):
		_fail("second security body left the tree before noise proof")
		return
	AlertPhase.reset()
	for _frame in 240:
		if _timed_out():
			_fail("timed out waiting for second guard to leave CHASE after alert reset")
			return
		await get_tree().physics_frame
		if int(noise_guard.state) != int(noise_guard.State.CHASE):
			break
	if int(noise_guard.state) == int(noise_guard.State.CHASE):
		_fail("second guard remained in CHASE after alert reset")
		return

	var noise_origin := noise_guard.global_position
	var noise_room_id := String(facility.staff_agent_state["agents"][noise_id].get("current_room", ""))
	var noise_room := _room_node(facility, noise_room_id)
	if noise_room == null:
		_fail("second guard room node missing")
		return
	var noise_target := noise_room.global_position + Vector3(2.0, 0.1, 2.0)
	NoiseBus.emit_noise(noise_target, 1.0, null)
	var searching := false
	for _frame in 180:
		if _timed_out():
			_fail("timed out waiting for SEARCH")
			return
		await get_tree().physics_frame
		if int(noise_guard.state) == int(noise_guard.State.SEARCH):
			searching = true
			break
	if not searching:
		_fail("loud world noise never put the second guard into SEARCH")
		return
	var nav: NavigationAgent3D = noise_guard.get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	if nav == null or not nav.target_position.is_equal_approx(noise_target):
		_fail("SEARCH did not set NavigationAgent3D to the noise target")
		return
	for _frame in 90:
		if _timed_out():
			_fail("timed out waiting for SEARCH movement")
			return
		await get_tree().physics_frame
	if noise_guard.global_position.distance_to(noise_origin) < 0.2:
		_fail("SEARCH investigation did not move along navigation")
		return
	_ok("loud world noise produces SEARCH navigation and movement")

	if _fails == 0:
		_ok(
			"generated facility physical patrol contracts held in %dms"
			% (Time.get_ticks_msec() - _started_ms)
		)



func _active_security_ids(facility: Node3D) -> Array[String]:
	var ids: Array[String] = []
	var agents: Dictionary = facility.staff_agent_state.get("agents", {})
	for staff_id_value in agents.keys():
		var staff_id := String(staff_id_value)
		if String((agents[staff_id] as Dictionary).get("job_id", "")) == "security_officer":
			ids.append(staff_id)
	ids.sort()
	return ids



func _staffing_marker_present(facility: Node3D, staff_id: String) -> bool:
	if facility.staffing_group == null:
		return false
	for marker in facility.staffing_group.get_children():
		if String(marker.get_meta("staff_id", "")) == staff_id:
			return true
	return false


func _personnel_door_between(facility: Node3D, from_room: String, to_room: String) -> Node:
	var doors: Node = facility.generated_facility.get_node_or_null("Doors")
	if doors == null:
		return null
	for door in doors.get_children():
		if String(door.get_meta("flow", "")) != "personnel":
			continue
		var door_from := String(door.get_meta("from_room", ""))
		var door_to := String(door.get_meta("to_room", ""))
		if (
			(door_from == from_room and door_to == to_room)
			or (door_from == to_room and door_to == from_room)
		):
			return door
	return null


func _room_node(facility: Node3D, room_id: String) -> Node3D:
	var rooms: Node = facility.generated_facility.get_node_or_null("Rooms")
	if rooms == null:
		return null
	for room_node in rooms.get_children():
		if String(room_node.get_meta("room_id", "")) == room_id:
			return room_node as Node3D
	return null


func _place_player_in_guard_sight(player: Node3D, guard: Node3D) -> void:
	player.global_position = guard.global_position - guard.global_transform.basis.z * 1.5
	player.global_position.y = guard.global_position.y
	guard.look_at(player.global_position, Vector3.UP)


func _timed_out() -> bool:
	return Time.get_ticks_msec() - _started_ms >= TIME_LIMIT_MS


func _fail(message: String) -> void:
	_fails += 1
	push_error("FAIL: %s" % message)
	print("FAIL: %s" % message)


func _ok(message: String) -> void:
	print("OK: %s" % message)


func _finish() -> void:
	var elapsed := Time.get_ticks_msec() - _started_ms
	print("=== generated_facility_patrol_selftest done fails=%d elapsed_ms=%d ===" % [_fails, elapsed])
	if elapsed > TIME_LIMIT_MS and _fails == 0:
		_fails += 1
		push_error("FAIL: selftest exceeded %dms bound" % TIME_LIMIT_MS)
		print("FAIL: selftest exceeded %dms bound" % TIME_LIMIT_MS)
	get_tree().quit(0 if _fails == 0 else 1)
