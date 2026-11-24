extends CharacterBody3D
## First-person motor: walk, look, jump, crouch, sprint, slide, mantle, landings, light wallrun.

const WALK_SPEED := MotorConstants.WALK_SPEED
const SPRINT_SPEED := MotorConstants.SPRINT_SPEED
const CROUCH_SPEED := MotorConstants.CROUCH_SPEED
const DRAG_SPEED := 2.2
const JUMP_VELOCITY := MotorConstants.JUMP_VELOCITY
const MOUSE_SENS := 0.0022
const MOUSE_SENS_ADS := 0.00135 ## tighter look while iron-sighting
const STAND_HEIGHT := MotorConstants.STAND_HEIGHT
const CROUCH_HEIGHT := MotorConstants.CROUCH_HEIGHT
const DIVE_HEIGHT := MotorConstants.DIVE_HEIGHT
const DIVE_AIR_SPEED := MotorConstants.DIVE_AIR_SPEED
const DIVE_JUMP_BOOST := MotorConstants.DIVE_JUMP_BOOST
const SLIDE_START_SPEED := MotorConstants.SLIDE_START_SPEED
const SLIDE_BOOST := MotorConstants.SLIDE_BOOST
const SLIDE_FRICTION := MotorConstants.SLIDE_FRICTION
const SLIDE_MIN_SPEED := MotorConstants.SLIDE_MIN_SPEED
const SLIDE_MAX_TIME := MotorConstants.SLIDE_MAX_TIME
const SLIDE_SPRINT_GRACE := MotorConstants.SLIDE_SPRINT_GRACE

@export var max_health: float = 100.0
@export var max_armor: float = 100.0

var health: float = 100.0
var armor: float = 50.0
var dead: bool = false
var _pitch: float = 0.0
var _crouching: bool = false
var _sliding: bool = false
var _slide_time: float = 0.0
var _diving: bool = false ## Air dive — low profile + faster air move
var _was_diving: bool = false
var _latched_dive: bool = false ## Space air-dive: stays diving until land without needing Ctrl
var _air_dive_used: bool = false ## One air-dive (2nd Space) per airborne period
var _crouch_was_held: bool = false ## edge-detect crouch for sprint-slide
var _sprint_grace_t: float = 0.0 ## time left where crouch still = sprint-slide
var _sprint_carry_spd: float = 0.0 ## speed remembered while grace is active
var _dive_slide_blend: float = 0.0 ## >0: smooth camera after dive→slide land
var _footstep_timer: float = 0.0
var has_keycard: bool = false
var keycard_tier: int = 0 ## 0 none, 1 facility, 2 server
var lockpicks: int = 0
var camera_loops: int = 0
var decoys: int = 0
var _hurt_flash: float = 0.0
var _drag_target: Node3D = null
var _threat_target: Node3D = null

# Motor state
var _airborne: bool = false
var _air_peak_y: float = 0.0
var _mantling: bool = false
var _mantle_t: float = 0.0
var _mantle_duration: float = 0.5
var _mantle_from: Vector3 = Vector3.ZERO
var _mantle_mid: Vector3 = Vector3.ZERO ## hang / grab lip
var _mantle_to: Vector3 = Vector3.ZERO ## stand on top
var _wallrunning: bool = false
var _wallrun_vertical: bool = false ## true = climb straight up; false = lateral arc
var _wallrun_t: float = 0.0
var _wallrun_normal: Vector3 = Vector3.ZERO
var _wallrun_side: float = 0.0 ## -1 wall on left, +1 wall on right (lateral)
var _wallrun_cooldown: float = 0.0 ## short peel-off buffer
var _wallrun_used_air: bool = false ## one wallrun per airtime — resets on floor
var _wallrun_cam_roll: float = 0.0
var _wallrun_facing_out: bool = false ## after Ctrl turn — look away from wall
var _wallrun_along: Vector3 = Vector3.ZERO ## locked travel dir for lateral run
var _wallrun_turn_t: float = -1.0 ## <0 = not turning; else elapsed
var _wallrun_turn_from_yaw: float = 0.0
var _wallrun_turn_to_yaw: float = 0.0
var _accuracy_penalty_t: float = 0.0
var _last_landing_kind: int = MotorConstants.LandingKind.NONE
var _last_landing_noise: float = 0.0
var _checkpoint: Transform3D = Transform3D.IDENTITY
var _has_checkpoint: bool = false
## Smooth step-up for small curbs (not stair flights — those use walk surfaces).
var _step_smooth_from_y: float = 0.0
var _step_smooth_to_y: float = 0.0
var _step_smooth_t: float = -1.0
const STEP_SMOOTH_TIME := 0.09
## Ignore brief floor leaves (stairs/slopes) so landings/camera don't pop.
var _air_time: float = 0.0
const FLOOR_STICKY := 0.12
const LANDING_MIN_FALL := 0.75

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var weapon: WeaponController = $CameraPivot/Camera3D/Weapon
@onready var interact_ray: RayCast3D = $CameraPivot/Camera3D/InteractRay

## True only after intentional Esc pause (not focus-loss). Click / Esc resumes.
var _mouse_paused: bool = false


func _ready() -> void:
	health = max_health
	armor = 50.0
	_mouse_paused = false
	# Deferred: capture often fails if the window isn't focused yet on boot
	call_deferred("_capture_mouse")
	add_to_group("player")
	_checkpoint = global_transform
	_has_checkpoint = true
	weapon.camera = camera
	weapon.ammo_changed.connect(_on_ammo_changed)
	weapon.weapon_changed.connect(_on_weapon_changed)
	_on_ammo_changed(weapon.mag, weapon.reserve)
	_on_weapon_changed(weapon.weapon_data.display_name)
	ObjectiveTracker.set_player_vitals(health, max_health, armor, max_armor)


func _capture_mouse() -> void:
	_mouse_paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _release_mouse_pause() -> void:
	_mouse_paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ObjectiveTracker.set_prompt("PAUSED — click or Esc to resume · P restart")


func _notification(what: int) -> void:
	# OS often drops capture on focus loss — take it back when we regain focus
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and not dead and not _mouse_paused:
		call_deferred("_capture_mouse")
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN and not dead and not _mouse_paused:
		call_deferred("_capture_mouse")


func _input(event: InputEvent) -> void:
	## Use _input (not only unhandled) so look never dies if a Control eats motion.
	if dead:
		return
	# Click-to-recapture when cursor is free (focus loss, bad boot capture, etc.)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			_capture_mouse()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := MOUSE_SENS
		if weapon and weapon.has_method("get_ads_blend"):
			var ads_b: float = float(weapon.call("get_ads_blend"))
			sens = lerpf(MOUSE_SENS, MOUSE_SENS_ADS, ads_b)
		# Soft-lock yaw during ME wall-climb turnaround
		if _wallrun_turn_t < 0.0:
			rotate_y(-event.relative.x * sens)
		_pitch = clampf(_pitch - event.relative.y * sens, deg_to_rad(-85.0), deg_to_rad(85.0))
		camera_pivot.rotation.x = _pitch
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if dead:
		if event.is_action_pressed("restart"):
			get_tree().reload_current_scene()
		return

	# Esc only — never treat Ctrl / other keys as pause
	var esc := false
	if event is InputEventKey and event.pressed and not event.echo:
		if int(event.keycode) == int(KEY_ESCAPE) or int(event.physical_keycode) == int(KEY_ESCAPE):
			esc = true
	elif event.is_action_pressed("ui_cancel") and not event.is_action_pressed("crouch"):
		# Fallback if project remaps ui_cancel, but never if it's crouch
		esc = true
	if esc:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_release_mouse_pause()
		else:
			_capture_mouse()
			ObjectiveTracker.set_prompt("")
		return

	if event.is_action_pressed("interact"):
		if not _try_start_drag():
			_try_interact()

	if event.is_action_released("interact"):
		_stop_drag()

	if event.is_action_pressed("takedown"):
		_try_takedown(true)

	if event.is_action_pressed("knockout"):
		_try_takedown(false)

	if event.is_action_pressed("gadget"):
		_use_camera_loop()

	if event.is_action_pressed("throw_decoy"):
		_throw_decoy()

	if event.is_action_pressed("demand_surrender"):
		_issue_demand("surrender")
	if event.is_action_pressed("demand_keycard"):
		_issue_demand("keycard")
	if event.is_action_pressed("demand_door"):
		_issue_demand("door")

	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


func _physics_process(delta: float) -> void:
	if dead:
		return

	_hurt_flash = maxf(0.0, _hurt_flash - delta)
	_accuracy_penalty_t = maxf(0.0, _accuracy_penalty_t - delta)
	ObjectiveTracker.set_hurt_flash(_hurt_flash)

	if _mantling:
		_tick_mantle(delta)
		return

	var on_floor_now := is_on_floor()
	# Sticky floor: brief leave on slopes/stairs doesn't count as airborne
	if on_floor_now:
		_air_time = 0.0
		# Floor contact restores wallrun for the next jump
		_wallrun_used_air = false
	else:
		_air_time += delta
	var grounded := on_floor_now or _air_time < FLOOR_STICKY

	if on_floor_now and _airborne:
		var fall_h := _air_peak_y - global_position.y
		# Dive→slide only when crouch held on impact (Space dive alone does not slide)
		var dive_slide_land := _was_diving and _is_crouch_held()
		if (
			fall_h >= LANDING_MIN_FALL
			and _air_time >= FLOOR_STICKY * 0.5
			and not dive_slide_land
		):
			_resolve_landing()
		_airborne = false
		_air_dive_used = false
		if dive_slide_land:
			velocity.y = 0.0
	if not on_floor_now:
		if not _airborne and _air_time >= FLOOR_STICKY:
			_airborne = true
			_air_peak_y = global_position.y
		elif _airborne:
			_air_peak_y = maxf(_air_peak_y, global_position.y)

	# Gravity only when truly off the ground (not sticky stair frames)
	if not grounded and not _wallrunning:
		velocity += get_gravity() * delta

	_wallrun_cooldown = maxf(0.0, _wallrun_cooldown - delta)

	# Wallrun: sprint-jump along a wall (airborne, clear of floor)
	var wallrun_ate_jump := false
	if _wallrunning:
		if on_floor_now and velocity.y <= 0.15:
			_end_wallrun(false)
		else:
			wallrun_ate_jump = _tick_wallrun(delta)
	elif (
		_wallrun_cooldown <= 0.0
		and not _wallrun_used_air
		and not on_floor_now
		and not grounded
		and _drag_target == null
		and not _sliding
		and not _mantling
	):
		_try_begin_wallrun()

	# Crouch: action map OR raw Ctrl (Linux often fails action-only Ctrl)
	var crouch_held := _is_crouch_held()
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var hvel := Vector3(velocity.x, 0.0, velocity.z)
	var hspd := hvel.length()

	# Auto ledge-grab when airborne / wallrunning and close to a lip
	if (
		not on_floor_now
		and not _mantling
		and not _sliding
		and _drag_target == null
		and velocity.y < MotorConstants.MANTLE_MAX_UP_VEL
		and velocity.y > MotorConstants.MANTLE_MAX_DOWN_VEL * 0.65
	):
		var auto_hit := probe_mantle_target()
		if not auto_hit.is_empty():
			var lh: float = float(auto_hit.get("ledge_height", 99.0))
			if lh >= MotorConstants.MANTLE_MIN * 0.55 and lh <= MotorConstants.MANTLE_MAX:
				var stand: Vector3 = auto_hit["stand_pos"]
				var to_lip := stand - global_position
				to_lip.y = 0.0
				# Hands near lip (planar) and lip roughly at chest/head height
				var hand_y := global_position.y + 1.35
				var lip_dy := absf(stand.y - hand_y)
				if to_lip.length() <= MotorConstants.MANTLE_AUTO_DIST and lip_dy < 0.85:
					_begin_mantle(stand, lh)
					return

	# --- Jump / mantle / air-dive (2nd Space) ---
	var jumped_this_frame := false
	if (
		Input.is_action_just_pressed("jump")
		and _drag_target == null
		and not wallrun_ate_jump
	):
		# Ledge grab / pull-up from floor, air, or wallrun
		if try_mantle():
			return
		if _wallrunning:
			pass # wallrun tick already handled kick if it ate jump
		elif on_floor_now or grounded:
			_sliding = false
			_latched_dive = false
			var takeoff_dir := hvel if hspd > 0.2 else (-transform.basis.z)
			takeoff_dir.y = 0.0
			if takeoff_dir.length() < 0.01:
				takeoff_dir = Vector3(0, 0, -1)
			else:
				takeoff_dir = takeoff_dir.normalized()
			var takeoff_spd := maxf(hspd, WALK_SPEED)
			if Input.is_action_pressed("sprint"):
				takeoff_spd = maxf(takeoff_spd, SPRINT_SPEED)
			if crouch_held:
				takeoff_spd = maxf(takeoff_spd, DIVE_AIR_SPEED)
			velocity.x = takeoff_dir.x * takeoff_spd
			velocity.z = takeoff_dir.z * takeoff_spd
			velocity.y = JUMP_VELOCITY + (DIVE_JUMP_BOOST if crouch_held else 0.0)
			_airborne = true
			_air_time = FLOOR_STICKY + 0.05
			_air_peak_y = global_position.y
			jumped_this_frame = true
			_air_dive_used = false
			if crouch_held:
				_diving = true
				_was_diving = true
				_latched_dive = true
		elif not _air_dive_used and not _mantling:
			# Double-jump / mid-air Space = dive (air only — no auto-slide on land)
			_air_dive_used = true
			_latched_dive = true
			_diving = true
			_was_diving = true
			_apply_dive_boost(direction)

	# --- Dive / crouch / slide ---
	# Use real floor only — sticky "grounded" must not cancel dive mid-jump
	var in_air := (not on_floor_now) or jumped_this_frame
	var prev_diving := _was_diving
	_diving = (crouch_held or _latched_dive) and in_air and not _wallrunning and not _mantling

	# Sprint grace: Shift→release→Ctrl still slides (speed would already be walk without this)
	var sprinting := Input.is_action_pressed("sprint")
	if (
		on_floor_now
		and not _sliding
		and not crouch_held
		and sprinting
		and hspd >= WALK_SPEED * 0.9
		and direction.length() > 0.1
	):
		_sprint_grace_t = SLIDE_SPRINT_GRACE
		_sprint_carry_spd = maxf(hspd, SPRINT_SPEED)
	elif on_floor_now and not crouch_held and hspd >= SPRINT_SPEED * 0.92:
		# Fast enough that we treat it as sprint momentum even without the key
		_sprint_grace_t = maxf(_sprint_grace_t, SLIDE_SPRINT_GRACE * 0.55)
		_sprint_carry_spd = maxf(_sprint_carry_spd, hspd)
	else:
		_sprint_grace_t = maxf(0.0, _sprint_grace_t - delta)

	# Slide: crouch-on-impact after dive, OR crouch *press* after sprint / while fast.
	# Space dive alone lands standing. Holding crouch after a slide ends does not re-slide.
	var crouch_pressed := crouch_held and not _crouch_was_held
	_crouch_was_held = crouch_held
	if on_floor_now and crouch_held and not jumped_this_frame and _drag_target == null:
		var sprint_recent := _sprint_grace_t > 0.0
		# Sprint→crouch: key held, OR just released, OR still at sprint-ish speed
		var sprint_slide := (
			(sprinting or sprint_recent)
			and (hspd >= WALK_SPEED * 0.75 or _sprint_carry_spd >= WALK_SPEED * 0.9)
		)
		var fast_enough := hspd >= SLIDE_START_SPEED or _sprint_carry_spd >= SLIDE_START_SPEED
		var enter_slide := prev_diving or (crouch_pressed and (fast_enough or sprint_slide))
		if not _sliding and enter_slide:
			# Start slide once — do not re-boost every frame
			_sliding = true
			_slide_time = 0.0
			_latched_dive = false
			_sprint_grace_t = 0.0
			var sdir := hvel if hspd > 0.15 else direction
			if sdir.length() < 0.15:
				sdir = -transform.basis.z
			sdir.y = 0.0
			if sdir.length() < 0.01:
				sdir = Vector3(0, 0, -1)
			else:
				sdir = sdir.normalized()
			var boost := maxf(hspd, SLIDE_BOOST)
			if prev_diving:
				boost = maxf(boost, DIVE_AIR_SPEED)
				_dive_slide_blend = 1.0
			elif sprint_slide or sprinting or sprint_recent:
				boost = maxf(boost, maxf(SLIDE_BOOST, _sprint_carry_spd))
			_sprint_carry_spd = 0.0
			velocity.x = sdir.x * boost
			velocity.z = sdir.z * boost
			velocity.y = 0.0

	# Space-dive latch ends on floor; crouch release cancels slide/crouch
	if on_floor_now:
		_latched_dive = false
	if not crouch_held:
		_sliding = false
		_slide_time = 0.0
		if not _latched_dive:
			_diving = false
			_dive_slide_blend = 0.0

	_crouching = (crouch_held and on_floor_now) or _sliding or _diving
	_apply_crouch()
	_was_diving = _diving
	if _dive_slide_blend > 0.0:
		_dive_slide_blend = maxf(0.0, _dive_slide_blend - delta * 2.2)

	_update_wallrun_camera(delta)

	if _wallrunning:
		# Keep crouch edge in sync even though we skip the slide/crouch block
		_crouch_was_held = crouch_held
		move_and_slide()
		_update_drag()
		_update_threat()
		_update_takedown_prompt()
		return

	if _sliding:
		_slide_time += delta
		var spd := Vector3(velocity.x, 0.0, velocity.z).length()
		# Always slow down (even briefly off edges / tables)
		spd = maxf(spd - SLIDE_FRICTION * delta, 0.0)
		if (
			not crouch_held
			or spd < SLIDE_MIN_SPEED
			or _drag_target != null
			or _slide_time >= SLIDE_MAX_TIME
		):
			_sliding = false
			_slide_time = 0.0
			if crouch_held and spd > 0.05:
				var d := Vector3(velocity.x, 0.0, velocity.z)
				if d.length() > 0.01:
					d = d.normalized()
					velocity.x = d.x * minf(spd, CROUCH_SPEED)
					velocity.z = d.z * minf(spd, CROUCH_SPEED)
		else:
			var slide_dir := Vector3(velocity.x, 0.0, velocity.z)
			if slide_dir.length() < 0.01:
				slide_dir = -transform.basis.z
			slide_dir.y = 0.0
			slide_dir = slide_dir.normalized()
			if direction.length() > 0.1:
				# Light steer only — no re-acceleration
				slide_dir = slide_dir.lerp(direction, minf(1.0, 1.5 * delta)).normalized()
			velocity.x = slide_dir.x * spd
			velocity.z = slide_dir.z * spd

	var speed := WALK_SPEED
	if not _sliding:
		if _drag_target != null:
			speed = DRAG_SPEED
		elif crouch_held and on_floor_now and not _diving:
			speed = CROUCH_SPEED
		elif Input.is_action_pressed("sprint"):
			speed = SPRINT_SPEED

		# Ground move (only when truly on floor — not sticky mid-air)
		if on_floor_now and not jumped_this_frame and velocity.y <= 0.5 and not _sliding:
			if direction:
				velocity = _velocity_along_floor(direction, speed)
			else:
				velocity.x = move_toward(velocity.x, 0.0, speed)
				velocity.z = move_toward(velocity.z, 0.0, speed)
				velocity.y = minf(velocity.y, 0.0)
		elif in_air or _diving or jumped_this_frame:
			# AIR / DIVE: always use dive speed when Ctrl held — never crouch crawl
			if crouch_held or _diving:
				_apply_dive_boost(direction)
			elif direction:
				var cur := Vector3(velocity.x, 0.0, velocity.z).length()
				var air_speed := maxf(speed, cur)
				velocity.x = direction.x * air_speed
				velocity.z = direction.z * air_speed

	if not jumped_this_frame:
		_move_with_step_up(direction)
	else:
		move_and_slide()
	_update_drag()
	_update_threat()
	_update_takedown_prompt()
	_update_footsteps(delta, speed, direction != Vector3.ZERO)

	# Fall void safety: drop far below spawn/checkpoint → reset
	var void_y := -8.0
	if _has_checkpoint:
		void_y = _checkpoint.origin.y - 40.0
	if global_position.y < void_y:
		return_to_checkpoint()


## Project wish direction onto the current floor so slopes/stairs don't leave the surface.
func _velocity_along_floor(wish_dir: Vector3, speed: float) -> Vector3:
	wish_dir.y = 0.0
	if wish_dir.length() < 0.01:
		return Vector3(velocity.x, minf(velocity.y, 0.0) if is_on_floor() else velocity.y, velocity.z)
	wish_dir = wish_dir.normalized()
	if not is_on_floor():
		return Vector3(wish_dir.x * speed, velocity.y, wish_dir.z * speed)
	var n := get_floor_normal()
	# If nearly flat, keep simple horizontal control
	if n.y > 0.99:
		return Vector3(wish_dir.x * speed, 0.0, wish_dir.z * speed)
	# Project onto slope plane — walk down without hopping off the surface
	var along := wish_dir.slide(n)
	if along.length() < 0.01:
		return Vector3(wish_dir.x * speed, 0.0, wish_dir.z * speed)
	along = along.normalized() * speed
	# Slight stick so we don't bounce off the ramp
	along -= n * 0.5
	return along


## Small-curb step-up (stairs use invisible walk surfaces — smooth, no snap).
func _move_with_step_up(wish_dir: Vector3) -> void:
	var delta := get_physics_process_delta_time()
	# Finish a smooth step blend if active
	if _step_smooth_t >= 0.0:
		_step_smooth_t += delta
		var u := clampf(_step_smooth_t / STEP_SMOOTH_TIME, 0.0, 1.0)
		# Smoothstep
		u = u * u * (3.0 - 2.0 * u)
		global_position.y = lerpf(_step_smooth_from_y, _step_smooth_to_y, u)
		velocity.y = 0.0
		if u >= 1.0:
			_step_smooth_t = -1.0
			global_position.y = _step_smooth_to_y

	var dir := wish_dir
	dir.y = 0.0
	if dir.length() < 0.1:
		dir = Vector3(velocity.x, 0.0, velocity.z)
	if dir.length() > 0.1:
		dir = dir.normalized()
	else:
		dir = Vector3.ZERO

	# Never clamp air/dive/slide to crouch crawl — that killed jump-dive speed
	var max_spd := SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
	if _diving:
		max_spd = DIVE_AIR_SPEED * 1.25
	elif _sliding:
		max_spd = maxf(SLIDE_BOOST, DIVE_AIR_SPEED)
	elif _crouching and is_on_floor() and not _diving:
		max_spd = CROUCH_SPEED
	var hvel2 := Vector3(velocity.x, 0.0, velocity.z)
	if hvel2.length() > max_spd + 0.05:
		hvel2 = hvel2.normalized() * max_spd
		velocity.x = hvel2.x
		velocity.z = hvel2.z

	move_and_slide()

	# Soft curb step only when blocked (not during stair-slope walking)
	if _step_smooth_t >= 0.0 or dir == Vector3.ZERO or not _can_attempt_step():
		return
	if not is_on_wall() and not _feet_blocked_by_riser(dir):
		return
	var climb_dir := dir
	if is_on_wall():
		var n := get_wall_normal()
		n.y = 0.0
		if n.length() > 0.1:
			climb_dir = (-n).normalized()
	_try_step_onto_ledge(climb_dir)


func _can_attempt_step() -> bool:
	if _sliding or _diving or _mantling or _wallrunning or _drag_target != null:
		return false
	return _is_grounded_for_step()


func _is_grounded_for_step() -> bool:
	if is_on_floor():
		return true
	var space := get_world_3d().direct_space_state
	if space == null:
		return false
	var from := global_position + Vector3(0.0, 0.25, 0.0)
	var to := global_position + Vector3(0.0, -0.55, 0.0)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1
	q.exclude = [self]
	var hit := space.intersect_ray(q)
	return not hit.is_empty() and hit.normal.y > 0.45


func _feet_blocked_by_riser(dir: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	if space == null:
		return false
	var origin := global_position + Vector3(0.0, 0.12, 0.0)
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * 0.45)
	q.collision_mask = 1
	q.exclude = [self]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return false
	return hit.normal.y < 0.35


## Start a smooth Y blend onto a small curb/ledge (one step, no speed gift).
func _try_step_onto_ledge(dir: Vector3) -> bool:
	dir.y = 0.0
	if dir.length() < 0.01 or _step_smooth_t >= 0.0:
		return false
	dir = dir.normalized()
	var max_step := MotorConstants.MAX_STEP_HEIGHT
	var space := get_world_3d().direct_space_state
	if space == null:
		return false
	var feet_y := global_position.y
	var dists: Array[float] = [0.30, 0.40, 0.50]
	for dist in dists:
		var probe: Vector3 = global_position + dir * dist
		var from := Vector3(probe.x, feet_y + max_step + 0.25, probe.z)
		var to := Vector3(probe.x, feet_y - 0.15, probe.z)
		var q := PhysicsRayQueryParameters3D.create(from, to)
		q.collision_mask = 1
		q.exclude = [self]
		var hit := space.intersect_ray(q)
		if hit.is_empty() or hit.normal.y < 0.45:
			continue
		var ledge_y: float = hit.position.y
		var step_h: float = ledge_y - feet_y
		if step_h < 0.02 or step_h > max_step:
			continue
		var head_q := PhysicsRayQueryParameters3D.create(
			Vector3(probe.x, ledge_y + 0.12, probe.z),
			Vector3(probe.x, ledge_y + STAND_HEIGHT * 0.9, probe.z)
		)
		head_q.collision_mask = 1
		head_q.exclude = [self]
		if not space.intersect_ray(head_q).is_empty():
			continue
		# Tiny forward + smooth vertical blend (no teleport pop)
		const FORWARD_NUDGE := 0.06
		global_position.x += dir.x * FORWARD_NUDGE
		global_position.z += dir.z * FORWARD_NUDGE
		_step_smooth_from_y = global_position.y
		_step_smooth_to_y = ledge_y + 0.03
		_step_smooth_t = 0.0
		velocity.y = 0.0
		return true
	return false


# --- Public motor API (tests + gym) -------------------------------------------

## Pure height-band check used by mantle probes and unit tests.
func is_mantleable_height(height_above_feet: float) -> bool:
	return MotorConstants.is_mantleable_height(height_above_feet)


func classify_landing(fall_height: float) -> int:
	return MotorConstants.classify_landing(fall_height)


func landing_noise_for_fall(fall_height: float) -> float:
	return MotorConstants.landing_noise_for_fall(fall_height)


func get_last_landing_kind() -> int:
	return _last_landing_kind


func get_last_landing_noise() -> float:
	return _last_landing_noise


func has_accuracy_penalty() -> bool:
	return _accuracy_penalty_t > 0.0


func set_checkpoint(xform: Transform3D) -> void:
	_checkpoint = xform
	_has_checkpoint = true


func return_to_checkpoint() -> void:
	if not _has_checkpoint:
		return
	global_transform = _checkpoint
	velocity = Vector3.ZERO
	_mantling = false
	_wallrunning = false
	_wallrun_vertical = false
	_wallrun_cooldown = 0.0
	_wallrun_used_air = false
	_wallrun_facing_out = false
	_wallrun_turn_t = -1.0
	_wallrun_cam_roll = 0.0
	if camera_pivot:
		camera_pivot.rotation.z = 0.0
	_sliding = false
	_diving = false
	_latched_dive = false
	_airborne = false
	ObjectiveTracker.set_prompt("Returned to zone checkpoint")


## Grab a standable ledge and pull up. Works from ground, air, or wallrun.
func try_mantle() -> bool:
	if _mantling or _drag_target != null or _sliding:
		return false
	var max_up := MotorConstants.MANTLE_MAX_UP_VEL
	if _wallrunning:
		# Vertical climb runs at ~7 m/s — must still be able to grab the lip
		max_up = MotorConstants.MANTLE_WALLCLIMB_MAX_UP_VEL
	if velocity.y > max_up:
		return false
	if velocity.y < MotorConstants.MANTLE_MAX_DOWN_VEL:
		return false
	var result := probe_mantle_target()
	if result.is_empty() and _wallrunning and _wallrun_vertical:
		result = _probe_wallclimb_lip()
	if result.is_empty():
		return false
	_begin_mantle(result["stand_pos"] as Vector3, float(result.get("ledge_height", 1.2)))
	return true


## While climbing: find standable top just past the wall face (balcony lip).
func _probe_wallclimb_lip() -> Dictionary:
	if _wallrun_normal.length() < 0.1:
		return {}
	var space := get_world_3d().direct_space_state
	if space == null:
		return {}
	var n := _wallrun_normal
	n.y = 0.0
	if n.length() < 0.1:
		return {}
	n = n.normalized()
	var feet_y := global_position.y
	# Search from just above hands up past likely balcony height
	var best: Dictionary = {}
	var best_h := 999.0
	var h_lo := 0.25
	var h_hi := MotorConstants.MANTLE_MAX + 0.35
	for i in 16:
		var t := float(i) / 15.0
		var probe_h := lerpf(h_lo, h_hi, t)
		# Start above, slightly past the outer face into the pad
		var above := global_position + Vector3(0.0, probe_h + 0.35, 0.0) - n * MotorConstants.MANTLE_TOP_INSET
		var down_q := PhysicsRayQueryParameters3D.create(above, above + Vector3(0, -2.8, 0))
		down_q.collision_mask = 1
		down_q.exclude = [self]
		var down_hit := space.intersect_ray(down_q)
		if down_hit.is_empty():
			continue
		if down_hit.normal.y < 0.45:
			continue
		var stand: Vector3 = down_hit.position
		var ledge_h := stand.y - feet_y
		if ledge_h < h_lo or ledge_h > h_hi:
			continue
		# Must be a surface beyond/at the wall (not the floor we climbed from)
		if stand.y < feet_y + 0.2:
			continue
		# Pull-up only needs torso clearance; balcony glass rails may sit at head height
		var head_from := stand + Vector3(0, 0.08, 0) - n * 0.55
		var head_q := PhysicsRayQueryParameters3D.create(
			head_from, head_from + Vector3(0, 1.05, 0)
		)
		head_q.collision_mask = 1
		head_q.exclude = [self]
		if not space.intersect_ray(head_q).is_empty():
			continue
		if ledge_h < best_h:
			best_h = ledge_h
			# Stand well onto the pad (past face + glass rail lines)
			var stand_pos := stand - n * 0.7 + Vector3(0, 0.04, 0)
			best = {"stand_pos": stand_pos, "ledge_height": ledge_h, "normal": n}
	return best


## Returns {} or {stand_pos, ledge_height} after world probes. Callable by tests with a built world.
func probe_mantle_target() -> Dictionary:
	var space := get_world_3d().direct_space_state
	if space == null:
		return {}
	var feet_y := global_position.y
	var forward := -transform.basis.z
	forward.y = 0.0
	if forward.length() < 0.01:
		var vf := Vector3(velocity.x, 0.0, velocity.z)
		if vf.length() > 0.2:
			forward = vf
		else:
			return {}
	forward = forward.normalized()

	# Collect candidate wall faces: look-forward + left/right (wallrun tops)
	var wall_hits: Array = []
	var eye_ys := [0.55, 0.9, 1.2, 1.5, 1.75, 2.05]
	var cast_dirs: Array = [forward, transform.basis.x, -transform.basis.x]
	if _wallrunning and _wallrun_normal.length() > 0.1:
		cast_dirs.append(-_wallrun_normal)
	for eye_y in eye_ys:
		for cdir in cast_dirs:
			var d: Vector3 = cdir
			d.y = 0.0
			if d.length() < 0.01:
				continue
			d = d.normalized()
			for side in [0.0, 0.2, -0.2]:
				var origin: Vector3 = global_position + Vector3(0, float(eye_y), 0) + transform.basis.x * float(side)
				var wall_q := PhysicsRayQueryParameters3D.create(
					origin, origin + d * MotorConstants.MANTLE_FORWARD_REACH
				)
				wall_q.collision_mask = 1
				wall_q.exclude = [self]
				var hit := space.intersect_ray(wall_q)
				if not hit.is_empty() and absf(hit.normal.y) < 0.55:
					wall_hits.append(hit)
					break
	if wall_hits.is_empty():
		return {}

	# Prefer lowest valid ledge in band (natural vault / grab height)
	var best: Dictionary = {}
	var best_h := 999.0
	var steps := 14
	var h_lo := MotorConstants.MANTLE_MIN * 0.5 if not is_on_floor() else MotorConstants.MANTLE_MIN
	var h_hi := MotorConstants.MANTLE_MAX
	# Wall-climb: allow slightly lower lips (hands already high on the face)
	if _wallrunning and _wallrun_vertical:
		h_lo = 0.3
		h_hi = MotorConstants.MANTLE_MAX + 0.25
	for wall_hit in wall_hits:
		var hit_pos: Vector3 = wall_hit.position
		var normal: Vector3 = wall_hit.normal
		normal.y = 0.0
		if normal.length() < 0.2:
			normal = -forward
		else:
			normal = normal.normalized()
		for i in steps + 1:
			var t := float(i) / float(steps)
			var probe_h := lerpf(h_lo, h_hi, t)
			# Push further onto the pad so balcony tops register (not just thin wall caps)
			var inset := MotorConstants.MANTLE_TOP_INSET if (_wallrunning and _wallrun_vertical) else 0.5
			var above := Vector3(hit_pos.x, feet_y + probe_h + MotorConstants.MANTLE_PROBE_UP, hit_pos.z)
			above += -normal * inset
			var down_q := PhysicsRayQueryParameters3D.create(above, above + Vector3(0, -2.5, 0))
			down_q.collision_mask = 1
			down_q.exclude = [self]
			var down_hit := space.intersect_ray(down_q)
			if down_hit.is_empty():
				continue
			if down_hit.normal.y < 0.45:
				continue # not a standable top
			var stand: Vector3 = down_hit.position
			var ledge_h := stand.y - feet_y
			# Ground: strict band (beyond jump). Air/wallrun: wider hand-reach window.
			if is_on_floor():
				if not is_mantleable_height(ledge_h):
					continue
			elif ledge_h < h_lo or ledge_h > h_hi:
				continue
			# Head clearance — shorter when climbing (balcony glass rails)
			var head_h := 1.05 if (_wallrunning and _wallrun_vertical) else (STAND_HEIGHT + 0.1)
			var head_inset := 0.55 if (_wallrunning and _wallrun_vertical) else 0.35
			var head_q := PhysicsRayQueryParameters3D.create(
				stand + Vector3(0, 0.1, 0) - normal * head_inset,
				stand + Vector3(0, head_h, 0) - normal * head_inset
			)
			head_q.collision_mask = 1
			head_q.exclude = [self]
			if not space.intersect_ray(head_q).is_empty():
				continue
			if ledge_h < best_h:
				best_h = ledge_h
				var onto := 0.65 if (_wallrunning and _wallrun_vertical) else 0.45
				var stand_pos := stand - normal * onto + Vector3(0, 0.03, 0)
				best = {"stand_pos": stand_pos, "ledge_height": ledge_h, "normal": normal}
	return best


# --- Mantle / landing / wallrun internals -------------------------------------

func _begin_mantle(stand_pos: Vector3, ledge_height: float = 1.2) -> void:
	_mantling = true
	_mantle_t = 0.0
	_mantle_from = global_position
	_mantle_to = stand_pos
	# Hang point: hands on lip, body still below
	var to_stand := stand_pos - global_position
	var planar := Vector3(to_stand.x, 0.0, to_stand.z)
	var along := planar.normalized() if planar.length() > 0.05 else -transform.basis.z
	along.y = 0.0
	if along.length() > 0.01:
		along = along.normalized()
	else:
		along = Vector3(0, 0, -1)
	_mantle_mid = Vector3(
		stand_pos.x - along.x * 0.12,
		stand_pos.y - 0.42,
		stand_pos.z - along.z * 0.12
	)
	# Taller ledges take a beat longer to pull up
	_mantle_duration = MotorConstants.MANTLE_DURATION + clampf(ledge_height - 1.0, 0.0, 1.2) * 0.12
	if _wallrunning:
		_wallrunning = false
		_wallrun_cooldown = 0.12
	_sliding = false
	_diving = false
	_latched_dive = false
	velocity = Vector3.ZERO
	GameAudio.play_interact()
	ObjectiveTracker.set_prompt("Pull-up")


func _tick_mantle(delta: float) -> void:
	_mantle_t += delta
	var u := clampf(_mantle_t / maxf(_mantle_duration, 0.05), 0.0, 1.0)
	# Phase 1: snap hands to lip · Phase 2: pull body onto surface
	if u < 0.38:
		var p := u / 0.38
		var ease := p * p * (3.0 - 2.0 * p)
		global_position = _mantle_from.lerp(_mantle_mid, ease)
	else:
		var p := (u - 0.38) / 0.62
		var ease := 1.0 - (1.0 - p) * (1.0 - p)
		global_position = _mantle_mid.lerp(_mantle_to, ease)
	velocity = Vector3.ZERO
	if u >= 1.0:
		_mantling = false
		global_position = _mantle_to
		_airborne = false
		_air_time = 0.0
		velocity = -transform.basis.z * MotorConstants.MANTLE_EXIT_SPEED
		ObjectiveTracker.set_prompt("")


func _resolve_landing() -> void:
	var fall_h := _air_peak_y - global_position.y
	var kind := classify_landing(fall_h)
	_last_landing_kind = kind
	_last_landing_noise = landing_noise_for_fall(fall_h)
	if kind == MotorConstants.LandingKind.NONE:
		return
	NoiseBus.emit_noise(global_position, _last_landing_noise, self)
	if kind == MotorConstants.LandingKind.HARD:
		_accuracy_penalty_t = MotorConstants.LANDING_HARD_ACCURACY_SEC
		_hurt_flash = maxf(_hurt_flash, 0.25)
		ObjectiveTracker.set_prompt("Hard landing")
		GameAudio.play_hurt()
	else:
		ObjectiveTracker.set_prompt("Soft landing")


func _feet_clearance() -> float:
	## Approximate height of feet above supporting geometry (ray down).
	var space := get_world_3d().direct_space_state
	if space == null:
		return 99.0
	var from := global_position + Vector3(0.0, 0.2, 0.0)
	var to := global_position + Vector3(0.0, -2.5, 0.0)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1
	q.exclude = [self]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return 99.0
	return maxf(0.0, global_position.y - hit.position.y)


func _wallrun_forward() -> Vector3:
	## Preferred run direction: velocity if moving, else look.
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if flat.length() > 0.4:
		return flat.normalized()
	var look := -transform.basis.z
	look.y = 0.0
	if look.length() < 0.01:
		return Vector3(0, 0, -1)
	return look.normalized()


func _probe_wallrun_wall() -> Dictionary:
	## Nearest runnable wall: sides (lateral) + forward (vertical climb).
	var space := get_world_3d().direct_space_state
	if space == null:
		return {}
	var forward := _wallrun_forward()
	var right := forward.cross(Vector3.UP)
	if right.length() < 0.01:
		right = transform.basis.x
	right = right.normalized()
	var look_fwd := -transform.basis.z
	look_fwd.y = 0.0
	if look_fwd.length() > 0.01:
		look_fwd = look_fwd.normalized()
	else:
		look_fwd = forward
	var origins := [
		global_position + Vector3(0, 0.55, 0),
		global_position + Vector3(0, 0.95, 0),
		global_position + Vector3(0, 1.35, 0),
	]
	var best: Dictionary = {}
	var best_d := MotorConstants.WALLRUN_ATTACH_DIST + 0.01
	var cast_dirs: Array = [
		right, -right, transform.basis.x, -transform.basis.x, look_fwd, forward
	]
	for origin in origins:
		for dvec_raw in cast_dirs:
			var dvec: Vector3 = dvec_raw
			dvec.y = 0.0
			if dvec.length() < 0.01:
				continue
			dvec = dvec.normalized()
			var q := PhysicsRayQueryParameters3D.create(
				origin, origin + dvec * MotorConstants.WALLRUN_ATTACH_DIST
			)
			q.collision_mask = 1
			q.exclude = [self]
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				continue
			if absf(hit.normal.y) > 0.35:
				continue
			var n: Vector3 = hit.normal
			n.y = 0.0
			if n.length() < 0.5:
				continue
			n = n.normalized()
			var dist: float = origin.distance_to(hit.position)
			if dist < best_d:
				best_d = dist
				best = {"normal": n, "distance": dist, "position": hit.position}
	return best


func _try_begin_wallrun() -> void:
	if _wallrun_cooldown > 0.0 or _wallrunning or _wallrun_used_air:
		return
	if is_on_floor():
		return
	if _feet_clearance() < MotorConstants.WALLRUN_MIN_HEIGHT:
		return
	var hspd := Vector3(velocity.x, 0.0, velocity.z).length()
	var sprinting := Input.is_action_pressed("sprint")
	var hit := _probe_wallrun_wall()
	if hit.is_empty():
		return
	var best_n: Vector3 = hit.normal
	var fwd := _wallrun_forward()
	var into_dot := fwd.dot(best_n)
	var look := -transform.basis.z
	look.y = 0.0
	if look.length() > 0.1:
		# Prefer look for into-wall detection (player aims at the wall to climb)
		into_dot = look.normalized().dot(best_n)

	var want_vertical := MotorConstants.can_start_vertical_wallrun(hspd, into_dot, sprinting)
	var want_lateral := MotorConstants.can_start_wallrun(hspd, into_dot, sprinting)

	# Prefer vertical when clearly driving into the wall
	if want_vertical:
		_begin_vertical_wallrun(best_n, hspd)
		return
	if not want_lateral:
		return
	var along := fwd.slide(best_n)
	if along.length() < 0.2:
		return
	along = along.normalized()
	if look.length() > 0.1 and along.dot(look.normalized()) < 0.0:
		along = -along
	_begin_lateral_wallrun(best_n, along, hspd)


func _begin_vertical_wallrun(wall_n: Vector3, hspd: float) -> void:
	_diving = false
	_latched_dive = false
	_sliding = false
	_wallrunning = true
	_wallrun_vertical = true
	_wallrun_used_air = true
	_wallrun_t = 0.0
	_wallrun_normal = wall_n
	_wallrun_side = 0.0
	_wallrun_facing_out = false
	_wallrun_turn_t = -1.0
	# Climb up; small residual into-wall stick
	var up_spd := maxf(MotorConstants.WALLRUN_VERT_SPEED, hspd * 0.55)
	velocity = -wall_n * MotorConstants.WALLRUN_VERT_STICK + Vector3.UP * up_spd
	_airborne = true
	ObjectiveTracker.set_prompt("Wall climb — Ctrl turn · Space grab/kick")


func _begin_lateral_wallrun(wall_n: Vector3, along: Vector3, hspd: float) -> void:
	_diving = false
	_latched_dive = false
	_sliding = false
	_wallrunning = true
	_wallrun_vertical = false
	_wallrun_used_air = true
	_wallrun_t = 0.0
	_wallrun_normal = wall_n
	_wallrun_along = along.normalized()
	_wallrun_facing_out = false
	_wallrun_turn_t = -1.0
	var right := along.cross(Vector3.UP).normalized()
	_wallrun_side = -signf(right.dot(wall_n))
	if absf(_wallrun_side) < 0.1:
		_wallrun_side = 1.0
	velocity = _wallrun_along * maxf(hspd, MotorConstants.WALLRUN_SPEED)
	velocity.y = _wallrun_arc_vertical_speed(0.0)
	_airborne = true
	ObjectiveTracker.set_prompt("Wallrun — Ctrl look out · Space kick")


func _wallrun_arc_vertical_speed(t: float) -> float:
	## Lateral arc: climb then descend.
	var T := MotorConstants.WALLRUN_MAX_TIME
	var peak := MotorConstants.WALLRUN_ARC_PEAK
	var apex := clampf(MotorConstants.WALLRUN_ARC_APEX_FRAC, 0.2, 0.6) * T
	if t <= apex:
		var w := (PI * 0.5) / maxf(apex, 0.05)
		return peak * w * cos(w * t)
	var span := maxf(T - apex, 0.05)
	var u := clampf((t - apex) / span, 0.0, 1.0)
	return -peak * (PI * 0.5) / span * sin(PI * 0.5 * u)


func _wallrun_keep_attached() -> bool:
	var space := get_world_3d().direct_space_state
	if space == null:
		return false
	var origin := global_position + Vector3(0, 1.0, 0)
	var q := PhysicsRayQueryParameters3D.create(
		origin, origin - _wallrun_normal * (MotorConstants.WALLRUN_ATTACH_DIST + 0.4)
	)
	q.collision_mask = 1
	q.exclude = [self]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return false
	if absf(hit.normal.y) > 0.4:
		return false
	var n: Vector3 = hit.normal
	n.y = 0.0
	if n.length() < 0.4:
		return false
	_wallrun_normal = n.normalized()
	return true


func _tick_wallrun(delta: float) -> bool:
	## Returns true if jump was consumed (kick or mantle) this frame.
	_wallrun_t += delta
	var max_t := (
		MotorConstants.WALLRUN_VERT_MAX_TIME
		if _wallrun_vertical
		else MotorConstants.WALLRUN_MAX_TIME
	)
	if _wallrun_t >= max_t:
		# Vertical: last chance to grab the lip before peeling off
		if _wallrun_vertical and try_mantle():
			return true
		_end_wallrun(false)
		return false
	if is_on_floor() and _wallrun_t > max_t * 0.2:
		_end_wallrun(false)
		return false

	if not _wallrun_keep_attached():
		# Lost wall — try grab if we crested a lip
		if try_mantle():
			return true
		_end_wallrun(false)
		return false

	if _wallrun_vertical:
		return _tick_vertical_wallrun(delta)
	return _tick_lateral_wallrun(delta)


func _tick_vertical_wallrun(delta: float) -> bool:
	# Mirror's Edge: Ctrl = 180° turn to face away from wall (kick setup)
	if _handle_wallrun_crouch_turn():
		return false
	_tick_wallrun_turnaround(delta)
	var crouch_edge := _is_crouch_held() and not _crouch_was_held

	# Climb up the face; stick into wall
	var climb := MotorConstants.WALLRUN_VERT_SPEED
	# Ease off climb earlier so lip-grab has a longer window
	var max_t := MotorConstants.WALLRUN_VERT_MAX_TIME
	var u := clampf(_wallrun_t / max_t, 0.0, 1.0)
	if u > 0.55:
		climb = lerpf(climb, climb * 0.25, (u - 0.55) / 0.45)
	# After turn, still stick but slightly less (ready to kick)
	var stick := MotorConstants.WALLRUN_VERT_STICK
	if _wallrun_facing_out:
		stick *= 0.75
	velocity = -_wallrun_normal * stick + Vector3.UP * climb

	# Auto pull-up when lip enters hand range (only while still facing the wall)
	if not _wallrun_facing_out and try_mantle():
		return true

	if Input.is_action_just_pressed("jump"):
		if not _wallrun_facing_out and try_mantle():
			return true
		_end_wallrun(true)
		return true
	if Input.is_action_pressed("move_back") and not crouch_edge:
		_end_wallrun(false)
	return false


func _start_wallrun_turnaround() -> void:
	## Snap yaw toward facing away from wall (out along normal). ME look-out.
	if _wallrun_turn_t >= 0.0:
		return
	_wallrun_turn_t = 0.0
	_wallrun_turn_from_yaw = rotation.y
	# Godot forward is -Z; face along outward normal
	var away := _wallrun_normal
	var target := atan2(-away.x, -away.z)
	# Shortest arc
	var diff := wrapf(target - _wallrun_turn_from_yaw, -PI, PI)
	_wallrun_turn_to_yaw = _wallrun_turn_from_yaw + diff
	_wallrun_facing_out = true
	if _wallrun_vertical:
		ObjectiveTracker.set_prompt("Wall climb — Space kick off")
	else:
		ObjectiveTracker.set_prompt("Wallrun — Space kick off")


func _tick_wallrun_turnaround(delta: float) -> void:
	if _wallrun_turn_t < 0.0:
		return
	_wallrun_turn_t += delta
	var dur := MotorConstants.WALLRUN_TURN_TIME
	var u := clampf(_wallrun_turn_t / maxf(dur, 0.01), 0.0, 1.0)
	# Smoothstep
	u = u * u * (3.0 - 2.0 * u)
	rotation.y = lerpf(_wallrun_turn_from_yaw, _wallrun_turn_to_yaw, u)
	# Slight look-down while turning out (ME read)
	var pitch_target := deg_to_rad(-12.0)
	_pitch = lerpf(_pitch, pitch_target, u * 0.55)
	camera_pivot.rotation.x = _pitch
	if u >= 1.0:
		rotation.y = _wallrun_turn_to_yaw
		_wallrun_turn_t = -1.0


func _handle_wallrun_crouch_turn() -> bool:
	## Ctrl: first press faces out; second drops. Returns true if wallrun ended.
	var crouch_edge := _is_crouch_held() and not _crouch_was_held
	if not crouch_edge and not Input.is_action_just_pressed("crouch"):
		return false
	if _wallrun_facing_out and _wallrun_turn_t < 0.0:
		_end_wallrun(false)
		return true
	_start_wallrun_turnaround()
	return false


func _tick_lateral_wallrun(delta: float) -> bool:
	# Mirror's Edge: Ctrl turns camera away from wall (keep running along it)
	if _handle_wallrun_crouch_turn():
		return false
	_tick_wallrun_turnaround(delta)

	# Strafe off toward free space only when still facing along the wall
	var input_x := Input.get_axis("move_left", "move_right")
	if (
		not _wallrun_facing_out
		and absf(input_x) > 0.55
		and signf(input_x) == -signf(_wallrun_side)
	):
		_end_wallrun(false)
		velocity += _wallrun_normal * 3.5
		return false

	# Keep locked travel direction so look-out doesn't zero the slide
	var along := _wallrun_along
	if along.length() < 0.1:
		along = _wallrun_forward().slide(_wallrun_normal)
	along.y = 0.0
	if along.length() < 0.12:
		_end_wallrun(false)
		return false
	along = along.normalized()
	_wallrun_along = along

	var spd := MotorConstants.WALLRUN_SPEED
	if Input.is_action_pressed("sprint"):
		spd = maxf(spd, SPRINT_SPEED + 0.4)
	var stick := MotorConstants.WALLRUN_STICK
	if _wallrun_facing_out:
		stick *= 0.7
	velocity = along * spd
	velocity.y = _wallrun_arc_vertical_speed(_wallrun_t)
	velocity += -_wallrun_normal * stick

	if Input.is_action_just_pressed("jump"):
		if not _wallrun_facing_out and try_mantle():
			return true
		_end_wallrun(true)
		return true
	if Input.is_action_pressed("move_back"):
		_end_wallrun(false)
	return false


func _end_wallrun(kick: bool) -> void:
	if not _wallrunning and not kick:
		return
	var was_vert := _wallrun_vertical
	var faced_out := _wallrun_facing_out
	_wallrunning = false
	_wallrun_vertical = false
	_wallrun_facing_out = false
	_wallrun_turn_t = -1.0
	_wallrun_along = Vector3.ZERO
	_wallrun_cooldown = MotorConstants.WALLRUN_COOLDOWN
	_wallrun_t = 0.0
	if kick:
		var kick_dir: Vector3
		if was_vert:
			# Stronger push when turned out (ME kick); still away from wall
			var up_w := 0.55 if faced_out else 0.65
			var out_w := 1.15 if faced_out else 1.0
			var look_w := 0.35 if faced_out else 0.0
			kick_dir = (
				_wallrun_normal * out_w
				+ Vector3.UP * up_w
				+ (-transform.basis.z) * look_w
			).normalized()
		elif faced_out:
			# Lateral look-out kick: away from wall + along track + up
			kick_dir = (
				_wallrun_normal * 1.05
				+ (-transform.basis.z) * 0.45
				+ Vector3.UP * 0.5
			).normalized()
		else:
			kick_dir = (
				-transform.basis.z * 0.85
				+ _wallrun_normal * 0.85
				+ Vector3.UP * 0.55
			).normalized()
		velocity = kick_dir * MotorConstants.WALLRUN_KICK_SPEED
		_air_dive_used = false
		_airborne = true
		_air_time = FLOOR_STICKY + 0.05
		_air_peak_y = global_position.y
		ObjectiveTracker.set_prompt("Wallkick")
	else:
		if was_vert:
			velocity = _wallrun_normal * 2.0 + Vector3.UP * maxf(velocity.y * 0.3, 0.0)
		else:
			var flat := Vector3(velocity.x, 0.0, velocity.z)
			if flat.length() > 0.1:
				flat = flat.slide(_wallrun_normal)
				if flat.length() > 0.1:
					velocity.x = flat.x
					velocity.z = flat.z
			velocity += _wallrun_normal * 1.2


func _update_wallrun_camera(delta: float) -> void:
	var target := 0.0
	# Lean into wall while looking along it; flatten when Ctrl look-out
	if _wallrunning and not _wallrun_vertical and not _wallrun_facing_out:
		target = deg_to_rad(MotorConstants.WALLRUN_CAM_ROLL_DEG) * _wallrun_side
	var rate := 12.0 if _wallrunning else 8.0
	_wallrun_cam_roll = lerpf(_wallrun_cam_roll, target, 1.0 - exp(-rate * delta))
	camera_pivot.rotation.z = _wallrun_cam_roll


func is_crouching() -> bool:
	return _crouching or _sliding or _diving


func is_sliding() -> bool:
	return _sliding


func is_diving() -> bool:
	return _diving


func _is_crouch_held() -> bool:
	# InputMap "crouch" plus raw Ctrl — physical Ctrl is unreliable as action-only on Linux
	if Input.is_action_pressed("crouch"):
		return true
	if Input.is_key_pressed(KEY_CTRL):
		return true
	if Input.is_physical_key_pressed(KEY_CTRL):
		return true
	return false


func _apply_dive_boost(wish_dir: Vector3 = Vector3.ZERO) -> void:
	## Raise horizontal speed to at least DIVE_AIR_SPEED along move/look direction.
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var dive_dir := wish_dir
	dive_dir.y = 0.0
	if dive_dir.length() < 0.1:
		dive_dir = flat
	if dive_dir.length() < 0.1:
		dive_dir = -transform.basis.z
		dive_dir.y = 0.0
	if dive_dir.length() < 0.01:
		return
	dive_dir = dive_dir.normalized()
	var push := maxf(flat.length(), DIVE_AIR_SPEED)
	velocity.x = dive_dir.x * push
	velocity.z = dive_dir.z * push


func is_mantling() -> bool:
	return _mantling


func is_wallrunning() -> bool:
	return _wallrunning


func noise_profile() -> float:
	if _drag_target != null:
		return 0.2
	if _sliding:
		return 0.4
	if _wallrunning:
		return 0.55
	if _crouching:
		return 0.05 if velocity.length() > 0.2 else 0.0
	if velocity.length() > 6.5:
		return 0.75
	if velocity.length() > 0.2:
		return 0.35
	return 0.0


func apply_damage(amount: float, _from: Node = null) -> void:
	if dead:
		return
	var remaining := amount
	if armor > 0.0:
		var absorbed := minf(armor, remaining * 0.65)
		armor -= absorbed
		remaining -= absorbed
	health = maxf(0.0, health - remaining)
	_hurt_flash = 0.55
	ObjectiveTracker.record_damage(amount)
	GameAudio.play_hurt()
	ObjectiveTracker.set_player_vitals(health, max_health, armor, max_armor)
	ObjectiveTracker.set_hurt_flash(_hurt_flash)
	if health <= 0.0:
		_die()


func heal(amount: float) -> void:
	health = minf(max_health, health + amount)
	ObjectiveTracker.set_player_vitals(health, max_health, armor, max_armor)


func add_armor(amount: float) -> void:
	armor = minf(max_armor, armor + amount)
	ObjectiveTracker.set_player_vitals(health, max_health, armor, max_armor)
	ObjectiveTracker.set_prompt("Body armor +%d" % int(amount))


func give_keycard(tier: int = 1) -> void:
	keycard_tier = maxi(keycard_tier, tier)
	has_keycard = keycard_tier >= 1
	if tier >= 2:
		ObjectiveTracker.set_prompt("SERVER keycard acquired")
	else:
		ObjectiveTracker.set_prompt("Facility keycard acquired")


func add_lockpicks(amount: int = 1) -> void:
	lockpicks += amount
	ObjectiveTracker.set_gadget_counts(lockpicks, camera_loops, decoys)
	ObjectiveTracker.set_prompt("Lockpicks +%d (%d)" % [amount, lockpicks])


func consume_lockpick() -> void:
	lockpicks = maxi(0, lockpicks - 1)
	ObjectiveTracker.set_gadget_counts(lockpicks, camera_loops, decoys)


func add_camera_loops(amount: int = 1) -> void:
	camera_loops += amount
	ObjectiveTracker.set_gadget_counts(lockpicks, camera_loops, decoys)
	ObjectiveTracker.set_prompt("Camera loop +%d (%d)" % [amount, camera_loops])


func add_decoys(amount: int = 1) -> void:
	decoys += amount
	ObjectiveTracker.set_gadget_counts(lockpicks, camera_loops, decoys)
	ObjectiveTracker.set_prompt("Decoys +%d (%d)" % [amount, decoys])


func _throw_decoy() -> void:
	if decoys <= 0:
		ObjectiveTracker.set_prompt("No decoys")
		return
	decoys -= 1
	ObjectiveTracker.set_gadget_counts(lockpicks, camera_loops, decoys)

	var body := RigidBody3D.new()
	body.set_script(load("res://scripts/world/decoy_projectile.gd"))
	body.collision_layer = 0
	body.collision_mask = 1
	body.mass = 0.35
	body.gravity_scale = 1.0
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	mesh_instance.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.55, 0.85)
	mat.emission_enabled = true
	mat.emission = Color(0.15, 0.4, 0.7)
	mesh_instance.material_override = mat
	body.add_child(mesh_instance)
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.09
	col.shape = shape
	body.add_child(col)

	var origin := camera.global_position + (-camera.global_transform.basis.z) * 0.55
	body.global_position = origin
	get_tree().current_scene.add_child(body)
	body.linear_velocity = (-camera.global_transform.basis.z) * 14.0 + Vector3.UP * 2.2
	GameAudio.play_interact()
	ObjectiveTracker.set_prompt("Decoy thrown (%d left)" % decoys)


func _use_camera_loop() -> void:
	if camera_loops <= 0:
		ObjectiveTracker.set_prompt("No camera loops")
		return
	camera_loops -= 1
	ObjectiveTracker.set_gadget_counts(lockpicks, camera_loops, decoys)
	var count := 0
	for node in get_tree().get_nodes_in_group("cameras"):
		if node.has_method("apply_loop"):
			node.apply_loop(14.0)
			count += 1
	GameAudio.play_pickup()
	NoiseBus.emit_noise(global_position, 0.08, self)
	ObjectiveTracker.set_prompt("Cameras looped %ds (%d feeds)" % [14, count])


func apply_recoil(pitch_delta_deg: float, yaw_delta_deg: float) -> void:
	var scale := 1.55 if _accuracy_penalty_t > 0.0 else 1.0
	_pitch = clampf(_pitch + deg_to_rad(pitch_delta_deg * scale), deg_to_rad(-85.0), deg_to_rad(85.0))
	camera_pivot.rotation.x = _pitch
	rotate_y(-deg_to_rad(yaw_delta_deg * scale))


func _die() -> void:
	dead = true
	_stop_drag()
	velocity = Vector3.ZERO
	ObjectiveTracker.mission_failed("You were killed. Press P to restart.")


func _apply_crouch() -> void:
	var shape := collision.shape as CapsuleShape3D
	if shape == null:
		return
	# Keep dive & slide capsule height the same so landing doesn't expand into
	# props (table) and jolt the body/camera.
	var target := STAND_HEIGHT
	if _diving or _sliding:
		target = DIVE_HEIGHT
	elif _crouching:
		target = CROUCH_HEIGHT
	shape.height = target
	collision.position.y = target * 0.5

	# Camera: stand during dive; duck on ground crouch; blend gently dive→slide
	const STAND_CAM_Y := 1.65
	const CROUCH_CAM_Y := 0.80
	const SLIDE_CAM_Y := 0.62
	var cam_target := STAND_CAM_Y
	if _diving:
		cam_target = STAND_CAM_Y
	elif _sliding:
		# While blending out of dive, ease from current stand height down
		cam_target = SLIDE_CAM_Y
	elif _crouching and is_on_floor():
		cam_target = CROUCH_CAM_Y
	var blend := 0.12 if _dive_slide_blend > 0.0 else 0.28
	if _diving:
		blend = 0.4 # snap to stand quickly when diving
	camera_pivot.position.y = lerpf(camera_pivot.position.y, cam_target, blend)


func _update_threat() -> void:
	var previous := _threat_target
	_threat_target = _ray_guard_target(9.0)
	if previous != null and previous != _threat_target and is_instance_valid(previous):
		if previous.has_method("set_under_threat"):
			previous.set_under_threat(self, false)
	if _threat_target and _threat_target.has_method("set_under_threat"):
		_threat_target.set_under_threat(self, true)
		if _threat_target.has_method("is_threat_ready") and _threat_target.is_threat_ready():
			if not ObjectiveTracker.prompt.begins_with("THREAT"):
				ObjectiveTracker.set_prompt("THREAT  1 hands up · 2 keycard · 3 open door")


func _ray_guard_target(max_dist: float) -> Node3D:
	if camera == null:
		return null
	var space := get_world_3d().direct_space_state
	var from := camera.global_position
	var to := from + (-camera.global_transform.basis.z) * max_dist
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collision_mask = 0b0101
	query.exclude = [self]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return null
	var col: Object = hit.collider
	if col == null:
		return null
	var node := col as Node
	if node == null:
		return null
	if node.is_in_group("guards"):
		return node as Node3D
	if node.get_parent() and node.get_parent().is_in_group("guards"):
		return node.get_parent() as Node3D
	return null


func _issue_demand(kind: String) -> void:
	if _threat_target == null or not is_instance_valid(_threat_target):
		ObjectiveTracker.set_prompt("Aim at a guard to threaten")
		return
	if not _threat_target.has_method("receive_demand"):
		return
	var result: String = _threat_target.receive_demand(kind)
	ObjectiveTracker.set_prompt(result)


func _try_takedown(lethal: bool) -> void:
	var guard := _nearest_takedown_target()
	if guard == null:
		return
	if guard.has_method("receive_takedown") and guard.receive_takedown(self, lethal):
		if lethal:
			ObjectiveTracker.set_prompt("Silent takedown")
		else:
			ObjectiveTracker.set_prompt("Knockout")


func _nearest_takedown_target() -> Node3D:
	var best: Node3D = null
	var best_d := 1.75
	for node in get_tree().get_nodes_in_group("guards"):
		if not is_instance_valid(node):
			continue
		var g := node as Node3D
		if g == null:
			continue
		if g.has_method("is_takedownable_from") and g.is_takedownable_from(self):
			var d := global_position.distance_to(g.global_position)
			if d < best_d:
				best_d = d
				best = g
	return best


func _update_takedown_prompt() -> void:
	if _drag_target != null:
		return
	var guard := _nearest_takedown_target()
	if guard and not (ObjectiveTracker.prompt.begins_with("F —") or ObjectiveTracker.prompt.begins_with("Q —")):
		ObjectiveTracker.set_prompt("F — kill · Q — knockout")


func _try_start_drag() -> bool:
	var nearest: Node3D = null
	var best := 2.2
	for node in get_tree().get_nodes_in_group("corpses"):
		if not is_instance_valid(node):
			continue
		var corpse := node as Node3D
		if corpse == null or corpse.get("hidden"):
			continue
		var d := global_position.distance_to(corpse.global_position)
		if d < best:
			best = d
			nearest = corpse
	if nearest and nearest.has_method("start_drag"):
		_drag_target = nearest
		nearest.start_drag()
		ObjectiveTracker.set_prompt("Dragging body — release E to drop · haul to closet")
		return true
	return false


func _stop_drag() -> void:
	if _drag_target and is_instance_valid(_drag_target) and _drag_target.has_method("stop_drag"):
		_drag_target.stop_drag()
	_drag_target = null


func _update_drag() -> void:
	if _drag_target == null or not is_instance_valid(_drag_target):
		_drag_target = null
		return
	if not Input.is_action_pressed("interact"):
		_stop_drag()
		return
	var behind := global_position - (-transform.basis.z) * 1.1
	behind.y = _drag_target.global_position.y
	_drag_target.global_position = _drag_target.global_position.lerp(behind, 0.35)


func _try_interact() -> void:
	if not interact_ray.is_colliding():
		return
	var collider := interact_ray.get_collider()
	if collider == null:
		return
	if collider.has_method("interact"):
		collider.interact(self)
	elif collider.get_parent() and collider.get_parent().has_method("interact"):
		collider.get_parent().interact(self)


func _update_footsteps(delta: float, speed: float, moving: bool) -> void:
	if not moving or not is_on_floor() or _crouching or _drag_target != null:
		_footstep_timer = 0.0
		return
	_footstep_timer -= delta
	if _footstep_timer <= 0.0:
		GameAudio.play_footstep()
		NoiseBus.emit_noise(global_position, 0.25 if speed < SPRINT_SPEED else 0.55, self)
		_footstep_timer = 0.45 if speed < SPRINT_SPEED else 0.3


func _on_ammo_changed(mag: int, reserve: int) -> void:
	ObjectiveTracker.set_ammo(mag, reserve)


func _on_weapon_changed(weapon_name: String) -> void:
	ObjectiveTracker.set_weapon_name(weapon_name)
