extends Node
## Headless: route typed facility circulation and infrastructure paths.
## Run: godot --path . --headless res://scenes/dev_facility_route_selftest.tscn

var _fails: int = 0


func _ready() -> void:
	print("=== facility_route_selftest ===")
	_test_routes_cover_operations_without_egress_bypass()
	_test_service_route_cannot_become_personnel_bypass()
	_test_route_waypoints_are_contiguous()
	_test_route_cannot_cross_unrelated_room()
	print("=== facility_route_selftest done fails=%d ===" % _fails)
	await get_tree().process_frame
	get_tree().quit(0 if _fails == 0 else 1)


func _test_routes_cover_operations_without_egress_bypass() -> void:
	var router_path := "res://scripts/facility/facility_route_router.gd"
	if not ResourceLoader.exists(router_path):
		_fail("FacilityRouteRouter production script is missing")
		return
	var graph_script: Script = load("res://scripts/facility/facility_operation_graph.gd")
	var solver_script: Script = load("res://scripts/facility/facility_layout_solver.gd")
	var router_script: Script = load(router_path)
	if router_script == null or not router_script.can_instantiate():
		_fail("FacilityRouteRouter cannot instantiate")
		return
	var graph: RefCounted = graph_script.new()
	var solver: RefCounted = solver_script.new()
	var router: RefCounted = router_script.new()
	graph.configure_cyber_archives(7319)
	var plan: Dictionary = solver.solve(graph)
	var route_plan: Dictionary = router.route(graph, plan)
	var errors: Array[String] = router.validate_routes(graph, plan, route_plan)
	if not errors.is_empty():
		_fail("typed route plan invalid: %s" % "; ".join(errors))
		return
	if not router.has_emergency_path(route_plan, "cyber_ops", "emergency_exit"):
		_fail("cyber operations has no emergency path")
		return
	if router.has_ordinary_path(route_plan, "cyber_ops", "emergency_exit"):
		_fail("emergency egress became an ordinary access bypass")
		return
	_ok("routes cover operations without admitting egress bypass")


func _test_service_route_cannot_become_personnel_bypass() -> void:
	var graph_script: Script = load("res://scripts/facility/facility_operation_graph.gd")
	var solver_script: Script = load("res://scripts/facility/facility_layout_solver.gd")
	var router_script: Script = load("res://scripts/facility/facility_route_router.gd")
	var graph: RefCounted = graph_script.new()
	var solver: RefCounted = solver_script.new()
	var router: RefCounted = router_script.new()
	graph.configure_cyber_archives(7319)
	var plan: Dictionary = solver.solve(graph)
	var route_plan: Dictionary = router.route(graph, plan)
	for route_data in route_plan["routes"]:
		var route_item: Dictionary = route_data
		if route_item["kind"] == "service":
			route_item["ordinary_access"] = true
			break
	var errors: Array[String] = router.validate_routes(graph, plan, route_plan)
	var found := false
	for error in errors:
		if "service route admits ordinary access" in error:
			found = true
			break
	if not found:
		_fail("validator accepted infrastructure route as personnel bypass")
	else:
		_ok("service route cannot become personnel bypass")


func _test_route_waypoints_are_contiguous() -> void:
	var graph_script: Script = load("res://scripts/facility/facility_operation_graph.gd")
	var solver_script: Script = load("res://scripts/facility/facility_layout_solver.gd")
	var router_script: Script = load("res://scripts/facility/facility_route_router.gd")
	var graph: RefCounted = graph_script.new()
	var solver: RefCounted = solver_script.new()
	var router: RefCounted = router_script.new()
	graph.configure_cyber_archives(7319)
	var plan: Dictionary = solver.solve(graph)
	var route_plan: Dictionary = router.route(graph, plan)
	for route_data in route_plan["routes"]:
		var route_item: Dictionary = route_data
		var waypoints: Array = route_item["waypoints"]
		for index in waypoints.size() - 1:
			var current: Dictionary = waypoints[index]
			var next: Dictionary = waypoints[index + 1]
			var floor_gap := absi(int(current["floor"]) - int(next["floor"]))
			var horizontal_gap := absi(int(current["x"]) - int(next["x"])) + absi(int(current["z"]) - int(next["z"]))
			if (floor_gap == 0 and horizontal_gap != 1) or (floor_gap == 1 and horizontal_gap != 0) or floor_gap > 1:
				_fail("route %s contains discontinuous waypoint step" % route_item["id"])
				return
	_ok("route waypoints are contiguous")


func _test_route_cannot_cross_unrelated_room() -> void:
	var graph_script: Script = load("res://scripts/facility/facility_operation_graph.gd")
	var solver_script: Script = load("res://scripts/facility/facility_layout_solver.gd")
	var router_script: Script = load("res://scripts/facility/facility_route_router.gd")
	var graph: RefCounted = graph_script.new()
	var solver: RefCounted = solver_script.new()
	var router: RefCounted = router_script.new()
	graph.configure_cyber_archives(7319)
	var plan: Dictionary = solver.solve(graph)
	var route_plan: Dictionary = router.route(graph, plan)
	for route_data in route_plan["routes"]:
		var route_item: Dictionary = route_data
		if route_item["from"] == "staff_control" and route_item["to"] == "plant" and route_item["flow"] == "personnel":
			var security_cell: Dictionary = plan["placements"]["security_control"]
			route_item["waypoints"][1] = {
				"floor": security_cell["floor"],
				"x": security_cell["x"],
				"z": security_cell["z"],
			}
			break
	var errors: Array[String] = router.validate_routes(graph, plan, route_plan)
	var found := false
	for error in errors:
		if "crosses occupied room" in error:
			found = true
			break
	if not found:
		_fail("validator accepted route through unrelated room")
	else:
		_ok("route cannot cross unrelated room")


func _fail(msg: String) -> void:
	_fails += 1
	print("FAIL: ", msg)


func _ok(msg: String) -> void:
	print("OK: ", msg)
