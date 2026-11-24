extends Node
## Headless: solve and validate abstract Cyber/Archives floor plans.
## Run: godot --path . --headless res://scenes/dev_facility_layout_selftest.tscn

var _fails: int = 0


func _ready() -> void:
	print("=== facility_layout_selftest ===")
	_test_seeded_layout_places_valid_operational_graph()
	_test_layout_rejects_restricted_room_on_perimeter()
	_test_multifloor_layout_requires_vertical_circulation()
	_test_adjacent_vertical_links_use_distinct_shafts()
	_test_seeded_layouts_vary_topology_and_realize_requested_counts()
	print("=== facility_layout_selftest done fails=%d ===" % _fails)
	await get_tree().process_frame
	get_tree().quit(0 if _fails == 0 else 1)


func _test_seeded_layout_places_valid_operational_graph() -> void:
	var graph_path := "res://scripts/facility/facility_operation_graph.gd"
	var solver_path := "res://scripts/facility/facility_layout_solver.gd"
	if not ResourceLoader.exists(solver_path):
		_fail("FacilityLayoutSolver production script is missing")
		return
	var graph_script: Script = load(graph_path)
	var solver_script: Script = load(solver_path)
	if graph_script == null or not graph_script.can_instantiate():
		_fail("FacilityOperationGraph cannot instantiate")
		return
	if solver_script == null or not solver_script.can_instantiate():
		_fail("FacilityLayoutSolver cannot instantiate")
		return
	var graph: RefCounted = graph_script.new()
	var solver: RefCounted = solver_script.new()
	graph.configure_cyber_archives(7319)
	var plan: Dictionary = solver.solve(graph)
	var errors: Array[String] = solver.validate_plan(graph, plan)
	if not errors.is_empty():
		_fail("seeded layout invalid: %s" % "; ".join(errors))
		return
	if (plan.get("placements", {}) as Dictionary).size() != graph.rooms.size():
		_fail("layout did not place every operational room exactly once")
		return
	if not solver.are_adjacent(plan, "screened_entry", "staff_control"):
		_fail("screened entry is not adjacent to staff control")
		return
	for index in graph.MATERIAL_CUSTODY_CHAIN.size() - 1:
		var from_room: String = graph.MATERIAL_CUSTODY_CHAIN[index]
		var to_room: String = graph.MATERIAL_CUSTODY_CHAIN[index + 1]
		if not solver.are_adjacent(plan, from_room, to_room):
			_fail("custody rooms are not adjacent: %s -> %s" % [from_room, to_room])
			return
	_ok("seeded layout places and validates the operational graph")


func _test_layout_rejects_restricted_room_on_perimeter() -> void:
	var graph_script: Script = load("res://scripts/facility/facility_operation_graph.gd")
	var solver_script: Script = load("res://scripts/facility/facility_layout_solver.gd")
	var graph: RefCounted = graph_script.new()
	var solver: RefCounted = solver_script.new()
	graph.configure_cyber_archives(7319)
	var plan: Dictionary = solver.solve(graph)
	var placements: Dictionary = plan["placements"]
	placements["cyber_ops"]["floor"] = 0
	placements["cyber_ops"]["x"] = 1
	placements["cyber_ops"]["z"] = -2
	var errors: Array[String] = solver.validate_plan(graph, plan)
	var found := false
	for error in errors:
		if "security depth" in error:
			found = true
			break
	if not found:
		_fail("validator accepted restricted cyber room against perimeter")
	else:
		_ok("layout rejects restricted room on perimeter")


func _test_multifloor_layout_requires_vertical_circulation() -> void:
	var graph_script: Script = load("res://scripts/facility/facility_operation_graph.gd")
	var solver_script: Script = load("res://scripts/facility/facility_layout_solver.gd")
	var graph: RefCounted = graph_script.new()
	var solver: RefCounted = solver_script.new()
	graph.configure_cyber_archives(7319) # odd seed produces three floors
	var plan: Dictionary = solver.solve(graph)
	var floor_count: int = int(plan["floor_count"])
	var vertical_links: Array = plan.get("vertical_links", [])
	if vertical_links.size() < floor_count - 1:
		_fail("multifloor layout lacks vertical circulation links")
		return
	plan["vertical_links"] = []
	var errors: Array[String] = solver.validate_plan(graph, plan)
	var found := false
	for error in errors:
		if "vertical circulation" in error:
			found = true
			break
	if not found:
		_fail("validator accepted disconnected generated floors")
	else:
		_ok("multifloor layout requires vertical circulation")


func _test_adjacent_vertical_links_use_distinct_shafts() -> void:
	var graph_script: Script = load("res://scripts/facility/facility_operation_graph.gd")
	var solver_script: Script = load("res://scripts/facility/facility_layout_solver.gd")
	var graph: RefCounted = graph_script.new()
	var solver: RefCounted = solver_script.new()
	graph.configure_cyber_archives(7319)
	var plan: Dictionary = solver.solve(graph)
	var links: Array = plan["vertical_links"]
	for index in links.size() - 1:
		var current: Dictionary = links[index]
		var next: Dictionary = links[index + 1]
		if int(current["x"]) == int(next["x"]) and int(current["z"]) == int(next["z"]):
			_fail("adjacent floor links stack in one unusable shaft cell")
			return
	_ok("adjacent vertical links use distinct shaft cells")


func _test_seeded_layouts_vary_topology_and_realize_requested_counts() -> void:
	var graph_script: Script = load("res://scripts/facility/facility_operation_graph.gd")
	var solver_script: Script = load("res://scripts/facility/facility_layout_solver.gd")
	var solver: RefCounted = solver_script.new()
	var topology_signatures: Dictionary = {}
	var topologies_by_profile_bucket: Dictionary = {}
	for seed in 64:
		var graph: RefCounted = graph_script.new()
		var replay_graph: RefCounted = graph_script.new()
		graph.configure_cyber_archives(seed)
		replay_graph.configure_cyber_archives(seed)
		var plan: Dictionary = solver.solve(graph)
		var replay_plan: Dictionary = solver.solve(replay_graph)
		if solver.fingerprint(plan) != solver.fingerprint(replay_plan):
			_fail("same seed produced different layout fingerprints: %d" % seed)
			return
		var errors: Array[String] = solver.validate_plan(graph, plan)
		if not errors.is_empty():
			_fail("seeded layout invalid for %d: %s" % [seed, "; ".join(errors)])
			return
		var placements: Dictionary = plan.get("placements", {})
		if placements.size() != graph.rooms.size():
			_fail("layout dropped operational rooms for seed %d" % seed)
			return
		for room_id in graph.rooms:
			if not placements.has(room_id):
				_fail("layout missing operational room %s for seed %d" % [room_id, seed])
				return
		var requested_labs: int = int(graph.generation_profile["contained_lab_count"])
		var requested_bays: int = int(graph.generation_profile["archive_bay_count"])
		var graph_labs := 0
		var graph_bays := 0
		for room_id in graph.rooms:
			var room_name := str(room_id)
			if room_name == "contained_lab" or room_name.begins_with("contained_lab_"):
				graph_labs += 1
			if room_name == "archive_stack" or room_name.begins_with("archive_stack_"):
				graph_bays += 1
		var plan_labs := 0
		var plan_bays := 0
		for room_id in placements:
			var placed_name := str(room_id)
			if placed_name == "contained_lab" or placed_name.begins_with("contained_lab_"):
				plan_labs += 1
			if placed_name == "archive_stack" or placed_name.begins_with("archive_stack_"):
				plan_bays += 1
		if graph_labs != requested_labs or plan_labs != requested_labs:
			_fail(
				"contained_lab_count not realized for seed %d: requested=%d graph=%d plan=%d"
				% [seed, requested_labs, graph_labs, plan_labs]
			)
			return
		if graph_bays != requested_bays or plan_bays != requested_bays:
			_fail(
				"archive_bay_count not realized for seed %d: requested=%d graph=%d plan=%d"
				% [seed, requested_bays, graph_bays, plan_bays]
			)
			return
		var room_ids: Array = placements.keys()
		room_ids.sort()
		var placement_parts: Array[String] = []
		var adjacency_parts: Array[String] = []
		for room_id in room_ids:
			var placement: Dictionary = placements[room_id]
			placement_parts.append(
				"%s@%d,%d,%d" % [room_id, int(placement["floor"]), int(placement["x"]), int(placement["z"])]
			)
		for first_index in room_ids.size():
			var first_id: String = room_ids[first_index]
			for second_index in range(first_index + 1, room_ids.size()):
				var second_id: String = room_ids[second_index]
				if solver.are_adjacent(plan, first_id, second_id):
					adjacency_parts.append("%s#%s" % [first_id, second_id])
		var topology_signature := "places=%s;adj=%s" % [
			"|".join(placement_parts),
			"|".join(adjacency_parts),
		]
		topology_signatures[topology_signature] = true
		# Hold floor/service and requested counts fixed so signature diversity is
		# true placement/adjacency topology, not profile cardinality alone.
		var profile_bucket := "%d|%s|labs=%d|bays=%d" % [
			int(plan["floor_count"]),
			str(plan["service_spine"]),
			requested_labs,
			requested_bays,
		]
		if not topologies_by_profile_bucket.has(profile_bucket):
			topologies_by_profile_bucket[profile_bucket] = {}
		(topologies_by_profile_bucket[profile_bucket] as Dictionary)[topology_signature] = true
	if topology_signatures.size() <= 1:
		_fail("solver returned one fixed topology across deterministic seed sample")
		return
	var varied_beyond_floor_service := false
	for profile_bucket in topologies_by_profile_bucket:
		if (topologies_by_profile_bucket[profile_bucket] as Dictionary).size() > 1:
			varied_beyond_floor_service = true
			break
	if not varied_beyond_floor_service:
		_fail("topology variation collapsed to floor count/service side only")
		return
	_ok("seeded layouts vary topology and realize requested lab/archive counts")


func _fail(msg: String) -> void:
	_fails += 1
	print("FAIL: ", msg)


func _ok(msg: String) -> void:
	print("OK: ", msg)
