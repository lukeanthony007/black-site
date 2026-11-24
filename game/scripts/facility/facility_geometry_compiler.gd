class_name FacilityGeometryCompiler
extends RefCounted
## Compiles validated semantic manifests into a generated Godot scene.
## The graph remains authoritative; every emitted node carries provenance metadata.

const CELL_SIZE := 7.0
const FLOOR_HEIGHT := 4.5
const ROOM_SIZE := CELL_SIZE
const CORRIDOR_SIZE := CELL_SIZE
const SLAB_HEIGHT := 0.22
const STAIR_RISE := 0.17
const STAIR_WIDTH := 3.2
const STAIR_TREAD_VISUAL := 0.42
const WALL_HEIGHT := 3.2
const WALL_THICKNESS := 0.20
const DOOR_WIDTH := 1.6
const DOOR_HEIGHT := 2.5
const THRESHOLD_DEPTH := 0.9
const ROOM_LIGHT_HEIGHT := 2.85
const ROOM_LIGHT_RANGE := 8.5
const ROOM_LIGHT_ENERGY := 2.4
const CORRIDOR_LIGHT_ENERGY := 1.8
const LAYOUT_SOLVER_PATH := "res://scripts/facility/facility_layout_solver.gd"
const ROUTE_ROUTER_PATH := "res://scripts/facility/facility_route_router.gd"
const POLICY_DOOR_PATH := "res://scripts/facility/facility_policy_door.gd"
const EQUIPMENT_STATION_PATH := "res://scripts/facility/facility_equipment_station.gd"


func compile(graph: RefCounted, plan: Dictionary, route_plan: Dictionary) -> Node3D:
	if not _manifests_are_valid(graph, plan, route_plan):
		return null
	var facility := Node3D.new()
	facility.name = "GeneratedCyberArchivesFacility"
	facility.set_meta("seed", graph.seed)
	facility.set_meta("generation_profile", graph.generation_profile.duplicate(true))
	facility.set_meta("operational_fingerprint", graph.generation_fingerprint())

	var rooms := _group("Rooms")
	var circulation := _group("Circulation")
	var doors := _group("Doors")
	var service := _group("Service")
	var equipment := _group("Equipment")
	var vertical_links := _group("VerticalLinks")
	facility.add_child(rooms)
	facility.add_child(circulation)
	facility.add_child(doors)
	facility.add_child(service)
	facility.add_child(equipment)
	facility.add_child(vertical_links)

	_compile_rooms(graph, plan, route_plan, rooms)
	_compile_circulation(plan, route_plan, circulation)
	_compile_service(plan, route_plan, service)
	_compile_equipment(graph, plan, equipment)
	_compile_doors(graph, plan, route_plan, doors)
	_compile_vertical_links(plan, vertical_links)
	return facility


func _manifests_are_valid(graph: RefCounted, plan: Dictionary, route_plan: Dictionary) -> bool:
	if not graph.validate().is_empty():
		return false
	var solver_script: Script = load(LAYOUT_SOLVER_PATH)
	var router_script: Script = load(ROUTE_ROUTER_PATH)
	var door_script: Script = load(POLICY_DOOR_PATH)
	var equipment_script: Script = load(EQUIPMENT_STATION_PATH)
	if solver_script == null or not solver_script.can_instantiate():
		return false
	if router_script == null or not router_script.can_instantiate():
		return false
	if door_script == null or not door_script.can_instantiate():
		return false
	if equipment_script == null or not equipment_script.can_instantiate():
		return false
	var solver: RefCounted = solver_script.new()
	var router: RefCounted = router_script.new()
	if not solver.validate_plan(graph, plan).is_empty():
		return false
	if not router.validate_routes(graph, plan, route_plan).is_empty():
		return false
	return true


func _compile_rooms(graph: RefCounted, plan: Dictionary, route_plan: Dictionary, parent: Node3D) -> void:
	var placements: Dictionary = plan.get("placements", {})
	var openings: Dictionary = _room_openings(plan, route_plan)
	var room_ids: Array = placements.keys()
	room_ids.sort()
	for room_id in room_ids:
		var placement: Dictionary = placements[room_id]
		var room: Dictionary = graph.rooms[room_id]
		var room_node := Node3D.new()
		room_node.name = _safe_name(room_id)
		room_node.position = _world_position(placement)
		room_node.set_meta("room_id", room_id)
		room_node.set_meta("zone", room["zone"])
		room_node.set_meta("security_tier", room["security_tier"])
		room_node.set_meta("owners", room["owners"].duplicate())
		room_node.set_meta("critical_requirements", room["critical_requirements"].duplicate())
		parent.add_child(room_node)
		var floor_body := _floor_body("FloorBody", Vector3(ROOM_SIZE, SLAB_HEIGHT, ROOM_SIZE), _zone_color(room["zone"]))
		# Keep the walkable top surface on the room plane so doorway thresholds mate cleanly.
		floor_body.position.y = -SLAB_HEIGHT * 0.5
		room_node.add_child(floor_body)
		var walls := _group("Walls")
		room_node.add_child(walls)
		_compile_room_walls(walls, openings.get(room_id, {}), _zone_color(room["zone"]))
		_compile_room_thresholds(room_node, openings.get(room_id, {}))
		# Ceiling slab closes the room volume so interiors are not open to the sky.
		var roof_body := _floor_body("RoofBody", Vector3(ROOM_SIZE, SLAB_HEIGHT, ROOM_SIZE), _zone_color(room["zone"]).darkened(0.35))
		roof_body.position.y = WALL_HEIGHT + SLAB_HEIGHT * 0.5
		roof_body.set_meta("enclosure", "roof")
		room_node.add_child(roof_body)
		# Enclosed rooms no longer receive the outdoor directional light; light them locally.
		var room_light := _ceiling_light("RoomLight", _zone_light_color(room["zone"]), ROOM_LIGHT_ENERGY, ROOM_LIGHT_RANGE)
		room_light.position = Vector3(0.0, ROOM_LIGHT_HEIGHT, 0.0)
		room_light.set_meta("room_id", room_id)
		room_node.add_child(room_light)


func _compile_room_thresholds(room_node: Node3D, room_openings: Dictionary) -> void:
	# Explicit doorway sills bridge any residual gap at wall openings so circulation never drops into void.
	for opening_key in room_openings:
		var parts: PackedStringArray = String(opening_key).split(":")
		if parts.size() != 2:
			continue
		var direction := Vector2i(int(parts[0]), int(parts[1]))
		if absi(direction.x) + absi(direction.y) != 1:
			continue
		var along_x := direction.y != 0
		var size := Vector3(DOOR_WIDTH + 0.4, SLAB_HEIGHT, THRESHOLD_DEPTH) if along_x else Vector3(THRESHOLD_DEPTH, SLAB_HEIGHT, DOOR_WIDTH + 0.4)
		var threshold := _floor_body("Threshold_%d_%d" % [direction.x, direction.y], size, Color(0.26, 0.30, 0.34))
		threshold.position = Vector3(
			float(direction.x) * (ROOM_SIZE * 0.5),
			-SLAB_HEIGHT * 0.5,
			float(direction.y) * (ROOM_SIZE * 0.5)
		)
		room_node.add_child(threshold)


func _room_openings(plan: Dictionary, route_plan: Dictionary) -> Dictionary:
	var openings: Dictionary = {}
	for route_data in route_plan.get("routes", []):
		var route_item: Dictionary = route_data
		if route_item["kind"] != "circulation":
			continue
		var waypoints: Array = route_item["waypoints"]
		if waypoints.size() < 2:
			continue
		_mark_opening(openings, route_item["from"], waypoints[0], waypoints[1])
		_mark_opening(openings, route_item["to"], waypoints.back(), waypoints[waypoints.size() - 2])
	return openings


func _mark_opening(openings: Dictionary, room_id: String, origin: Dictionary, neighbor: Dictionary) -> void:
	if int(origin["floor"]) != int(neighbor["floor"]):
		return
	var direction := Vector2i(
		int(neighbor["x"]) - int(origin["x"]),
		int(neighbor["z"]) - int(origin["z"])
	)
	if absi(direction.x) + absi(direction.y) != 1:
		return
	if not openings.has(room_id):
		openings[room_id] = {}
	openings[room_id]["%d:%d" % [direction.x, direction.y]] = true


func _compile_room_walls(parent: Node3D, room_openings: Dictionary, color: Color) -> void:
	_add_wall_side(parent, "North", Vector2i(0, -1), room_openings, color)
	_add_wall_side(parent, "South", Vector2i(0, 1), room_openings, color)
	_add_wall_side(parent, "West", Vector2i(-1, 0), room_openings, color)
	_add_wall_side(parent, "East", Vector2i(1, 0), room_openings, color)


func _add_wall_side(
	parent: Node3D,
	side_name: String,
	direction: Vector2i,
	room_openings: Dictionary,
	color: Color
) -> void:
	var has_opening: bool = room_openings.has("%d:%d" % [direction.x, direction.y])
	var along_x := direction.y != 0
	var edge_offset := ROOM_SIZE * 0.5
	var base_position := Vector3(
		float(direction.x) * edge_offset,
		WALL_HEIGHT * 0.5,
		float(direction.y) * edge_offset
	)
	if not has_opening:
		var full_size := Vector3(ROOM_SIZE, WALL_HEIGHT, WALL_THICKNESS) if along_x else Vector3(WALL_THICKNESS, WALL_HEIGHT, ROOM_SIZE)
		var full_wall := _floor_body("Wall_%s" % side_name, full_size, color.lightened(0.12))
		full_wall.position = base_position
		parent.add_child(full_wall)
		return
	var segment_length := (ROOM_SIZE - DOOR_WIDTH) * 0.5
	var segment_offset := (DOOR_WIDTH + segment_length) * 0.5
	for sign_value in [-1.0, 1.0]:
		var segment_size := Vector3(segment_length, WALL_HEIGHT, WALL_THICKNESS) if along_x else Vector3(WALL_THICKNESS, WALL_HEIGHT, segment_length)
		var wall_segment := _floor_body("Wall_%s_%s" % [side_name, "A" if sign_value < 0.0 else "B"], segment_size, color.lightened(0.12))
		wall_segment.position = base_position
		if along_x:
			wall_segment.position.x += sign_value * segment_offset
		else:
			wall_segment.position.z += sign_value * segment_offset
		parent.add_child(wall_segment)
	var lintel_height := WALL_HEIGHT - DOOR_HEIGHT
	if lintel_height > 0.0:
		var lintel_size := Vector3(DOOR_WIDTH, lintel_height, WALL_THICKNESS) if along_x else Vector3(WALL_THICKNESS, lintel_height, DOOR_WIDTH)
		var lintel := _floor_body("Wall_%s_Lintel" % side_name, lintel_size, color.lightened(0.12))
		lintel.position = base_position
		lintel.position.y = DOOR_HEIGHT + lintel_height * 0.5
		parent.add_child(lintel)


func _compile_circulation(plan: Dictionary, route_plan: Dictionary, parent: Node3D) -> void:
	var occupied_rooms := _occupied_room_cells(plan)
	var vertical_apertures := _vertical_aperture_cells(plan)
	var cells: Dictionary = {}
	for route_data in route_plan.get("routes", []):
		var route_item: Dictionary = route_data
		if route_item["kind"] != "circulation":
			continue
		for waypoint_data in route_item["waypoints"]:
			var waypoint: Dictionary = waypoint_data
			var key := _cell_key(waypoint)
			if occupied_rooms.has(key) or vertical_apertures.has(key):
				continue
			if not cells.has(key):
				cells[key] = {"point": waypoint.duplicate(), "flows": [], "route_ids": []}
			var record: Dictionary = cells[key]
			if not record["flows"].has(route_item["flow"]):
				record["flows"].append(route_item["flow"])
			record["route_ids"].append(route_item["id"])
	var keys: Array = cells.keys()
	keys.sort()
	for key in keys:
		var record: Dictionary = cells[key]
		var point: Dictionary = record["point"]
		var body := _floor_body("Corridor_%s" % _safe_name(key), Vector3(CORRIDOR_SIZE, SLAB_HEIGHT, CORRIDOR_SIZE), Color(0.22, 0.28, 0.34))
		body.position = _world_position(point)
		body.position.y -= SLAB_HEIGHT * 0.5
		body.set_meta("cell", key)
		body.set_meta("flows", record["flows"])
		body.set_meta("route_ids", record["route_ids"])
		parent.add_child(body)
		var roof := _floor_body("CorridorRoof_%s" % _safe_name(key), Vector3(CORRIDOR_SIZE, SLAB_HEIGHT, CORRIDOR_SIZE), Color(0.16, 0.20, 0.24))
		roof.position = _world_position(point)
		roof.position.y += WALL_HEIGHT + SLAB_HEIGHT * 0.5
		roof.set_meta("cell", key)
		roof.set_meta("enclosure", "roof")
		parent.add_child(roof)
		var corridor_light := _ceiling_light(
			"CorridorLight_%s" % _safe_name(key),
			Color(0.78, 0.86, 0.95),
			CORRIDOR_LIGHT_ENERGY,
			ROOM_LIGHT_RANGE
		)
		corridor_light.position = _world_position(point)
		corridor_light.position.y += ROOM_LIGHT_HEIGHT
		corridor_light.set_meta("cell", key)
		parent.add_child(corridor_light)
	var walls := _group("Walls")
	parent.add_child(walls)
	_compile_corridor_walls(cells, route_plan, walls)


func _compile_corridor_walls(cells: Dictionary, route_plan: Dictionary, parent: Node3D) -> void:
	var open_boundaries := _route_boundaries(route_plan)
	var emitted: Dictionary = {}
	var directions: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
	for cell_key in cells:
		var record: Dictionary = cells[cell_key]
		var point: Dictionary = record["point"]
		for direction in directions:
			var neighbor := {
				"floor": int(point["floor"]),
				"x": int(point["x"]) + direction.x,
				"z": int(point["z"]) + direction.y,
			}
			var boundary_key := _boundary_key(point, neighbor)
			if open_boundaries.has(boundary_key) or emitted.has(boundary_key):
				continue
			emitted[boundary_key] = true
			var along_x := direction.y != 0
			var wall_size := Vector3(CELL_SIZE, WALL_HEIGHT, WALL_THICKNESS) if along_x else Vector3(WALL_THICKNESS, WALL_HEIGHT, CELL_SIZE)
			var wall := _floor_body("CorridorWall_%s" % _safe_name(boundary_key), wall_size, Color(0.30, 0.34, 0.39))
			wall.position = _world_position(point) + Vector3(
				float(direction.x) * CELL_SIZE * 0.5,
				WALL_HEIGHT * 0.5,
				float(direction.y) * CELL_SIZE * 0.5
			)
			wall.set_meta("boundary", boundary_key)
			parent.add_child(wall)


func _route_boundaries(route_plan: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for route_data in route_plan.get("routes", []):
		var route_item: Dictionary = route_data
		if route_item["kind"] != "circulation":
			continue
		var waypoints: Array = route_item["waypoints"]
		for index in waypoints.size() - 1:
			var current: Dictionary = waypoints[index]
			var next: Dictionary = waypoints[index + 1]
			if int(current["floor"]) == int(next["floor"]):
				result[_boundary_key(current, next)] = true
	return result


func _boundary_key(first: Dictionary, second: Dictionary) -> String:
	var first_key := _cell_key(first)
	var second_key := _cell_key(second)
	return "%s|%s" % [first_key, second_key] if first_key < second_key else "%s|%s" % [second_key, first_key]


func _compile_service(plan: Dictionary, route_plan: Dictionary, parent: Node3D) -> void:
	var emitted: Dictionary = {}
	for route_data in route_plan.get("routes", []):
		var route_item: Dictionary = route_data
		if route_item["kind"] != "service":
			continue
		for waypoint_data in route_item["waypoints"]:
			var waypoint: Dictionary = waypoint_data
			var key := "%s:%s" % [route_item["service_kind"], _cell_key(waypoint)]
			if emitted.has(key):
				continue
			emitted[key] = true
			var conduit := MeshInstance3D.new()
			conduit.name = "Conduit_%s" % _safe_name(key)
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.28, 0.18, 0.28)
			conduit.mesh = mesh
			conduit.position = _world_position(waypoint) + Vector3(0.0, 0.28, 0.0)
			conduit.material_override = _material(_service_color(route_item["service_kind"]))
			conduit.set_meta("service_kind", route_item["service_kind"])
			conduit.set_meta("ordinary_access", false)
			parent.add_child(conduit)


func _compile_equipment(graph: RefCounted, plan: Dictionary, parent: Node3D) -> void:
	var placements: Dictionary = plan.get("placements", {})
	var equipment_script: Script = load(EQUIPMENT_STATION_PATH)
	var room_counts: Dictionary = {}
	var equipment_ids: Array = graph.equipment.keys()
	equipment_ids.sort()
	for equipment_id in equipment_ids:
		var item: Dictionary = graph.equipment[equipment_id]
		var room_id: String = item["room"]
		if not placements.has(room_id):
			continue
		var room_index: int = int(room_counts.get(room_id, 0))
		room_counts[room_id] = room_index + 1
		var size := _equipment_size(equipment_id)
		var station := StaticBody3D.new()
		station.set_script(equipment_script)
		station.name = "Equipment_%s" % _safe_name(equipment_id)
		station.collision_layer = 1
		station.collision_mask = 1
		station.position = _world_position(placements[room_id]) + Vector3(
			-1.35 + float(room_index % 2) * 2.7,
			size.y * 0.5,
			1.25 - float(room_index / 2) * 1.45
		)
		var base_color := _equipment_color(item["utility_requirements"])
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "MeshInstance3D"
		var mesh := BoxMesh.new()
		mesh.size = size
		mesh_instance.mesh = mesh
		mesh_instance.material_override = _material(base_color)
		station.add_child(mesh_instance)
		var collision := CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		station.add_child(collision)
		station.call("configure", item, _equipment_mission_steps(graph, equipment_id), base_color)
		parent.add_child(station)


func _equipment_mission_steps(graph: RefCounted, equipment_id: String) -> Array[String]:
	var result: Array[String] = []
	for step in graph.mission_steps:
		if (step["required_equipment"] as Array).has(equipment_id):
			result.append(step["id"])
	return result


func _equipment_size(equipment_id: String) -> Vector3:
	if equipment_id == "controlled_shelving":
		return Vector3(1.8, 2.4, 0.65)
	if "bench" in equipment_id:
		return Vector3(2.0, 1.0, 1.0)
	return Vector3(1.35, 1.15, 0.75)


func _equipment_color(requirements: Array) -> Color:
	if requirements.has("cooling"):
		return Color(0.16, 0.48, 0.64)
	if requirements.has("communications"):
		return Color(0.24, 0.38, 0.56)
	return Color(0.42, 0.36, 0.25)


func _compile_doors(graph: RefCounted, plan: Dictionary, route_plan: Dictionary, parent: Node3D) -> void:
	var emitted: Dictionary = {}
	var placements: Dictionary = plan.get("placements", {})
	var door_script: Script = load(POLICY_DOOR_PATH)
	for route_data in route_plan.get("routes", []):
		var route_item: Dictionary = route_data
		if route_item["kind"] != "circulation":
			continue
		var door_key := _door_key(route_item)
		if emitted.has(door_key):
			continue
		emitted[door_key] = true
		if not placements.has(route_item["from"]) or not placements.has(route_item["to"]):
			continue
		var direction := _route_source_direction(route_item)
		if direction == Vector2i.ZERO:
			continue
		var source: Dictionary = placements[route_item["from"]]
		var target: Dictionary = placements[route_item["to"]]
		var door := StaticBody3D.new()
		door.set_script(door_script)
		door.name = "Door_%s" % _safe_name(door_key)
		door.collision_layer = 1
		door.collision_mask = 1
		door.position = _world_position(source) + Vector3(
			float(direction.x) * ROOM_SIZE * 0.5,
			DOOR_HEIGHT * 0.5,
			float(direction.y) * ROOM_SIZE * 0.5
		)
		if direction.x != 0:
			door.rotation.y = PI * 0.5
		var clearance_tier := maxi(int(source["security_tier"]), int(target["security_tier"]))
		var destination_roles: Array[String] = []
		if graph.rooms.has(route_item["to"]):
			if route_item["flow"] == "personnel":
				destination_roles.assign(graph.rooms[route_item["to"]]["access_roles"])
			elif route_item["flow"] in ["material", "evidence"]:
				destination_roles.assign(graph.rooms[route_item["to"]]["owners"])
		door.call("configure", route_item, clearance_tier, destination_roles)
		var marker := MeshInstance3D.new()
		marker.name = "Marker"
		var mesh := BoxMesh.new()
		mesh.size = Vector3(DOOR_WIDTH, DOOR_HEIGHT, WALL_THICKNESS)
		marker.mesh = mesh
		marker.material_override = _material(_door_color(route_item["door_mode"]))
		door.add_child(marker)
		var collision := CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		var shape := BoxShape3D.new()
		shape.size = Vector3(DOOR_WIDTH, DOOR_HEIGHT, WALL_THICKNESS)
		collision.shape = shape
		door.add_child(collision)
		# Open after leaf/collision exist so open_internal starts physically passable.
		if route_item.get("door_mode", "") == "open_internal":
			door.call("request_open", {"clearance_tier": 99, "roles": []}, false)
		parent.add_child(door)


func _route_source_direction(route_item: Dictionary) -> Vector2i:
	var waypoints: Array = route_item.get("waypoints", [])
	if waypoints.size() < 2:
		return Vector2i.ZERO
	var source: Dictionary = waypoints[0]
	var neighbor: Dictionary = waypoints[1]
	if int(source["floor"]) != int(neighbor["floor"]):
		return Vector2i.ZERO
	var direction := Vector2i(
		int(neighbor["x"]) - int(source["x"]),
		int(neighbor["z"]) - int(source["z"])
	)
	return direction if absi(direction.x) + absi(direction.y) == 1 else Vector2i.ZERO


func _compile_vertical_links(plan: Dictionary, parent: Node3D) -> void:
	for index in (plan.get("vertical_links", []) as Array).size():
		var link: Dictionary = plan["vertical_links"][index]
		var shaft := Node3D.new()
		shaft.name = "VerticalLink_%d" % index
		shaft.position = Vector3(float(link["x"]) * CELL_SIZE, 0.0, float(link["z"]) * CELL_SIZE)
		shaft.set_meta("from_floor", link["from_floor"])
		shaft.set_meta("to_floor", link["to_floor"])
		shaft.set_meta("kind", link["kind"])
		shaft.set_meta("policy_transition", link["policy_transition"])
		shaft.set_meta("egress_capable", link["egress_capable"])
		var from_floor: int = int(link["from_floor"])
		var to_floor: int = int(link["to_floor"])
		var base_y: float = float(from_floor) * FLOOR_HEIGHT
		var top_y: float = float(to_floor) * FLOOR_HEIGHT
		var rise: float = top_y - base_y
		var landing_depth := 1.0
		var usable_run: float = CELL_SIZE - landing_depth * 2.0
		var ramp_thickness := 0.18
		var ramp_length: float = sqrt(usable_run * usable_run + rise * rise)
		# Walkable ramp is the authoritative climb surface. Visible treads are presentation only.
		var ramp := _floor_body(
			"StairRamp",
			Vector3(STAIR_WIDTH, ramp_thickness, ramp_length),
			Color(0.30, 0.34, 0.38)
		)
		var ramp_pitch: float = -atan2(rise, usable_run)
		# Offset the box center half a thickness along the surface normal so the walk
		# plane (top face) runs flush from the bottom landing inner edge at base_y to
		# the top landing inner edge at top_y - no riser lip at either landing.
		ramp.position = Vector3(
			0.0,
			base_y + rise * 0.5 - ramp_thickness * 0.5 * (usable_run / ramp_length),
			ramp_thickness * 0.5 * (rise / ramp_length)
		)
		ramp.rotation.x = ramp_pitch
		# Hide collision mesh look slightly; keep collision solid.
		var ramp_mesh: MeshInstance3D = ramp.get_node("MeshInstance3D")
		if ramp_mesh != null:
			var ramp_mat := _material(Color(0.33, 0.37, 0.42))
			ramp_mat.roughness = 0.9
			ramp_mesh.material_override = ramp_mat
		shaft.add_child(ramp)
		# Bottom / top landings mate the ramp to each floor plane.
		var bottom_landing := _floor_body("Landing_Bottom", Vector3(STAIR_WIDTH + 1.0, SLAB_HEIGHT, 1.0), Color(0.28, 0.32, 0.36))
		bottom_landing.position = Vector3(0.0, base_y - SLAB_HEIGHT * 0.5, -CELL_SIZE * 0.5 + 0.5)
		shaft.add_child(bottom_landing)
		var top_landing := _floor_body("Landing_Top", Vector3(STAIR_WIDTH + 1.0, SLAB_HEIGHT, 1.0), Color(0.28, 0.32, 0.36))
		top_landing.position = Vector3(0.0, top_y - SLAB_HEIGHT * 0.5, CELL_SIZE * 0.5 - 0.5)
		shaft.add_child(top_landing)
		# Side walkways for same-floor route continuity through the shaft cell.
		var strip_width: float = maxf(0.9, (CELL_SIZE - STAIR_WIDTH) * 0.5 - 0.05)
		for floor_index in [from_floor, to_floor]:
			for side in [-1.0, 1.0]:
				var side_landing := _floor_body(
					"Landing_F%d_%s" % [floor_index, "L" if side < 0.0 else "R"],
					Vector3(strip_width, SLAB_HEIGHT, CELL_SIZE),
					Color(0.24, 0.28, 0.32)
				)
				side_landing.position = Vector3(
					side * (STAIR_WIDTH * 0.5 + strip_width * 0.5),
					float(floor_index) * FLOOR_HEIGHT - SLAB_HEIGHT * 0.5,
					0.0
				)
				shaft.add_child(side_landing)
		# Decorative treads (mesh only) so the flight reads as stairs without fighting the ramp collider.
		var steps := _group("Steps")
		shaft.add_child(steps)
		var step_count: int = maxi(1, ceili(rise / STAIR_RISE))
		var step_run: float = usable_run / float(step_count)
		for step_index in step_count:
			var t: float = (float(step_index) + 0.5) / float(step_count)
			var tread := MeshInstance3D.new()
			tread.name = "Step_%02d" % step_index
			var mesh := BoxMesh.new()
			mesh.size = Vector3(STAIR_WIDTH * 0.98, 0.06, maxf(step_run * 0.9, STAIR_TREAD_VISUAL * 0.5))
			tread.mesh = mesh
			tread.material_override = _material(Color(0.40, 0.44, 0.48))
			tread.position = Vector3(
				0.0,
				base_y + t * rise + 0.04,
				-CELL_SIZE * 0.5 + landing_depth + t * usable_run
			)
			steps.add_child(tread)
		var rail_material := _material(Color(0.82, 0.66, 0.16))
		for side in [-1.0, 1.0]:
			var rail := MeshInstance3D.new()
			rail.name = "Rail_%s" % ("L" if side < 0.0 else "R")
			var rail_mesh := BoxMesh.new()
			rail_mesh.size = Vector3(0.10, 0.12, ramp_length)
			rail.mesh = rail_mesh
			rail.position = Vector3(side * STAIR_WIDTH * 0.5, base_y + rise * 0.5 + 0.95, 0.0)
			rail.rotation.x = -atan2(rise, usable_run)
			rail.material_override = rail_material
			shaft.add_child(rail)
		parent.add_child(shaft)


func _floor_body(node_name: String, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 1
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _material(color)
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body


func _group(group_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = group_name
	return node


func _occupied_room_cells(plan: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for placement_data in (plan.get("placements", {}) as Dictionary).values():
		var placement: Dictionary = placement_data
		result[_cell_key(placement)] = true
	return result


func _vertical_aperture_cells(plan: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for link_data in plan.get("vertical_links", []):
		var link: Dictionary = link_data
		result["%d:%d:%d" % [link["from_floor"], link["x"], link["z"]]] = true
		result["%d:%d:%d" % [link["to_floor"], link["x"], link["z"]]] = true
	return result


func _world_position(point: Dictionary) -> Vector3:
	return Vector3(
		float(point["x"]) * CELL_SIZE,
		float(point["floor"]) * FLOOR_HEIGHT,
		float(point["z"]) * CELL_SIZE
	)


func _cell_key(point: Dictionary) -> String:
	return "%d:%d:%d" % [point["floor"], point["x"], point["z"]]


func _door_key(route_item: Dictionary) -> String:
	var first: String = route_item["from"]
	var second: String = route_item["to"]
	if route_item["flow"] == "personnel" and second < first:
		var swap := first
		first = second
		second = swap
	return "%s:%s:%s" % [route_item["flow"], first, second]


func _safe_name(value: Variant) -> String:
	return str(value).replace(":", "_").replace("->", "_to_").replace("/", "_").replace(" ", "_")


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	return material


func _ceiling_light(node_name: String, color: Color, energy: float, light_range: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = node_name
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.omni_attenuation = 1.35
	light.shadow_enabled = false
	light.set_meta("fixture", "ceiling")
	return light


func _zone_light_color(zone: String) -> Color:
	match zone:
		"external", "entry": return Color(0.90, 0.93, 0.98)
		"operations", "cyber": return Color(0.72, 0.88, 1.0)
		"research": return Color(0.78, 0.84, 1.0)
		"archives": return Color(1.0, 0.90, 0.72)
		"service", "plant": return Color(1.0, 0.86, 0.70)
		"infrastructure": return Color(0.84, 0.88, 0.92)
		"egress": return Color(0.78, 1.0, 0.82)
		_: return Color(0.88, 0.90, 0.94)


func _zone_color(zone: String) -> Color:
	match zone:
		"external", "entry": return Color(0.30, 0.34, 0.38)
		"operations", "cyber": return Color(0.12, 0.28, 0.38)
		"research": return Color(0.18, 0.24, 0.42)
		"archives": return Color(0.35, 0.27, 0.16)
		"service", "plant": return Color(0.32, 0.22, 0.18)
		"infrastructure": return Color(0.20, 0.22, 0.25)
		"egress": return Color(0.20, 0.38, 0.24)
		_: return Color(0.28, 0.28, 0.30)


func _service_color(kind: String) -> Color:
	match kind:
		"power": return Color(0.95, 0.70, 0.12)
		"cooling": return Color(0.15, 0.68, 0.92)
		"communications": return Color(0.72, 0.28, 0.92)
		"maintenance": return Color(0.88, 0.42, 0.16)
		_: return Color(0.75, 0.75, 0.75)


func _door_color(mode: String) -> Color:
	match mode:
		"alarmed_emergency_egress": return Color(0.22, 0.85, 0.32)
		"credentialed_interlock": return Color(0.82, 0.18, 0.15)
		"custody_transfer_interlock": return Color(0.90, 0.56, 0.12)
		"evidence_transfer_interlock": return Color(0.70, 0.32, 0.86)
		_: return Color(0.52, 0.58, 0.62)
