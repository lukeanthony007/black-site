class_name FacilityLayoutSolver
extends RefCounted
## Deterministic abstract grid solver. Converts operational meaning into placement;
## it does not build meshes or mutate the live scene.


func solve(graph: RefCounted) -> Dictionary:
	var profile: Dictionary = graph.generation_profile
	var floor_count: int = int(profile.get("floor_count", 2))
	var service_spine: String = str(profile.get("service_spine", "east"))
	var service_sign := 1 if service_spine == "east" else -1
	var archive_floor := 0 if floor_count == 2 else 1
	var cyber_floor := floor_count - 1
	var topology_variant := int(absi(int(graph.seed)) / 16) % 4
	var placements: Dictionary = {}

	# Entry sequence: exterior -> screened threshold -> controlled staff side.
	_place(graph, placements, "perimeter", 0, 0, -2)
	_place(graph, placements, "screened_entry", 0, 0, -1)
	_place(graph, placements, "staff_control", 0, 0, 0)
	_place(graph, placements, "security_control", 0, -service_sign, 0)

	# Screened service spine and archive custody sequence. Mirroring the X axis
	# changes the generated plan without changing institutional meaning.
	_place(graph, placements, "loading", archive_floor, service_sign * 6, 2)
	_place(graph, placements, "material_screening", archive_floor, service_sign * 5, 2)
	_place(graph, placements, "archive_accession", archive_floor, service_sign * 4, 2)
	_place(graph, placements, "quarantine", archive_floor, service_sign * 3, 2)
	_place(graph, placements, "archive_processing", archive_floor, service_sign * 2, 2)
	_place(graph, placements, "archive_stack", archive_floor, service_sign * 1, 2)

	# Plant and communication entry share the service side but remain separated
	# from received material.
	_place(graph, placements, "plant", 0, service_sign * 6, -2)
	_place(graph, placements, "communications_entry", 0, service_sign * 5, -2)

	# Cyber work occupies the most restricted generated floor.
	_place(graph, placements, "cyber_ops", cyber_floor, 0, 0)
	_place(graph, placements, "contained_lab", cyber_floor, -1, 0)
	_place(graph, placements, "compute_core", cyber_floor, 1, 0)
	_place(graph, placements, "emergency_exit", 0, 0, 3)

	var lab_offsets: Array[Vector2i]
	var archive_offsets: Array[Vector2i]
	match topology_variant:
		0:
			lab_offsets = [Vector2i(-2, 0), Vector2i(-2, 1)]
			archive_offsets = [Vector2i(1, 4), Vector2i(2, 4)]
		1:
			lab_offsets = [Vector2i(-1, -1), Vector2i(-2, -1)]
			archive_offsets = [Vector2i(2, 3), Vector2i(3, 3)]
		2:
			lab_offsets = [Vector2i(-2, 0), Vector2i(-3, 0)]
			archive_offsets = [Vector2i(1, 4), Vector2i(1, 5)]
		_:
			lab_offsets = [Vector2i(-1, 1), Vector2i(-2, 1)]
			archive_offsets = [Vector2i(3, 3), Vector2i(3, 4)]
	for lab_number in range(2, int(profile["contained_lab_count"]) + 1):
		var offset: Vector2i = lab_offsets[lab_number - 2]
		_place(graph, placements, "contained_lab_%02d" % lab_number, cyber_floor, offset.x, offset.y)
	for bay_number in range(2, int(profile["archive_bay_count"]) + 1):
		var offset: Vector2i = archive_offsets[bay_number - 2]
		_place(graph, placements, "archive_stack_%02d" % bay_number, archive_floor, service_sign * offset.x, offset.y)

	_place_remaining_rooms(graph, placements, floor_count)
	var vertical_links: Array[Dictionary] = _build_vertical_links(floor_count)
	return {
		"seed": graph.seed,
		"floor_count": floor_count,
		"service_spine": service_spine,
		"topology_variant": topology_variant,
		"placements": placements,
		"vertical_links": vertical_links,
	}


func validate_plan(graph: RefCounted, plan: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var placements: Dictionary = plan.get("placements", {})
	var floor_count: int = int(plan.get("floor_count", 0))
	if not graph.validate().is_empty():
		errors.append("source operational graph is invalid")
	if floor_count < 1:
		errors.append("layout has no floors")

	for room_id in graph.rooms:
		if not placements.has(room_id):
			errors.append("operational room is unplaced: %s" % room_id)
	for room_id in placements:
		if not graph.rooms.has(room_id):
			errors.append("layout contains unknown room: %s" % room_id)

	var occupied_cells: Dictionary = {}
	for room_id in placements:
		var placement: Dictionary = placements[room_id]
		var floor_index: int = int(placement.get("floor", -1))
		if floor_index < 0 or floor_index >= floor_count:
			errors.append("room %s is outside generated floors" % room_id)
		var cell_key := "%d:%d:%d" % [floor_index, int(placement.get("x", 0)), int(placement.get("z", 0))]
		if occupied_cells.has(cell_key):
			errors.append("rooms overlap at %s: %s and %s" % [cell_key, occupied_cells[cell_key], room_id])
		else:
			occupied_cells[cell_key] = room_id

	if placements.has("screened_entry") and placements.has("staff_control") and not are_adjacent(plan, "screened_entry", "staff_control"):
		errors.append("screened entry is not adjacent to staff control")
	for index in graph.MATERIAL_CUSTODY_CHAIN.size() - 1:
		var from_room: String = graph.MATERIAL_CUSTODY_CHAIN[index]
		var to_room: String = graph.MATERIAL_CUSTODY_CHAIN[index + 1]
		if placements.has(from_room) and placements.has(to_room) and not are_adjacent(plan, from_room, to_room):
			errors.append("custody adjacency is broken: %s -> %s" % [from_room, to_room])
	_validate_security_depth(plan, errors)
	_validate_vertical_circulation(plan, errors)
	return errors


func _build_vertical_links(floor_count: int) -> Array[Dictionary]:
	var links: Array[Dictionary] = []
	for floor_index in floor_count - 1:
		links.append({
			"from_floor": floor_index,
			"to_floor": floor_index + 1,
			"x": floor_index * 2,
			"z": 1,
			"kind": "secure_stair",
			"policy_transition": true,
			"egress_capable": true,
		})
	return links


func _validate_vertical_circulation(plan: Dictionary, errors: Array[String]) -> void:
	var floor_count: int = int(plan.get("floor_count", 0))
	var links: Array = plan.get("vertical_links", [])
	for floor_index in floor_count - 1:
		var found := false
		for link in links:
			if int(link.get("from_floor", -1)) == floor_index and int(link.get("to_floor", -1)) == floor_index + 1 and bool(link.get("egress_capable", false)):
				found = true
				break
		if not found:
			errors.append("vertical circulation missing between floors %d and %d" % [floor_index, floor_index + 1])


func _validate_security_depth(plan: Dictionary, errors: Array[String]) -> void:
	var placements: Dictionary = plan.get("placements", {})
	var room_ids: Array = placements.keys()
	for first_index in room_ids.size():
		var first_id: String = room_ids[first_index]
		var first: Dictionary = placements[first_id]
		for second_index in range(first_index + 1, room_ids.size()):
			var second_id: String = room_ids[second_index]
			var second: Dictionary = placements[second_id]
			if int(first["floor"]) != int(second["floor"]):
				continue
			var distance := absi(int(first["x"]) - int(second["x"])) + absi(int(first["z"]) - int(second["z"]))
			if distance != 1:
				continue
			var tier_gap := absi(int(first["security_tier"]) - int(second["security_tier"]))
			if tier_gap >= 3:
				errors.append("security depth collapse between %s and %s" % [first_id, second_id])


func are_adjacent(plan: Dictionary, first_room: String, second_room: String) -> bool:
	var placements: Dictionary = plan.get("placements", {})
	if not placements.has(first_room) or not placements.has(second_room):
		return false
	var first: Dictionary = placements[first_room]
	var second: Dictionary = placements[second_room]
	if int(first["floor"]) != int(second["floor"]):
		return false
	var distance := absi(int(first["x"]) - int(second["x"])) + absi(int(first["z"]) - int(second["z"]))
	return distance == 1


func fingerprint(plan: Dictionary) -> String:
	var placements: Dictionary = plan.get("placements", {})
	var room_ids: Array = placements.keys()
	room_ids.sort()
	var parts: Array[String] = [
		"seed=%d" % int(plan.get("seed", 0)),
		"floors=%d" % int(plan.get("floor_count", 0)),
		"service=%s" % str(plan.get("service_spine", "")),
		"topology=%d" % int(plan.get("topology_variant", 0)),
	]
	for room_id in room_ids:
		var placement: Dictionary = placements[room_id]
		parts.append("%s@%d,%d,%d" % [room_id, placement["floor"], placement["x"], placement["z"]])
	return "|".join(parts)


func _place(
	graph: RefCounted,
	placements: Dictionary,
	room_id: String,
	floor_index: int,
	x: int,
	z: int
) -> void:
	if not graph.rooms.has(room_id):
		return
	var room: Dictionary = graph.rooms[room_id]
	placements[room_id] = {
		"room_id": room_id,
		"floor": floor_index,
		"x": x,
		"z": z,
		"zone": room["zone"],
		"security_tier": room["security_tier"],
	}


func _place_remaining_rooms(graph: RefCounted, placements: Dictionary, floor_count: int) -> void:
	var room_ids: Array = graph.rooms.keys()
	room_ids.sort()
	for room_id in room_ids:
		if placements.has(room_id):
			continue
		var room: Dictionary = graph.rooms[room_id]
		var floor_index := _preferred_floor(str(room["zone"]), floor_count)
		var cell := _first_free_cell(placements, floor_index)
		_place(graph, placements, room_id, floor_index, cell.x, cell.y)


func _preferred_floor(zone: String, floor_count: int) -> int:
	if zone == "cyber" or zone == "research" or zone == "infrastructure":
		return floor_count - 1
	if zone == "archives" and floor_count > 2:
		return 1
	return 0


func _first_free_cell(placements: Dictionary, floor_index: int) -> Vector2i:
	for z in range(-4, 5):
		for x in range(-8, 9):
			var occupied := false
			for room_id in placements:
				var placement: Dictionary = placements[room_id]
				if int(placement["floor"]) == floor_index and int(placement["x"]) == x and int(placement["z"]) == z:
					occupied = true
					break
			if not occupied:
				return Vector2i(x, z)
	return Vector2i(0, 0)
