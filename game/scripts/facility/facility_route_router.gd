class_name FacilityRouteRouter
extends RefCounted
## Converts typed operational edges into abstract traversable routes and door
## policies. Emergency, custody, personnel, and infrastructure paths remain
## separate facts even when their geometric waypoints coincide.


func route(graph: RefCounted, plan: Dictionary) -> Dictionary:
	var routes: Array[Dictionary] = []
	var circulation_route_index := 0
	for edge in graph.circulation_edges:
		var flow: String = edge["flow"]
		var policy_transition: bool = bool(edge["policy_transition"])
		routes.append({
			"id": "circulation_%d" % circulation_route_index,
			"kind": "circulation",
			"from": edge["from"],
			"to": edge["to"],
			"flow": flow,
			"policy_transition": policy_transition,
			"door_mode": _door_mode(flow, policy_transition),
			"ordinary_access": flow == "personnel",
			"emergency_only": flow == "egress",
			"one_way": flow == "material" or flow == "evidence" or flow == "egress",
			"waypoints": _route_waypoints(plan, edge["from"], edge["to"]),
		})
		circulation_route_index += 1
	var service_route_index := 0
	for dependency in graph.dependency_edges:
		var dependency_kind: String = dependency["kind"]
		routes.append({
			"id": "service_%d" % service_route_index,
			"kind": "service",
			"from": dependency["provider"],
			"to": dependency["consumer"],
			"flow": "service_%s" % dependency_kind,
			"service_kind": dependency_kind,
			"policy_transition": true,
			"door_mode": "authorized_service",
			"ordinary_access": false,
			"emergency_only": false,
			"one_way": true,
			"waypoints": _route_waypoints(plan, dependency["provider"], dependency["consumer"]),
		})
		service_route_index += 1
	return {"routes": routes}


func validate_routes(graph: RefCounted, plan: Dictionary, route_plan: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var routes: Array = route_plan.get("routes", [])
	for edge in graph.circulation_edges:
		if not _has_route(routes, "circulation", edge["from"], edge["to"], edge["flow"]):
			errors.append("missing %s circulation route: %s -> %s" % [edge["flow"], edge["from"], edge["to"]])
	for dependency in graph.dependency_edges:
		if not _has_route(routes, "service", dependency["provider"], dependency["consumer"], "service_%s" % dependency["kind"]):
			errors.append("missing %s service route: %s -> %s" % [dependency["kind"], dependency["provider"], dependency["consumer"]])

	var route_ids: Dictionary = {}
	for route_data in routes:
		var route_item: Dictionary = route_data
		var route_id: String = route_item.get("id", "")
		if route_id.is_empty() or route_ids.has(route_id):
			errors.append("route id is empty or duplicated: %s" % route_id)
		else:
			route_ids[route_id] = true
		if not graph.rooms.has(route_item.get("from", "")) or not graph.rooms.has(route_item.get("to", "")):
			errors.append("route %s has unknown endpoint" % route_id)
		_validate_route_policy(route_item, errors)
		_validate_waypoints(plan, route_item, errors)
	return errors


func ordinary_room_path(route_plan: Dictionary, from_room: String, to_room: String) -> Array:
	var pending: Array[String] = [from_room]; var previous: Dictionary = {from_room: ""}
	while not pending.is_empty():
		var current: String = pending.pop_front()
		if current == to_room:
			var path: Array = []; var cursor: String = current
			while not cursor.is_empty(): path.push_front(cursor); cursor = previous[cursor]
			return path
		for route_value in route_plan.get("routes", []):
			var route: Dictionary = route_value
			if route.get("from", "") != current or route.get("flow", "") != "personnel" or not bool(route.get("ordinary_access", false)) or bool(route.get("emergency_only", false)): continue
			var next_room: String = route.get("to", "")
			if not previous.has(next_room): previous[next_room] = current; pending.append(next_room)
	return []

func has_ordinary_path(route_plan: Dictionary, from_room: String, to_room: String) -> bool:
	return _has_path(route_plan, from_room, to_room, false)


func has_emergency_path(route_plan: Dictionary, from_room: String, to_room: String) -> bool:
	return _has_path(route_plan, from_room, to_room, true)


func _has_path(route_plan: Dictionary, from_room: String, to_room: String, emergency_mode: bool) -> bool:
	var pending: Array[String] = [from_room]
	var visited: Dictionary = {from_room: true}
	var routes: Array = route_plan.get("routes", [])
	while not pending.is_empty():
		var current: String = pending.pop_front()
		if current == to_room:
			return true
		for route_data in routes:
			var route_item: Dictionary = route_data
			if route_item["from"] != current:
				continue
			if emergency_mode:
				if not bool(route_item["emergency_only"]):
					continue
			elif not bool(route_item["ordinary_access"]):
				continue
			var next_room: String = route_item["to"]
			if not visited.has(next_room):
				visited[next_room] = true
				pending.append(next_room)
	return false


func _route_waypoints(plan: Dictionary, from_room: String, to_room: String) -> Array[Dictionary]:
	var placements: Dictionary = plan.get("placements", {})
	var result: Array[Dictionary] = []
	if not placements.has(from_room) or not placements.has(to_room):
		return result
	var source: Dictionary = placements[from_room]
	var target: Dictionary = placements[to_room]
	var current_floor: int = int(source["floor"])
	var target_floor: int = int(target["floor"])
	var current_cell := Vector2i(int(source["x"]), int(source["z"]))
	var target_cell := Vector2i(int(target["x"]), int(target["z"]))
	var floor_step := 1 if target_floor > current_floor else -1
	while current_floor != target_floor:
		var link: Dictionary = _find_vertical_link(plan, current_floor, current_floor + floor_step)
		if link.is_empty():
			return []
		var stair_cell := Vector2i(int(link["x"]), int(link["z"]))
		var stair_segment: Array[Vector2i] = _grid_path(plan, current_floor, current_cell, stair_cell)
		if stair_segment.is_empty():
			return []
		_append_segment(result, current_floor, stair_segment)
		current_floor += floor_step
		result.append(_waypoint(current_floor, stair_cell.x, stair_cell.y))
		current_cell = stair_cell
	var final_segment: Array[Vector2i] = _grid_path(plan, current_floor, current_cell, target_cell)
	if final_segment.is_empty():
		return []
	_append_segment(result, current_floor, final_segment)
	return result


func _grid_path(
	plan: Dictionary,
	floor_index: int,
	start: Vector2i,
	goal: Vector2i
) -> Array[Vector2i]:
	if start == goal:
		return [start]
	var blocked: Dictionary = {}
	for placement_data in (plan.get("placements", {}) as Dictionary).values():
		var placement: Dictionary = placement_data
		if int(placement["floor"]) == floor_index:
			blocked[Vector2i(int(placement["x"]), int(placement["z"]))] = true
	blocked.erase(start)
	blocked.erase(goal)
	var pending: Array[Vector2i] = [start]
	var visited: Dictionary = {start: true}
	var previous: Dictionary = {}
	var directions: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
	while not pending.is_empty():
		var current: Vector2i = pending.pop_front()
		for direction in directions:
			var next := current + direction
			if next.x < -12 or next.x > 12 or next.y < -8 or next.y > 8:
				continue
			if blocked.has(next) or visited.has(next):
				continue
			visited[next] = true
			previous[next] = current
			if next == goal:
				return _reconstruct_grid_path(previous, start, goal)
			pending.append(next)
	return []


func _reconstruct_grid_path(previous: Dictionary, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [goal]
	var cursor: Vector2i = goal
	while cursor != start:
		if not previous.has(cursor):
			return []
		cursor = previous[cursor]
		path.push_front(cursor)
	return path


func _append_segment(result: Array[Dictionary], floor_index: int, cells: Array[Vector2i]) -> void:
	for cell in cells:
		var point := _waypoint(floor_index, cell.x, cell.y)
		if not result.is_empty() and result.back() == point:
			continue
		result.append(point)


func _find_vertical_link(plan: Dictionary, from_floor: int, to_floor: int) -> Dictionary:
	for link_data in plan.get("vertical_links", []):
		var link: Dictionary = link_data
		var low_floor: int = mini(int(link["from_floor"]), int(link["to_floor"]))
		var high_floor: int = maxi(int(link["from_floor"]), int(link["to_floor"]))
		if low_floor == mini(from_floor, to_floor) and high_floor == maxi(from_floor, to_floor):
			return link
	return {}


func _waypoint(floor_index: Variant, x: Variant, z: Variant) -> Dictionary:
	return {"floor": int(floor_index), "x": int(x), "z": int(z)}


func _door_mode(flow: String, policy_transition: bool) -> String:
	if flow == "egress":
		return "alarmed_emergency_egress"
	if flow == "material":
		return "custody_transfer_interlock"
	if flow == "evidence":
		return "evidence_transfer_interlock"
	if policy_transition:
		return "credentialed_interlock"
	return "open_internal"


func _has_route(routes: Array, kind: String, from_room: String, to_room: String, flow: String) -> bool:
	for route_data in routes:
		var route_item: Dictionary = route_data
		if route_item["kind"] == kind and route_item["from"] == from_room and route_item["to"] == to_room and route_item["flow"] == flow:
			return true
	return false


func _validate_route_policy(route_item: Dictionary, errors: Array[String]) -> void:
	var route_id: String = route_item["id"]
	var flow: String = route_item["flow"]
	if route_item["kind"] == "service":
		if bool(route_item["ordinary_access"]):
			errors.append("service route admits ordinary access: %s" % route_id)
		if route_item["door_mode"] != "authorized_service":
			errors.append("service route lacks authorized service boundary: %s" % route_id)
	if flow == "egress":
		if not bool(route_item["emergency_only"]) or bool(route_item["ordinary_access"]):
			errors.append("egress route admits ordinary access: %s" % route_id)
		if route_item["door_mode"] != "alarmed_emergency_egress":
			errors.append("egress route lacks alarmed emergency door: %s" % route_id)
	elif bool(route_item["emergency_only"]):
		errors.append("non-egress route marked emergency-only: %s" % route_id)
	if bool(route_item["policy_transition"]) and flow == "personnel" and route_item["door_mode"] != "credentialed_interlock":
		errors.append("personnel policy boundary lacks credentialed door: %s" % route_id)
	if (flow == "material" or flow == "evidence") and not bool(route_item["one_way"]):
		errors.append("custody transfer route is not one-way: %s" % route_id)


func _validate_waypoints(plan: Dictionary, route_item: Dictionary, errors: Array[String]) -> void:
	var waypoints: Array = route_item.get("waypoints", [])
	var route_id: String = route_item["id"]
	if waypoints.is_empty():
		errors.append("route has no traversable waypoints: %s" % route_id)
		return
	if waypoints.size() < 2 and route_item["from"] != route_item["to"]:
		errors.append("inter-room route has no traversable span: %s" % route_id)
		return
	var placements: Dictionary = plan.get("placements", {})
	var source: Dictionary = placements.get(route_item["from"], {})
	var target: Dictionary = placements.get(route_item["to"], {})
	if source.is_empty() or target.is_empty():
		return
	var first: Dictionary = waypoints.front()
	var last: Dictionary = waypoints.back()
	if int(first["floor"]) != int(source["floor"]) or int(first["x"]) != int(source["x"]) or int(first["z"]) != int(source["z"]):
		errors.append("route starts outside source room: %s" % route_id)
	if int(last["floor"]) != int(target["floor"]) or int(last["x"]) != int(target["x"]) or int(last["z"]) != int(target["z"]):
		errors.append("route ends outside target room: %s" % route_id)
	var occupied_by_room: Dictionary = {}
	for room_id in placements:
		if room_id == route_item["from"] or room_id == route_item["to"]:
			continue
		var placement: Dictionary = placements[room_id]
		var occupied_key := "%d:%d:%d" % [placement["floor"], placement["x"], placement["z"]]
		occupied_by_room[occupied_key] = room_id
	for waypoint_data in waypoints:
		var waypoint: Dictionary = waypoint_data
		var waypoint_key := "%d:%d:%d" % [waypoint["floor"], waypoint["x"], waypoint["z"]]
		if occupied_by_room.has(waypoint_key):
			errors.append("route %s crosses occupied room %s" % [route_id, occupied_by_room[waypoint_key]])
	for index in waypoints.size() - 1:
		var current: Dictionary = waypoints[index]
		var next: Dictionary = waypoints[index + 1]
		var floor_gap := absi(int(current["floor"]) - int(next["floor"]))
		var horizontal_gap := absi(int(current["x"]) - int(next["x"])) + absi(int(current["z"]) - int(next["z"]))
		if floor_gap == 0 and horizontal_gap != 1:
			errors.append("route has discontinuous horizontal waypoints: %s" % route_id)
		elif floor_gap > 1:
			errors.append("route jumps floors without vertical circulation: %s" % route_id)
		elif floor_gap == 1 and horizontal_gap != 0:
			errors.append("route changes floor outside a vertical shaft: %s" % route_id)
		elif floor_gap == 1 and _find_vertical_link(plan, int(current["floor"]), int(next["floor"])).is_empty():
			errors.append("route uses missing vertical circulation: %s" % route_id)
