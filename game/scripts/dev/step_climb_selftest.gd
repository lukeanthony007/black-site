extends Node


func _ready() -> void:
	print("STEPTEST begin")
	var root := Node3D.new()
	add_child(root)
	_box(root, Vector3(0, -0.15, 0), Vector3(40, 0.3, 40))
	for i in 10:
		var rise := 0.17
		var tread := 0.45
		var pos := Vector3(0, rise * (float(i) + 0.5), -1.0 - tread * (float(i) + 0.5))
		_box(root, pos, Vector3(2.0, rise, tread))

	var player: CharacterBody3D = load("res://scenes/player.tscn").instantiate()
	player.position = Vector3(0, 0.05, 0.5)
	player.set_physics_process(false)
	player.set_process(false)
	player.set_process_unhandled_input(false)
	root.add_child(player)
	await get_tree().physics_frame
	var cs: CollisionShape3D = player.get_node("CollisionShape3D")
	print("mask=%d layer=%d shape_disabled=%s shape=%s" % [
		player.collision_mask, player.collision_layer, str(cs.disabled), str(cs.shape)
	])
	for _i in 15:
		player.velocity = Vector3(0, -10, 0)
		player.move_and_slide()
		await get_tree().physics_frame
	print("settled y=%.3f floor=%s" % [player.global_position.y, str(player.is_on_floor())])

	# Walk into stairs reporting collisions
	for f in 80:
		player.velocity = Vector3(0, 0, -3.5)
		var before := player.global_position
		player.call("_move_with_step_up", Vector3(0, 0, -1))
		if f % 10 == 0:
			print("f=%d y=%.3f z=%.3f floor=%s wall=%s slides=%d" % [
				f, player.global_position.y, player.global_position.z,
				str(player.is_on_floor()), str(player.is_on_wall()),
				player.get_slide_collision_count()
			])
		await get_tree().physics_frame

	print("END y=%.3f z=%.3f" % [player.global_position.y, player.global_position.z])
	if player.global_position.y > 0.4:
		print("PASS climbed")
		get_tree().quit(0)
	else:
		print("FAIL no climb")
		get_tree().quit(1)


func _box(parent: Node, pos: Vector3, size: Vector3) -> void:
	var b := StaticBody3D.new()
	b.position = pos
	b.collision_layer = 1
	b.collision_mask = 0
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	c.shape = s
	b.add_child(c)
	# also mesh for debugging
	parent.add_child(b)
