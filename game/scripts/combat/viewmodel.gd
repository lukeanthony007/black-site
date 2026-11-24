extends Node3D
class_name Viewmodel
## GoldenEye FP viewmodel — grip sits in an empty mitten pocket (no mesh intersection).

enum Kind { PISTOL, SILENCED, SMG, RIFLE }

const SKIN := Color(0.68, 0.5, 0.38)
const SKIN_D := Color(0.6, 0.43, 0.32)
const SLEEVE := Color(0.1, 0.1, 0.12)
const STEEL := Color(0.2, 0.2, 0.23)
const STEEL_D := Color(0.06, 0.06, 0.07)
const WOOD := Color(0.3, 0.22, 0.12)
const POLY := Color(0.13, 0.15, 0.12)

var kind: Kind = Kind.PISTOL
var _gun_root: Node3D
var _hands_root: Node3D
var _slide: Node3D
var _mag: Node3D
var _grip: Node3D
var _rest_pos: Vector3 = Vector3.ZERO
var _rest_rot: Vector3 = Vector3.ZERO
var _bob_t: float = 0.0
var _busy: bool = false
var _fire_kick: float = 0.0
var _move_speed: float = 0.0
var _crouching: bool = false
var _airborne: bool = false
var _ads: float = 0.0 ## 0 hip → 1 iron sights
var _muzzle_flash: MeshInstance3D
## Iron-sight tops in gun-local space (shared height so they stack).
const SIGHT_Y := 0.074
const FRONT_SIGHT_LOCAL := Vector3(0.0, SIGHT_Y, -0.24)
const REAR_SIGHT_LOCAL := Vector3(0.0, SIGHT_Y, -0.027)

signal reload_visual_done


func _ready() -> void:
	_rest_pos = position
	_rest_rot = rotation_degrees


func set_loco(speed: float, crouching: bool = false, airborne: bool = false) -> void:
	_crouching = crouching
	_airborne = airborne
	# No run bob in the air — freeze loco input speed
	_move_speed = 0.0 if airborne else speed


func set_ads(amount: float) -> void:
	_ads = clampf(amount, 0.0, 1.0)


func get_ads() -> float:
	return _ads


## Zero local pose so the weapon node alone places the gun for ADS.
func prepare_ads_pose() -> void:
	position = Vector3.ZERO
	rotation = Vector3.ZERO
	if _gun_root and is_instance_valid(_gun_root):
		_gun_root.position = Vector3.ZERO
		_gun_root.rotation = Vector3.ZERO


## Midpoint of the iron-sight line in world space (for screen-center alignment).
func get_sight_mid_global() -> Vector3:
	if _gun_root == null or not is_instance_valid(_gun_root):
		return global_position
	var front := _gun_root.to_global(FRONT_SIGHT_LOCAL)
	var rear := _gun_root.to_global(REAR_SIGHT_LOCAL)
	return (front + rear) * 0.5


func _process(delta: float) -> void:
	if _busy or _gun_root == null:
		return
	_fire_kick = move_toward(_fire_kick, 0.0, delta * 10.0)
	# ADS: zero local offset so weapon ADS_POS alone places sights on screen center
	var ads_s := _ads * _ads * (3.0 - 2.0 * _ads)
	if ads_s > 0.95:
		position = Vector3.ZERO
		rotation_degrees = Vector3.ZERO
		return
	var kick_mul := lerpf(1.0, 0.35, ads_s)
	var bob_mul := lerpf(1.0, 0.08, ads_s)
	# Mid-air or idle: hold rest pose (fire kick still decays)
	if _airborne or _move_speed < 0.15:
		var idle_off := Vector3(
			0.0,
			-_fire_kick * 0.02 * kick_mul,
			_fire_kick * 0.035 * kick_mul
		)
		position = _rest_pos.lerp(Vector3.ZERO, ads_s) + idle_off * (1.0 - ads_s)
		rotation_degrees = _rest_rot.lerp(Vector3.ZERO, ads_s) + Vector3(
			_fire_kick * 5.5 * kick_mul * (1.0 - ads_s), 0.0, 0.0
		)
		return
	var bob_rate := 8.0 + clampf(_move_speed, 0.0, 8.0) * 0.8
	var bob_amp := (0.004 + clampf(_move_speed / 8.0, 0.0, 1.0) * 0.016) * bob_mul
	if _crouching:
		bob_amp *= 0.45
		bob_rate *= 0.7
	_bob_t += delta * (bob_rate / 7.0)
	var bob_y := sin(_bob_t * bob_rate) * bob_amp
	var bob_x := cos(_bob_t * bob_rate * 0.5) * bob_amp * 0.6
	var hip_pos := _rest_pos + Vector3(
		bob_x,
		bob_y - _fire_kick * 0.02 * kick_mul,
		_fire_kick * 0.035 * kick_mul
	)
	position = hip_pos.lerp(Vector3.ZERO, ads_s)
	var hip_rot := _rest_rot + Vector3(
		_fire_kick * 5.5 * kick_mul,
		bob_x * 30.0,
		bob_x * -18.0
	)
	rotation_degrees = hip_rot.lerp(Vector3.ZERO, ads_s)


func rebuild(new_kind: Kind) -> void:
	kind = new_kind
	while get_child_count() > 0:
		var child := get_child(0)
		remove_child(child)
		child.free()
	_slide = null
	_mag = null
	_grip = null

	_gun_root = Node3D.new()
	_gun_root.name = "Gun"
	# Rest pose only — every frame aim_at_global() re-orients the gun so the
	# barrel axis passes through the real hit point. Beam, barrel and dot are
	# then collinear on screen by construction; no tuned screen angles.
	_gun_root.rotation_degrees = Vector3(0, -10, 3)
	_gun_root.scale = Vector3.ONE
	add_child(_gun_root)
	_hands_root = _gun_root

	match kind:
		Kind.PISTOL:
			_build_pp7(false)
			_build_pistol_hand()
		Kind.SILENCED:
			_build_pp7(true)
			_build_pistol_hand()
		Kind.SMG:
			_build_kf7()
			_build_pistol_hand()
		Kind.RIFLE:
			_build_ar33()
			_build_pistol_hand()
	_ensure_muzzle_flash()


func play_equip() -> void:
	_busy = true
	position = _rest_pos + Vector3(0.12, -0.22, 0.08)
	rotation_degrees = _rest_rot + Vector3(22, -16, 12)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", _rest_pos, 0.28)
	tw.parallel().tween_property(self, "rotation_degrees", _rest_rot, 0.28)
	await tw.finished
	_busy = false


func play_fire() -> void:
	_fire_kick = 1.0
	if _muzzle_flash and is_instance_valid(_muzzle_flash):
		_muzzle_flash.visible = true
		_muzzle_flash.rotation_degrees.z = randf_range(0.0, 360.0)
		_muzzle_flash.scale = Vector3.ONE * randf_range(0.9, 1.3)
		var flash_tw := create_tween()
		flash_tw.tween_interval(0.04)
		flash_tw.tween_callback(func() -> void:
			if is_instance_valid(_muzzle_flash):
				_muzzle_flash.visible = false
		)
	if _slide and is_instance_valid(_slide):
		var rest := _slide.position
		var tw := create_tween()
		tw.tween_property(_slide, "position", rest + Vector3(0, 0, 0.04), 0.03)
		tw.tween_property(_slide, "position", rest, 0.09)


func play_reload() -> void:
	if _busy:
		return
	_busy = true
	var tip := _rest_rot + Vector3(26, 10, -10)
	var down := _rest_pos + Vector3(0.04, -0.1, 0.05)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "rotation_degrees", tip, 0.18)
	tw.parallel().tween_property(self, "position", down, 0.18)
	if _mag and is_instance_valid(_mag):
		var mrest := _mag.position
		tw.tween_property(_mag, "position", mrest + Vector3(0, -0.14, 0), 0.2)
		tw.tween_property(_mag, "position", mrest, 0.16)
	else:
		tw.tween_interval(0.35)
	tw.tween_property(self, "rotation_degrees", _rest_rot, 0.2)
	tw.parallel().tween_property(self, "position", _rest_pos, 0.2)
	await tw.finished
	_busy = false
	reload_visual_done.emit()


func _muzzle_tip() -> Vector3:
	# Gun-local bore exit point per weapon kind. Laser beam, muzzle flash and
	# tracer all key off this single constant so they can never desync.
	match kind:
		Kind.SILENCED:
			return Vector3(0, 0.055, -0.53)
		Kind.SMG:
			return Vector3(0, 0.045, -0.52)
		Kind.RIFLE:
			return Vector3(0, 0.055, -0.66)
		_:
			return Vector3(0, 0.055, -0.29)


func _laser_lens() -> Vector3:
	# Under-barrel emitter lens, just below the bore. Starting the beam here
	# makes it emerge from beneath the muzzle instead of over the slide top —
	# the gun is aimed at the hit point, so it still converges dead on the dot.
	match kind:
		Kind.SILENCED:
			return Vector3(0, 0.034, -0.54)
		Kind.SMG:
			return Vector3(0, 0.028, -0.52)
		Kind.RIFLE:
			return Vector3(0, 0.038, -0.66)
		_:
			return Vector3(0, 0.036, -0.26)


func laser_origin_global() -> Vector3:
	if _gun_root and is_instance_valid(_gun_root):
		return _gun_root.to_global(_laser_lens())
	return global_position


func aim_at_global(target: Vector3) -> void:
	# Hip: point barrel at hit (laser collinear). ADS orientation is owned by
	# prepare_ads_pose() + weapon ADS mount (camera-aligned).
	if _gun_root == null or not is_instance_valid(_gun_root):
		return
	if _busy:
		return
	var ads_s := _ads * _ads * (3.0 - 2.0 * _ads)
	if ads_s > 0.85:
		_gun_root.rotation = Vector3.ZERO
		_gun_root.position = Vector3.ZERO
	elif ads_s > 0.02:
		var origin := _gun_root.global_position
		if origin.distance_squared_to(target) >= 0.25:
			_gun_root.look_at(target, Vector3.UP)
			_gun_root.rotate_object_local(Vector3(0, 0, 1), deg_to_rad(3.0))
			_gun_root.rotation = _gun_root.rotation.lerp(Vector3.ZERO, ads_s)
		else:
			_gun_root.rotation = _gun_root.rotation.lerp(Vector3.ZERO, ads_s)
	else:
		var origin2 := _gun_root.global_position
		if origin2.distance_squared_to(target) < 0.25:
			return
		_gun_root.look_at(target, Vector3.UP)
		_gun_root.rotate_object_local(Vector3(0, 0, 1), deg_to_rad(3.0))
	if _muzzle_flash and is_instance_valid(_muzzle_flash):
		_muzzle_flash.position = muzzle_local_offset()


func muzzle_local_offset() -> Vector3:
	# Gun-local muzzle tip pushed through the gun transform, so reframing the
	# viewmodel never desyncs the flash/tracer origin
	return _gun_root.transform * _muzzle_tip() if _gun_root else _muzzle_tip()


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.0
	m.roughness = 0.9
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	m.cull_mode = BaseMaterial3D.CULL_BACK
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return m


func _put(parent: Node, mesh: ArrayMesh, pos: Vector3, color: Color, part_name: String, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


func _beam(parent: Node, pos: Vector3, cross: Vector2, length: float, color: Color, part_name: String, taper := 0.92) -> MeshInstance3D:
	return _put(parent, N64Geo.tapered_box(cross, cross * taper, length), pos, color, part_name, Vector3(90, 0, 0))


func _hex_z(parent: Node, pos: Vector3, radius: float, length: float, color: Color, part_name: String) -> MeshInstance3D:
	return _put(parent, N64Geo.hex_limb(radius, length, 1.0), pos, color, part_name, Vector3(90, 0, 0))


# --- hands ------------------------------------------------------------------
# The hand is built ON the grip node, in grip-local space. Grip spans y 0
# (top, under the frame) to y -0.11 (heel). Alignment is structural, not tuned.

func _build_pistol_hand() -> void:
	var host: Node3D = _grip if _grip else _gun_root

	# Four fingers wrap the front face of the grip, covering most of its
	# height. Wider than the grip so tips read as curling around the far side.
	for i in 4:
		_put(host, N64Geo.tapered_box(Vector2(0.054, 0.05), Vector2(0.052, 0.048), 0.017),
			Vector3(0.003, -0.032 - 0.019 * i, -0.004), SKIN if i % 2 == 0 else SKIN_D, "Finger%d" % i)

	# Palm mass behind the grip (heel of hand) — wide enough to fully envelop
	# the grip's cross-section so no dark sliver escapes the left edge
	_put(host, N64Geo.tapered_box(Vector2(0.056, 0.052), Vector2(0.05, 0.046), 0.085),
		Vector3(0.002, -0.062, 0.036), SKIN, "Palm")
	# Knuckle mass joining fingers to palm on the camera side
	_put(host, N64Geo.tapered_box(Vector2(0.02, 0.06), Vector2(0.018, 0.055), 0.07),
		Vector3(0.026, -0.06, 0.0), SKIN, "Knuckles")

	# Thumb hugs the LEFT flank of the grip pointing forward — the signature
	# GE detail that sells the wrap.
	_put(host, N64Geo.tapered_box(Vector2(0.015, 0.055), Vector2(0.013, 0.048), 0.02),
		Vector3(-0.023, -0.028, -0.004), SKIN, "Thumb")
	_put(host, N64Geo.tapered_box(Vector2(0.018, 0.04), Vector2(0.016, 0.034), 0.035),
		Vector3(-0.018, -0.048, 0.028), SKIN_D, "ThumbBase")

	# Wrist swallows the grip heel; sleeve trails to the bottom screen edge
	_put(host, N64Geo.tapered_box(Vector2(0.046, 0.05), Vector2(0.052, 0.058), 0.055),
		Vector3(0.006, -0.118, 0.04), SKIN_D, "Wrist", Vector3(-24, 0, 0))
	_loft_put(_gun_root, [
		{y = -0.07, w = 0.08, d = 0.075, color = SLEEVE},
		{y = 0.0, w = 0.065, d = 0.06, color = SLEEVE},
		{y = 0.02, w = 0.058, d = 0.054, color = SLEEVE.lightened(0.08)},
	], Vector3(0.018, -0.19, 0.1), Vector3(30, -6, 5), "Sleeve")


func _loft_put(parent: Node, sections: Array, pos: Vector3, rot: Vector3, part_name: String, chamfer := 0.5, glossy := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	# Gun metal gets hard facets so each bevel lights as its own plane;
	# organic parts stay smooth
	mi.mesh = N64Geo.loft(sections, chamfer, not glossy)
	mi.material_override = N64Geo.mat_vc()
	if glossy:
		# GE gunmetal: subtle vertex-lit glints along the bevel edges
		var m := mi.material_override as StandardMaterial3D
		m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
		m.roughness = 0.55
		m.metallic = 0.05
		m.specular = 0.18
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


# --- guns -------------------------------------------------------------------
# Stack rule: frame Y max < slide Y min. Grip entirely below frame. Mag inside grip, same color.

func _build_pp7(silenced: bool) -> void:
	var g := _gun_root
	# One coherent body: slide over frame, raked full-height grip at the rear.
	# The hand is built on the grip node, so gun and hand cannot drift apart.
	_slide = Node3D.new()
	_slide.name = "Slide"
	_slide.position = Vector3(0, 0.055, -0.115)
	g.add_child(_slide)
	# Slide rear ends flush with the grip backstrap (z ≈ 0.025) — on the real
	# gun the slide never overhangs behind the handle.
	_beam(_slide, Vector3.ZERO, Vector2(0.036, 0.03), 0.28, Color(0.055, 0.055, 0.065), "SlideBody", 0.96)
	# Rear block bevels toward its back face instead of ending in a flat slab
	_beam(_slide, Vector3(0, 0.002, 0.115), Vector2(0.04, 0.034), 0.05, Color(0.05, 0.05, 0.06), "SlideRear", 0.82)
	# Hammer: subtle spur emerging from the rear face — near slide value so it
	# reads as silhouette detail, not a bright patch
	_put(_slide, N64Geo.tapered_box(Vector2(0.01, 0.012), Vector2(0.014, 0.016), 0.026),
		Vector3(0, 0.008, 0.15), Color(0.09, 0.09, 0.11), "Hammer", Vector3(-45, 0, 0))
	# Firing-pin plate: faint inset on the rear face under the spur
	_put(_slide, N64Geo.tapered_box(Vector2(0.016, 0.004), Vector2(0.014, 0.004), 0.014),
		Vector3(0, -0.002, 0.139), Color(0.12, 0.12, 0.14), "RearPlate")
	_beam(_slide, Vector3(0, 0.016, -0.03), Vector2(0.011, 0.002), 0.18, Color(0.14, 0.14, 0.16), "SlideCatch", 0.94)
	# Laser module tucked under the barrel at the slide's front, emitter lens
	# just below the bore so the beam (origin = _muzzle_tip()) exits beside it.
	_beam(g, Vector3(0, 0.03, -0.22), Vector2(0.014, 0.012), 0.05, Color(0.035, 0.035, 0.04), "LaserMount", 0.9)
	var laser_emitter := _put(g, N64Geo.tapered_box(Vector2(0.006, 0.006), Vector2(0.004, 0.004), 0.012),
		Vector3(0, 0.038, -0.25), Color(1.0, 0.04, 0.02), "LaserEmitter")
	var laser_mat := laser_emitter.material_override as StandardMaterial3D
	laser_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	laser_mat.emission_enabled = true
	laser_mat.emission = Color(1.0, 0.02, 0.01)
	laser_mat.emission_energy_multiplier = 3.0

	# Frame tucked underneath, same value family as the slide (no light step)
	_beam(g, Vector3(0, 0.03, -0.12), Vector2(0.032, 0.022), 0.2, Color(0.06, 0.06, 0.07), "Frame", 0.94)
	_hex_z(g, Vector3(0, 0.055, -0.27), 0.009, 0.035, Color(0.045, 0.045, 0.052), "Muzzle")
	# Iron sights — tops at SIGHT_Y so get_sight_mid_global() can center them.
	_put(
		g,
		N64Geo.tapered_box(Vector2(0.005, 0.008), Vector2(0.0035, 0.005), 0.012),
		FRONT_SIGHT_LOCAL,
		Color(0.18, 0.18, 0.2),
		"FrontSight"
	)
	# Rear U-notch on the slide (convert gun-space Y into slide-local)
	var rear_local_y := SIGHT_Y - 0.055
	var rear_local_z := REAR_SIGHT_LOCAL.z - (-0.115) # slide.position.z
	_put(
		_slide,
		N64Geo.tapered_box(Vector2(0.005, 0.014), Vector2(0.004, 0.011), 0.016),
		Vector3(-0.011, rear_local_y, rear_local_z),
		Color(0.12, 0.12, 0.14),
		"RearSightL"
	)
	_put(
		_slide,
		N64Geo.tapered_box(Vector2(0.005, 0.014), Vector2(0.004, 0.011), 0.016),
		Vector3(0.011, rear_local_y, rear_local_z),
		Color(0.12, 0.12, 0.14),
		"RearSightR"
	)
	_put(
		_slide,
		N64Geo.tapered_box(Vector2(0.026, 0.004), Vector2(0.024, 0.004), 0.012),
		Vector3(0, rear_local_y - 0.008, rear_local_z),
		Color(0.09, 0.09, 0.11),
		"RearSightBase"
	)

	if silenced:
		_hex_z(g, Vector3(0, 0.055, -0.4), 0.016, 0.22, STEEL_D, "Suppressor")
		_hex_z(g, Vector3(0, 0.055, -0.52), 0.014, 0.02, STEEL_D, "CanCap")

	# Full-height raked grip: top tucks under the frame rear, heel drops
	# down-back. The hand parts key off this node.
	_grip = Node3D.new()
	_grip.name = "Grip"
	_grip.position = Vector3(0, 0.025, -0.015)
	_grip.rotation_degrees = Vector3(16, 0, 0)
	g.add_child(_grip)
	_put(_grip, N64Geo.tapered_box(Vector2(0.034, 0.05), Vector2(0.038, 0.056), 0.09), Vector3(0, -0.04, 0), Color(0.045, 0.045, 0.052), "GripBody")

	_mag = Node3D.new()
	_mag.name = "Mag"
	_mag.position = Vector3(0, -0.088, 0)
	_grip.add_child(_mag)
	_put(_mag, N64Geo.tapered_box(Vector2(0.024, 0.04), Vector2(0.022, 0.036), 0.012), Vector3.ZERO, STEEL_D, "MagBase")

	# Trigger guard: thin bar under the frame ahead of the grip
	_put(g, N64Geo.tapered_box(Vector2(0.008, 0.028), Vector2(0.008, 0.026), 0.008), Vector3(0, -0.014, -0.075), Color(0.055, 0.055, 0.065), "GuardBar")
	_put(g, N64Geo.tapered_box(Vector2(0.008, 0.008), Vector2(0.008, 0.008), 0.028), Vector3(0, 0.0, -0.088), Color(0.055, 0.055, 0.065), "GuardPost")


func _build_kf7() -> void:
	var g := _gun_root
	_beam(g, Vector3(0, 0.04, -0.16), Vector2(0.042, 0.052), 0.4, STEEL, "Receiver", 0.92)
	_hex_z(g, Vector3(0, 0.045, -0.42), 0.012, 0.18, STEEL_D, "Barrel")
	_beam(g, Vector3(0, 0.082, -0.1), Vector2(0.022, 0.022), 0.09, STEEL_D, "RearSight", 1.0)
	# Wood handguard over the front half
	_beam(g, Vector3(0, 0.036, -0.28), Vector2(0.048, 0.042), 0.14, WOOD, "Handguard", 0.94)
	# Grip stub bridges receiver to fist
	_grip = Node3D.new()
	_grip.name = "Grip"
	_grip.position = Vector3(0, 0.0, 0.02)
	_grip.rotation_degrees = Vector3(12, 0, 0)
	g.add_child(_grip)
	_put(_grip, N64Geo.tapered_box(Vector2(0.03, 0.038), Vector2(0.028, 0.034), 0.05), Vector3(0, -0.025, 0), WOOD, "Grip")
	# Curved-look mag: angled box ahead of trigger
	_mag = Node3D.new()
	_mag.position = Vector3(0, -0.05, -0.1)
	_mag.rotation_degrees = Vector3(-14, 0, 0)
	g.add_child(_mag)
	_put(_mag, N64Geo.tapered_box(Vector2(0.028, 0.045), Vector2(0.025, 0.04), 0.11), Vector3(0, -0.03, 0), STEEL_D, "MagBody")
	# Stock stub — mostly hidden behind the fist, just suggests mass
	_beam(g, Vector3(0, 0.025, 0.1), Vector2(0.032, 0.038), 0.09, WOOD, "Stock", 0.9)
	_slide = null


func _build_ar33() -> void:
	var g := _gun_root
	_beam(g, Vector3(0, 0.05, -0.22), Vector2(0.044, 0.06), 0.5, STEEL, "Receiver", 0.9)
	_hex_z(g, Vector3(0, 0.055, -0.54), 0.011, 0.22, STEEL_D, "Barrel")
	_beam(g, Vector3(0, 0.092, -0.14), Vector2(0.024, 0.028), 0.13, STEEL_D, "Carry", 1.0)
	_beam(g, Vector3(0, 0.045, -0.36), Vector2(0.052, 0.048), 0.16, POLY, "Handguard", 0.94)
	_grip = Node3D.new()
	_grip.name = "Grip"
	_grip.position = Vector3(0, 0.0, 0.0)
	_grip.rotation_degrees = Vector3(14, 0, 0)
	g.add_child(_grip)
	_put(_grip, N64Geo.tapered_box(Vector2(0.03, 0.038), Vector2(0.028, 0.034), 0.05), Vector3(0, -0.025, 0), STEEL_D, "Grip")
	_mag = Node3D.new()
	_mag.position = Vector3(0, -0.045, -0.12)
	_mag.rotation_degrees = Vector3(-8, 0, 0)
	g.add_child(_mag)
	_put(_mag, N64Geo.tapered_box(Vector2(0.03, 0.05), Vector2(0.027, 0.045), 0.1), Vector3(0, -0.03, 0), STEEL_D, "MagBody")
	_beam(g, Vector3(0, 0.03, 0.1), Vector2(0.034, 0.046), 0.1, POLY, "Stock", 0.88)
	_slide = null


func _ensure_muzzle_flash() -> void:
	if _muzzle_flash and is_instance_valid(_muzzle_flash):
		_muzzle_flash.queue_free()
	_muzzle_flash = MeshInstance3D.new()
	_muzzle_flash.name = "MuzzleFlash"
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.14, 0.14)
	_muzzle_flash.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.35, 0.95)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.2)
	mat.emission_energy_multiplier = 4.0
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_muzzle_flash.material_override = mat
	_muzzle_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_muzzle_flash.position = muzzle_local_offset()
	_muzzle_flash.visible = false
	add_child(_muzzle_flash)
