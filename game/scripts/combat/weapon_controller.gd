class_name WeaponController
extends Node3D
## Hitscan weapons. Aim = camera center. RMB iron sights. N64 viewmodel.

signal ammo_changed(mag: int, reserve: int)
signal weapon_changed(weapon_name: String)
signal fired

@export var weapon_data: WeaponData
@export var camera: Camera3D

## Hip / ADS weapon mount offsets (local to Camera3D).
const HIP_POS := Vector3(0.12, -0.26, -0.42)
## Base ADS depth; XY is corrected each frame so the sight line hits screen center.
const ADS_POS := Vector3(0.0, -0.074, -0.38)
const HIP_FOV := 80.0
const ADS_FOV := 68.0 ## mild zoom only — keep room around the pistol
const ADS_BLEND_SPEED := 11.0

var mag: int = 0
var reserve: int = 0
var _cooldown: float = 0.0
var _recoil_pitch: float = 0.0
var _recoil_yaw: float = 0.0
var _reloading: bool = false
var _ads_blend: float = 0.0 ## 0 hip → 1 iron sights
var _laser_dot: MeshInstance3D
var _laser_line: MeshInstance3D
var _laser_overlay: Line2D

@onready var _muzzle: Marker3D = $Muzzle
@onready var _flash: OmniLight3D = $Muzzle/Flash
@onready var _viewmodel: Node3D = $Viewmodel


func _ready() -> void:
	if weapon_data == null:
		weapon_data = WeaponData.make_pistol()
	mag = weapon_data.magazine_size
	reserve = weapon_data.reserve_ammo
	if _flash:
		_flash.visible = false
	# Optional scene children — headless tests may attach a bare controller
	if get_node_or_null("Muzzle") == null:
		_muzzle = null
		_flash = null
	if get_node_or_null("Viewmodel") == null:
		_viewmodel = null
	position = HIP_POS
	_make_laser_dot()
	_make_laser_line()
	_apply_weapon_visual()
	ammo_changed.emit(mag, reserve)
	weapon_changed.emit(weapon_data.display_name)


func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_update_ads(delta)
	_update_viewmodel_loco()
	# Snappier camera kick during recovery: impulse scales with recovery_speed
	if _recoil_pitch != 0.0 or _recoil_yaw != 0.0:
		var player := _player()
		var kick_scale := 22.0
		if player and player.has_method("apply_recoil"):
			player.apply_recoil(_recoil_pitch * delta * kick_scale, _recoil_yaw * delta * kick_scale)
		var rec := weapon_data.recovery_speed
		_recoil_pitch = move_toward(_recoil_pitch, 0.0, rec * delta)
		_recoil_yaw = move_toward(_recoil_yaw, 0.0, rec * delta)

	if _reloading:
		return

	if weapon_data.automatic:
		if Input.is_action_pressed("fire"):
			try_fire()
	elif Input.is_action_just_pressed("fire"):
		try_fire()

	if Input.is_action_just_pressed("reload"):
		reload()


func _update_ads(delta: float) -> void:
	var want := 0.0
	if is_aiming() and not _reloading and not _ads_blocked():
		want = 1.0
	_ads_blend = move_toward(_ads_blend, want, ADS_BLEND_SPEED * delta)
	var t := _ads_blend * _ads_blend * (3.0 - 2.0 * _ads_blend) # smoothstep
	if camera:
		camera.fov = lerpf(HIP_FOV, ADS_FOV, t)
	if _viewmodel and _viewmodel.has_method("set_ads"):
		_viewmodel.call("set_ads", _ads_blend)

	# Base hip→ads mount
	position = HIP_POS.lerp(ADS_POS, t)

	# Full ADS: lock gun to camera, then shift so front/rear sights sit on optical axis
	if t > 0.15 and camera != null and _viewmodel != null:
		if _viewmodel.has_method("prepare_ads_pose"):
			_viewmodel.call("prepare_ads_pose")
		if t > 0.35 and _viewmodel.has_method("get_sight_mid_global"):
			# Force identity on the mount chain before measuring
			if _viewmodel is Node3D:
				(_viewmodel as Node3D).position = Vector3.ZERO
				(_viewmodel as Node3D).rotation = Vector3.ZERO
			var mid: Vector3 = _viewmodel.call("get_sight_mid_global")
			var local: Vector3 = camera.global_transform.affine_inverse() * mid
			# Move weapon so the sight midpoint lands on (0, 0, depth) in camera space
			position.x -= local.x * t
			position.y -= local.y * t


func _ads_blocked() -> bool:
	var player := _player()
	if player == null:
		return false
	if player.has_method("is_sliding") and bool(player.call("is_sliding")):
		return true
	if player.has_method("is_diving") and bool(player.call("is_diving")):
		return true
	if player.has_method("is_mantling") and bool(player.call("is_mantling")):
		return true
	if player.has_method("is_wallrunning") and bool(player.call("is_wallrunning")):
		return true
	return false


## Hold RMB — visual iron sights (not crouch steadiness).
func is_aiming() -> bool:
	return Input.is_action_pressed("aim")


## ADS = hold aim (RMB) or crouch steadiness. Used by spread + tests.
func is_ads_active() -> bool:
	if is_aiming() and _ads_blend > 0.35:
		return true
	if Input.is_action_pressed("aim"):
		return true
	var player := _player()
	if player and player.has_method("is_crouching") and player.is_crouching():
		return true
	return false


func get_ads_blend() -> float:
	return _ads_blend


## Shipped spread in degrees for current weapon + movement + ADS state.
func compute_spread_deg(move_speed: float = -1.0, force_ads: int = -1) -> float:
	var speed := move_speed
	if speed < 0.0:
		speed = 0.0
		var player := _player()
		if player is CharacterBody3D:
			speed = (player as CharacterBody3D).velocity.length()
	var ads := is_ads_active() if force_ads < 0 else force_ads == 1
	return WeaponData.compute_spread_deg(weapon_data, speed, ads)


## Recoil residual remaining (tests measure recovery rate via recovery_speed field).
func get_recoil_pitch() -> float:
	return _recoil_pitch


func get_recovery_speed() -> float:
	return weapon_data.recovery_speed if weapon_data else 0.0


func try_fire() -> void:
	if _cooldown > 0.0 or _reloading:
		return
	if mag <= 0:
		reload()
		return

	mag -= 1
	_cooldown = 1.0 / weapon_data.fire_rate
	# ADS reduces felt recoil slightly
	var recoil_mul := 0.72 if is_ads_active() else 1.0
	_recoil_pitch = weapon_data.recoil_pitch * recoil_mul
	_recoil_yaw = randf_range(-weapon_data.recoil_yaw_jitter, weapon_data.recoil_yaw_jitter) * recoil_mul
	ammo_changed.emit(mag, reserve)
	fired.emit()
	ObjectiveTracker.record_shot()
	if weapon_data.noise <= 0.35:
		GameAudio.play_silenced()
	else:
		GameAudio.play_gunshot()
	_show_flash()
	if _viewmodel and _viewmodel.has_method("play_fire"):
		_viewmodel.call("play_fire")
	_hitscan()

	var origin := global_position
	var player := _player()
	if player:
		origin = player.global_position
	NoiseBus.emit_noise(origin, weapon_data.noise, player)


func reload() -> void:
	if _reloading or reserve <= 0 or mag >= weapon_data.magazine_size:
		return
	_reloading = true
	ObjectiveTracker.set_prompt("Reloading…")
	if _viewmodel and _viewmodel.has_method("play_reload"):
		_viewmodel.call("play_reload")
	await get_tree().create_timer(0.85).timeout
	if not is_instance_valid(self):
		return
	var need := weapon_data.magazine_size - mag
	var take := mini(need, reserve)
	mag += take
	reserve -= take
	_reloading = false
	ammo_changed.emit(mag, reserve)
	ObjectiveTracker.set_prompt("%s ready" % weapon_data.display_name)


func add_ammo(amount: int) -> void:
	reserve += amount
	ammo_changed.emit(mag, reserve)


func equip(data: WeaponData, keep_reserve_bonus: int = 0) -> void:
	weapon_data = data
	mag = data.magazine_size
	reserve = data.reserve_ammo + keep_reserve_bonus
	_apply_weapon_visual()
	if _viewmodel and _viewmodel.has_method("play_equip"):
		_viewmodel.call("play_equip")
	ammo_changed.emit(mag, reserve)
	weapon_changed.emit(data.display_name)
	ObjectiveTracker.set_prompt("Picked up %s" % data.display_name)
	GameAudio.play_pickup()


func _apply_weapon_visual() -> void:
	if _viewmodel == null:
		return
	if _viewmodel.has_method("rebuild"):
		_viewmodel.call("rebuild", weapon_data.view_kind)
	if _muzzle and _viewmodel.has_method("muzzle_local_offset"):
		_muzzle.position = _viewmodel.call("muzzle_local_offset")


func _update_viewmodel_loco() -> void:
	if _viewmodel == null or not _viewmodel.has_method("set_loco"):
		return
	var player := _player()
	var speed := 0.0
	var crouch := false
	var airborne := false
	if player is CharacterBody3D:
		var body := player as CharacterBody3D
		var vel := body.velocity
		speed = Vector2(vel.x, vel.z).length()
		# True air only — ignore sticky-floor frames for bob
		airborne = not body.is_on_floor()
	if player and player.has_method("is_crouching"):
		crouch = bool(player.call("is_crouching"))
	_viewmodel.call("set_loco", speed, crouch, airborne)


func _player() -> Node:
	return get_parent().get_parent().get_parent()


func _make_laser_dot() -> void:
	_laser_dot = MeshInstance3D.new()
	_laser_dot.name = "LaserDot"
	var sphere := SphereMesh.new()
	sphere.radius = 0.045
	sphere.height = 0.09
	sphere.radial_segments = 8
	sphere.rings = 4
	_laser_dot.mesh = sphere
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.12, 0.08, 0.9)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.05, 0.05)
	m.emission_energy_multiplier = 3.0
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_laser_dot.material_override = m
	_laser_dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_laser_dot.top_level = true
	_laser_dot.visible = false
	add_child(_laser_dot)


func _make_laser_line() -> void:
	_laser_line = MeshInstance3D.new()
	_laser_line.name = "LaserLine"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.008
	cylinder.bottom_radius = 0.008
	cylinder.height = 1.0
	cylinder.radial_segments = 6
	_laser_line.mesh = cylinder
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.04, 0.02, 0.72)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.02, 0.01)
	m.emission_energy_multiplier = 2.5
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	_laser_line.material_override = m
	_laser_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_laser_line.top_level = true
	_laser_line.visible = false
	add_child(_laser_line)

	var overlay_layer := CanvasLayer.new()
	overlay_layer.name = "LaserOverlayLayer"
	overlay_layer.layer = 20
	add_child(overlay_layer)
	_laser_overlay = Line2D.new()
	_laser_overlay.name = "LaserOverlay"
	_laser_overlay.width = 3.0
	_laser_overlay.default_color = Color(1.0, 0.03, 0.01, 0.9)
	_laser_overlay.antialiased = false
	_laser_overlay.z_index = 20
	_laser_overlay.visible = false
	overlay_layer.add_child(_laser_overlay)


func _physics_process(_delta: float) -> void:
	_update_laser_dot()


func _update_laser_dot() -> void:
	if camera == null or _laser_dot == null:
		return
	# Same aim as _hitscan minus spread: the dot and beam mark the true impact point.
	var space := get_world_3d().direct_space_state
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * weapon_data.range_distance
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collision_mask = 0b0101
	var player := _player()
	if player is CollisionObject3D:
		query.exclude = [(player as CollisionObject3D).get_rid()]
	var hit := space.intersect_ray(query)
	var aim_pt: Vector3 = to if hit.is_empty() else hit.position
	# Keep the viewmodel barrel on the true aim line so sights / beam stay collinear
	if _viewmodel and _viewmodel.has_method("aim_at_global"):
		_viewmodel.call("aim_at_global", aim_pt)
		if _muzzle and _viewmodel.has_method("muzzle_local_offset"):
			_muzzle.position = _viewmodel.call("muzzle_local_offset")
	# Iron-sight ADS: hide laser so the sight picture is clean
	var show_laser := _ads_blend < 0.55
	if hit.is_empty() or not show_laser:
		_laser_dot.visible = false
		if _laser_line:
			_laser_line.visible = false
		if _laser_overlay:
			_laser_overlay.visible = false
		return
	_laser_dot.visible = true
	_laser_dot.global_position = hit.position + hit.normal * 0.01
	# Constant apparent size: scale with distance
	var dist: float = (hit.position - from).length()
	_laser_dot.scale = Vector3.ONE * clampf(dist * 0.014, 0.01, 0.4)
	var laser_origin := _muzzle.global_position if _muzzle else global_position
	if _viewmodel and _viewmodel.has_method("laser_origin_global"):
		laser_origin = _viewmodel.call("laser_origin_global")
	_update_laser_line(laser_origin, hit.position)


func _update_laser_line(start: Vector3, end: Vector3) -> void:
	if _laser_line == null:
		return
	var delta := end - start
	var length := delta.length()
	if length <= 0.001:
		_laser_line.visible = false
		if _laser_overlay:
			_laser_overlay.visible = false
		return
	var direction := delta / length
	_laser_line.global_position = (start + end) * 0.5
	_laser_line.basis = Basis(Quaternion(Vector3.UP, direction)).scaled(Vector3(1.0, length, 1.0))
	_laser_line.visible = false
	if _laser_overlay and camera:
		# The overlay has no depth test, so clip the near end forward past the
		# muzzle — otherwise its first pixels paint over the slide silhouette.
		var clipped_start := start + direction * minf(0.12, length * 0.4)
		_laser_overlay.points = PackedVector2Array([
			camera.unproject_position(clipped_start),
			camera.unproject_position(end),
		])
		_laser_overlay.visible = true


func _hitscan() -> void:
	if camera == null:
		return
	var space := get_world_3d().direct_space_state
	var from := camera.global_position
	var forward := -camera.global_transform.basis.z
	var player := _player()
	var speed := 0.0
	if player is CharacterBody3D:
		speed = (player as CharacterBody3D).velocity.length()
	var spread := deg_to_rad(compute_spread_deg(speed))
	# Hard-landing accuracy penalty from player motor
	if player and player.has_method("has_accuracy_penalty") and player.has_accuracy_penalty():
		spread *= 1.55
	var right := camera.global_transform.basis.x
	var up := camera.global_transform.basis.y
	var dir := (forward
		+ right * randf_range(-spread, spread)
		+ up * randf_range(-spread, spread)).normalized()
	var to := from + dir * weapon_data.range_distance
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collision_mask = 0b0101 # world + enemies
	if player is CollisionObject3D:
		query.exclude = [(player as CollisionObject3D).get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return

	GameAudio.play_impact()
	_spawn_impact(hit.position, hit.normal)

	var damageable := _find_damageable(hit.collider)
	if damageable:
		if hit.collider is Node and ((hit.collider as Node).is_in_group("guards")
				or (hit.collider as Node).is_in_group("corpses")):
			AlertPhase.mark_player_hostile()
		var dmg := weapon_data.damage
		if hit.collider is Node3D:
			var body_node := hit.collider as Node3D
			var local_y: float = (hit.position - body_node.global_position).y
			if local_y > 1.35:
				dmg *= 2.0
		damageable.apply_damage(dmg, player)


func _find_damageable(node: Object) -> Damageable:
	if node == null:
		return null
	if node is Node:
		var n := node as Node
		var d := n.get_node_or_null("Damageable")
		if d is Damageable:
			return d
		if n.get_parent():
			d = n.get_parent().get_node_or_null("Damageable")
			if d is Damageable:
				return d
	return null


func _show_flash() -> void:
	if _flash == null:
		return
	_flash.visible = true
	var tween := create_tween()
	tween.tween_interval(0.04)
	tween.tween_callback(func() -> void:
		if is_instance_valid(_flash):
			_flash.visible = false
	)


func _spawn_impact(pos: Vector3, normal: Vector3) -> void:
	var host := get_tree().current_scene
	if host == null:
		host = get_tree().root
	var decal := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	decal.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.15, 0.15)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.6, 0.1)
	mat.emission_energy_multiplier = 2.0
	decal.material_override = mat
	host.add_child(decal)
	decal.global_position = pos + normal * 0.02
	var fade := create_tween()
	fade.tween_interval(2.0)
	fade.tween_callback(decal.queue_free)
