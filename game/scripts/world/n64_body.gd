extends Node3D
## Tall skinny GoldenEye guard — one torso shell, limbs hang from external sockets.

const SKIN := Color(0.84, 0.64, 0.5)
const SKIN_D := Color(0.65, 0.46, 0.36)
const HAIR := Color(0.17, 0.12, 0.08)
const BOOT := Color(0.09, 0.08, 0.07)
const GUN := Color(0.16, 0.16, 0.15)
const SUIT := Color(0.22, 0.23, 0.24)

var uniform_color: Color = SUIT
var _rig: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _walk_t: float = 0.0
var _hands_up: bool = false
var _face_seed: int = 0


func _ready() -> void:
	if get_child_count() == 0:
		build(uniform_color)


func build(uniform: Color) -> void:
	uniform_color = uniform
	_face_seed = hash(get_instance_id())
	while get_child_count() > 0:
		var c := get_child(0)
		remove_child(c)
		c.free()

	# Mesh is authored facing +Z; guard logic treats -Z as forward (look_at).
	# The rig flips the model so the face points where the code aims.
	_rig = Node3D.new()
	_rig.name = "Rig"
	_rig.rotation_degrees.y = 180.0
	add_child(_rig)

	# Torso: hips → belt → jacket → shoulders → collar as one smooth loft.
	# Zone shades are relative grays multiplied by the uniform albedo, so alert
	# tints recolor the whole suit while the zones survive.
	var w := Color(1, 1, 1)
	var tr := Color(0.68, 0.68, 0.72)
	var belt := Color(0.22, 0.2, 0.2)
	_loft("Torso", [
		{y = 0.82, w = 0.26, d = 0.16, color = tr * 0.9},
		{y = 0.97, w = 0.25, d = 0.16, color = tr},
		{y = 0.975, w = 0.255, d = 0.165, color = belt},
		{y = 1.02, w = 0.255, d = 0.165, color = belt},
		{y = 1.025, w = 0.26, d = 0.17, color = w * 0.82},
		{y = 1.2, w = 0.29, d = 0.185, color = w * 0.92},
		{y = 1.42, w = 0.36, d = 0.19, color = w},
		{y = 1.5, w = 0.3, d = 0.17, color = w},
		{y = 1.56, w = 0.14, d = 0.115, color = w},
	], uniform, true)

	# Head: neck → jaw → skull in one faceted loft; hair wraps every facet but
	# the front one, and the crown caps in hair color.
	_loft("HeadLoft", [
		{y = 1.52, w = 0.09, d = 0.09, color = SKIN_D},
		{y = 1.63, w = 0.1, d = 0.1, color = SKIN_D},
		{y = 1.68, w = 0.15, d = 0.145, color = SKIN_D, back = HAIR},
		{y = 1.7, w = 0.155, d = 0.155, color = SKIN, back = HAIR},
		{y = 1.82, w = 0.165, d = 0.17, color = SKIN, back = HAIR},
		{y = 1.875, w = 0.15, d = 0.155, color = SKIN, back = HAIR},
		{y = 1.88, w = 0.149, d = 0.154, color = HAIR, back = HAIR},
		{y = 1.93, w = 0.105, d = 0.105, color = HAIR, back = HAIR},
	], Color.WHITE, false, 0.7)
	var face := _add(N64Geo.face_card(0.115, 0.19), Vector3(0, 1.79, 0.088), SKIN, "Face", false, _face_tex())
	face.rotation_degrees.x = -2.0

	# Arms: deltoid → sleeve → wrist as one loft per side, hand as a small
	# skin loft on the same pivot. Slight A-pose.
	_left_arm = _limb("LeftArm", Vector3(-0.17, 1.44, 0), uniform)
	_left_arm.rotation_degrees.z = -5.0
	_right_arm = _limb("RightArm", Vector3(0.17, 1.44, 0), uniform)
	_right_arm.rotation_degrees.z = 5.0

	# Rifle on back — fully behind body rear face
	_add(N64Geo.tapered_box(Vector2(0.038, 0.038), Vector2(0.026, 0.026), 0.46), Vector3(0.09, 1.24, -0.13), GUN, "Rifle", false)

	_left_leg = _leg("LeftLeg", Vector3(-0.075, 0.84, 0), uniform)
	_right_leg = _leg("RightLeg", Vector3(0.075, 0.84, 0), uniform)


func _limb(limb_name: String, pivot: Vector3, uniform: Color) -> Node3D:
	var root := Node3D.new()
	root.name = limb_name
	root.position = pivot
	_rig.add_child(root)
	var w := Color(1, 1, 1)
	_loft("Sleeve", [
		{y = -0.54, w = 0.056, d = 0.056, color = w * 0.85, z = 0.008},
		{y = -0.28, w = 0.075, d = 0.075, color = w * 0.92, z = 0.004},
		{y = -0.05, w = 0.1, d = 0.1, color = w},
		{y = 0.04, w = 0.095, d = 0.095, color = w},
	], uniform, true, 0.55, root)
	_loft("Hand", [
		{y = -0.7, w = 0.032, d = 0.042, color = SKIN_D, z = 0.014},
		{y = -0.62, w = 0.056, d = 0.06, color = SKIN, z = 0.012},
		{y = -0.535, w = 0.05, d = 0.048, color = SKIN},
	], Color.WHITE, false, 0.55, root)
	return root


func _leg(limb_name: String, pivot: Vector3, uniform: Color) -> Node3D:
	var root := Node3D.new()
	root.name = limb_name
	root.position = pivot
	_rig.add_child(root)
	var tr := Color(0.68, 0.68, 0.72)
	_loft("Trouser", [
		{y = -0.73, w = 0.072, d = 0.082, color = tr * 0.85},
		{y = -0.36, w = 0.095, d = 0.105, color = tr * 0.94, z = 0.006},
		{y = 0.04, w = 0.115, d = 0.14, color = tr},
	], uniform, true, 0.55, root)
	_loft("Boot", [
		{y = -0.8, w = 0.068, d = 0.095, color = BOOT},
		{y = -0.72, w = 0.062, d = 0.072, color = BOOT},
	], Color.WHITE, false, 0.55, root)
	var toe := _add(N64Geo.wedge(0.062, 0.055, 0.07), Vector3(0, -0.812, 0.045), BOOT.lightened(0.05), "Toe", false, null, root)
	toe.rotation_degrees.x = 4.0
	return root


func _loft(
	part_name: String,
	sections: Array,
	albedo: Color,
	is_uniform: bool,
	chamfer: float = 0.55,
	parent: Node = null
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	mi.mesh = N64Geo.loft(sections, chamfer)
	mi.material_override = N64Geo.mat_vc(albedo)
	if is_uniform:
		mi.add_to_group("n64_uniform")
	(parent if parent else _rig).add_child(mi)
	return mi


func set_uniform(color: Color) -> void:
	uniform_color = color
	_tint(self, color)


func _tint(node: Node, color: Color) -> void:
	if node is MeshInstance3D and node.is_in_group("n64_uniform"):
		var existing: Material = (node as MeshInstance3D).material_override
		if existing is StandardMaterial3D and (existing as StandardMaterial3D).vertex_color_use_as_albedo:
			(existing as StandardMaterial3D).albedo_color = color
		else:
			(node as MeshInstance3D).material_override = N64Geo.mat(color)
	for child in node.get_children():
		_tint(child, color)


func set_hands_up(active: bool) -> void:
	_hands_up = active
	if _left_arm:
		_left_arm.rotation_degrees.x = -155.0 if active else 0.0
	if _right_arm:
		_right_arm.rotation_degrees.x = -155.0 if active else 0.0


func tick_walk(delta: float, speed: float) -> void:
	if _hands_up:
		return
	if speed < 0.15:
		_walk_t = 0.0
		_ease(_left_leg, 0.0, delta)
		_ease(_right_leg, 0.0, delta)
		_ease(_left_arm, 0.0, delta)
		_ease(_right_arm, 6.0, delta)
		return
	_walk_t += delta * speed * 2.5
	var s := sin(_walk_t) * 28.0
	if _left_leg:
		_left_leg.rotation_degrees.x = s
	if _right_leg:
		_right_leg.rotation_degrees.x = -s
	if _left_arm:
		_left_arm.rotation_degrees.x = -s * 0.65
	if _right_arm:
		_right_arm.rotation_degrees.x = s * 0.65


func _ease(n: Node3D, t: float, d: float) -> void:
	if n:
		n.rotation_degrees.x = move_toward(n.rotation_degrees.x, t, 220.0 * d)


func _add(
	mesh: ArrayMesh,
	pos: Vector3,
	color: Color,
	part_name: String,
	is_uniform: bool,
	tex: Texture2D = null,
	parent: Node = null
) -> MeshInstance3D:
	return N64Geo.add_mesh(parent if parent else _rig, mesh, pos, color, part_name, is_uniform, tex)


func _face_tex() -> ImageTexture:
	# Base MUST equal the head-loft SKIN so the card disappears into the head;
	# per-guard variety comes from features only, never the base tone.
	var rng := RandomNumberGenerator.new()
	rng.seed = _face_seed
	var skin := SKIN
	var shade := skin.darkened(0.16)
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(skin)

	# Hairline: two rows fading into the hair-colored loft cap directly above
	_px(img, 0, 0, 32, 1, HAIR)
	_px(img, 0, 1, 32, 1, HAIR.lerp(skin, 0.35))

	# Side shading pulls the flat card toward the head's beveled cheeks
	_px(img, 0, 2, 2, 30, shade)
	_px(img, 30, 2, 2, 30, shade)

	# Brows: two separate blocks, weight varies per guard
	var brow := HAIR.lightened(rng.randf_range(0.0, 0.25))
	_px(img, 6, 9, 8, 2, brow)
	_px(img, 18, 9, 8, 2, brow)

	# Eyes: big GE whites with iris + pupil, whites read at distance
	var iris := [Color(0.2, 0.25, 0.4), Color(0.16, 0.3, 0.2), Color(0.25, 0.17, 0.1)][rng.randi() % 3] as Color
	_px(img, 6, 12, 8, 4, Color(0.93, 0.93, 0.9))
	_px(img, 18, 12, 8, 4, Color(0.93, 0.93, 0.9))
	_px(img, 9, 12, 3, 4, iris)
	_px(img, 20, 12, 3, 4, iris)
	_px(img, 10, 13, 1, 2, Color(0.02, 0.02, 0.02))
	_px(img, 21, 13, 1, 2, Color(0.02, 0.02, 0.02))

	# Nose: narrow bridge shadow ending in nostril darks
	_px(img, 14, 15, 4, 6, skin.darkened(0.1))
	_px(img, 13, 20, 2, 1, shade)
	_px(img, 17, 20, 2, 1, shade)

	# Mouth: wide lip line with a subtle lower-lip light
	var half_mouth := 5 + (rng.randi() % 2)
	_px(img, 16 - half_mouth, 24, half_mouth * 2, 2, Color(0.48, 0.26, 0.24))
	_px(img, 16 - half_mouth + 1, 26, half_mouth * 2 - 2, 1, skin.lightened(0.06))

	# Chin crease
	_px(img, 12, 29, 8, 1, skin.darkened(0.08))
	return ImageTexture.create_from_image(img)


func _px(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if xx >= 0 and yy >= 0 and xx < 32 and yy < 32:
				img.set_pixel(xx, yy, c)
