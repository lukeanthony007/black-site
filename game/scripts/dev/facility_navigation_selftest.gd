extends Node
## Headless proof: generated facility navigation bake, stair/door links, credentialed door signal.
## Run: godot --path . --headless res://scenes/dev_facility_navigation_selftest.tscn

var _fails: int = 0

const READY_FRAME_BUDGET := 1200


func _ready() -> void:
	print("=== facility_navigation_selftest ===")
	var scene_path := "res://scenes/dev_generated_facility.tscn"
	if not ResourceLoader.exists(scene_path):
		_fail("dedicated generated facility scene is missing")
		await _finish(null)
		return

	var packed: PackedScene = load(scene_path)
	var facility: Node3D = packed.instantiate()
	facility.operator_run = false
	add_child(facility)

	var navigation: Node = facility.get("navigation_runtime")
	if navigation == null:
		navigation = facility.get_node_or_null("FacilityNavigationRuntime")
	if navigation == null:
		_fail("generated facility exposes no FacilityNavigationRuntime")
		await _finish(facility)
		return

	var ready := false
	var failed_message := ""
	navigation.navigation_ready.connect(func() -> void: ready = true)
	navigation.navigation_failed.connect(func(message: String) -> void: failed_message = message)

	for _frame in READY_FRAME_BUDGET:
		if ready or bool(navigation.call("is_ready")):
			ready = true
			break
		if not str(navigation.get("error_message")).is_empty():
			failed_message = str(navigation.get("error_message"))
			break
		await get_tree().process_frame

	if not ready:
		_fail(
			"navigation_ready not reached within %d frames%s"
			% [READY_FRAME_BUDGET, ("" if failed_message.is_empty() else (": " + failed_message))]
		)
		await _finish(facility)
		return
	if not failed_message.is_empty():
		_fail("navigation_failed while ready: %s" % failed_message)
		await _finish(facility)
		return

	var generated: Node3D = facility.get("generated_facility") as Node3D
	if generated == null:
		generated = facility.get_node_or_null("GeneratedCyberArchivesFacility") as Node3D
	if generated == null:
		_fail("generated facility node missing after navigation_ready")
		await _finish(facility)
		return

	var vertical_links_group := generated.get_node_or_null("VerticalLinks")
	var doors_group := generated.get_node_or_null("Doors")
	if vertical_links_group == null or doors_group == null:
		_fail("compiled facility missing VerticalLinks or Doors source group")
		await _finish(facility)
		return

	var expected_vertical_links: int = vertical_links_group.get_child_count()
	var expected_floors := _expected_floor_count(vertical_links_group)
	var personnel_policy_doors: Array[Node] = _compiled_personnel_policy_doors(doors_group)
	var expected_door_links: int = personnel_policy_doors.size()

	var regions: Array[NavigationRegion3D] = []
	var stair_links: Array[NavigationLink3D] = []
	var door_links: Array[NavigationLink3D] = []
	for child in navigation.get_children():
		if child is NavigationRegion3D and str(child.name).begins_with("FloorNavigationRegion_"):
			regions.append(child as NavigationRegion3D)
		elif child is NavigationLink3D and str(child.name).begins_with("StairNavigationLink_"):
			stair_links.append(child as NavigationLink3D)
		elif child is NavigationLink3D and str(child.name).begins_with("DoorNavigationLink_"):
			door_links.append(child as NavigationLink3D)

	if regions.size() != expected_floors:
		_fail("expected %d floor NavigationRegion3D nodes, found %d" % [expected_floors, regions.size()])
	else:
		var seen_floors: Dictionary = {}
		for region in regions:
			var floor_index := int(region.get_meta("floor", -1))
			if floor_index < 0 or floor_index >= expected_floors:
				_fail("NavigationRegion3D %s has invalid floor meta %d" % [region.name, floor_index])
				continue
			if seen_floors.has(floor_index):
				_fail("duplicate NavigationRegion3D for floor %d" % floor_index)
				continue
			seen_floors[floor_index] = true
			if not region.enabled:
				_fail("floor %d NavigationRegion3D is not enabled after navigation_ready" % floor_index)
			var mesh: NavigationMesh = region.navigation_mesh
			if mesh == null or mesh.get_polygon_count() == 0:
				_fail("floor %d NavigationRegion3D has missing/empty navigation mesh" % floor_index)
				continue
			var region_map: RID = NavigationServer3D.region_get_map(region.get_region_rid())
			if not region_map.is_valid():
				_fail("floor %d NavigationRegion3D did not enter a valid NavigationServer map" % floor_index)
		for floor_index in expected_floors:
			if not seen_floors.has(floor_index):
				_fail("missing NavigationRegion3D for generated floor %d" % floor_index)

	if stair_links.size() != expected_vertical_links:
		_fail(
			"stair NavigationLink3D count %d does not equal vertical_links %d"
			% [stair_links.size(), expected_vertical_links]
		)

	if door_links.size() != expected_door_links:
		_fail(
			"door NavigationLink3D count %d does not match compiled personnel policy doors %d"
			% [door_links.size(), expected_door_links]
		)
	else:
		var linked_route_ids: Dictionary = {}
		for link in door_links:
			var route_id := str(link.get_meta("route_id", ""))
			if route_id.is_empty():
				_fail("door NavigationLink3D %s has empty route_id" % link.name)
			elif linked_route_ids.has(route_id):
				_fail("duplicate door NavigationLink3D for route %s" % route_id)
			else:
				linked_route_ids[route_id] = true
		for door in personnel_policy_doors:
			var door_route_id := str(door.get_meta("route_id", ""))
			if not linked_route_ids.has(door_route_id):
				_fail("compiled personnel policy door %s has no DoorNavigationLink" % door.name)

	var closed_credentialed: Node = null
	for door in personnel_policy_doors:
		if str(door.get_meta("door_mode", "")) != "credentialed_interlock":
			continue
		if bool(door.get("is_open")):
			continue
		closed_credentialed = door
		break
	if closed_credentialed == null:
		_fail("compiled facility has no closed credentialed personnel policy door")
	else:
		var door_link := _door_link_for(door_links, closed_credentialed)
		if door_link == null:
			_fail("closed credentialed door %s has no DoorNavigationLink" % closed_credentialed.name)
		elif door_link.enabled:
			_fail("closed credentialed door link started enabled")
		else:
			var insufficient: Dictionary = {"clearance_tier": 99, "roles": []}
			if bool(closed_credentialed.call("request_open", insufficient, false)):
				_fail("credentialed door accepted clearance without security_officer role")
			elif door_link.enabled:
				_fail("door NavigationLink3D enabled after rejected open request")
			else:
				var required_tier := int(closed_credentialed.get("required_clearance_tier"))
				var sufficient: Dictionary = {
					"clearance_tier": required_tier,
					"roles": ["security_officer"],
				}
				if not bool(closed_credentialed.call("request_open", sufficient, false)):
					_fail("credentialed door rejected sufficient real security_officer credentials")
				elif not bool(closed_credentialed.call("is_navigation_open")):
					_fail("credentialed door did not report navigation open after accepted request")
				elif not door_link.enabled:
					_fail("dead door signal: DoorNavigationLink stayed disabled after accepted request_open")
				else:
					_ok(
						"navigation bake, stair/door links, map sync, and credentialed door signal are live"
					)

	await _finish(facility)


func _expected_floor_count(vertical_links_group: Node) -> int:
	var max_floor := 0
	var saw_link := false
	for link in vertical_links_group.get_children():
		saw_link = true
		max_floor = maxi(max_floor, int(link.get_meta("from_floor", 0)))
		max_floor = maxi(max_floor, int(link.get_meta("to_floor", 0)))
	return max_floor + 1 if saw_link else 1


func _compiled_personnel_policy_doors(doors_group: Node) -> Array[Node]:
	var doors: Array[Node] = []
	for door in doors_group.get_children():
		if not door.has_method("request_open"):
			continue
		# Compiled FacilityPolicyDoor nodes are the personnel-security policy boundary set.
		# Navigation owns one DoorNavigationLink per compiled door child.
		doors.append(door)
	return doors


func _door_link_for(door_links: Array[NavigationLink3D], door: Node) -> NavigationLink3D:
	var route_id := str(door.get_meta("route_id", ""))
	var door_path := str(door.get_path())
	for link in door_links:
		if str(link.get_meta("route_id", "")) == route_id:
			return link
		if str(link.get_meta("door", "")) == door_path:
			return link
	return null


func _fail(message: String) -> void:
	_fails += 1
	print("FAIL: ", message)


func _ok(message: String) -> void:
	print("OK: ", message)


func _finish(facility: Node) -> void:
	if facility != null and is_instance_valid(facility):
		facility.queue_free()
	await get_tree().process_frame
	print("=== facility_navigation_selftest done fails=%d ===" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
