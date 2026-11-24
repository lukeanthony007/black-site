extends Node
## Headless: compile validated facility manifests into Godot geometry.
## Run: godot --path . --headless res://scenes/dev_facility_geometry_selftest.tscn

var _fails: int = 0


func _ready() -> void:
	print("=== facility_geometry_selftest ===")
	_test_compiler_emits_provenance_backed_geometry()
	_test_compiler_rejects_corrupt_route_manifest()
	_test_compiler_emits_enclosures_and_functional_policy_doors()
	_test_vertical_core_has_steps_and_clear_apertures()
	_test_corridor_cells_have_boundary_enclosure()
	_test_equipment_geometry_matches_operational_graph()
	_test_equipment_visual_state_tracks_service_loss()
	await _test_adjacent_circulation_floors_are_continuous()
	print("=== facility_geometry_selftest done fails=%d ===" % _fails)
	await get_tree().process_frame
	get_tree().quit(0 if _fails == 0 else 1)


func _test_compiler_emits_provenance_backed_geometry() -> void:
	var compiler_path := "res://scripts/facility/facility_geometry_compiler.gd"
	if not ResourceLoader.exists(compiler_path):
		_fail("FacilityGeometryCompiler production script is missing")
		return
	var graph_script: Script = load("res://scripts/facility/facility_operation_graph.gd")
	var solver_script: Script = load("res://scripts/facility/facility_layout_solver.gd")
	var router_script: Script = load("res://scripts/facility/facility_route_router.gd")
	var compiler_script: Script = load(compiler_path)
	if compiler_script == null or not compiler_script.can_instantiate():
		_fail("FacilityGeometryCompiler cannot instantiate")
		return
	var graph: RefCounted = graph_script.new()
	var solver: RefCounted = solver_script.new()
	var router: RefCounted = router_script.new()
	var compiler: RefCounted = compiler_script.new()
	graph.configure_cyber_archives(7319)
	var plan: Dictionary = solver.solve(graph)
	var route_plan: Dictionary = router.route(graph, plan)
	var facility: Node3D = compiler.compile(graph, plan, route_plan)
	if facility == null:
		_fail("compiler returned null")
		return
	add_child(facility)
	for group_name in ["Rooms", "Circulation", "Doors", "Service", "VerticalLinks"]:
		if facility.get_node_or_null(group_name) == null:
			_fail("compiled facility missing %s group" % group_name)
			return
	var rooms: Node = facility.get_node("Rooms")
	if rooms.get_child_count() != graph.rooms.size():
		_fail("compiled room count does not match operational graph")
		return
	for room_node in rooms.get_children():
		if not room_node.has_meta("room_id") or not room_node.has_meta("zone") or not room_node.has_meta("security_tier"):
			_fail("compiled room lost operational provenance")
			return
		if room_node.get_node_or_null("FloorBody/CollisionShape3D") == null:
			_fail("compiled room lacks floor collision")
			return
	var service: Node = facility.get_node("Service")
	for service_node in service.get_children():
		if service_node is CollisionObject3D:
			_fail("service conduit became walkable collision geometry")
			return
	if int(facility.get_meta("seed", -1)) != graph.seed:
		_fail("compiled facility lost generation seed")
		return
	_ok("compiler emits provenance-backed collidable geometry")


func _test_compiler_rejects_corrupt_route_manifest() -> void:
	var graph_script: Script = load("res://scripts/facility/facility_operation_graph.gd")
	var solver_script: Script = load("res://scripts/facility/facility_layout_solver.gd")
	var router_script: Script = load("res://scripts/facility/facility_route_router.gd")
	var compiler_script: Script = load("res://scripts/facility/facility_geometry_compiler.gd")
	var graph: RefCounted = graph_script.new()
	var solver: RefCounted = solver_script.new()
	var router: RefCounted = router_script.new()
	var compiler: RefCounted = compiler_script.new()
	graph.configure_cyber_archives(7319)
	var plan: Dictionary = solver.solve(graph)
	var route_plan: Dictionary = router.route(graph, plan)
	route_plan["routes"] = (route_plan["routes"] as Array).filter(func(route_item: Dictionary) -> bool:
		return route_item["flow"] != "egress"
	)
	var facility: Node3D = compiler.compile(graph, plan, route_plan)
	if facility != null:
		facility.free()
		_fail("compiler accepted route manifest with no emergency egress")
	else:
		_ok("compiler rejects corrupt route manifest")


func _test_compiler_emits_enclosures_and_functional_policy_doors() -> void:
	var graph_script: Script = load("res://scripts/facility/facility_operation_graph.gd")
	var solver_script: Script = load("res://scripts/facility/facility_layout_solver.gd")
	var router_script: Script = load("res://scripts/facility/facility_route_router.gd")
	var compiler_script: Script = load("res://scripts/facility/facility_geometry_compiler.gd")
	var graph: RefCounted = graph_script.new()
	var solver: RefCounted = solver_script.new()
	var router: RefCounted = router_script.new()
	var compiler: RefCounted = compiler_script.new()
	graph.configure_cyber_archives(7319)
	var plan: Dictionary = solver.solve(graph)
	var route_plan: Dictionary = router.route(graph, plan)
	var facility: Node3D = compiler.compile(graph, plan, route_plan)
	if facility == null:
		_fail("compiler returned null for enclosure test")
		return
	add_child(facility)
	for room_node in facility.get_node("Rooms").get_children():
		var walls: Node = room_node.get_node_or_null("Walls")
		if walls == null or walls.get_child_count() == 0:
			_fail("compiled room lacks architectural enclosure")
			facility.queue_free()
			return
		if room_node.get_node_or_null("RoofBody/CollisionShape3D") == null:
			_fail("compiled room lacks roof enclosure")
			facility.queue_free()
			return
		var room_light: OmniLight3D = room_node.get_node_or_null("RoomLight") as OmniLight3D
		if room_light == null:
			_fail("compiled room lacks ceiling RoomLight")
			facility.queue_free()
			return
		if room_light.light_energy <= 0.0 or room_light.omni_range <= 0.0:
			_fail("compiled room light has no usable energy/range")
			facility.queue_free()
			return
		var roof_body: StaticBody3D = room_node.get_node_or_null("RoofBody") as StaticBody3D
		var roof_collision: CollisionShape3D = roof_body.get_node_or_null("CollisionShape3D") as CollisionShape3D
		var roof_shape: BoxShape3D = roof_collision.shape as BoxShape3D
		var threshold_count := 0
		for room_child in room_node.get_children():
			if str(room_child.name).begins_with("Threshold_"):
				threshold_count += 1
		var lintel_count := 0
		var roof_bottom := roof_body.position.y - roof_shape.size.y * 0.5
		for wall_child in walls.get_children():
			var wall_body: StaticBody3D = wall_child as StaticBody3D
			var wall_collision: CollisionShape3D = wall_body.get_node_or_null("CollisionShape3D") as CollisionShape3D
			var wall_shape: BoxShape3D = wall_collision.shape as BoxShape3D
			if not is_equal_approx(wall_body.position.y + wall_shape.size.y * 0.5, roof_bottom):
				_fail("compiled room wall does not meet roof enclosure")
				facility.queue_free()
				return
			if str(wall_body.name).ends_with("_Lintel"):
				lintel_count += 1
		if lintel_count != threshold_count:
			_fail("compiled doorway opening lacks roof-connected lintel")
			facility.queue_free()
			return
	var corridor_lights := 0
	for child in facility.get_node("Circulation").get_children():
		if child is OmniLight3D and str(child.name).begins_with("CorridorLight_"):
			corridor_lights += 1
	if corridor_lights == 0:
		_fail("compiled circulation lacks corridor ceiling lights")
		facility.queue_free()
		return
	var found_emergency := false
	var found_credentialed := false
	var found_destination_owned_custody := false
	for door_node in facility.get_node("Doors").get_children():
		if not door_node.has_method("request_open") or not door_node.has_method("interact") or door_node.get_node_or_null("CollisionShape3D") == null:
			_fail("compiled policy door is not functional collision geometry")
			facility.queue_free()
			return
		var mode: String = door_node.get_meta("door_mode")
		if mode == "alarmed_emergency_egress" and not found_emergency:
			found_emergency = true
			if door_node.request_open({"clearance_tier": 5}, false):
				_fail("emergency door opened as ordinary access")
				facility.queue_free()
				return
			if not door_node.request_open({}, true):
				_fail("emergency door refused emergency release")
				facility.queue_free()
				return
			door_node.close_door()
		elif mode == "credentialed_interlock" and not found_credentialed:
			found_credentialed = true
			var allowed_roles: Array = door_node.get_meta("required_roles", [])
			if allowed_roles.is_empty():
				_fail("credentialed door has no destination access policy")
				facility.queue_free()
				return
			if door_node.request_open({"clearance_tier": 0, "roles": [allowed_roles[0]]}, false):
				_fail("credentialed door accepted insufficient clearance")
				facility.queue_free()
				return
			if door_node.request_open({"clearance_tier": 5, "roles": []}, false):
				_fail("credentialed door accepted clearance without destination role")
				facility.queue_free()
				return
			if not door_node.request_open({"clearance_tier": 5, "roles": [allowed_roles[0]]}, false):
				_fail("credentialed door rejected sufficient clearance and role")
				facility.queue_free()
				return
			door_node.close_door()
		elif mode == "custody_transfer_interlock" and door_node.get_meta("from_room", "") == "loading" and door_node.get_meta("to_room", "") == "material_screening":
			found_destination_owned_custody = true
			if door_node.request_open({"roles": ["archive_custodian"]}, false):
				_fail("custody door accepted a role that does not own destination screening")
				facility.queue_free()
				return
			if not door_node.request_open({"roles": ["security_officer"]}, false):
				_fail("custody door rejected destination screening owner")
				facility.queue_free()
				return
			door_node.close_door()
	if not found_emergency or not found_credentialed or not found_destination_owned_custody:
		_fail("compiled facility lacks required policy-door modes and ownership")
	else:
		_ok("compiler emits enclosures and functional policy doors")
	facility.queue_free()


func _test_vertical_core_has_steps_and_clear_apertures() -> void:
	var graph_script: Script = load("res://scripts/facility/facility_operation_graph.gd")
	var solver_script: Script = load("res://scripts/facility/facility_layout_solver.gd")
	var router_script: Script = load("res://scripts/facility/facility_route_router.gd")
	var compiler_script: Script = load("res://scripts/facility/facility_geometry_compiler.gd")
	var graph: RefCounted = graph_script.new()
	var solver: RefCounted = solver_script.new()
	var router: RefCounted = router_script.new()
	var compiler: RefCounted = compiler_script.new()
	graph.configure_cyber_archives(7319)
	var plan: Dictionary = solver.solve(graph)
	var route_plan: Dictionary = router.route(graph, plan)
	var facility: Node3D = compiler.compile(graph, plan, route_plan)
	if facility == null:
		_fail("compiler returned null for vertical-core test")
		return
	add_child(facility)
	var aperture_cells: Dictionary = {}
	for link in plan["vertical_links"]:
		aperture_cells["%d:%d:%d" % [link["from_floor"], link["x"], link["z"]]] = true
		aperture_cells["%d:%d:%d" % [link["to_floor"], link["x"], link["z"]]] = true
	for corridor in facility.get_node("Circulation").get_children():
		if aperture_cells.has(corridor.get_meta("cell", "")):
			_fail("circulation slab blocks vertical shaft aperture")
			facility.queue_free()
			return
	for vertical_link in facility.get_node("VerticalLinks").get_children():
		var ramp := vertical_link.get_node_or_null("StairRamp")
		if ramp == null or not ramp is StaticBody3D or ramp.get_node_or_null("CollisionShape3D") == null:
			_fail("vertical link lacks walkable stair ramp collision")
			facility.queue_free()
			return
		if vertical_link.get_node_or_null("Landing_Bottom") == null or vertical_link.get_node_or_null("Landing_Top") == null:
			_fail("vertical link lacks top/bottom landings")
			facility.queue_free()
			return
		var steps := vertical_link.get_node_or_null("Steps")
		if steps == null or steps.get_child_count() < 8:
			_fail("vertical link lacks visible stair treads")
			facility.queue_free()
			return
	_ok("vertical core has walkable ramp, landings, and clear apertures")
	facility.queue_free()


func _test_corridor_cells_have_boundary_enclosure() -> void:
	var graph_script: Script = load("res://scripts/facility/facility_operation_graph.gd")
	var solver_script: Script = load("res://scripts/facility/facility_layout_solver.gd")
	var router_script: Script = load("res://scripts/facility/facility_route_router.gd")
	var compiler_script: Script = load("res://scripts/facility/facility_geometry_compiler.gd")
	var graph: RefCounted = graph_script.new()
	var solver: RefCounted = solver_script.new()
	var router: RefCounted = router_script.new()
	var compiler: RefCounted = compiler_script.new()
	graph.configure_cyber_archives(7319)
	var plan: Dictionary = solver.solve(graph)
	var route_plan: Dictionary = router.route(graph, plan)
	var facility: Node3D = compiler.compile(graph, plan, route_plan)
	if facility == null:
		_fail("compiler returned null for corridor enclosure test")
		return
	add_child(facility)
	var walls := facility.get_node_or_null("Circulation/Walls")
	if walls == null or walls.get_child_count() == 0:
		_fail("generated corridors lack boundary enclosure")
		facility.queue_free()
		return
	for wall in walls.get_children():
		if not wall is StaticBody3D or wall.get_node_or_null("CollisionShape3D") == null:
			_fail("corridor boundary wall lacks collision")
			facility.queue_free()
			return
	_ok("corridor cells have colliding boundary enclosure")
	facility.queue_free()


func _test_equipment_geometry_matches_operational_graph() -> void:
	var graph_script: Script = load("res://scripts/facility/facility_operation_graph.gd")
	var solver_script: Script = load("res://scripts/facility/facility_layout_solver.gd")
	var router_script: Script = load("res://scripts/facility/facility_route_router.gd")
	var compiler_script: Script = load("res://scripts/facility/facility_geometry_compiler.gd")
	var graph: RefCounted = graph_script.new()
	var solver: RefCounted = solver_script.new()
	var router: RefCounted = router_script.new()
	var compiler: RefCounted = compiler_script.new()
	graph.configure_cyber_archives(7319)
	var plan: Dictionary = solver.solve(graph)
	var route_plan: Dictionary = router.route(graph, plan)
	var facility: Node3D = compiler.compile(graph, plan, route_plan)
	if facility == null:
		_fail("compiler returned null for equipment test")
		return
	add_child(facility)
	var equipment_group := facility.get_node_or_null("Equipment")
	if equipment_group == null or equipment_group.get_child_count() != graph.equipment.size():
		_fail("compiled equipment count does not match operational graph")
		facility.queue_free()
		return
	for equipment_node in equipment_group.get_children():
		var equipment_id: String = equipment_node.get_meta("equipment_id", "")
		if not graph.equipment.has(equipment_id):
			_fail("compiled unknown equipment")
			facility.queue_free()
			return
		var item: Dictionary = graph.equipment[equipment_id]
		if equipment_node.get_meta("room", "") != item["room"] or equipment_node.get_meta("owner_job", "") != item["owner_job"]:
			_fail("compiled equipment lost station ownership")
			facility.queue_free()
			return
		if equipment_node.get_node_or_null("MeshInstance3D") == null:
			_fail("compiled equipment lacks visible geometry")
			facility.queue_free()
			return
	_ok("equipment geometry matches operational graph")
	facility.queue_free()


func _test_equipment_visual_state_tracks_service_loss() -> void:
	var graph_script: Script = load("res://scripts/facility/facility_operation_graph.gd")
	var solver_script: Script = load("res://scripts/facility/facility_layout_solver.gd")
	var router_script: Script = load("res://scripts/facility/facility_route_router.gd")
	var compiler_script: Script = load("res://scripts/facility/facility_geometry_compiler.gd")
	var graph: RefCounted = graph_script.new()
	var solver: RefCounted = solver_script.new()
	var router: RefCounted = router_script.new()
	var compiler: RefCounted = compiler_script.new()
	graph.configure_cyber_archives(7319)
	var plan: Dictionary = solver.solve(graph)
	var route_plan: Dictionary = router.route(graph, plan)
	var facility: Node3D = compiler.compile(graph, plan, route_plan)
	if facility == null:
		_fail("compiler returned null for degraded equipment test")
		return
	add_child(facility)
	var bench: Node = null
	var authorization_console: Node = null
	for equipment_node in facility.get_node("Equipment").get_children():
		if equipment_node.get_meta("equipment_id", "") == "contained_analysis_bench":
			bench = equipment_node
		elif equipment_node.get_meta("equipment_id", "") == "access_authorization_console":
			authorization_console = equipment_node
	if bench == null or authorization_console == null or not bench.has_method("set_service_available"):
		_fail("compiled equipment has no runtime service state")
		facility.queue_free()
		return
	bench.set_service_available("cooling", false)
	if bench.is_operational() or not authorization_console.is_operational():
		_fail("cooling loss degraded wrong equipment set")
		facility.queue_free()
		return
	if bench.get_meta("visual_state", "") != "degraded":
		_fail("affected equipment did not expose degraded visual state")
		facility.queue_free()
		return
	bench.set_service_available("cooling", true)
	if not bench.is_operational() or bench.get_meta("visual_state", "") != "operational":
		_fail("equipment did not recover after service restoration")
		facility.queue_free()
		return
	_ok("equipment visual state tracks service loss and recovery")
	facility.queue_free()


func _test_adjacent_circulation_floors_are_continuous() -> void:
	var graph_script: Script = load("res://scripts/facility/facility_operation_graph.gd")
	var solver_script: Script = load("res://scripts/facility/facility_layout_solver.gd")
	var router_script: Script = load("res://scripts/facility/facility_route_router.gd")
	var compiler_script: Script = load("res://scripts/facility/facility_geometry_compiler.gd")
	var graph: RefCounted = graph_script.new()
	var solver: RefCounted = solver_script.new()
	var router: RefCounted = router_script.new()
	var compiler: RefCounted = compiler_script.new()
	graph.configure_cyber_archives(7319)
	var plan: Dictionary = solver.solve(graph)
	var route_plan: Dictionary = router.route(graph, plan)
	var facility: Node3D = compiler.compile(graph, plan, route_plan)
	if facility == null:
		_fail("compiler returned null for floor continuity test")
		return
	add_child(facility)
	await get_tree().process_frame
	await get_tree().physics_frame
	var cell_size: float = 7.0
	var room_size: float = 7.0
	if compiler.get_script() != null:
		# Prefer live constants from the compiler resource when available.
		var constants: Dictionary = compiler.get_script().get_script_constant_map()
		cell_size = float(constants.get("CELL_SIZE", cell_size))
		room_size = float(constants.get("ROOM_SIZE", room_size))
	if room_size + 0.001 < cell_size:
		_fail("room floors still smaller than grid cells; doorway voids will remain")
		facility.queue_free()
		return
	var space: PhysicsDirectSpaceState3D = get_viewport().world_3d.direct_space_state
	var samples: int = 0
	var missing: Array[String] = []
	for route_data in route_plan.get("routes", []):
		var route_item: Dictionary = route_data
		if route_item.get("kind", "") != "circulation" or route_item.get("flow", "") != "personnel":
			continue
		var waypoints: Array = route_item.get("waypoints", [])
		for index in waypoints.size() - 1:
			var a: Dictionary = waypoints[index]
			var b: Dictionary = waypoints[index + 1]
			if int(a.get("floor", 0)) != int(b.get("floor", 0)):
				continue
			var ax: float = float(a["x"]) * cell_size
			var az: float = float(a["z"]) * cell_size
			var bx: float = float(b["x"]) * cell_size
			var bz: float = float(b["z"]) * cell_size
			var y: float = float(a["floor"]) * 4.5 + 0.05
			# Prefer side-of-stair walk lanes when probing shaft cells so rays don't drop through the open stair run.
			var sample_offsets: Array[Vector3] = [Vector3.ZERO, Vector3(1.8, 0.0, 0.0), Vector3(-1.8, 0.0, 0.0)]
			for t in [0.0, 0.25, 0.5, 0.75, 1.0]:
				var base := Vector3(lerpf(ax, bx, t), y + 2.0, lerpf(az, bz, t))
				var hit_any: bool = false
				for offset in sample_offsets:
					var sample: Vector3 = base + offset
					var query := PhysicsRayQueryParameters3D.create(sample, sample + Vector3(0.0, -4.0, 0.0))
					query.collision_mask = 1
					var hit: Dictionary = space.intersect_ray(query)
					if not hit.is_empty():
						hit_any = true
						break
				samples += 1
				if not hit_any:
					missing.append("%s@%s" % [route_item.get("id", "?"), base])
					if missing.size() >= 8:
						break
			if missing.size() >= 8:
				break
		if missing.size() >= 8:
			break
	if samples == 0:
		_fail("no personnel floor samples collected")
		facility.queue_free()
		return
	if not missing.is_empty():
		_fail("walkable floor missing on personnel routes: %s" % ", ".join(missing))
		facility.queue_free()
		return
	_ok("adjacent personnel circulation floors are continuous under ray probes")
	facility.queue_free()


func _fail(msg: String) -> void:
	_fails += 1
	print("FAIL: ", msg)


func _ok(msg: String) -> void:
	print("OK: ", msg)
