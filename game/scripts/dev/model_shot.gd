extends Node3D
## Dev-only: renders guard + viewmodels, saves screenshots to /tmp, quits.

const SHOT_DIR := "/tmp/blacksite_shots"

var _cam: Camera3D


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.13, 0.14, 0.18)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.56, 0.62)
	e.ambient_light_energy = 0.8
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -35, 0)
	sun.light_energy = 1.0
	add_child(sun)

	_cam = Camera3D.new()
	_cam.fov = 55
	add_child(_cam)
	_cam.current = true

	var body: Node3D = load("res://scripts/world/n64_body.gd").new()
	add_child(body)

	await _snap(Vector3(1.3, 1.5, 2.4), Vector3(0, 1.0, 0), "guard_front")
	await _snap(Vector3(-1.3, 1.5, -2.4), Vector3(0, 1.0, 0), "guard_back")
	await _snap(Vector3(2.2, 1.2, 0.4), Vector3(0, 1.0, 0), "guard_side")
	await _snap(Vector3(0.9, 0.4, 1.6), Vector3(0, 1.3, 0), "guard_low")
	body.visible = false

	# First-person rig: camera fov 80, weapon offset as in player.tscn
	_cam.fov = 80.0
	var weapon := Node3D.new()
	weapon.position = Vector3(0.12, -0.26, -0.42)
	_cam.add_child(weapon)
	var vm: Node3D = load("res://scripts/combat/viewmodel.gd").new()
	weapon.add_child(vm)

	for entry: Array in [["vm_silenced", 1], ["vm_pistol", 0], ["vm_smg", 2], ["vm_rifle", 3]]:
		vm.rebuild(entry[1])
		# Keep camera at identity — weapon is parented in view space already.
		_cam.position = Vector3.ZERO
		_cam.rotation = Vector3.ZERO
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/%s.png" % [SHOT_DIR, entry[0]])
		print("shot: ", entry[0])

	get_tree().quit()


func _snap(cam_pos: Vector3, target: Vector3, shot_name: String) -> void:
	_cam.position = cam_pos
	_cam.look_at_from_position(cam_pos, target)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [SHOT_DIR, shot_name])
	print("shot: ", shot_name)
