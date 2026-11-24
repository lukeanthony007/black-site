extends CharacterBody3D
## Guard FSM + Threat+Demand compliance.
## Detection helpers (evaluate_*) are pure-ish for headless stealth tests.

signal facility_leg_arrived(staff_id: String, room_id: String)

enum State { PATROL, SUSPICIOUS, CHASE, SEARCH, DEAD }
enum Demand { NONE, SURRENDER, KEYCARD, DOOR }
## Noise response codes for evaluate_noise_response
enum NoiseResponse { IGNORE = 0, SUSPICIOUS = 1, SEARCH = 2 }

const FACILITY_ARRIVAL_TOLERANCE := 0.45
const CHALLENGE_SECONDS := 1.25

@export var move_speed: float = 3.2
@export var chase_speed: float = 4.6
@export var sight_range: float = 18.0
@export var sight_angle_deg: float = 55.0
## Wider peripheral cone at reduced range (fraction of sight_range).
@export var peripheral_angle_deg: float = 95.0
@export var peripheral_range_mul: float = 0.45
@export var hearing_range: float = 24.0
@export var fire_range: float = 16.0
@export var fire_rate: float = 1.4
@export var damage: float = 12.0
@export var patrol_points: PackedVector3Array = PackedVector3Array()
@export var bravery: float = 0.45
@export var carries_keycard: bool = false
## Awareness fills on peripheral glimpses; 1.0 → investigate.
@export var awareness_rate: float = 1.35
@export var awareness_decay: float = 0.55
## Scene-independent authorization fact supplied by the room/facility that owns this guard.
@export var player_room_authorized: bool = false

var state: State = State.PATROL
var _patrol_index: int = 0
var _fire_cooldown: float = 0.0
var _player: Node3D
var _investigate_point: Vector3 = Vector3.ZERO
var _search_timer: float = 0.0
var _suspicious_timer: float = 0.0
var _last_known: Vector3 = Vector3.ZERO
var _body_check_timer: float = 0.0
var hidden: bool = false
var being_dragged: bool = false
var _kill_recorded: bool = false
var unconscious: bool = false
var _wake_timer: float = 0.0
const WAKE_SECONDS := 42.0

var _threatened_by: Node3D = null
var _threat_hold: float = 0.0
var _complying: bool = false
var _hands_up: bool = false
var _keycard_dropped: bool = false
var _comply_break: float = 0.0
var _spawn_grace: float = 2.0
var _awareness: float = 0.0
var _noise_stack: int = 0
var staff_id: String = ""
var job_id: String = ""
var credentials: Dictionary = {}
var _facility_leg_active: bool = false
var _facility_target: Vector3 = Vector3.ZERO
var _facility_target_room: String = ""
var _institutional_context: Dictionary = {}
var _institutional_response: int = FacilityIntrusionPolicy.Response.CLEAR
var _challenge_remaining: float = 0.0
var _challenge_contained: bool = false

@onready var damageable: Damageable = $Damageable
@onready var vision: RayCast3D = $VisionRay
@onready var body: Node3D = $Body
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var navigation_agent: NavigationAgent3D = get_node_or_null(^"NavigationAgent3D") as NavigationAgent3D


func _ready() -> void:
	add_to_group("guards")
	# The scene's CapsuleShape3D is shared across all guard instances — one
	# corpse resizing it would sink every living guard into the floor.
	if collision.shape:
		collision.shape = collision.shape.duplicate()
	bravery = clampf(bravery + randf_range(-0.15, 0.2), 0.15, 0.95)
	# ~35% of guards carry a spare facility card
	if randf() < 0.35:
		carries_keycard = true
	damageable.died.connect(_on_died)
	if patrol_points.is_empty():
		patrol_points = PackedVector3Array([global_position, global_position + Vector3(4, 0, 0)])
	NoiseBus.noise_emitted.connect(_on_noise)
	AlertPhase.phase_changed.connect(_on_phase_changed)
	if body and body.has_method("build"):
		body.call("build", Color(0.22, 0.23, 0.24)) # charcoal suit
	_set_mat(Color(0.22, 0.23, 0.24))
	# Face first patrol point so we don't stare at spawn through doorways
	if patrol_points.size() > 0:
		var face_to: Vector3 = patrol_points[0] - global_position
		face_to.y = 0.0
		if face_to.length() > 0.1:
			_face(face_to)
	vision.add_exception(self)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		if unconscious and not hidden:
			_wake_timer -= delta
			if _wake_timer <= 0.0 and not being_dragged:
				_wake_up()
		if being_dragged:
			velocity = Vector3.ZERO
		elif not hidden:
			# Corpses keep settling under gravity so they can never hover in
			# air or stay wedged inside geometry after a drag or collapse
			velocity.x = 0.0
			velocity.z = 0.0
			if not is_on_floor():
				velocity += get_gravity() * delta
			else:
				velocity.y = 0.0
			move_and_slide()
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	_player = get_tree().get_first_node_in_group("player") as Node3D
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	_body_check_timer -= delta
	_spawn_grace = maxf(0.0, _spawn_grace - delta)
	_update_threat(delta)

	if _complying:
		velocity.x = 0.0
		velocity.z = 0.0
		if _threatened_by:
			_face(_threatened_by.global_position - global_position)
		if body and body.has_method("set_hands_up"):
			body.call("set_hands_up", true)
		move_and_slide()
		return

	if body and body.has_method("set_hands_up"):
		body.call("set_hands_up", false)
	if body and body.has_method("tick_walk"):
		var planar := Vector2(velocity.x, velocity.z).length()
		body.call("tick_walk", delta, planar)

	match state:
		State.PATROL:
			if _facility_leg_active:
				_move_toward_point(_facility_target, move_speed)
			else:
				_do_patrol(delta)
			_tick_awareness(delta)
			if _can_see_player():
				_respond_to_visible_player(delta)
			elif _awareness >= 1.0 and _player:
				_awareness = 0.0
				_enter_suspicious(_player.global_position)
			elif _can_hear_player_soft():
				_enter_suspicious(_player.global_position)
			elif _body_check_timer <= 0.0:
				_body_check_timer = 0.6
				_check_for_corpses()
		State.SUSPICIOUS:
			_do_suspicious(delta)
			if _can_see_player():
				_respond_to_visible_player(delta)
		State.CHASE:
			_do_chase(delta)
			_try_bash_doors(delta)
		State.SEARCH:
			_do_search(delta)
			_try_bash_doors(delta)
			if _can_see_player():
				_respond_to_visible_player(delta)
			elif _body_check_timer <= 0.0:
				_body_check_timer = 0.5
				_check_for_corpses()

	if AlertPhase.phase == AlertPhase.Phase.ALERT and state == State.PATROL:
		sight_range = 22.0
	elif state != State.DEAD:
		sight_range = 18.0

	move_and_slide()

	if (
		_facility_leg_active
		and state == State.PATROL
		and navigation_agent != null
		and navigation_agent.target_position.is_equal_approx(_facility_target)
		and navigation_agent.is_navigation_finished()
	):
		# End the leg before emitting. A cancelled or unreachable leg therefore
		# cannot emit now or later, and every accepted leg emits at most once.
		_facility_leg_active = false
		velocity.x = 0.0
		velocity.z = 0.0
		var arrived_room := _facility_target_room
		_facility_target_room = ""
		var target_offset := _facility_target - global_position
		target_offset.y = 0.0
		if (
			navigation_agent.is_target_reachable()
			and target_offset.length() <= FACILITY_ARRIVAL_TOLERANCE
		):
			facility_leg_arrived.emit(staff_id, arrived_room)


# --- Pure detection API (stealth selftests) ------------------------------------

## 0=ignore, 1=suspicious, 2=search. Hearing is independent of combat authority.
func evaluate_noise_response(
	dist: float,
	loudness: float,
	_source_is_player: bool,
	_player_hostile: bool
) -> int:
	# Keep the established call shape: source/hostility describe provenance, but
	# neither suppresses a noise that is physically loud enough to hear.
	var hear_dist := hearing_range * clampf(loudness, 0.1, 1.0)
	if dist > hear_dist:
		return NoiseResponse.IGNORE
	if loudness >= 0.7:
		return NoiseResponse.SEARCH
	return NoiseResponse.SUSPICIOUS


## Detection confidence 0–1 for a target at dist with angle from forward (degrees).
## Direct cone → high score; peripheral → partial; crouch shrinks ranges.
func evaluate_sight_score(
	dist: float,
	angle_deg: float,
	target_crouching: bool,
	alert: bool
) -> float:
	var range_mul := 0.7 if target_crouching else 1.0
	if alert:
		range_mul *= 1.15
	var direct_range := sight_range * range_mul
	var peri_range := sight_range * peripheral_range_mul * range_mul
	if dist > direct_range and dist > peri_range:
		return 0.0
	if angle_deg <= sight_angle_deg and dist <= direct_range:
		# Full lock scales slightly with proximity
		return clampf(1.15 - dist / maxf(direct_range, 0.01) * 0.35, 0.55, 1.0)
	if angle_deg <= peripheral_angle_deg and dist <= peri_range:
		return clampf(0.55 - dist / maxf(peri_range, 0.01) * 0.25, 0.2, 0.55)
	return 0.0


## Pure public seam for generated facilities and physical guards.
func evaluate_intrusion_context(context: Dictionary) -> int:
	return FacilityIntrusionPolicy.evaluate(context)


## Mirrors FacilityStaffBody's non-authoritative embodiment contract. The
## facility runtime remains the sole owner of room state and commits arrivals.
func configure_facility_identity(
	staff_identity: String,
	job: String,
	credential_metadata: Dictionary,
	uniform_color: Color,
) -> void:
	staff_id = staff_identity
	job_id = job
	credentials = credential_metadata.duplicate(true)
	set_meta("staff_id", staff_id)
	set_meta("job_id", job_id)
	set_meta("credentials", credentials.duplicate(true))
	_set_mat(uniform_color)


func assign_facility_leg(target_position: Vector3, target_room: String) -> bool:
	if state == State.DEAD or _facility_leg_active or not is_inside_tree() or not _has_navigation_map():
		return false
	_facility_target = target_position
	_facility_target_room = target_room
	navigation_agent.target_position = target_position
	_facility_leg_active = true
	return true


func cancel_facility_leg() -> void:
	_facility_leg_active = false
	_facility_target_room = ""
	velocity.x = 0.0
	velocity.z = 0.0


func is_facility_moving() -> bool:
	return _facility_leg_active


func is_facility_incapacitated() -> bool:
	return state == State.DEAD


func current_target_room() -> String:
	return _facility_target_room


func set_facility_intrusion_context(context: Dictionary) -> void:
	_institutional_context = context.duplicate(true)
	if context.has("room_authorized"):
		player_room_authorized = bool(context["room_authorized"])


func get_facility_response() -> int:
	return _institutional_response


func get_awareness() -> float:
	return _awareness


func set_under_threat(by: Node3D, active: bool) -> void:
	if state == State.DEAD:
		return
	if active:
		_threatened_by = by
		_comply_break = 0.0
	else:
		if _threatened_by == by:
			_threatened_by = null


func is_threat_ready() -> bool:
	return _threat_hold >= 0.35 and _threatened_by != null and not _complying and state != State.DEAD


func receive_demand(kind: String) -> String:
	if state == State.DEAD or _threatened_by == null:
		return "No target"
	if _threat_hold < 0.3:
		return "Keep them covered…"

	# Resist check
	var resist_chance := bravery * 0.35
	if state == State.CHASE:
		resist_chance += 0.4
	if AlertPhase.phase == AlertPhase.Phase.ALERT:
		resist_chance += 0.15
	if randf() < resist_chance:
		_resist()
		return "They resisted!"

	match kind:
		"surrender":
			_enter_comply()
			return "Hands up"
		"keycard":
			if not _enter_comply():
				return "Failed"
			if _keycard_dropped or not carries_keycard:
				return "No keycard"
			_drop_keycard()
			return "Keycard dropped"
		"door":
			if not _enter_comply():
				return "Failed"
			if _open_nearest_door():
				return "Door opened"
			return "No door nearby"
		_:
			return "Unknown demand"


func _enter_comply() -> bool:
	_complying = true
	_hands_up = true
	velocity = Vector3.ZERO
	_set_mat(Color(0.75, 0.7, 0.2))
	GameAudio.play_interact()
	return true


func _resist() -> void:
	# Holding a guard at gunpoint counts as attacking first
	AlertPhase.mark_player_hostile()
	_complying = false
	_hands_up = false
	_threatened_by = null
	_threat_hold = 0.0
	_set_mat(Color(0.55, 0.48, 0.2))
	_enter_chase()
	AlertPhase.raise_alert(8.0)
	NoiseBus.emit_noise(global_position, 0.7, self)


func _drop_keycard() -> void:
	_keycard_dropped = true
	carries_keycard = false
	var pickup_script: Script = load("res://scripts/world/pickup.gd")
	var area := Area3D.new()
	area.position = global_position + Vector3(0.4, 0.3, 0)
	area.collision_layer = 0
	area.collision_mask = 2
	area.set_script(pickup_script)
	area.set("pickup_type", Pickup.PickupType.KEYCARD)
	area.set("amount", 1.0)
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	mesh_instance.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.85, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.85, 0.2)
	mesh_instance.material_override = mat
	area.add_child(mesh_instance)
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.55
	col.shape = shape
	area.add_child(col)
	get_tree().current_scene.add_child(area)
	GameAudio.play_pickup()


func _open_nearest_door() -> bool:
	var best: Node = null
	var best_d := 10.0
	for node in get_tree().get_nodes_in_group("doors"):
		if not is_instance_valid(node):
			continue
		if node.has_method("is_open") and node.is_open():
			continue
		var d: float = global_position.distance_to((node as Node3D).global_position)
		if d < best_d:
			best_d = d
			best = node
	if best and best.has_method("unlock_and_open"):
		best.unlock_and_open()
		return true
	return false


func _update_threat(delta: float) -> void:
	if _threatened_by == null or not is_instance_valid(_threatened_by):
		_threatened_by = null
		_threat_hold = 0.0
		if _complying:
			_comply_break += delta
			if _comply_break > 1.2:
				# Threat broken — flee to search
				_complying = false
				_hands_up = false
				_set_mat(Color(0.28, 0.28, 0.26))
				_enter_search(global_position)
		return

	var dist := global_position.distance_to(_threatened_by.global_position)
	if dist > 10.0:
		set_under_threat(_threatened_by, false)
		return

	_threat_hold += delta
	if _complying:
		_comply_break = 0.0


func _do_patrol(_delta: float) -> void:
	if patrol_points.is_empty():
		return
	var speed := move_speed * (1.15 if AlertPhase.phase == AlertPhase.Phase.ALERT else 0.7)
	var target := patrol_points[_patrol_index]
	if _move_toward_point(target, speed):
		_patrol_index = (_patrol_index + 1) % patrol_points.size()


func _do_suspicious(delta: float) -> void:
	_suspicious_timer -= delta
	_move_toward_point(_investigate_point, move_speed * 0.85)
	if _suspicious_timer <= 0.0:
		state = State.PATROL
		_set_mat(Color(0.22, 0.23, 0.24))


func _do_chase(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_enter_search(global_position)
		return

	var to_player := _player.global_position - global_position
	var dist := to_player.length()
	_face(to_player)
	_last_known = _player.global_position

	if _can_see_player():
		if dist > 3.5:
			_move_toward_point(_player.global_position, chase_speed)
		else:
			velocity.x = 0.0
			velocity.z = 0.0
		if dist <= fire_range and _fire_cooldown <= 0.0:
			_shoot_player()
	else:
		_enter_search(_last_known)


func _do_search(delta: float) -> void:
	_search_timer -= delta
	_move_toward_point(_investigate_point, move_speed)
	if global_position.distance_to(_investigate_point) < 1.2:
		rotate_y(delta * 1.8)
	if _search_timer <= 0.0:
		state = State.PATROL
		_set_mat(Color(0.22, 0.23, 0.24))


func _check_for_corpses() -> void:
	for node in get_tree().get_nodes_in_group("corpses"):
		if node == self or not is_instance_valid(node):
			continue
		if node.get("hidden"):
			continue
		var corpse := node as Node3D
		if corpse == null:
			continue
		var dist := global_position.distance_to(corpse.global_position)
		if dist > 10.0:
			continue
		if _has_line_of_sight_to(corpse.global_position + Vector3.UP * 0.3):
			AlertPhase.notify_body_found(corpse.global_position)
			_enter_search(corpse.global_position)
			return


func _has_line_of_sight_to(target: Vector3) -> bool:
	var eye := global_position + Vector3.UP * 1.75
	var to := target - eye
	if to.length() > sight_range:
		return false
	var forward := -global_transform.basis.z
	if forward.normalized().angle_to(to.normalized()) > deg_to_rad(sight_angle_deg + 15.0):
		return false
	vision.global_position = eye
	vision.target_position = vision.to_local(target)
	vision.force_raycast_update()
	if not vision.is_colliding():
		return true
	var col := vision.get_collider()
	return col != null and (col.is_in_group("corpses") or (col.get_parent() and col.get_parent().is_in_group("corpses")))


func _respond_to_visible_player(delta: float = 0.0) -> void:
	if _player == null:
		return
	var context := {
		"room_authorized": player_room_authorized,
		"access_denied": false,
		"custody_violation": false,
		"compromised_disguise": false,
	}
	for key in ["room_authorized", "access_denied", "custody_violation", "compromised_disguise"]:
		if _institutional_context.has(key):
			context[key] = _institutional_context[key]
	context["visible_weapon"] = _threatened_by == _player
	context["suspicious_movement"] = (
		_player.has_method("is_crouching") and bool(_player.is_crouching())
	)
	context["noise_loudness"] = 0.0
	context["hostile_act"] = AlertPhase.player_hostile
	var response := evaluate_intrusion_context(context)

	if response != FacilityIntrusionPolicy.Response.CHALLENGE:
		_challenge_remaining = 0.0
		_challenge_contained = false
	_institutional_response = response

	match response:
		FacilityIntrusionPolicy.Response.ENGAGE:
			# Policy receives the live hostility fact above; _enter_chase retains
			# the combat-authority gate as a second, effect-side check.
			_enter_chase()
		FacilityIntrusionPolicy.Response.CONTAIN:
			_enter_search(_player.global_position)
		FacilityIntrusionPolicy.Response.CHALLENGE:
			if _challenge_contained:
				_institutional_response = FacilityIntrusionPolicy.Response.CONTAIN
				_enter_search(_player.global_position)
			else:
				if _challenge_remaining <= 0.0:
					_challenge_remaining = CHALLENGE_SECONDS
				_challenge_remaining = maxf(0.0, _challenge_remaining - delta)
				if _challenge_remaining <= 0.0:
					_challenge_contained = true
					_institutional_response = FacilityIntrusionPolicy.Response.CONTAIN
					_enter_search(_player.global_position)
				else:
					_enter_suspicious(_player.global_position)
		FacilityIntrusionPolicy.Response.OBSERVE:
			_enter_suspicious(_player.global_position)


func _enter_chase() -> void:
	if _complying:
		return
	# Combat authority remains separate from institutional detection: only a
	# hostile act permits chase and lethal force.
	if not AlertPhase.player_hostile:
		return
	state = State.CHASE
	_set_mat(Color(0.35, 0.28, 0.22)) # chase — slight warm tint, stay skinny charcoal
	AlertPhase.raise_alert(10.0)
	if _player:
		_last_known = _player.global_position


func _enter_suspicious(point: Vector3) -> void:
	if state == State.CHASE or state == State.DEAD or _complying:
		return
	_investigate_point = point
	_suspicious_timer = 4.5
	_awareness = 0.0
	if state == State.SUSPICIOUS:
		return
	state = State.SUSPICIOUS
	_set_mat(Color(0.4, 0.36, 0.22))
	AlertPhase.raise_caution(5.0)


func _enter_search(point: Vector3) -> void:
	if _complying:
		return
	state = State.SEARCH
	_investigate_point = point
	_search_timer = 7.0
	_awareness = 0.0
	_noise_stack = 0
	_set_mat(Color(0.28, 0.28, 0.26))
	AlertPhase.raise_caution(7.0)


func _on_noise(position: Vector3, loudness: float, source: Node) -> void:
	if state == State.DEAD or state == State.CHASE or _complying:
		return
	var source_is_player := source != null and source.is_in_group("player")
	var dist := global_position.distance_to(position)
	var response := evaluate_noise_response(
		dist, loudness, source_is_player, AlertPhase.player_hostile
	)
	if response == NoiseResponse.IGNORE:
		return
	# Stacking soft noises escalates to search (more coherent investigation)
	if response == NoiseResponse.SUSPICIOUS:
		_noise_stack += 1
		if _noise_stack >= 2 or state == State.SUSPICIOUS:
			response = NoiseResponse.SEARCH
			_noise_stack = 0
	else:
		_noise_stack = 0
	_last_known = position
	if response == NoiseResponse.SEARCH:
		if _can_see_player():
			_respond_to_visible_player()
		else:
			_enter_search(position)
	else:
		_enter_suspicious(position)


func _on_phase_changed(phase: Variant, _label: String) -> void:
	if state == State.DEAD or _complying:
		return
	if phase == AlertPhase.Phase.ALERT and state == State.PATROL:
		# Converging on the player's live position is only fair once provoked
		if _player and AlertPhase.player_hostile:
			_enter_search(_player.global_position)


func _shoot_player() -> void:
	if _complying or _hands_up:
		return
	_fire_cooldown = 1.0 / fire_rate
	GameAudio.play_gunshot()
	NoiseBus.emit_noise(global_position, 0.9, self)
	if _player and _player.has_method("apply_damage"):
		var dist := global_position.distance_to(_player.global_position)
		var hit_chance := 1.0
		if _player.has_method("is_crouching") and _player.is_crouching():
			hit_chance -= 0.25
		hit_chance -= clampf((dist - 8.0) / 30.0, 0.0, 0.35)
		if randf() <= hit_chance:
			_player.apply_damage(damage, self)


func _can_see_player() -> bool:
	if _player == null or _spawn_grace > 0.0:
		return false
	var crouching: bool = _player.has_method("is_crouching") and bool(_player.is_crouching())
	var eye := global_position + Vector3.UP * 1.75
	var target_height := 0.6 if crouching else 1.2
	var target := _player.global_position + Vector3.UP * target_height
	var to := target - eye
	var dist := to.length()
	var forward := -global_transform.basis.z
	var angle_deg := rad_to_deg(forward.normalized().angle_to(to.normalized()))
	var alert: bool = AlertPhase.phase == AlertPhase.Phase.ALERT
	var score := evaluate_sight_score(dist, angle_deg, crouching, alert)
	# Direct lock only for chase (score >= 0.55); peripheral feeds awareness instead
	if score < 0.55:
		return false
	vision.global_position = eye
	vision.target_position = vision.to_local(target)
	vision.force_raycast_update()
	if not vision.is_colliding():
		return false
	var col := vision.get_collider()
	return col == _player or (col != null and col.get_parent() == _player)


func _tick_awareness(delta: float) -> void:
	if _player == null or _spawn_grace > 0.0 or state != State.PATROL:
		_awareness = maxf(0.0, _awareness - awareness_decay * delta)
		return
	var crouching: bool = _player.has_method("is_crouching") and bool(_player.is_crouching())
	var eye := global_position + Vector3.UP * 1.75
	var target_height := 0.6 if crouching else 1.2
	var target := _player.global_position + Vector3.UP * target_height
	var to := target - eye
	var dist := to.length()
	var forward := -global_transform.basis.z
	var angle_deg := rad_to_deg(forward.normalized().angle_to(to.normalized()))
	var alert: bool = AlertPhase.phase == AlertPhase.Phase.ALERT
	var score := evaluate_sight_score(dist, angle_deg, crouching, alert)
	if score > 0.0 and score < 0.55:
		# LOS required for awareness gain
		vision.global_position = eye
		vision.target_position = vision.to_local(target)
		vision.force_raycast_update()
		if vision.is_colliding():
			var col := vision.get_collider()
			if col == _player or (col != null and col.get_parent() == _player):
				_awareness = minf(1.0, _awareness + awareness_rate * score * delta)
				return
	_awareness = maxf(0.0, _awareness - awareness_decay * delta)


func _can_hear_player_soft() -> bool:
	if _player == null or _spawn_grace > 0.0 or not _player.has_method("noise_profile"):
		return false
	var profile: float = _player.noise_profile()
	if profile < 0.3:
		return false
	var dist := _player.global_position.distance_to(global_position)
	return dist < hearing_range * profile


func _has_navigation_map() -> bool:
	if navigation_agent == null or not navigation_agent.is_inside_tree():
		return false
	var navigation_map := navigation_agent.get_navigation_map()
	return (
		navigation_map.is_valid()
		and NavigationServer3D.map_get_iteration_id(navigation_map) > 0
	)


func _move_toward_point(target: Vector3, speed: float) -> bool:
	if _has_navigation_map():
		if not navigation_agent.target_position.is_equal_approx(target):
			navigation_agent.target_position = target
		if navigation_agent.is_navigation_finished():
			velocity.x = 0.0
			velocity.z = 0.0
			return true
		var path_offset := navigation_agent.get_next_path_position() - global_position
		path_offset.y = 0.0
		if path_offset.length_squared() > 0.0001:
			_face(path_offset)
			var path_direction := path_offset.normalized()
			velocity.x = path_direction.x * speed
			velocity.z = path_direction.z * speed
		else:
			velocity.x = 0.0
			velocity.z = 0.0
		return false

	# Script-attached legacy scenes without a ready NavigationAgent keep their
	# established direct movement instead of becoming inert.
	var to := target - global_position
	to.y = 0.0
	if to.length() < 0.55:
		velocity.x = 0.0
		velocity.z = 0.0
		return true
	_face(to)
	var direction := to.normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	return false


func _try_bash_doors(delta: float) -> void:
	if AlertPhase.phase == AlertPhase.Phase.NORMAL:
		return
	for node in get_tree().get_nodes_in_group("doors"):
		if not is_instance_valid(node):
			continue
		if node.has_method("try_bash"):
			node.try_bash(self, delta)


func _face(direction: Vector3) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length() < 0.01:
		return
	look_at(global_position + flat.normalized(), Vector3.UP)


func receive_takedown(from: Node3D, lethal: bool = true) -> bool:
	if state == State.DEAD:
		return false
	# Any takedown attempt — successful or botched — is an attack
	AlertPhase.mark_player_hostile()
	# Hands-up targets are easy takedowns from any angle
	var easy := _complying or _hands_up
	if not easy:
		if state == State.CHASE:
			return false
		if state == State.SEARCH and AlertPhase.phase == AlertPhase.Phase.ALERT:
			return false
		var to_attacker := from.global_position - global_position
		to_attacker.y = 0.0
		if to_attacker.length() > 1.7:
			return false
		var forward := -global_transform.basis.z
		if forward.normalized().angle_to(to_attacker.normalized()) < deg_to_rad(120.0):
			return false
	else:
		if from.global_position.distance_to(global_position) > 2.2:
			return false
	_complying = false
	if lethal:
		_die_stealth()
	else:
		_knockout()
	return true


func is_takedownable_from(from: Node3D) -> bool:
	if state == State.DEAD:
		return false
	if _complying or _hands_up:
		return from.global_position.distance_to(global_position) <= 2.2
	if state == State.CHASE:
		return false
	var to_attacker := from.global_position - global_position
	to_attacker.y = 0.0
	if to_attacker.length() > 1.7:
		return false
	var forward := -global_transform.basis.z
	return forward.normalized().angle_to(to_attacker.normalized()) >= deg_to_rad(120.0)


func _knockout() -> void:
	if state == State.DEAD:
		return
	_kill_recorded = true
	unconscious = true
	_wake_timer = WAKE_SECONDS
	_complying = false
	ObjectiveTracker.record_knockout()
	GameAudio.play_interact()
	NoiseBus.emit_noise(global_position, 0.1, null)
	_collapse(false)
	_set_mat(Color(0.2, 0.25, 0.45))
	ObjectiveTracker.set_prompt("Guard unconscious — wakes in ~%ds" % int(WAKE_SECONDS))


func _die_stealth() -> void:
	if state == State.DEAD:
		return
	_kill_recorded = true
	unconscious = false
	_complying = false
	ObjectiveTracker.record_kill(true)
	GameAudio.play_interact()
	NoiseBus.emit_noise(global_position, 0.12, null)
	_collapse(true)


func _on_died() -> void:
	if state == State.DEAD:
		return
	if not _kill_recorded:
		_kill_recorded = true
		ObjectiveTracker.record_kill(false)
	unconscious = false
	_complying = false
	_collapse(true)


func _collapse(lethal: bool) -> void:
	cancel_facility_leg()
	state = State.DEAD
	velocity = Vector3.ZERO
	collision_layer = 1
	# Keep colliding with the world (bit 1) so the body rests ON the floor —
	# mask 0 let corpses sink into or through it
	collision_mask = 1
	remove_from_group("guards")
	add_to_group("corpses")
	if lethal:
		_set_mat(Color(0.25, 0.05, 0.05))
	if body:
		body.rotation_degrees.x = 90.0
		body.position = Vector3(0, 0.2, 0)
	if collision.shape is CapsuleShape3D:
		var cap := collision.shape as CapsuleShape3D
		collision.rotation_degrees.x = 90.0
		collision.position = Vector3(0, 0.25, 0)
		cap.height = 1.2
	if lethal:
		NoiseBus.emit_noise(global_position, 0.15, self)


func _wake_up() -> void:
	if hidden or not unconscious:
		return
	unconscious = false
	_wake_timer = 0.0
	being_dragged = false
	_complying = false
	_hands_up = false
	remove_from_group("corpses")
	add_to_group("guards")
	collision_layer = 4
	collision_mask = 1
	if body:
		body.rotation_degrees = Vector3.ZERO
		body.position = Vector3.ZERO
	if collision.shape is CapsuleShape3D:
		var cap := collision.shape as CapsuleShape3D
		collision.rotation_degrees = Vector3.ZERO
		collision.position = Vector3(0, 0.95, 0)
		cap.height = 1.9
		cap.radius = 0.28
	_snap_to_floor()
	_set_mat(Color(0.28, 0.28, 0.26))
	_kill_recorded = false
	if damageable:
		damageable.health = damageable.max_health
	AlertPhase.raise_caution(8.0)
	_enter_search(global_position)
	NoiseBus.emit_noise(global_position, 0.45, self)
	ObjectiveTracker.set_prompt("A guard woke up")
	GameAudio.play_hurt()


func _snap_to_floor() -> void:
	# Cast from chest height so a body left partially inside the floor stands
	# up ON the surface instead of staying embedded
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 1.2, global_position + Vector3.DOWN * 3.0)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		global_position.y = hit.position.y + 0.05
	velocity = Vector3.ZERO


func start_drag() -> void:
	if state != State.DEAD or hidden:
		return
	being_dragged = true


func stop_drag() -> void:
	being_dragged = false


func hide_body() -> void:
	hidden = true
	being_dragged = false
	unconscious = false
	_wake_timer = 0.0
	remove_from_group("corpses")
	visible = false
	collision.disabled = true
	ObjectiveTracker.set_prompt("Body hidden")
	GameAudio.play_interact()
	queue_free()


func _set_mat(color: Color) -> void:
	if body and body.has_method("set_uniform"):
		body.call("set_uniform", color)
