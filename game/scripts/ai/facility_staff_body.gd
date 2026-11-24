class_name FacilityStaffBody
extends CharacterBody3D
## Physical, non-authoritative representation of one facility staff member.

signal facility_leg_arrived(staff_id: String, room_id: String)

const ARRIVAL_TOLERANCE := 0.45

@export var move_speed := 3.2

var staff_id: String = ""
var job_id: String = ""
var credentials: Dictionary = {}

var _leg_active := false
var _facility_target := Vector3.ZERO
var _target_room := ""

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D


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
	var uniform_mesh: MeshInstance3D = get_node_or_null(^"Body/Uniform")
	if uniform_mesh != null:
		var uniform_material := StandardMaterial3D.new()
		uniform_material.albedo_color = uniform_color
		uniform_material.roughness = 0.85
		uniform_mesh.material_override = uniform_material


func assign_facility_leg(target_position: Vector3, target_room: String) -> bool:
	if _leg_active or not is_inside_tree() or not navigation_agent.is_inside_tree():
		return false
	var navigation_map := navigation_agent.get_navigation_map()
	if (
		not navigation_map.is_valid()
		or NavigationServer3D.map_get_iteration_id(navigation_map) == 0
	):
		return false
	_facility_target = target_position
	_target_room = target_room
	navigation_agent.target_position = target_position
	_leg_active = true
	return true


func cancel_facility_leg() -> void:
	_leg_active = false
	_target_room = ""
	velocity.x = 0.0
	velocity.z = 0.0


func is_facility_moving() -> bool:
	return _leg_active


func current_target_room() -> String:
	return _target_room


func _physics_process(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity += get_gravity() * delta

	if not _leg_active:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var next_path_position := navigation_agent.get_next_path_position()
	var offset := next_path_position - global_position
	offset.y = 0.0
	if navigation_agent.is_navigation_finished():
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		var travel_direction := offset.normalized()
		velocity.x = travel_direction.x * move_speed
		velocity.z = travel_direction.z * move_speed
		if travel_direction.length_squared() > 0.0:
			look_at(global_position + travel_direction, Vector3.UP)

	move_and_slide()

	if _leg_active and navigation_agent.is_navigation_finished():
		# The leg ends here either way; arrival only fires for a reachable
		# target actually reached, so unreachable or cancelled legs stay silent.
		_leg_active = false
		velocity.x = 0.0
		velocity.z = 0.0
		var arrived_room := _target_room
		_target_room = ""
		var target_offset := _facility_target - global_position
		target_offset.y = 0.0
		if (
			navigation_agent.is_target_reachable()
			and target_offset.length() <= ARRIVAL_TOLERANCE
		):
			facility_leg_arrived.emit(staff_id, arrived_room)
