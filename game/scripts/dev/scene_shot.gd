extends Node
## Dev-only: boots the real level, screenshots a few camera vantages, quits.

const SHOT_DIR := "/tmp/blacksite_shots"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	for i in 20:
		await get_tree().process_frame
	var cam := get_viewport().get_camera_3d()
	await _snap("scene_spawn")
	# Keep camera looking forward — don't re-aim (warps viewmodel perception)
	await _snap("scene_hall")
	get_tree().quit()


func _snap(shot_name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var cam := get_viewport().get_camera_3d()
	var gun := get_node_or_null("Main/Player/CameraPivot/Camera3D/Weapon/Viewmodel/Gun")
	if cam and gun:
		var tip_pt: Vector3 = gun.to_global(Vector3(0, 0.05, -0.25))
		var grip_pt: Vector3 = gun.to_global(Vector3(0, -0.02, 0))
		var tip_sp: Vector2 = cam.unproject_position(tip_pt)
		var grip_sp: Vector2 = cam.unproject_position(grip_pt)
		var vp := get_viewport().get_visible_rect().size
		var tip_ndc := Vector2(tip_sp.x / vp.x, tip_sp.y / vp.y)
		var grip_ndc := Vector2(grip_sp.x / vp.x, grip_sp.y / vp.y)
		# Angle of barrel on screen: 0 = right, 90 = up, -90 = down, 180 = left
		var screen_angle_deg := rad_to_deg(atan2(-(tip_ndc.y - grip_ndc.y), tip_ndc.x - grip_ndc.x))
		print("aim_debug ", shot_name, " tip=", tip_ndc, " grip=", grip_ndc, " angle=", screen_angle_deg, " rot=", gun.rotation_degrees)
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [SHOT_DIR, shot_name])
	print("shot: ", shot_name)
