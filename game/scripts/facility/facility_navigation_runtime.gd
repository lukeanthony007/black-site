class_name FacilityNavigationRuntime
extends Node3D
## Builds generated-facility navigation after its collision geometry enters the tree.

signal navigation_ready
signal navigation_failed(message: String)

enum BuildState { IDLE, PARSING, BAKING, SYNCING, READY, FAILED }

const CELL_SIZE := 7.0
const FLOOR_HEIGHT := 4.5
const AGENT_RADIUS := 0.4
const AGENT_HEIGHT := 1.8
const AGENT_MAX_CLIMB := 0.35
const AGENT_MAX_SLOPE := 46.0
const FLOOR_BOUNDS_BOTTOM := 0.35
const FLOOR_BOUNDS_TOP := 3.05

var state: BuildState = BuildState.IDLE
var error_message: String = ""

var _facility: Node3D
var _plan: Dictionary = {}
var _route_plan: Dictionary = {}
var _regions: Array[NavigationRegion3D] = []
var _finished_floor_count := 0
var _legacy_door_links: Array[Dictionary] = []


func initialize(facility: Node3D, plan: Dictionary, route_plan: Dictionary) -> void:
	if state != BuildState.IDLE:
		_fail("Facility navigation runtime was initialized more than once")
		return
	set_process(false)
	if facility == null or not facility.is_inside_tree():
		_fail("Facility navigation requires a facility already inside the SceneTree")
		return
	if not is_inside_tree():
		_fail("Facility navigation runtime must enter the SceneTree before initialization")
		return
	_facility = facility
	_plan = plan.duplicate(true)
	_route_plan = route_plan.duplicate(true)
	global_transform = facility.global_transform
	state = BuildState.PARSING
	call_deferred("_begin_navigation_build")


func is_ready() -> bool:
	return state == BuildState.READY


func _process(_delta: float) -> void:
	for record in _legacy_door_links:
		var door: Node = record["door"]
		var link: NavigationLink3D = record["link"]
		if not is_instance_valid(door) or not is_instance_valid(link):
			continue
		var navigation_open := _door_is_navigation_open(door)
		if navigation_open != bool(record["open"]):
			record["open"] = navigation_open
			link.enabled = navigation_open


func _begin_navigation_build() -> void:
	if state != BuildState.PARSING:
		return
	if not is_instance_valid(_facility) or not _facility.is_inside_tree():
		_fail("Facility left the SceneTree before navigation source parsing")
		return
	var floor_count := int(_plan.get("floor_count", 0))
	if floor_count < 1:
		_fail("Facility navigation plan contains no floors")
		return
	state = BuildState.BAKING
	for floor_index in floor_count:
		var baking_bounds := _floor_baking_bounds(floor_index)
		if baking_bounds.size.x <= 0.0 or baking_bounds.size.z <= 0.0:
			_fail("Facility navigation floor %d has no placement or route geometry" % floor_index)
			return
		var navigation_mesh := NavigationMesh.new()
		navigation_mesh.agent_radius = AGENT_RADIUS
		navigation_mesh.agent_height = AGENT_HEIGHT
		navigation_mesh.agent_max_climb = AGENT_MAX_CLIMB
		navigation_mesh.agent_max_slope = AGENT_MAX_SLOPE
		navigation_mesh.cell_size = 0.2
		navigation_mesh.cell_height = 0.05
		navigation_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
		navigation_mesh.geometry_collision_mask = 1
		navigation_mesh.filter_baking_aabb = baking_bounds
		var region := NavigationRegion3D.new()
		region.name = "FloorNavigationRegion_%d" % floor_index
		region.navigation_mesh = navigation_mesh
		region.enabled = false
		region.set_meta("floor", floor_index)
		add_child(region)
		_regions.append(region)
		var source_geometry := NavigationMeshSourceGeometryData3D.new()
		NavigationServer3D.parse_source_geometry_data(
			navigation_mesh,
			source_geometry,
			_facility,
			_on_floor_geometry_parsed.bind(floor_index, source_geometry)
		)
	var vertical_links := _facility.get_node_or_null("VerticalLinks")
	if vertical_links == null:
		_fail("Compiled facility has no VerticalLinks source group")
		return
	var source_nodes := vertical_links.get_children()
	var manifest_links: Array = _plan.get("vertical_links", [])
	if source_nodes.size() != manifest_links.size():
		_fail("Compiled vertical-link count does not match the navigation plan")
		return
	for index in source_nodes.size():
		var source: Node3D = source_nodes[index] as Node3D
		var bottom_landing := source.get_node_or_null("Landing_Bottom") as Node3D
		var top_landing := source.get_node_or_null("Landing_Top") as Node3D
		if bottom_landing == null or top_landing == null:
			_fail("Compiled vertical link %d has no landing endpoints" % index)
			return
		var link := NavigationLink3D.new()
		link.name = "StairNavigationLink_%d" % index
		link.bidirectional = true
		link.start_position = to_local(bottom_landing.global_position + Vector3.UP * 0.05)
		link.end_position = to_local(top_landing.global_position + Vector3.UP * 0.05)
		for metadata_key in ["from_floor", "to_floor", "kind", "policy_transition", "egress_capable"]:
			link.set_meta(metadata_key, source.get_meta(metadata_key))
		add_child(link)

	var doors := _facility.get_node_or_null("Doors")
	if doors == null:
		_fail("Compiled facility has no Doors source group")
		return
	for door_data in doors.get_children():
		var door := door_data as Node3D
		var route := _route_for_door(door)
		if route.is_empty():
			_fail("Compiled policy door %s has no authoritative route" % door.name)
			return
		var collision := door.get_node_or_null("CollisionShape3D") as CollisionShape3D
		var box := collision.shape as BoxShape3D if collision != null else null
		if box == null:
			_fail("Compiled policy door %s has no box collision" % door.name)
			return
		var route_id := str(route.get("id", ""))
		if route_id.is_empty():
			_fail("Compiled policy door %s has an empty route id" % door.name)
			return
		var link := NavigationLink3D.new()
		link.name = "DoorNavigationLink_%s" % _safe_name(route_id)
		add_child(link)
		link.global_transform = door.global_transform
		var crossing_distance := box.size.z * 0.5 + AGENT_RADIUS + 0.5
		var floor_offset := -box.size.y * 0.5 + 0.05
		link.start_position = Vector3(0.0, floor_offset, -crossing_distance)
		link.end_position = Vector3(0.0, floor_offset, crossing_distance)
		link.bidirectional = not bool(route.get("one_way", false))
		link.set_meta("route_id", route_id)
		link.set_meta("door", door.get_path())
		link.enabled = _door_is_navigation_open(door)
		if door.has_signal("navigation_state_changed") and door.has_method("is_navigation_open"):
			door.connect("navigation_state_changed", _on_door_navigation_state_changed.bind(link))
		else:
			_legacy_door_links.append({"door": door, "link": link, "open": link.enabled})
	if not _legacy_door_links.is_empty():
		push_warning(
			"FacilityPolicyDoor lacks the navigation_state_changed/is_navigation_open contract; " +
			"navigation links are using compatibility state observation"
		)
		set_process(true)


func _on_floor_geometry_parsed(
	floor_index: int,
	source_geometry: NavigationMeshSourceGeometryData3D
) -> void:
	if state == BuildState.FAILED:
		return
	if floor_index < 0 or floor_index >= _regions.size():
		_fail("Facility navigation parsed an unknown floor")
		return
	NavigationServer3D.bake_from_source_geometry_data_async(
		_regions[floor_index].navigation_mesh,
		source_geometry,
		_on_floor_bake_finished.bind(floor_index)
	)


func _on_floor_bake_finished(floor_index: int) -> void:
	if state == BuildState.FAILED:
		return
	if floor_index < 0 or floor_index >= _regions.size():
		_fail("Facility navigation baked an unknown floor")
		return
	var region := _regions[floor_index]
	if region.navigation_mesh == null or region.navigation_mesh.get_polygon_count() == 0:
		_fail("Facility navigation bake produced no polygons for floor %d" % floor_index)
		return
	region.enabled = true
	_finished_floor_count += 1
	if _finished_floor_count == _regions.size():
		state = BuildState.SYNCING
		_finish_after_navigation_sync()


func _finish_after_navigation_sync() -> void:
	await get_tree().physics_frame
	if state != BuildState.SYNCING:
		return
	for region in _regions:
		if not is_instance_valid(region) or not region.enabled:
			_fail("Facility navigation region disappeared before server synchronization")
			return
		var region_map := NavigationServer3D.region_get_map(region.get_region_rid())
		if not region_map.is_valid():
			_fail("Facility navigation region did not enter a NavigationServer map")
			return
	state = BuildState.READY
	navigation_ready.emit()


func _floor_baking_bounds(floor_index: int) -> AABB:
	var cells: Array[Vector2i] = []
	for placement_data in (_plan.get("placements", {}) as Dictionary).values():
		var placement: Dictionary = placement_data
		if int(placement.get("floor", -1)) == floor_index:
			cells.append(Vector2i(int(placement["x"]), int(placement["z"])))
	for route_data in _route_plan.get("routes", []):
		var route: Dictionary = route_data
		for waypoint_data in route.get("waypoints", []):
			var waypoint: Dictionary = waypoint_data
			if int(waypoint.get("floor", -1)) == floor_index:
				cells.append(Vector2i(int(waypoint["x"]), int(waypoint["z"])))
	for link_data in _plan.get("vertical_links", []):
		var vertical_link: Dictionary = link_data
		if floor_index in [int(vertical_link["from_floor"]), int(vertical_link["to_floor"])]:
			cells.append(Vector2i(int(vertical_link["x"]), int(vertical_link["z"])))
	if cells.is_empty():
		return AABB()
	var minimum := cells[0]
	var maximum := cells[0]
	for cell in cells:
		minimum.x = mini(minimum.x, cell.x)
		minimum.y = mini(minimum.y, cell.y)
		maximum.x = maxi(maximum.x, cell.x)
		maximum.y = maxi(maximum.y, cell.y)
	var planar_margin := CELL_SIZE * 0.5 + AGENT_RADIUS
	var floor_y := float(floor_index) * FLOOR_HEIGHT
	return AABB(
		Vector3(
			float(minimum.x) * CELL_SIZE - planar_margin,
			floor_y - FLOOR_BOUNDS_BOTTOM,
			float(minimum.y) * CELL_SIZE - planar_margin
		),
		Vector3(
			float(maximum.x - minimum.x) * CELL_SIZE + planar_margin * 2.0,
			FLOOR_BOUNDS_BOTTOM + FLOOR_BOUNDS_TOP,
			float(maximum.y - minimum.y) * CELL_SIZE + planar_margin * 2.0
		)
	)


func _route_for_door(door: Node3D) -> Dictionary:
	for route_data in _route_plan.get("routes", []):
		var route: Dictionary = route_data
		if (
			route.get("kind", "") == "circulation"
			and route.get("from", "") == door.get_meta("from_room", "")
			and route.get("to", "") == door.get_meta("to_room", "")
			and route.get("flow", "") == door.get_meta("flow", "")
		):
			return route
	return {}


func _door_is_navigation_open(door: Node) -> bool:
	if door.has_method("is_navigation_open"):
		return bool(door.call("is_navigation_open"))
	return bool(door.get("is_open"))


func _on_door_navigation_state_changed(
	_door: Node,
	navigation_open: bool,
	link: NavigationLink3D
) -> void:
	if is_instance_valid(link):
		link.enabled = navigation_open


func _safe_name(value: String) -> String:
	return value.replace(":", "_").replace("->", "_to_").replace("/", "_").replace(" ", "_")


func _fail(message: String) -> void:
	if state == BuildState.FAILED:
		return
	state = BuildState.FAILED
	error_message = message
	set_process(false)
	push_error(message)
	navigation_failed.emit(message)
