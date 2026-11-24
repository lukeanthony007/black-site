extends Node
## Physics proof: the real player motor climbs a generated stair flight.


func _ready() -> void:
	print("=== facility_vertical_traversal_selftest ===")
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
		_fail("compiler returned null")
		return
	add_child(facility)
	var first_link: Dictionary = plan["vertical_links"][0]
	var player: CharacterBody3D = load("res://scenes/player.tscn").instantiate()
	player.position = Vector3(
		float(first_link["x"]) * compiler.CELL_SIZE,
		0.05,
		float(first_link["z"]) * compiler.CELL_SIZE - compiler.CELL_SIZE * 0.5 + 0.2
	)
	player.set_physics_process(false)
	player.set_process(false)
	player.set_process_unhandled_input(false)
	add_child(player)
	await get_tree().physics_frame
	for _settle in 12:
		player.velocity = Vector3(0, -10, 0)
		player.move_and_slide()
		await get_tree().physics_frame
	for _frame in 150:
		player.velocity = Vector3(0, 0, 3.5)
		player.call("_move_with_step_up", Vector3(0, 0, 1))
		await get_tree().physics_frame
	var target_height: float = float(first_link["to_floor"]) * float(compiler.FLOOR_HEIGHT)
	if player.global_position.y < target_height - 0.55:
		_fail("player failed to climb generated vertical core; y=%.2f target=%.2f" % [player.global_position.y, target_height])
	else:
		print("OK: real player motor climbed generated vertical core y=%.2f" % player.global_position.y)
		get_tree().quit(0)


func _fail(msg: String) -> void:
	print("FAIL: ", msg)
	get_tree().quit(1)
