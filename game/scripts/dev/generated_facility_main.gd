extends Node3D
## Launchable generated Cyber/Archives facility inspection scene.

@export var facility_seed: int = 7319
@export var grant_inspection_credentials: bool = true
@export var operator_run: bool = false
@export var operator_contract_id: String = "foreign_extract_evidence"
@export var physical_staff_near_distance: float = 24.0

const PHYSICAL_STAFF_SCENE_PATH := "res://scenes/facility_staff_body.tscn"
const SECURITY_STAFF_SCENE_PATH := "res://scenes/guard.tscn"
const SECURITY_PATROL_ROOMS: Array[String] = [
	"security_control",
	"staff_control",
	"screened_entry",
	"staff_control",
]


@onready var player: CharacterBody3D = $Player

var operation_graph: RefCounted
var operation_runtime: RefCounted
var mission_state: Dictionary = {}
var generated_facility: Node3D
var custody_runtime: RefCounted
var custody_state: Dictionary = {}
var custody_marker: MeshInstance3D
var personnel_security_runtime: RefCounted
var personnel_state: Dictionary = {}
var staffing_runtime: RefCounted
var staffing_state: Dictionary = {}
var escort_holdover_turnover_authorized: bool=false
var staffing_group: Node3D
var physical_staff_group: Node3D
var physical_staff_bodies: Dictionary = {}
var physical_staff_target_rooms: Dictionary = {}
var designated_security_patrol_id: String = ""
var security_patrol_index: int = 0
var control_room_runtime: RefCounted
var control_console_state: Dictionary = {}
var control_snapshot: Dictionary = {}
var control_status_board: Label3D
var infrastructure_runtime: RefCounted
var infrastructure_state: Dictionary = {}
var environmental_observation_runtime: RefCounted
var environmental_observation_state: Dictionary = {}
var procedure_panel_script: Script
var procedure_panels: Node3D
var procedure_panel_definitions: Dictionary = {}
var procedure_receipts: Dictionary = {}
var procedure_panel_log: Array[Dictionary] = []
var staff_agent_runtime: RefCounted
var staff_agent_state: Dictionary = {}
var procedure_work_runtime: RefCounted
var procedure_work_state: Dictionary = {}
var operations_queue_runtime: RefCounted
var operations_queue_state: Dictionary = {}
var mutual_aid_runtime: RefCounted
var mutual_aid_state: Dictionary = {}
var control_network_runtime: RefCounted
var control_network_state: Dictionary = {}
var generated_route_plan: Dictionary = {}
var navigation_runtime: Node
var scene_checkpoint_runtime: RefCounted
var scene_journal_runtime: RefCounted
var next_scene_checkpoint_epoch: int = 1
var last_recovered_scene_epoch: int = 0
var player_mission_runtime: RefCounted
var player_mission_state: Dictionary = {}



func _ready() -> void:
	set_process(false)
	var graph_script: Script = load("res://scripts/facility/facility_operation_graph.gd")
	var solver_script: Script = load("res://scripts/facility/facility_layout_solver.gd")
	var router_script: Script = load("res://scripts/facility/facility_route_router.gd")
	var compiler_script: Script = load("res://scripts/facility/facility_geometry_compiler.gd")
	var runtime_script: Script = load("res://scripts/facility/facility_operation_runtime.gd")
	var custody_script: Script = load("res://scripts/facility/facility_custody_runtime.gd")
	var personnel_security_script: Script = load("res://scripts/facility/facility_personnel_security_runtime.gd")
	var staffing_script: Script = load("res://scripts/facility/facility_staffing_runtime.gd")
	var control_room_script: Script = load("res://scripts/facility/facility_control_room_runtime.gd")
	var infrastructure_script: Script = load("res://scripts/facility/facility_infrastructure_runtime.gd")
	var environmental_observation_script: Script = load("res://scripts/facility/environmental_observation_round_runtime.gd")
	procedure_panel_script = load("res://scripts/facility/facility_procedure_panel.gd")
	var staff_agent_script: Script = load("res://scripts/facility/facility_staff_agent_runtime.gd")
	var procedure_work_script: Script = load("res://scripts/facility/facility_procedure_work_runtime.gd")
	var operations_queue_script: Script = load("res://scripts/facility/facility_operations_queue_runtime.gd")
	var mutual_aid_script: Script = load("res://scripts/facility/facility_mutual_aid_runtime.gd")
	var control_network_script: Script = load("res://scripts/facility/facility_control_network_runtime.gd")
	var navigation_script: Script = load("res://scripts/facility/facility_navigation_runtime.gd")
	var scene_checkpoint_script: Script = load("res://scripts/facility/facility_scene_checkpoint_runtime.gd")
	var scene_journal_script: Script = load("res://scripts/facility/facility_scene_journal_runtime.gd")
	var player_mission_script: Script = load("res://scripts/facility/facility_player_mission_runtime.gd")
	for script in [graph_script, solver_script, router_script, compiler_script, runtime_script, custody_script, personnel_security_script, staffing_script, control_room_script, infrastructure_script, environmental_observation_script, procedure_panel_script, staff_agent_script, procedure_work_script, operations_queue_script, mutual_aid_script, control_network_script, navigation_script, scene_checkpoint_script, scene_journal_script, player_mission_script]:
		if script == null or not script.can_instantiate():
			push_error("Generated facility dependency cannot instantiate")
			return
	operation_graph = graph_script.new()
	operation_runtime = runtime_script.new()
	custody_runtime = custody_script.new()
	personnel_security_runtime = personnel_security_script.new()
	staffing_runtime = staffing_script.new()
	control_room_runtime = control_room_script.new()
	infrastructure_runtime = infrastructure_script.new()
	environmental_observation_runtime = environmental_observation_script.new()
	environmental_observation_state = environmental_observation_runtime.new_state()
	staff_agent_runtime = staff_agent_script.new()
	procedure_work_runtime = procedure_work_script.new()
	operations_queue_runtime = operations_queue_script.new()
	mutual_aid_runtime = mutual_aid_script.new()
	control_network_runtime = control_network_script.new()
	scene_checkpoint_runtime = scene_checkpoint_script.new()
	scene_journal_runtime = scene_journal_script.new()
	procedure_work_state = procedure_work_runtime.start_scheduler()
	operations_queue_state = operations_queue_runtime.start_queue()
	mutual_aid_state = mutual_aid_runtime.start_state()
	control_network_state = control_network_runtime.start_state()
	var graph: RefCounted = operation_graph
	var solver: RefCounted = solver_script.new()
	var router: RefCounted = router_script.new()
	var compiler: RefCounted = compiler_script.new()
	graph.configure_cyber_archives(facility_seed)
	var plan: Dictionary = solver.solve(graph)
	var route_plan: Dictionary = router.route(graph, plan)
	generated_route_plan = route_plan.duplicate(true)
	generated_facility = compiler.compile(graph, plan, route_plan)
	var facility: Node3D = generated_facility
	if facility == null:
		push_error("Generated facility manifests failed closed")
		return
	add_child(facility)
	navigation_runtime = navigation_script.new()
	navigation_runtime.name = "FacilityNavigationRuntime"
	add_child(navigation_runtime)
	navigation_runtime.connect("navigation_ready", _on_navigation_ready)
	navigation_runtime.connect("navigation_failed", func(message: String) -> void:
		push_error("FACILITY_NAVIGATION_FAILED: %s" % message)
	)
	navigation_runtime.initialize(facility, plan, route_plan)
	mission_state = operation_runtime.start_mission(operation_graph, "inspection-%d" % facility_seed)
	infrastructure_state = infrastructure_runtime.start_services(operation_graph)
	infrastructure_runtime.apply_mission_snapshot(operation_graph, infrastructure_state, operation_runtime, mission_state)
	staffing_state = staffing_runtime.build_schedule(operation_graph)
	staff_agent_state = staff_agent_runtime.build_active_watch(operation_graph, staffing_state, staffing_runtime)
	staffing_runtime.apply_mission_availability(operation_graph, staffing_state, operation_runtime, mission_state)
	_create_staffing_markers()
	_create_procedure_panels()
	_register_control_network_procedure_definitions()
	_apply_service_snapshot()
	custody_state = custody_runtime.receive_material("inspection-media-%d" % facility_seed)
	_create_custody_marker()
	var entry_room := _find_room(facility, "screened_entry")
	if entry_room == null:
		push_error("Generated facility has no screened entry spawn")
		return
	player.global_position = entry_room.global_position + Vector3(0.0, 0.15, 0.0)
	player.set_checkpoint(player.global_transform)
	if operator_run:
		# Free-agent cover: forged researcher credentials, not inspection god-mode.
		player.keycard_tier = 4
		player.has_keycard = true
		player.set_meta("facility_roles", ["cyber_researcher"])
	elif grant_inspection_credentials:
		player.keycard_tier = 5
		player.has_keycard = true
		player.set_meta("facility_roles", [
			"duty_officer",
			"security_officer",
			"cyber_researcher",
			"records_officer",
			"archive_custodian",
			"accession_technician",
			"facilities_engineer",
			"systems_administrator",
		])
	var admission_roles: Array = player.get_meta("facility_roles", [])
	var person_id: String = "operator_player" if operator_run else "inspection_player"
	personnel_state = personnel_security_runtime.register_person(person_id, int(player.keycard_tier), admission_roles)
	personnel_security_runtime.complete_screening(personnel_state, {"roles": ["security_officer"]})
	var entry_receipt: Dictionary = personnel_security_runtime.begin_transition(operation_graph, personnel_state, "screened_entry")
	if not entry_receipt.get("accepted", false) or not personnel_security_runtime.complete_transition(personnel_state, entry_receipt).get("accepted", false):
		push_error("Generated facility could not establish screened player admission")
		return
	_sync_personnel_position()
	player_mission_runtime = player_mission_script.new()
	player_mission_state = {}
	control_console_state = control_room_runtime.start_console("duty-console-%d" % facility_seed)
	_create_control_status_board()
	_refresh_control_status_board()
	_install_testing_build_hud()
	ObjectiveTracker.set_prompt("FACILITY TEST BUILD · seed %d · E interact · WASD move · mouse look · Esc free cursor" % facility_seed)
	print("GENERATED_FACILITY_READY seed=%d fingerprint=%s" % [facility_seed, graph.generation_fingerprint()])
	print("FACILITY_TEST_BUILD_READY main_scene=res://scenes/dev_generated_facility.tscn seed=%d" % facility_seed)
	if operator_run:
		run_institution_workday()
		start_player_contract(operator_contract_id)
		_create_player_mission_stations()
		ObjectiveTracker.set_prompt("OPERATOR RUN · %s · doors + E stations · steal institution secrets" % operator_contract_id)
		print("OPERATOR_RUN_READY person=%s roles=%s" % [person_id, str(admission_roles)])



func _on_navigation_ready() -> void:
	physical_staff_group = Node3D.new()
	physical_staff_group.name = "PhysicalStaff"
	add_child(physical_staff_group)
	set_process(true)
	_reconcile_physical_staff()
	_create_staffing_markers()
	print("FACILITY_NAVIGATION_READY seed=%d" % facility_seed)


func _process(_delta: float) -> void:
	var staff_changed := _reconcile_physical_staff()
	_update_security_guard_contexts()
	if _advance_security_patrols():
		staff_changed = true
	if staff_changed:
		_create_staffing_markers()


func _reconcile_physical_staff() -> bool:
	if (
		physical_staff_group == null
		or not is_instance_valid(physical_staff_group)
		or staff_agent_runtime == null
		or staff_agent_state.is_empty()
		or generated_facility == null
		or player == null
	):
		return false
	var changed := false
	var agents: Dictionary = staff_agent_state.get("agents", {})
	for embodied_id in physical_staff_bodies.keys():
		var embodied_body: Node = physical_staff_bodies[embodied_id]
		if not is_instance_valid(embodied_body):
			physical_staff_bodies.erase(embodied_id)
			physical_staff_target_rooms.erase(embodied_id)
			changed = true
			continue
		if not agents.has(embodied_id):
			_release_physical_staff_body(embodied_id, staff_agent_state)
			changed = true
			continue
		var embodied_agent: Dictionary = agents[embodied_id]
		if (
			String(embodied_agent.get("job_id", "")) == "security_officer"
			and embodied_body.is_facility_incapacitated()
		):
			if embodied_body.is_facility_moving():
				embodied_body.cancel_facility_leg()
				changed = true
			if not (embodied_agent.get("route", []) as Array).is_empty():
				staff_agent_runtime.cancel_dispatch(
					staff_agent_state,
					embodied_id,
					"security guard body incapacitated"
				)
				changed = true
			if physical_staff_target_rooms.erase(embodied_id):
				changed = true
			if embodied_body.has_meta("facility_target_room"):
				embodied_body.remove_meta("facility_target_room")
				changed = true
			if embodied_body.has_meta("facility_target_position"):
				embodied_body.remove_meta("facility_target_position")
				changed = true
			continue
		if (
			String(embodied_body.get_meta("authoritative_room", ""))
			!= String(embodied_agent.get("current_room", ""))
		):
			# Authority relocated this agent outside the physical arrival path
			# (checkpoint recovery, holdover restore, external rebind); the body
			# is recreated at the new room instead of being moved.
			_release_physical_staff_body(embodied_id, staff_agent_state)
			changed = true
			continue
		var embodied_room := _find_room(generated_facility, String(embodied_agent.get("current_room", "")))
		var keep_embodied := (
			String(embodied_agent.get("job_id", "")) == "security_officer"
			or (
				embodied_room != null
				and embodied_room.global_position.distance_to(player.global_position)
					<= maxf(physical_staff_near_distance, 0.0)
			)
		)
		if not keep_embodied:
			_release_physical_staff_body(embodied_id, staff_agent_state)
			changed = true

	var staff_ids: Array = agents.keys()
	staff_ids.sort()
	var physical_staff_scene := load(PHYSICAL_STAFF_SCENE_PATH) as PackedScene
	if physical_staff_scene == null:
		push_error("Physical staff scene could not be loaded")
		return changed
	var security_staff_scene := load(SECURITY_STAFF_SCENE_PATH) as PackedScene
	if security_staff_scene == null:
		push_error("Security staff scene could not be loaded")
		return changed
	for staff_id in staff_ids:
		var agent: Dictionary = agents[staff_id]
		var job_id: String = String(agent.get("job_id", ""))
		var room_id: String = String(agent.get("current_room", ""))
		var room_node := _find_room(generated_facility, room_id)
		if room_node == null:
			continue
		var should_embody := (
			job_id == "security_officer"
			or room_node.global_position.distance_to(player.global_position)
				<= maxf(physical_staff_near_distance, 0.0)
		)
		if not should_embody:
			continue
		if physical_staff_bodies.has(staff_id):
			var existing_body: Node = physical_staff_bodies[staff_id]
			if is_instance_valid(existing_body):
				if (
					job_id == "security_officer"
					and existing_body.is_facility_incapacitated()
				):
					staff_agent_runtime.set_embodied(staff_agent_state, staff_id, true)
					continue
				staff_agent_runtime.set_embodied(staff_agent_state, staff_id, true)
				var authoritative_next: String = staff_agent_runtime.next_route_room(staff_agent_state, staff_id)
				if String(existing_body.call("current_target_room")) != authoritative_next:
					# The authoritative route was cancelled, replaced, or the leg ended
					# without a committed arrival; stale physical targets must never
					# survive into a later commit.
					if bool(existing_body.call("is_facility_moving")):
						existing_body.call("cancel_facility_leg")
						changed = true
					if physical_staff_target_rooms.erase(staff_id):
						changed = true
					if existing_body.has_meta("facility_target_room"):
						existing_body.remove_meta("facility_target_room")
					if existing_body.has_meta("facility_target_position"):
						existing_body.remove_meta("facility_target_position")
				if not bool(existing_body.call("is_facility_moving")):
					_assign_physical_staff_leg(staff_id)
				continue
			physical_staff_bodies.erase(staff_id)
			physical_staff_target_rooms.erase(staff_id)
		var staff_scene: PackedScene = (
			security_staff_scene
			if job_id == "security_officer"
			else physical_staff_scene
		)
		var body := staff_scene.instantiate() as CharacterBody3D
		if body == null:
			push_error("Staff scene did not instantiate a CharacterBody3D")
			continue
		body.name = "Staff_%s" % staff_id
		physical_staff_group.add_child(body)
		var room_tier: int = int(operation_graph.rooms.get(room_id, {}).get("security_tier", 0))
		var uniform_color := (
			Color(0.14, 0.62, 0.42)
			if bool(operation_graph.jobs.get(job_id, {}).get("continuous", false))
			else Color(0.28, 0.48, 0.72)
		)
		body.call("configure_facility_identity", staff_id, job_id, {
			"clearance_tier": room_tier,
			"roles": [job_id],
			"target_room": room_id,
		}, uniform_color)
		body.global_position = room_node.global_position + Vector3(0.0, 0.1, 0.0)
		body.set_meta("authoritative_room", room_id)
		body.connect("facility_leg_arrived", _on_physical_staff_leg_arrived)
		physical_staff_bodies[staff_id] = body
		var embodiment: Dictionary = staff_agent_runtime.set_embodied(staff_agent_state, staff_id, true)
		if not embodiment.get("accepted", false):
			_release_physical_staff_body(staff_id, staff_agent_state)
			continue
		_assign_physical_staff_leg(staff_id)
		changed = true
	return changed


func _update_security_guard_contexts() -> void:
	if personnel_state.is_empty() or operation_graph == null:
		return
	var player_room_id: String = String(personnel_state.get("current_room", ""))
	var room_policy: Dictionary = operation_graph.rooms.get(player_room_id, {})
	var player_roles: Array = personnel_state.get("roles", [])
	var access_roles: Array = room_policy.get("access_roles", [])
	var role_authorized := player_roles.has("security_officer")
	if not role_authorized:
		for access_role in access_roles:
			if player_roles.has(access_role):
				role_authorized = true
				break
	var denials: Array = personnel_state.get("denials", [])
	var latest_denial: Dictionary = {}
	if not denials.is_empty():
		latest_denial = denials.back()
	var open_investigations: Array = custody_state.get("open_investigations", [])
	var player_person_id: String = String(personnel_state.get("person_id", ""))
	var custody_violation := not String(custody_state.get("active_incident", "")).is_empty()
	if not custody_violation:
		for investigation in open_investigations:
			if (
				bool((investigation as Dictionary).get("open", true))
				and String((investigation as Dictionary).get("actor_person_id", "")) == player_person_id
			):
				custody_violation = true
				break
	var context := {
		"person_id": player_person_id,
		"room": player_room_id,
		"room_security_tier": int(room_policy.get("security_tier", 0)),
		"room_access_roles": access_roles.duplicate(),
		"room_authorized": (
			int(personnel_state.get("clearance_tier", 0))
				>= int(room_policy.get("security_tier", 0))
			and role_authorized
		),
		"access_denied": not latest_denial.is_empty(),
		"latest_denial": latest_denial.duplicate(true),
		"custody_violation": custody_violation,
		"custody_incident": String(custody_state.get("active_incident", "")),
		"custody_investigations": open_investigations.duplicate(true),
		"mission_status": String(player_mission_state.get("status", "")),
		"mission_evidence": {
			"contract_id": String(player_mission_state.get("contract_id", "")),
			"acquired_artifact": String(player_mission_state.get("acquired_artifact", "")),
			"inventory": (player_mission_state.get("inventory", []) as Array).duplicate(),
			"heat": int(player_mission_state.get("heat", 0)),
		},
		"hostile_act": bool(AlertPhase.player_hostile),
		"alert_phase": int(AlertPhase.phase),
	}
	for staff_id in physical_staff_bodies.keys():
		var agent: Dictionary = staff_agent_state.get("agents", {}).get(staff_id, {})
		if String(agent.get("job_id", "")) != "security_officer":
			continue
		var guard: Node = physical_staff_bodies[staff_id]
		if not is_instance_valid(guard):
			continue
		if guard.is_facility_incapacitated():
			continue
		guard.set_facility_intrusion_context(context)


func _advance_security_patrols() -> bool:
	if (
		staff_agent_runtime == null
		or staff_agent_state.is_empty()
		or staffing_runtime == null
		or staffing_state.is_empty()
	):
		return false
	var agents: Dictionary = staff_agent_state.get("agents", {})
	var security_ids: Array[String] = staffing_runtime.active_staff_ids(
		staffing_state,
		"security_officer"
	)
	security_ids.sort()
	security_ids.reverse()
	var designation_valid := (
		not designated_security_patrol_id.is_empty()
		and security_ids.has(designated_security_patrol_id)
		and agents.has(designated_security_patrol_id)
		and String((agents[designated_security_patrol_id] as Dictionary).get("job_id", ""))
			== "security_officer"
	)
	if designation_valid and physical_staff_bodies.has(designated_security_patrol_id):
		var designated_body: Node = physical_staff_bodies[designated_security_patrol_id]
		if (
			is_instance_valid(designated_body)
			and designated_body.is_facility_incapacitated()
		):
			# Incapacitation releases the designation only after the reconcile
			# pass has cancelled the runtime route; until then the patrol stays
			# pinned to this officer so no second patrol can start.
			var designated_agent: Dictionary = agents[designated_security_patrol_id]
			if not (designated_agent.get("route", []) as Array).is_empty():
				return false
			designation_valid = false
	if not designation_valid:
		if (
			not designated_security_patrol_id.is_empty()
			and agents.has(designated_security_patrol_id)
			and not (
				(agents[designated_security_patrol_id] as Dictionary).get("route", []) as Array
			).is_empty()
		):
			# The outgoing designee still owns a runtime patrol route; reselecting
			# now could put two patrol routes in flight at once.
			return false
		designated_security_patrol_id = ""
		security_patrol_index = 0
		for staff_id in security_ids:
			if (
				not agents.has(staff_id)
				or String((agents[staff_id] as Dictionary).get("job_id", "")) != "security_officer"
			):
				continue
			if physical_staff_bodies.has(staff_id):
				var candidate_body: Node = physical_staff_bodies[staff_id]
				if (
					is_instance_valid(candidate_body)
					and candidate_body.is_facility_incapacitated()
				):
					continue
			designated_security_patrol_id = staff_id
			break
	if designated_security_patrol_id.is_empty():
		return false
	var agent: Dictionary = agents[designated_security_patrol_id]
	if (
		staff_agent_runtime.is_mutual_aid_bound(
			staff_agent_state,
			designated_security_patrol_id
		)
		or not physical_staff_bodies.has(designated_security_patrol_id)
		or not is_instance_valid(physical_staff_bodies[designated_security_patrol_id])
		or String(agent.get("status", "")) == "working"
		or agent.has("work_action")
		or not (agent.get("route", []) as Array).is_empty()
	):
		return false
	var guard: Node = physical_staff_bodies[designated_security_patrol_id]
	if (
		guard.is_facility_incapacitated()
		or bool(guard.call("is_facility_moving"))
		or physical_staff_target_rooms.has(designated_security_patrol_id)
	):
		return false
	var attempts := 0
	while attempts < SECURITY_PATROL_ROOMS.size():
		var destination: String = SECURITY_PATROL_ROOMS[security_patrol_index]
		security_patrol_index = (
			(security_patrol_index + 1) % SECURITY_PATROL_ROOMS.size()
		)
		attempts += 1
		if not (
			operation_graph.rooms.get(destination, {}).get("access_roles", []) as Array
		).has("security_officer"):
			continue
		var dispatched: Dictionary = staff_agent_runtime.dispatch(
			operation_graph,
			staff_agent_state,
			designated_security_patrol_id,
			destination
		)
		if not dispatched.get("accepted", false):
			continue
		if bool(dispatched.get("already_committed", false)):
			continue
		var physical_leg_assigned := _assign_physical_staff_leg(
			designated_security_patrol_id
		)
		if not physical_leg_assigned:
			staff_agent_runtime.cancel_dispatch(
				staff_agent_state,
				designated_security_patrol_id,
				"patrol_physical_leg_unavailable"
			)
			physical_staff_target_rooms.erase(designated_security_patrol_id)
			if guard.has_meta("facility_target_room"):
				guard.remove_meta("facility_target_room")
			if guard.has_meta("facility_target_position"):
				guard.remove_meta("facility_target_position")
			return false
		return true
	return false


func _assign_physical_staff_leg(staff_id: String) -> bool:
	if not physical_staff_bodies.has(staff_id) or not staff_agent_state.get("agents", {}).has(staff_id):
		return false
	var body: Node = physical_staff_bodies[staff_id]
	if not is_instance_valid(body) or bool(body.call("is_facility_moving")):
		return false
	var next_room: String = staff_agent_runtime.next_route_room(staff_agent_state, staff_id)
	if next_room.is_empty():
		physical_staff_target_rooms.erase(staff_id)
		return false
	var agent: Dictionary = staff_agent_state["agents"][staff_id]
	var current_room: String = String(agent.get("current_room", ""))
	var target_room := _find_room(generated_facility, next_room)
	var doors := generated_facility.get_node_or_null("Doors")
	if target_room == null or doors == null:
		return false
	var personnel_door: Node
	for candidate in doors.get_children():
		if String(candidate.get_meta("flow", "")) != "personnel":
			continue
		var door_from: String = String(candidate.get_meta("from_room", ""))
		var door_to: String = String(candidate.get_meta("to_room", ""))
		if (
			(door_from == current_room and door_to == next_room)
			or (door_from == next_room and door_to == current_room)
		):
			personnel_door = candidate
			break
	if personnel_door == null or not personnel_door.has_method("request_open"):
		return false
	var job_id: String = String(agent.get("job_id", ""))
	var destination_tier: int = int(operation_graph.rooms.get(next_room, {}).get("security_tier", 0))
	var credentials := {
		"clearance_tier": maxi(
			destination_tier,
			int(personnel_door.get_meta("required_clearance_tier", destination_tier))
		),
		"roles": [job_id],
		"target_room": next_room,
	}
	var uniform_color := (
		Color(0.14, 0.62, 0.42)
		if bool(operation_graph.jobs.get(job_id, {}).get("continuous", false))
		else Color(0.28, 0.48, 0.72)
	)
	body.call("configure_facility_identity", staff_id, job_id, credentials, uniform_color)
	if not bool(personnel_door.call("request_open", credentials, false)):
		return false
	var target_position: Vector3 = target_room.global_position + Vector3(0.0, 0.1, 0.0)
	body.set_meta("facility_target_room", next_room)
	body.set_meta("facility_target_position", target_position)
	if not bool(body.call("assign_facility_leg", target_position, next_room)):
		body.remove_meta("facility_target_room")
		body.remove_meta("facility_target_position")
		return false
	physical_staff_target_rooms[staff_id] = next_room
	return true


func _on_physical_staff_leg_arrived(staff_id: String, room_id: String) -> void:
	if not physical_staff_bodies.has(staff_id) or not physical_staff_target_rooms.has(staff_id):
		return
	var body: Node = physical_staff_bodies[staff_id]
	if not is_instance_valid(body):
		physical_staff_bodies.erase(staff_id)
		physical_staff_target_rooms.erase(staff_id)
		return
	var arrived_room: String = String(physical_staff_target_rooms[staff_id])
	if room_id != arrived_room or staff_agent_runtime.next_route_room(staff_agent_state, staff_id) != arrived_room:
		return
	var committed: Dictionary = staff_agent_runtime.commit_physical_arrival(
		staff_agent_state,
		staff_id,
		arrived_room
	)
	if not committed.get("accepted", false):
		return
	physical_staff_target_rooms.erase(staff_id)
	body.set_meta("authoritative_room", arrived_room)
	body.remove_meta("facility_target_room")
	body.remove_meta("facility_target_position")
	_assign_physical_staff_leg(staff_id)
	_advance_security_patrols()
	_create_staffing_markers()
	_refresh_procedure_panels()


func _release_physical_staff_body(staff_id: String, agent_state: Dictionary) -> void:
	if agent_state.get("agents", {}).has(staff_id):
		staff_agent_runtime.set_embodied(agent_state, staff_id, false)
	physical_staff_target_rooms.erase(staff_id)
	if not physical_staff_bodies.has(staff_id):
		return
	var body: Node = physical_staff_bodies[staff_id]
	physical_staff_bodies.erase(staff_id)
	if is_instance_valid(body):
		body.call("cancel_facility_leg")
		body.queue_free()


func _release_all_physical_staff(agent_state: Dictionary) -> void:
	for staff_id in physical_staff_bodies.keys():
		_release_physical_staff_body(staff_id, agent_state)
	designated_security_patrol_id = ""
	security_patrol_index = 0


func _install_testing_build_hud() -> void:
	if ObjectiveTracker.has_method("reset_mission"):
		ObjectiveTracker.reset_mission()
	ObjectiveTracker.objectives = {
		"walk": {"label": "1. Walk the generated Cyber/Archives facility", "done": false, "required": true},
		"panels": {"label": "2. Reach plant / security_control / staff_control procedure surfaces", "done": false, "required": true},
		"ops": {"label": "3. Exercise degraded ops via selftests when changing authority", "done": false, "required": false},
	}
	ObjectiveTracker.objectives_changed.emit()
	if has_node("TestingBanner"):
		return
	var layer := CanvasLayer.new()
	layer.name = "TestingBanner"
	layer.layer = 20
	add_child(layer)
	var banner := Label.new()
	banner.name = "Banner"
	banner.text = "BLACK SITE · FACILITY TEST BUILD · seed %d · fullscreen launch" % facility_seed
	banner.anchor_left = 0.0
	banner.anchor_top = 0.0
	banner.anchor_right = 1.0
	banner.anchor_bottom = 0.0
	banner.offset_left = 12.0
	banner.offset_top = 8.0
	banner.offset_right = -12.0
	banner.offset_bottom = 36.0
	banner.add_theme_font_size_override("font_size", 16)
	banner.add_theme_color_override("font_color", Color(0.82, 0.94, 1.0, 0.95))
	banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	banner.add_theme_constant_override("outline_size", 4)
	layer.add_child(banner)


func _create_procedure_panels() -> void:
	procedure_panels = Node3D.new()
	procedure_panels.name = "ProcedurePanels"
	add_child(procedure_panels)
	procedure_panel_definitions.clear()
	var station_counts: Dictionary = {}
	for service_id in operation_graph.service_continuity_profiles:
		var profile: Dictionary = operation_graph.service_continuity_profiles[service_id]
		var procedure_id: String = _procedure_for_service(service_id)
		if procedure_id.is_empty():
			continue
		var procedure: Dictionary = operation_graph.failure_procedures[procedure_id]
		for transition in profile["transitions"]:
			_add_procedure_panel(service_id, transition["action"], transition["station"], transition["actor_job"], transition["from"], station_counts)
			for alternate in transition.get("alternate_controls", []):
				_add_procedure_panel(service_id, transition["action"], alternate["station"], alternate["actor_job"], transition["from"], station_counts, alternate["mode"], alternate.get("equipment", ""))
		_add_procedure_panel(service_id, "begin_repair", procedure["station"], procedure["owner_job"], "repair_pending", station_counts)
		_add_procedure_panel(service_id, "record_repair", procedure["station"], procedure["owner_job"], "repair_pending", station_counts)
		_add_procedure_panel(service_id, "functional_test", procedure["station"], procedure["owner_job"], "testing", station_counts)
		for recovery_control in profile.get("recovery_controls", []):
			var recovery_phase: String="repair_pending" if recovery_control["action"] in ["begin_repair", "record_repair"] else "testing"
			_add_procedure_panel(service_id, recovery_control["action"], recovery_control["station"], recovery_control["actor_job"], recovery_phase, station_counts, recovery_control["mode"], recovery_control.get("equipment", ""))
		_add_procedure_panel(service_id, "verify_reconstitution", operation_graph.jobs["duty_officer"]["station"], "duty_officer", "reconstitution_pending", station_counts)
		for verification_control in profile.get("verification_controls", []):
			_add_procedure_panel(service_id, "verify_reconstitution", verification_control["station"], verification_control["actor_job"], "reconstitution_pending", station_counts, verification_control["mode"], verification_control.get("equipment", ""))
	_add_procedure_panel("custody", "contain_incident", "archive_processing", "records_officer", "archive_fire_water", station_counts)
	_add_procedure_panel("custody", "record_quarantine_disposition", "quarantine", "accession_technician", "disposition_pending", station_counts)


func _add_procedure_panel(
	service_id: String,
	action: String,
	station: String,
	actor_job: String,
	required_phase: String,
	station_counts: Dictionary,
	control_mode: String = "primary_control",
	equipment_id: String = ""
) -> void:
	var panel_id := "%s:%s" % [service_id, action]
	if control_mode != "primary_control":
		panel_id += "@%s" % station
	var definition := {
		"panel_id": panel_id,
		"service": service_id,
		"action": action,
		"station": station,
		"actor_job": actor_job,
		"required_phase": required_phase,
		"required_services": _procedure_required_services(service_id, station),
		"control_mode": control_mode,
		"equipment": equipment_id,
		"duration_ticks": _procedure_duration_ticks(action),
	}
	procedure_panel_definitions[panel_id] = definition
	var panel: StaticBody3D = procedure_panel_script.new()
	panel.name = panel_id.replace(":", "_")
	procedure_panels.add_child(panel)
	panel.configure(self, panel_id, service_id, action, station, actor_job, required_phase, definition["duration_ticks"], definition["required_services"], control_mode)
	var station_node := _find_room(generated_facility, station)
	var index := int(station_counts.get(station, 0))
	station_counts[station] = index + 1
	if station_node != null:
		var column := index % 4
		var row := index / 4
		panel.global_position = station_node.global_position + Vector3(-1.35 + float(column) * 0.9, 1.15 + float(row) * 0.72, -1.55)
	_refresh_procedure_panels()


func _procedure_required_services(recovered_service: String, station: String) -> Array[String]:
	var required: Array[String] = []
	for service_id in operation_graph.rooms[station].get("critical_requirements", []):
		if service_id != recovered_service:
			required.append(service_id)
	return required


func _procedure_duration_ticks(action: String) -> int:
	match action:
		"record_repair", "contain_incident":
			return 3
		"isolate_for_repair", "functional_test", "record_quarantine_disposition":
			return 2
		_:
			return 1


func _custody_procedure_phase() -> String:
	if not String(custody_state.get("active_incident", "")).is_empty():
		return custody_state["active_incident"]
	if custody_state.get("current_room", "") == "quarantine" and not bool(custody_state.get("quarantine_cleared", false)):
		return "disposition_pending"
	return "normal"


func _refresh_procedure_panels() -> void:
	if procedure_panels == null:
		return
	for panel in procedure_panels.get_children():
		var service_id: String = panel.get_meta("service", "")
		var action: String = panel.get_meta("action", "")
		var available: bool
		if service_id == "custody":
			available = _custody_procedure_phase() == panel.get_meta("required_phase", "")
		else:
			available = infrastructure_state.has("active_failures") and infrastructure_state["active_failures"].has(service_id)
			if available:
				available = infrastructure_runtime.service_phase(infrastructure_state, service_id) == panel.get_meta("required_phase", "")
		if available and action == "begin_repair":
			available = not procedure_receipts.has(service_id)
		elif available and action == "record_repair":
			available = procedure_receipts.has(service_id) and (procedure_receipts[service_id].get("remediation", {}) as Dictionary).is_empty()
		if available and control_network_state.get("posture", "normal") == "isolated" and panel.get_meta("control_mode", "primary_control") == "primary_control":
			available = false
		if available:
			available = not procedure_work_state.get("active_panel_tasks", {}).has(panel.get_meta("panel_id", ""))
		if available:
			available = not staffing_runtime.active_staff_ids(staffing_state, panel.get_meta("actor_job", "")).is_empty()
		if available:
			var condition_probe := {
				"station": panel.get_meta("station", ""),
				"actor_job": panel.get_meta("actor_job", ""),
				"required_services": panel.get_meta("required_services", []),
			}
			available = procedure_work_runtime.task_conditions(operation_graph, condition_probe, _procedure_condition_snapshot()).get("available", false)
		if panel.has_method("set_available"):
			panel.set_available(available)
		if panel.has_method("set_work_state"):
			var task_id: String = procedure_work_state.get("active_panel_tasks", {}).get(panel.get_meta("panel_id", ""), "")
			var task: Dictionary = procedure_work_state.get("tasks", {}).get(task_id, {})
			var work_reason := ""
			if task.get("status", "") == "interrupted" and not (task.get("interruptions", []) as Array).is_empty():
				work_reason = task["interruptions"][-1].get("reason", "")
			panel.set_work_state(task.get("status", ""), int(task.get("remaining_ticks", 0)), task.get("handoffs", []).size(), work_reason)


func _is_failure_transition_action(service_id: String, action: String) -> bool:
	if not operation_graph.service_continuity_profiles.has(service_id): return false
	var current_phase: String=infrastructure_runtime.service_phase(infrastructure_state,service_id)
	for transition in operation_graph.service_continuity_profiles[service_id].get("transitions",[]):
		if transition.get("from","")==current_phase and transition.get("action","")==action: return true
	return false


func _procedure_for_service(service_id: String) -> String:
	for procedure_id in operation_graph.failure_procedures:
		if (operation_graph.failure_procedures[procedure_id]["capabilities"] as Array).has(service_id):
			return procedure_id
	return ""


func _create_control_status_board() -> void:
	control_status_board = Label3D.new()
	control_status_board.name = "ControlStatusBoard"
	control_status_board.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	control_status_board.font_size = 38
	control_status_board.outline_size = 12
	control_status_board.pixel_size = 0.007
	control_status_board.no_depth_test = true
	add_child(control_status_board)
	var duty_station: String = operation_graph.jobs["duty_officer"]["station"]
	var station_node := _find_room(generated_facility, duty_station)
	if station_node != null:
		control_status_board.global_position = station_node.global_position + Vector3(0.0, 2.75, 0.0)
	control_status_board.set_meta("station", duty_station)


func _refresh_control_status_board() -> void:
	if control_room_runtime == null or control_console_state.is_empty() or control_status_board == null:
		return
	control_snapshot = control_room_runtime.compile_status(
		operation_graph,
		control_console_state,
		mission_state,
		custody_state,
		personnel_state,
		staffing_state,
		staffing_runtime,
		infrastructure_state
	)
	var lines: Array[String] = [
		"CONTROL %s" % String(control_snapshot["severity"]).to_upper(),
		"MISSION  %s" % control_snapshot["mission"]["status"],
		"NEXT  %s" % control_snapshot["mission"]["next_step"],
		"SHIFT  %s" % control_snapshot["staffing"]["active_shift"],
		"CUSTODY  %s" % control_snapshot["custody"]["current_room"],
	]
	if control_network_state.get("posture", "normal") == "isolated":
		lines.append("CONTROL isolated  %s" % control_network_state.get("active_incident", {}).get("occurrence_id", "UNKNOWN"))
	var queue_waiting := 0
	var queue_escalated := 0
	var queue_safe_hold := 0
	var queue_shutdown := 0
	for entry in operations_queue_state.get("entries", {}).values():
		if entry.get("status", "") == "waiting":
			queue_waiting += 1
			if bool(entry.get("escalated", false)):
				queue_escalated += 1
		elif entry.get("status", "") == "safe_hold":
			queue_safe_hold += 1
		elif entry.get("status", "") == "mission_shutdown":
			queue_shutdown += 1
	var reserved_count: int = operations_queue_state.get("reservations", {}).get("stations", {}).size()
	lines.append("OPS  WAIT %d  ESC %d  RESERVED %d  SAFE %d  SHUT %d  DEC %d" % [queue_waiting, queue_escalated, reserved_count, queue_safe_hold, queue_shutdown, operations_queue_state.get("continuity_decisions", []).size()])
	for condition in control_snapshot["conditions"]:
		lines.append("%s  %s  %s%s" % [
			"ACK" if bool(condition["acknowledged"]) else "OPEN",
			String(condition["kind"]).to_upper(),
			condition["id"],
			"  [%s]" % condition["phase"] if condition.has("phase") else "",
		])
		lines.append("  %s" % condition["procedure"])
		lines.append("  OWNER  %s" % condition["owner_job"])
	control_status_board.text = "\n".join(lines)
	control_status_board.modulate = Color(1.0, 0.72, 0.16) if control_snapshot["severity"] == "alarm" else Color(0.3, 0.95, 0.55)
	control_status_board.set_meta("severity", control_snapshot["severity"])
	control_status_board.set_meta("condition_count", control_snapshot["conditions"].size())
	control_status_board.set_meta("snapshot", control_snapshot.duplicate(true))


func acknowledge_condition(occurrence_id: String, roles: Array) -> Dictionary:
	if control_room_runtime == null or control_snapshot.is_empty():
		return {"accepted": false, "reason": "control room unavailable"}
	var result: Dictionary = control_room_runtime.acknowledge(
		control_console_state,
		control_snapshot,
		occurrence_id,
		{"roles": roles.duplicate()}
	)
	_refresh_control_status_board()
	return result


func exhaust_job_staffing(job_id: String) -> Dictionary:
	if staffing_runtime == null or staffing_state.is_empty():
		return {"procedure": "", "uncovered_jobs": [job_id]}
	var staff_ids: Array[String] = staffing_runtime.all_staff_ids_for_job(staffing_state, job_id)
	var result: Dictionary = staffing_runtime.apply_shortage(operation_graph, staffing_state, staff_ids)
	staffing_runtime.apply_mission_availability(operation_graph, staffing_state, operation_runtime, mission_state)
	_release_all_physical_staff(staff_agent_state)
	staff_agent_state = staff_agent_runtime.build_active_watch(operation_graph, staffing_state, staffing_runtime)
	_create_staffing_markers()
	_refresh_control_status_board()
	return result


func turnover_shift(to_shift: String) -> Dictionary:
	if staffing_runtime == null or staffing_state.is_empty():
		return {"accepted": false, "reason": "staffing unavailable"}
	for mutual_case in mutual_aid_state.get("cases",{}).values():
		if mutual_case.get("phase","")=="demobilizing" and not escort_holdover_turnover_authorized:
			return {"accepted":false,"reason":"shift turnover would abandon active external responder escort","case_id":mutual_case.get("case_id","")}
	var receipt: Dictionary = staffing_runtime.begin_shift_turnover(operation_graph, staffing_state, to_shift)
	if not receipt.get("accepted", false):
		return receipt
	var work_handoffs: Dictionary = procedure_work_runtime.begin_shift_handoffs(procedure_work_state, receipt)
	if not work_handoffs.get("accepted", false):
		staffing_runtime.cancel_shift_turnover(staffing_state, receipt, work_handoffs.get("reason", "procedure work handoff rejected"))
		return work_handoffs
	var hazard_handoffs: Dictionary = environmental_observation_runtime.begin_hazard_shift_handoff(environmental_observation_state, receipt)
	if not hazard_handoffs.get("accepted", false):
		procedure_work_runtime.cancel_shift_handoffs(procedure_work_state, receipt["turnover_id"])
		staffing_runtime.cancel_shift_turnover(staffing_state, receipt, hazard_handoffs.get("reason", "environmental hazard work handoff rejected"))
		return hazard_handoffs
	var release_handoffs: Dictionary = environmental_observation_runtime.begin_release_shift_handoff(environmental_observation_state, receipt)
	if not release_handoffs.get("accepted", false):
		procedure_work_runtime.cancel_shift_handoffs(procedure_work_state, receipt["turnover_id"])
		staffing_runtime.cancel_shift_turnover(staffing_state, receipt, release_handoffs.get("reason", "protective release handoff rejected"))
		return release_handoffs
	var reentry_handoffs: Dictionary=environmental_observation_runtime.begin_reentry_shift_handoff(environmental_observation_state,receipt)
	if not reentry_handoffs.get("accepted",false):
		procedure_work_runtime.cancel_shift_handoffs(procedure_work_state,receipt["turnover_id"])
		staffing_runtime.cancel_shift_turnover(staffing_state,receipt,reentry_handoffs.get("reason","room re-entry handoff rejected"))
		return reentry_handoffs
	var result: Dictionary = staffing_runtime.complete_shift_turnover(operation_graph, staffing_state, receipt)
	if not result.get("accepted", false):
		procedure_work_runtime.cancel_shift_handoffs(procedure_work_state, receipt["turnover_id"])
		return result
	staffing_runtime.apply_mission_availability(operation_graph, staffing_state, operation_runtime, mission_state)
	_release_all_physical_staff(staff_agent_state)
	staff_agent_state = staff_agent_runtime.build_active_watch(operation_graph, staffing_state, staffing_runtime)
	var completed_hazard_handoffs: Dictionary = environmental_observation_runtime.complete_hazard_shift_handoff(environmental_observation_state, hazard_handoffs.get("receipts", []), staff_agent_state)
	if not completed_hazard_handoffs.get("accepted", false): return {"accepted": false, "reason": "committed shift has unresolved environmental hazard handoff", "turnover_id": receipt["turnover_id"], "handoff_result": completed_hazard_handoffs}
	var completed_release_handoffs: Dictionary = environmental_observation_runtime.complete_release_shift_handoff(environmental_observation_state, release_handoffs.get("receipts", []), staff_agent_state)
	if not completed_release_handoffs.get("accepted", false): return {"accepted": false, "reason": "committed shift has unresolved protective release handoff", "turnover_id": receipt["turnover_id"], "handoff_result": completed_release_handoffs}
	var completed_reentry_handoffs: Dictionary=environmental_observation_runtime.complete_reentry_shift_handoff(environmental_observation_state,reentry_handoffs.get("receipts",[]),staff_agent_state)
	if not completed_reentry_handoffs.get("accepted",false): return {"accepted":false,"reason":"committed shift has unresolved room re-entry handoff","turnover_id":receipt["turnover_id"],"handoff_result":completed_reentry_handoffs}
	var completed_handoffs: Array[Dictionary] = []
	for work_receipt in work_handoffs["receipts"]:
		var completed: Dictionary = procedure_work_runtime.complete_shift_handoff(
			operation_graph, procedure_work_state, work_receipt, staff_agent_state, staff_agent_runtime
		)
		if not completed.get("accepted", false):
			_create_staffing_markers()
			_refresh_procedure_panels()
			_refresh_control_status_board()
			return {"accepted": false, "reason": "committed shift has unresolved procedure handoff", "turnover_id": receipt["turnover_id"], "handoff_result": completed}
		completed_handoffs.append(completed)
	result["work_handoffs"] = completed_handoffs
	result["hazard_handoffs"] = completed_hazard_handoffs.get("handoffs", [])
	result["release_handoffs"] = completed_release_handoffs.get("handoffs", [])
	result["reentry_handoffs"] = completed_reentry_handoffs.get("handoffs", [])
	_create_staffing_markers()
	_refresh_procedure_panels()
	_refresh_control_status_board()
	return result

func turnover_shift_with_external_escort_holdover(to_shift: String, case_id: String) -> Dictionary:
	var c: Dictionary=mutual_aid_state.get("cases",{}).get(case_id,{})
	var work: Dictionary=mutual_aid_state.get("demobilizations",{}).get(case_id,{})
	if c.get("phase","")!="demobilizing" or work.is_empty(): return {"accepted":false,"reason":"external escort holdover requires active demobilization"}
	var escort_id: String=c.get("escort_actor",""); var escort_staff: Dictionary=staffing_state.get("staff",{}).get(escort_id,{})
	if escort_staff.get("job_id","")!="security_officer" or escort_id not in staffing_runtime.active_staff_ids(staffing_state,"security_officer"): return {"accepted":false,"reason":"current escort is not active security staff"}
	var commander_id: String=""
	for command in environmental_observation_state.get("displaced_commands",[]):
		if command.get("finding_id","")==c.get("occurrence_id",""): commander_id=command.get("actor_person_id",""); break
	if commander_id.is_empty() or commander_id not in staffing_runtime.active_staff_ids(staffing_state,"duty_officer"): return {"accepted":false,"reason":"active displaced commander unavailable for incident holdover"}
	var old_agents: Dictionary={escort_id:staff_agent_state.get("agents",{}).get(escort_id,{}).duplicate(true),commander_id:staff_agent_state.get("agents",{}).get(commander_id,{}).duplicate(true)}; var mutual_before: Dictionary=mutual_aid_state.duplicate(true)
	escort_holdover_turnover_authorized=true
	var result: Dictionary=turnover_shift(to_shift)
	escort_holdover_turnover_authorized=false
	if not result.get("accepted",false): return result
	if mutual_aid_state!=mutual_before: return {"accepted":false,"reason":"shift turnover mutated active mutual-aid demobilization"}
	for person_id in [escort_id,commander_id]:
		var staff_record: Dictionary=staffing_state["staff"][person_id]; var location: String=mutual_aid_state["temporary_locations"].get(person_id,old_agents[person_id].get("current_room",""))
		var holdover: Dictionary={"person_id":person_id,"job_id":staff_record["job_id"],"case_id":case_id,"turnover_id":result.get("turnover_id","") ,"from_shift":staff_record.get("shift",""),"to_shift":to_shift,"location":location}
		staffing_state["incident_holdovers"][person_id]=holdover
		var old_agent: Dictionary=old_agents[person_id]
		if not old_agent.is_empty(): old_agent["current_room"]=location; old_agent["route"]=[]; staff_agent_state["agents"][person_id]=old_agent
	result["escort_person_id"]=escort_id; result["commander_person_id"]=commander_id; result["incident_holdovers"]=staffing_state["incident_holdovers"].duplicate(true)
	return result


func _create_staffing_markers() -> void:
	if staffing_group == null:
		staffing_group = Node3D.new()
		staffing_group.name = "Staffing"
		add_child(staffing_group)
	else:
		for child in staffing_group.get_children():
			staffing_group.remove_child(child)
			child.free()
	var room_counts: Dictionary = {}
	var temporary_locations: Dictionary = mutual_aid_state.get("temporary_locations", {})
	var agents: Dictionary = staff_agent_state.get("agents", {})
	var job_ids: Array = operation_graph.jobs.keys()
	job_ids.sort()
	for job_id in job_ids:
		var on_duty: Array[String] = staffing_runtime.active_primary_staff_ids(staffing_state, job_id)
		for relief_id in staffing_state["active_relief"].get(job_id, []):
			if not staffing_state["unavailable"].has(relief_id):
				on_duty.append(relief_id)
		for staff_id in on_duty:
			var station_room: String = operation_graph.jobs[job_id]["station"]
			if agents.has(staff_id):
				station_room = agents[staff_id]["current_room"]
			if temporary_locations.has(staff_id):
				station_room = String(temporary_locations[staff_id])
			if physical_staff_bodies.has(staff_id) and is_instance_valid(physical_staff_bodies[staff_id]):
				continue
			var station_node := _find_room(generated_facility, station_room)
			if station_node == null:
				continue
			var room_index: int = int(room_counts.get(station_room, 0))
			room_counts[station_room] = room_index + 1
			var marker := MeshInstance3D.new()
			marker.name = "Staff_%s" % staff_id
			var mesh := SphereMesh.new()
			mesh.radius = 0.18
			mesh.height = 0.48
			marker.mesh = mesh
			var material := StandardMaterial3D.new()
			if temporary_locations.has(staff_id):
				material.albedo_color = Color(0.62, 0.22, 0.72)
			else:
				material.albedo_color = Color(0.14, 0.62, 0.42) if bool(operation_graph.jobs[job_id]["continuous"]) else Color(0.28, 0.48, 0.72)
			marker.material_override = material
			staffing_group.add_child(marker)
			marker.global_position = station_node.global_position + Vector3(
				-1.8 + float(room_index % 5) * 0.72,
				0.42,
				-1.7 + float(room_index / 5) * 0.62
			)
			marker.set_meta("staff_id", staff_id)
			marker.set_meta("job_id", job_id)
			marker.set_meta("current_room", station_room)
			marker.set_meta("agent_status", agents.get(staff_id, {}).get("status", "untracked"))
			marker.set_meta("shift", staffing_state["active_shift"])
			marker.set_meta("relief", (staffing_state["active_relief"][job_id] as Array).has(staff_id))
			if temporary_locations.has(staff_id):
				marker.set_meta("mutual_aid_bound", true)
				marker.set_meta("temporary_mutual_aid", true)
				marker.set_meta("role", "escort")
				var bound_case_id: String = String(agents.get(staff_id, {}).get("mutual_aid_case_id", ""))
				if not bound_case_id.is_empty():
					marker.set_meta("case_id", bound_case_id)
					var bound_case: Dictionary = mutual_aid_state.get("cases", {}).get(bound_case_id, {})
					if not bound_case.is_empty():
						marker.set_meta("phase", bound_case.get("phase", ""))
	var external_ids: Array = temporary_locations.keys()
	external_ids.sort()
	for person_id in external_ids:
		if agents.has(person_id):
			continue
		var room_id: String = String(temporary_locations[person_id])
		var room_node := _find_room(generated_facility, room_id)
		if room_node == null:
			continue
		var external_index: int = int(room_counts.get(room_id, 0))
		room_counts[room_id] = external_index + 1
		var external_marker := MeshInstance3D.new()
		external_marker.name = "MutualAid_%s" % person_id
		var external_mesh := SphereMesh.new()
		external_mesh.radius = 0.18
		external_mesh.height = 0.48
		external_marker.mesh = external_mesh
		var external_material := StandardMaterial3D.new()
		external_material.albedo_color = Color(0.86, 0.55, 0.12)
		external_marker.material_override = external_material
		staffing_group.add_child(external_marker)
		external_marker.global_position = room_node.global_position + Vector3(
			-1.8 + float(external_index % 5) * 0.72,
			0.42,
			-1.7 + float(external_index / 5) * 0.62
		)
		external_marker.set_meta("person_id", person_id)
		external_marker.set_meta("temporary_mutual_aid", true)
		external_marker.set_meta("current_room", room_id)
		external_marker.set_meta("role", "external")
		for case_entry in mutual_aid_state.get("cases", {}).values():
			if case_entry.get("responder_id", "") == person_id or case_entry.get("external_id", "") == person_id:
				external_marker.set_meta("case_id", case_entry.get("case_id", ""))
				external_marker.set_meta("phase", case_entry.get("phase", ""))
				break


func _sync_mutual_aid_locations() -> void:
	if staff_agent_runtime != null and not staff_agent_state.is_empty():
		# Mutual-aid authority relocates authoritative rooms directly, so any
		# affected embodied body must be released before the sync; leaving it
		# embodied would strand a physical body at the pre-binding position.
		var temporary_locations: Dictionary = mutual_aid_state.get("temporary_locations", {})
		var agents: Dictionary = staff_agent_state.get("agents", {})
		for staff_id in physical_staff_bodies.keys():
			if not agents.has(staff_id):
				continue
			var affected: bool = (
				temporary_locations.has(staff_id)
				or bool((agents[staff_id] as Dictionary).get("mutual_aid_bound", false))
			)
			if affected:
				_release_physical_staff_body(staff_id, staff_agent_state)
		staff_agent_runtime.sync_mutual_aid_bindings(staff_agent_state, mutual_aid_state)
		# Reconcile only now that authoritative locations are stable; a released
		# security officer respawns at the new current_room instead of teleporting.
		_reconcile_physical_staff()
	_create_staffing_markers()


func request_personnel_transition(to_room: String, emergency_mode: bool = false, relocate_body: bool = true) -> Dictionary:
	if personnel_security_runtime == null or personnel_state.is_empty():
		return {"accepted": false, "reason": "personnel security unavailable"}
	var receipt: Dictionary = personnel_security_runtime.begin_transition(operation_graph, personnel_state, to_room, emergency_mode)
	if not receipt.get("accepted", false):
		_refresh_control_status_board()
		return receipt
	var result: Dictionary = personnel_security_runtime.complete_transition(personnel_state, receipt)
	if result.get("accepted", false):
		_sync_personnel_position(relocate_body)
	_refresh_control_status_board()
	return result


func handle_policy_door_interact(door: Node, interactor: Node) -> Dictionary:
	if interactor != player or personnel_state.is_empty():
		return {"accepted": false, "reason": "no personnel identity"}
	var from_room: String = str(door.get_meta("from_room", ""))
	var to_room: String = str(door.get_meta("to_room", ""))
	var current: String = str(personnel_state.get("current_room", ""))
	var dest := ""
	var emergency: bool = bool(door.get_meta("emergency_only", false)) or bool(interactor.get_meta("facility_emergency_mode", false))
	if current == from_room:
		dest = to_room
	elif current == to_room:
		dest = from_room
	else:
		ObjectiveTracker.set_prompt("Not at this door boundary")
		return {"accepted": false, "reason": "player not at door boundary"}
	# Authorize room change, then open the physical door. Never teleport the body.
	var result: Dictionary = request_personnel_transition(dest, emergency, false)
	if result.get("accepted", false):
		var opened := false
		if door.has_method("request_open"):
			var credentials := {
				"clearance_tier": int(player.keycard_tier) if "keycard_tier" in player else 0,
				"roles": player.get_meta("facility_roles", []),
			}
			opened = bool(door.request_open(credentials, emergency))
			if opened and "is_open" in door:
				opened = bool(door.is_open)
		ObjectiveTracker.set_prompt("Door open — walk into %s" % dest if opened else "Access granted — enter %s" % dest)
		result["door_opened"] = opened
		result["relocated_body"] = false
		_note_player_mission_access(true, dest, "")
	else:
		ObjectiveTracker.set_prompt("Access denied — %s" % result.get("reason", "policy"))
		_note_player_mission_access(false, dest, str(result.get("reason", "")))
	return result


func _note_player_mission_access(granted: bool, room: String, reason: String) -> void:
	if player_mission_state.is_empty() or player_mission_runtime == null:
		return
	if player_mission_state.get("status", "") != "active":
		return
	if not granted:
		player_mission_runtime.record_access_denial(player_mission_state, room, reason)
		_sync_player_mission_hud()

func _sync_personnel_position(relocate_body: bool = true) -> void:
	if generated_facility == null or personnel_state.is_empty():
		return
	var room_node := _find_room(generated_facility, personnel_state["current_room"])
	if relocate_body and room_node != null:
		player.global_position = room_node.global_position + Vector3(0.0, 0.15, 0.0)
	player.set_meta("authoritative_room", personnel_state["current_room"])
	player.set_meta("screened", personnel_state["screened"])
	player.set_meta("security_denial_count", personnel_state["denials"].size())


func set_service_available(service_kind: String, available: bool) -> Dictionary:
	if operation_runtime == null or mission_state.is_empty() or infrastructure_runtime == null:
		return {"accepted": false, "reason": "infrastructure unavailable"}
	if available:
		return {"accepted": false, "reason": "service restoration requires procedure execution"}
	var infrastructure_before: Dictionary = infrastructure_state.duplicate(true)
	var result: Dictionary = infrastructure_runtime.declare_service_failure(operation_graph, infrastructure_state, service_kind)
	if result.get("accepted", false) and service_kind == "environmental_monitoring" and not environmental_observation_state.get("active", false):
		var observation_activation: Dictionary = _activate_environmental_observation_authority(result.get("failure_id", ""))
		if not observation_activation.get("accepted", false):
			infrastructure_state = infrastructure_before
			return observation_activation
	infrastructure_runtime.apply_mission_snapshot(operation_graph, infrastructure_state, operation_runtime, mission_state)
	_refresh_procedure_panels()
	_apply_service_snapshot()
	_refresh_control_status_board()
	return result


func _activate_environmental_observation_authority(occurrence_id: String) -> Dictionary:
	var obligation: Dictionary = operation_graph.service_continuity_profiles.get("environmental_monitoring", {}).get("degraded_obligations", [])[0]
	var actors_by_job: Dictionary = {}
	for assignment in obligation.get("room_assignments", []):
		var job_id: String = assignment.get("actor_job", "")
		var candidates: Array[String] = staffing_runtime.active_staff_ids(staffing_state, job_id)
		candidates.sort()
		var selected_id: String = ""
		for candidate_id in candidates:
			if staff_agent_state.get("agents", {}).has(candidate_id): selected_id = candidate_id; break
		if selected_id.is_empty(): return {"accepted": false, "reason": "no named active observer:" + job_id}
		actors_by_job[job_id] = selected_id
	return environmental_observation_runtime.activate(environmental_observation_state, occurrence_id, obligation, actors_by_job)


func tick_environmental_observation_rounds(readings_by_room: Dictionary) -> Dictionary:
	if not environmental_observation_state.get("active", false): return {"accepted": false, "reason": "environmental observation authority inactive"}
	if environmental_observation_state.get("active_round", {}).is_empty():
		return environmental_observation_runtime.tick(environmental_observation_state, {}, readings_by_room)
	var round_state: Dictionary = environmental_observation_state["active_round"]
	var assignment: Dictionary = round_state["assignments"][round_state["room_index"]]
	var actor_id: String = assignment["actor_person_id"]
	var room_id: String = assignment["room"]
	if not staff_agent_runtime.is_at_room(staff_agent_state, actor_id, room_id):
		var agent: Dictionary = staff_agent_state.get("agents", {}).get(actor_id, {})
		if agent.is_empty(): return {"accepted": false, "reason": "named observer left active watch"}
		if (agent.get("route", []) as Array).is_empty():
			var dispatched: Dictionary = staff_agent_runtime.dispatch(operation_graph, staff_agent_state, actor_id, room_id)
			if not dispatched.get("accepted", false): return dispatched
		staff_agent_runtime.tick(staff_agent_state)
		var waiting_result: Dictionary = environmental_observation_runtime.tick_waiting(environmental_observation_state)
		return {"accepted": waiting_result.get("accepted", false), "status": "observer_traveling", "actor_person_id": actor_id, "destination": room_id, "overdue": waiting_result.get("overdue", false)}
	var actor_locations: Dictionary = {}
	for staff_id in staff_agent_state.get("agents", {}): actor_locations[staff_id] = staff_agent_state["agents"][staff_id]["current_room"]
	return environmental_observation_runtime.tick(environmental_observation_state, actor_locations, readings_by_room)


func dispatch_environmental_hazard_authority(finding_id: String) -> Dictionary:
	var finding: Dictionary = {}
	for candidate_finding in environmental_observation_state.get("hazard_findings", []):
		if candidate_finding.get("finding_id", "") == finding_id: finding = candidate_finding; break
	if finding.is_empty() or finding.get("status", "") != "unresolved": return {"accepted": false, "reason": "unresolved environmental hazard not found"}
	var policy: Dictionary = environmental_observation_state.get("obligation", {}).get("escalation", {})
	var candidates: Array[String] = staffing_runtime.active_staff_ids(staffing_state, policy.get("actor_job", "")); candidates.sort()
	var actor_id: String = ""
	for candidate_id in candidates:
		if staff_agent_state.get("agents", {}).has(candidate_id): actor_id = candidate_id; break
	if actor_id.is_empty(): return {"accepted": false, "reason": "no named active hazard command authority"}
	var station: String = policy.get("station", "")
	if not staff_agent_runtime.is_at_room(staff_agent_state, actor_id, station):
		var agent: Dictionary = staff_agent_state["agents"][actor_id]
		if (agent.get("route", []) as Array).is_empty():
			var dispatched: Dictionary = staff_agent_runtime.dispatch(operation_graph, staff_agent_state, actor_id, station)
			if not dispatched.get("accepted", false): return dispatched
		staff_agent_runtime.tick(staff_agent_state)
		return {"accepted": true, "status": "traveling", "actor_person_id": actor_id, "station": station}
	return {"accepted": true, "status": "ready", "actor_person_id": actor_id, "station": station}


func decide_environmental_hazard(finding_id: String, decision: String, rationale: String, actor_person_id: String) -> Dictionary:
	var agent: Dictionary = staff_agent_state.get("agents", {}).get(actor_person_id, {})
	if agent.is_empty(): return {"accepted": false, "reason": "named hazard command actor not active"}
	var result: Dictionary = environmental_observation_runtime.decide_hazard(environmental_observation_state, finding_id, decision, rationale, {"person_id":actor_person_id,"roles":[agent.get("job_id","")],"current_room":agent.get("current_room","")})
	if result.get("accepted", false):
		for room_id in environmental_observation_state.get("protective_postures", {}):
			var posture: String = environmental_observation_state["protective_postures"][room_id]
			operation_runtime.set_room_protective_posture(mission_state, room_id, posture)
			staff_agent_runtime.set_room_entry_block(staff_agent_state, room_id, "environmental_evacuation" if posture == "evacuate" else "")
	return result


func dispatch_environmental_room_evacuation(finding_id: String) -> Dictionary:
	if not environmental_observation_state.get("active_room_evacuation", {}).is_empty(): return {"accepted": true, "status": "active"}
	var finding: Dictionary = {}
	for candidate in environmental_observation_state.get("hazard_findings", []):
		if candidate.get("finding_id", "") == finding_id: finding = candidate; break
	if finding.is_empty(): return {"accepted": false, "reason": "evacuation finding not found"}
	var policy: Dictionary = {}
	for rule in environmental_observation_state.get("obligation", {}).get("hazard_rules", []):
		if rule.get("classification", "") == finding.get("classification", ""): policy = rule.get("evacuation", {}); break
	if policy.is_empty(): return {"accepted": false, "reason": "evacuation policy unavailable"}
	var roster: Array = []
	var person_ids: Array = staff_agent_state.get("agents", {}).keys(); person_ids.sort()
	for person_id in person_ids:
		var agent: Dictionary = staff_agent_state["agents"][person_id]
		if agent.get("current_room", "") == finding.get("room", ""): roster.append({"person_id":person_id,"job":agent["job_id"],"source_room":finding["room"]})
	var begun: Dictionary = environmental_observation_runtime.begin_room_evacuation(environmental_observation_state, finding_id, roster)
	if not begun.get("accepted", false): return begun
	for entry in roster:
		var dispatched: Dictionary = staff_agent_runtime.dispatch_egress(operation_graph, staff_agent_state, entry["person_id"], policy["destination"])
		if not dispatched.get("accepted", false): environmental_observation_state["active_room_evacuation"] = {}; return dispatched
	return begun


func tick_environmental_room_evacuation() -> Dictionary:
	var active: Dictionary = environmental_observation_state.get("active_room_evacuation", {})
	if active.is_empty(): return {"accepted": false, "reason": "room evacuation not active"}
	staff_agent_runtime.tick(staff_agent_state)
	var locations: Dictionary = {}
	for entry in active["roster"]:
		if staff_agent_state.get("agents", {}).has(entry["person_id"]): locations[entry["person_id"]] = staff_agent_state["agents"][entry["person_id"]]["current_room"]
	var accountability_actor: Dictionary = {}
	var candidates: Array[String] = staffing_runtime.active_staff_ids(staffing_state, active["accountability_job"]); candidates.sort()
	for person_id in candidates:
		if staff_agent_runtime.is_at_room(staff_agent_state, person_id, active["accountability_station"]): accountability_actor = {"person_id":person_id,"job":active["accountability_job"],"current_room":active["accountability_station"]}; break
	return environmental_observation_runtime.complete_room_evacuation(environmental_observation_state, locations, accountability_actor)

func dispatch_environmental_displaced_command(finding_id: String) -> Dictionary:
	var finding: Dictionary={}; var evacuation: Dictionary={}; var policy: Dictionary={}
	for candidate in environmental_observation_state.get("hazard_findings",[]):
		if candidate.get("finding_id","")==finding_id: finding=candidate; break
	for candidate in environmental_observation_state.get("room_evacuations",[]):
		if candidate.get("finding_id","")==finding_id: evacuation=candidate; break
	for rule in environmental_observation_state.get("obligation",{}).get("hazard_rules",[]):
		if rule.get("classification","")==finding.get("classification",""): policy=rule.get("evacuation",{}).get("displaced_command",{}); break
	if finding.is_empty() or evacuation.is_empty() or policy.is_empty(): return {"accepted":false,"reason":"displaced command policy or accounted evacuation unavailable"}
	var evacuated: Dictionary={}
	for roster_entry in evacuation.get("roster",[]): evacuated[roster_entry.get("person_id","")]=true
	var candidates: Array[String]=staffing_runtime.active_staff_ids(staffing_state,policy["actor_job"]); candidates.sort()
	var actor_id: String=""
	for candidate_id in candidates:
		if not evacuated.has(candidate_id) and staff_agent_runtime.is_at_room(staff_agent_state,candidate_id,policy["station"]): actor_id=candidate_id; break
	if actor_id.is_empty():
		for candidate_id in candidates:
			if not evacuated.has(candidate_id) and staff_agent_state.get("agents",{}).has(candidate_id): actor_id=candidate_id; break
	if actor_id.is_empty(): return {"accepted":false,"reason":"no non-evacuated duty officer available for displaced command"}
	if not staff_agent_runtime.is_at_room(staff_agent_state,actor_id,policy["station"]):
		var agent: Dictionary=staff_agent_state["agents"][actor_id]
		if (agent.get("route",[]) as Array).is_empty():
			var dispatched: Dictionary=staff_agent_runtime.dispatch(operation_graph,staff_agent_state,actor_id,policy["station"])
			if not dispatched.get("accepted",false): return dispatched
		staff_agent_runtime.tick(staff_agent_state)
		return {"accepted":true,"status":"traveling","actor_person_id":actor_id,"station":policy["station"]}
	return {"accepted":true,"status":"ready","actor_person_id":actor_id,"station":policy["station"]}

func establish_environmental_displaced_command(finding_id: String, rationale: String, actor_person_id: String) -> Dictionary:
	var agent: Dictionary=staff_agent_state.get("agents",{}).get(actor_person_id,{})
	if agent.is_empty(): return {"accepted":false,"reason":"named displaced command actor not active"}
	return environmental_observation_runtime.establish_displaced_command(environmental_observation_state,finding_id,rationale,{"person_id":actor_person_id,"job":agent.get("job_id",""),"current_room":agent.get("current_room","")})


func dispatch_environmental_compute_reactivation(finding_id: String) -> Dictionary:
	var finding: Dictionary = {}
	for candidate in environmental_observation_state.get("hazard_findings", []):
		if candidate.get("finding_id", "") == finding_id: finding = candidate; break
	if not String(finding.get("classification","")).begins_with("compute_") or finding.get("status", "") != "closed": return {"accepted": false, "reason": "closed compute finding not found"}
	var policy: Dictionary = {}
	for rule in environmental_observation_state.get("obligation", {}).get("hazard_rules", []):
		if rule.get("classification", "") == finding["classification"]: policy = rule.get("remediation", {}).get("reactivation", {}); break
	if policy.is_empty(): return {"accepted": false, "reason": "compute reactivation policy unavailable"}
	var authority_candidates: Array[String] = staffing_runtime.active_staff_ids(staffing_state, policy["authority_job"]); authority_candidates.sort()
	var concurrence_candidates: Array[String] = staffing_runtime.active_staff_ids(staffing_state, policy["concurrence_job"]); concurrence_candidates.sort()
	var authority_id: String = ""; var concurrence_id: String = ""
	for candidate_id in authority_candidates:
		if staff_agent_runtime.is_at_room(staff_agent_state,candidate_id,policy["authority_station"]): authority_id=candidate_id; break
	if authority_id.is_empty():
		for candidate_id in authority_candidates:
			if staff_agent_state.get("agents", {}).has(candidate_id): authority_id = candidate_id; break
	for candidate_id in concurrence_candidates:
		if candidate_id!=authority_id and staff_agent_runtime.is_at_room(staff_agent_state,candidate_id,policy["concurrence_station"]): concurrence_id=candidate_id; break
	if concurrence_id.is_empty():
		for candidate_id in concurrence_candidates:
			var candidate_agent: Dictionary=staff_agent_state.get("agents",{}).get(candidate_id,{})
			if candidate_id!=authority_id and candidate_agent.get("destination","")==policy["concurrence_station"] and not (candidate_agent.get("route",[]) as Array).is_empty(): concurrence_id=candidate_id; break
	if concurrence_id.is_empty():
		for candidate_id in concurrence_candidates:
			if staff_agent_state.get("agents", {}).has(candidate_id) and candidate_id != authority_id: concurrence_id = candidate_id; break
	if authority_id.is_empty() or concurrence_id.is_empty(): return {"accepted": false, "reason": "compute reactivation lacks separated active-watch participants"}
	var traveling := false
	for dispatch_spec in [{"person_id":authority_id,"station":policy["authority_station"]},{"person_id":concurrence_id,"station":policy["concurrence_station"]}]:
		if not staff_agent_runtime.is_at_room(staff_agent_state, dispatch_spec["person_id"], dispatch_spec["station"]):
			var agent: Dictionary = staff_agent_state["agents"][dispatch_spec["person_id"]]
			if (agent.get("route", []) as Array).is_empty():
				var dispatched: Dictionary = staff_agent_runtime.dispatch(operation_graph, staff_agent_state, dispatch_spec["person_id"], dispatch_spec["station"])
				if not dispatched.get("accepted", false): return dispatched
			traveling = true
	if traveling: staff_agent_runtime.tick(staff_agent_state)
	var status: String = "ready" if staff_agent_runtime.is_at_room(staff_agent_state, authority_id, policy["authority_station"]) and staff_agent_runtime.is_at_room(staff_agent_state, concurrence_id, policy["concurrence_station"]) else "traveling"
	return {"accepted": true, "status": status, "authority_person_id": authority_id, "concurrence_person_id": concurrence_id}


func reactivate_environmental_compute(finding_id: String, rationale: String, authority_person_id: String, concurrence_person_id: String) -> Dictionary:
	var authority: Dictionary = staff_agent_state.get("agents", {}).get(authority_person_id, {})
	var concurrence: Dictionary = staff_agent_state.get("agents", {}).get(concurrence_person_id, {})
	if authority.is_empty() or concurrence.is_empty(): return {"accepted": false, "reason": "compute reactivation participants not active"}
	var monitoring_normal: bool = infrastructure_state.get("service_states", {}).get("environmental_monitoring", {}).get("phase", "") == "normal"
	return environmental_observation_runtime.request_compute_reactivation(environmental_observation_state, finding_id, monitoring_normal, rationale, {"person_id":authority_person_id,"roles":[authority["job_id"]],"current_room":authority["current_room"]}, {"person_id":concurrence_person_id,"roles":[concurrence["job_id"]],"current_room":concurrence["current_room"]})


func resume_environmental_compute_reactivation(finding_id: String) -> Dictionary:
	var work: Dictionary = environmental_observation_state.get("active_compute_reactivation", {})
	if work.is_empty(): return {"accepted": false, "reason": "compute reactivation not active"}
	var locations: Dictionary = {}
	for person_id in [work["authority_person_id"], work["concurrence_person_id"]]:
		if staff_agent_state.get("agents", {}).has(person_id): locations[person_id] = staff_agent_state["agents"][person_id]["current_room"]
	return environmental_observation_runtime.resume_compute_reactivation(environmental_observation_state, finding_id, locations)


func tick_environmental_compute_reactivation() -> Dictionary:
	var work: Dictionary = environmental_observation_state.get("active_compute_reactivation", {})
	if work.is_empty(): return {"accepted": false, "reason": "compute reactivation not active"}
	var locations: Dictionary = {}
	for person_id in [work["authority_person_id"], work["concurrence_person_id"]]:
		if staff_agent_state.get("agents", {}).has(person_id): locations[person_id] = staff_agent_state["agents"][person_id]["current_room"]
	var result: Dictionary = environmental_observation_runtime.tick_compute_reactivation(environmental_observation_state, locations)
	if result.get("status", "") == "committed": operation_runtime.set_room_protective_posture(mission_state, "compute_core", "")
	return result


func request_environmental_fire_inspector(finding_id: String, responder_id: String) -> Dictionary:
	var finding: Dictionary={}; var inspection_policy: Dictionary={}
	for candidate in environmental_observation_state.get("hazard_findings",[]):
		if candidate.get("finding_id","")==finding_id: finding=candidate; break
	for rule in environmental_observation_state.get("obligation",{}).get("hazard_rules",[]):
		if rule.get("classification","")==finding.get("classification",""): inspection_policy=rule.get("remediation",{}).get("inspection",{}); break
	if finding.is_empty() or inspection_policy.is_empty(): return {"accepted":false,"reason":"fire inspection policy unavailable"}
	var response_policy: Dictionary=operation_graph.mutual_aid_policy.duplicate(true)
	response_policy["authority_job"]=inspection_policy.get("authority_job",""); response_policy["authority_station"]=inspection_policy.get("authority_station","")
	response_policy["escort_job"]=inspection_policy.get("escort_job",response_policy.get("escort_job","")); response_policy["escort_station"]=inspection_policy.get("escort_station",response_policy.get("escort_station",""))
	return mutual_aid_runtime.request(mutual_aid_state,finding_id,inspection_policy["response_job"],inspection_policy["destination"],responder_id,response_policy)

func begin_environmental_fire_inspection(finding_id: String, closure_id: String, rationale: String) -> Dictionary:
	var capacity: Dictionary=mutual_aid_runtime.active_capacity(mutual_aid_state,finding_id)
	if not capacity.get("accepted",false): return capacity
	var finding: Dictionary={}
	for candidate in environmental_observation_state.get("hazard_findings",[]):
		if candidate.get("finding_id","")==finding_id: finding=candidate; break
	var policy: Dictionary={}
	for rule in environmental_observation_state.get("obligation",{}).get("hazard_rules",[]):
		if rule.get("classification","")==finding.get("classification",""): policy=rule.get("remediation",{}).get("inspection",{}); break
	var authority: Dictionary={}; var authority_ids: Array[String]=staffing_runtime.active_staff_ids(staffing_state,policy.get("authority_job","")); authority_ids.sort()
	for authority_id in authority_ids:
		var agent: Dictionary=staff_agent_state.get("agents",{}).get(authority_id,{})
		if agent.get("current_room","")==policy.get("authority_station",""): authority={"person_id":authority_id,"roles":[agent["job_id"]],"current_room":agent["current_room"]}; break
	return environmental_observation_runtime.begin_fire_inspection(environmental_observation_state,finding_id,closure_id,capacity,authority,rationale)

func resume_environmental_fire_inspection(finding_id: String) -> Dictionary:
	return environmental_observation_runtime.resume_fire_inspection(environmental_observation_state,finding_id,mutual_aid_state.get("temporary_locations",{}))

func tick_environmental_fire_inspection(evidence: Dictionary) -> Dictionary:
	return environmental_observation_runtime.tick_fire_inspection(environmental_observation_state,mutual_aid_state.get("temporary_locations",{}),evidence)


func begin_environmental_fire_inspector_demobilization(finding_id: String) -> Dictionary:
	var inspection: Dictionary={}
	for candidate in environmental_observation_state.get("fire_inspections",[]):
		if candidate.get("finding_id","")==finding_id: inspection=candidate; break
	if inspection.is_empty(): return {"accepted":false,"reason":"completed fire inspection unavailable for demobilization"}
	var case_id: String=inspection.get("case_id",""); var c: Dictionary=mutual_aid_state.get("cases",{}).get(case_id,{})
	if c.is_empty() or c.get("phase","")!="admitted": return {"accepted":false,"reason":"admitted inspector case unavailable for demobilization"}
	var route_runtime=load("res://scripts/facility/facility_route_router.gd").new()
	var responder_route: Array=route_runtime.ordinary_room_path(generated_route_plan,c["destination"],c["staging_room"])
	var escort_route: Array=route_runtime.ordinary_room_path(generated_route_plan,c["destination"],c["escort_station"])
	if responder_route.size()<2 or escort_route.size()<2: return {"accepted":false,"reason":"inspector demobilization route unavailable"}
	var before: Dictionary=mutual_aid_state.duplicate(true)
	var revoked: Dictionary=mutual_aid_runtime.revoke(mutual_aid_state,case_id,finding_id)
	if not revoked.get("accepted",false): return revoked
	var started: Dictionary=mutual_aid_runtime.begin_demobilization(mutual_aid_state,case_id,responder_route,escort_route)
	if not started.get("accepted",false):
		mutual_aid_state=before
		return started
	_sync_mutual_aid_locations()
	return started

func resume_environmental_fire_inspector_demobilization(case_id: String, responder_id: String, escort_id: String) -> Dictionary:
	var result: Dictionary = mutual_aid_runtime.resume_demobilization(mutual_aid_state,case_id,responder_id,escort_id)
	if result.get("accepted", false):
		_sync_mutual_aid_locations()
	return result

func tick_environmental_fire_inspector_demobilization(case_id: String) -> Dictionary:
	var result: Dictionary = mutual_aid_runtime.tick_demobilization(mutual_aid_state,case_id)
	if result.get("accepted", false):
		_sync_mutual_aid_locations()
	return result

func begin_mutual_aid_escorted_travel(case_id: String, responder_route: Array, escort_route: Array, evidence: Dictionary = {}) -> Dictionary:
	var result: Dictionary = mutual_aid_runtime.begin_escorted_travel(mutual_aid_state, case_id, responder_route, escort_route, evidence)
	if result.get("accepted", false):
		_sync_mutual_aid_locations()
	return result

func tick_mutual_aid_escorted_travel(case_id: String) -> Dictionary:
	var result: Dictionary = mutual_aid_runtime.tick_escorted_travel(mutual_aid_state, case_id)
	if result.get("accepted", false):
		_sync_mutual_aid_locations()
	return result

func resume_mutual_aid_escorted_travel(case_id: String, responder_id: String, escort_id: String) -> Dictionary:
	var result: Dictionary = mutual_aid_runtime.resume_escorted_travel(mutual_aid_state, case_id, responder_id, escort_id)
	if result.get("accepted", false):
		_sync_mutual_aid_locations()
	return result

func complete_mutual_aid_escorted_travel(case_id: String, max_ticks: int = 64) -> Dictionary:
	var result: Dictionary = mutual_aid_runtime.complete_escorted_travel(mutual_aid_state, case_id, max_ticks)
	if result.get("accepted", false):
		_sync_mutual_aid_locations()
	return result

func compose_mutual_aid_escort_route_via_staging(escort_to_staging: Array, staging_to_destination: Array) -> Array:
	return mutual_aid_runtime.compose_escort_route_via_staging(escort_to_staging, staging_to_destination)

func begin_environmental_room_reentry(finding_id: String, inspection_id: String, rationale: String) -> Dictionary:
	var finding: Dictionary={}; var inspection: Dictionary={}
	for candidate in environmental_observation_state.get("hazard_findings",[]):
		if candidate.get("finding_id","")==finding_id: finding=candidate; break
	for candidate in environmental_observation_state.get("fire_inspections",[]):
		if candidate.get("inspection_id","")==inspection_id: inspection=candidate; break
	var policy: Dictionary={}
	for rule in environmental_observation_state.get("obligation",{}).get("hazard_rules",[]):
		if rule.get("classification","")==finding.get("classification",""): policy=rule.get("remediation",{}).get("inspection",{}).get("reentry",{}); break
	var ids_by_role: Dictionary={}; var routes_changed:=false
	for role_key in ["authority","concurrence"]:
		var ids: Array[String]=staffing_runtime.active_staff_ids(staffing_state,policy.get(role_key+"_job","")); ids.sort()
		var selected_id: String=""
		for person_id in ids:
			var agent: Dictionary=staff_agent_state.get("agents",{}).get(person_id,{})
			if agent.get("current_room","")==policy.get(role_key+"_station",""): selected_id=person_id; break
		if selected_id.is_empty():
			for person_id in ids:
				if staff_agent_state.get("agents",{}).has(person_id): selected_id=person_id; break
		if selected_id.is_empty(): return {"accepted":false,"reason":"room re-entry participant unavailable:"+role_key}
		ids_by_role[role_key]=selected_id
		if not staff_agent_runtime.is_at_room(staff_agent_state,selected_id,policy.get(role_key+"_station","")):
			var selected_agent: Dictionary=staff_agent_state["agents"][selected_id]
			if (selected_agent.get("route",[]) as Array).is_empty():
				var dispatched: Dictionary=staff_agent_runtime.dispatch(operation_graph,staff_agent_state,selected_id,policy.get(role_key+"_station",""))
				if not dispatched.get("accepted",false): return dispatched
			routes_changed=true
	if ids_by_role["authority"]==ids_by_role["concurrence"]: return {"accepted":false,"reason":"room re-entry participants are not separated"}
	if routes_changed:
		staff_agent_runtime.tick(staff_agent_state)
		return {"accepted":true,"status":"traveling","authority_person_id":ids_by_role["authority"],"concurrence_person_id":ids_by_role["concurrence"]}
	var authority: Dictionary=staff_agent_state["agents"][ids_by_role["authority"]]; var concurrence: Dictionary=staff_agent_state["agents"][ids_by_role["concurrence"]]
	return environmental_observation_runtime.request_room_reentry(environmental_observation_state,finding_id,inspection_id,{"person_id":ids_by_role["authority"],"roles":[authority["job_id"]],"current_room":authority["current_room"]},{"person_id":ids_by_role["concurrence"],"roles":[concurrence["job_id"]],"current_room":concurrence["current_room"]},rationale)

func resume_environmental_room_reentry(finding_id: String) -> Dictionary:
	var work: Dictionary=environmental_observation_state.get("active_room_reentry",{})
	var locations: Dictionary={}
	if not work.is_empty():
		for person_id in [work["authority_person_id"],work["concurrence_person_id"]]: locations[person_id]=staff_agent_state.get("agents",{}).get(person_id,{}).get("current_room","")
	return environmental_observation_runtime.resume_room_reentry(environmental_observation_state,finding_id,locations)

func tick_environmental_room_reentry() -> Dictionary:
	var work: Dictionary=environmental_observation_state.get("active_room_reentry",{})
	if work.is_empty(): return {"accepted":false,"reason":"no active room re-entry"}
	var locations: Dictionary={}
	for person_id in [work["authority_person_id"],work["concurrence_person_id"]]: locations[person_id]=staff_agent_state.get("agents",{}).get(person_id,{}).get("current_room","")
	var environmental_before: Dictionary=environmental_observation_state.duplicate(true); var mutual_before: Dictionary=mutual_aid_state.duplicate(true)
	var result: Dictionary=environmental_observation_runtime.tick_room_reentry(environmental_observation_state,locations)
	if result.get("status","")=="committed":
		var case_phase: String=mutual_aid_state.get("cases",{}).get(work["case_id"],{}).get("phase","")
		if case_phase=="admitted":
			var revoked: Dictionary=mutual_aid_runtime.revoke(mutual_aid_state,work["case_id"],work["finding_id"])
			if not revoked.get("accepted",false): environmental_observation_state=environmental_before; mutual_aid_state=mutual_before; return {"accepted":false,"reason":"room re-entry could not revoke inspection credential"}
		elif case_phase!="closed": environmental_observation_state=environmental_before; mutual_aid_state=mutual_before; return {"accepted":false,"reason":"room re-entry found incomplete inspector demobilization"}
		staff_agent_runtime.set_room_entry_block(staff_agent_state,work["room"],"")
		operation_runtime.set_room_protective_posture(mission_state,work["room"],work.get("post_reentry_posture",""))
	return result


func begin_environmental_primary_command_restoration(finding_id: String, rationale: String) -> Dictionary:
	if not environmental_observation_state.get("active_command_restoration",{}).is_empty(): return {"accepted":true,"status":"active"}
	var finding: Dictionary={}; var displaced_command: Dictionary={}; var policy: Dictionary={}
	for candidate in environmental_observation_state.get("hazard_findings",[]):
		if candidate.get("finding_id","")==finding_id: finding=candidate; break
	for candidate in environmental_observation_state.get("displaced_commands",[]):
		if candidate.get("finding_id","")==finding_id: displaced_command=candidate; break
	for rule in environmental_observation_state.get("obligation",{}).get("hazard_rules",[]):
		if rule.get("classification","")==finding.get("classification",""): policy=rule.get("remediation",{}).get("inspection",{}).get("reentry",{}).get("command_restoration",{}); break
	if finding.is_empty() or displaced_command.is_empty() or policy.is_empty(): return {"accepted":false,"reason":"primary command restoration policy unavailable"}
	var displaced_id: String=displaced_command.get("actor_person_id",""); var primary_id: String=""
	var primary_ids: Array[String]=staffing_runtime.active_staff_ids(staffing_state,policy.get("primary_job","")); primary_ids.sort()
	for person_id in primary_ids:
		if person_id!=displaced_id and staff_agent_runtime.is_at_room(staff_agent_state,person_id,policy.get("primary_station","")): primary_id=person_id; break
	if primary_id.is_empty():
		for person_id in primary_ids:
			var candidate_agent: Dictionary=staff_agent_state.get("agents",{}).get(person_id,{})
			if person_id!=displaced_id and not (candidate_agent.get("route",[]) as Array).is_empty(): primary_id=person_id; break
	if primary_id.is_empty():
		for person_id in primary_ids:
			if person_id==displaced_id or not staff_agent_state.get("agents",{}).has(person_id): continue
			var dispatched_primary: Dictionary=staff_agent_runtime.dispatch(operation_graph,staff_agent_state,person_id,policy.get("primary_station",""))
			if dispatched_primary.get("accepted",false): primary_id=person_id; staff_agent_runtime.tick(staff_agent_state); return {"accepted":true,"status":"traveling","displaced_actor_person_id":displaced_id,"primary_actor_person_id":primary_id}
	if displaced_id.is_empty() or primary_id.is_empty(): return {"accepted":false,"reason":"command restoration participants unavailable"}
	var traveling: bool=false
	for spec in [{"person_id":displaced_id,"station":policy["displaced_station"]},{"person_id":primary_id,"station":policy["primary_station"]}]:
		if not staff_agent_runtime.is_at_room(staff_agent_state,spec["person_id"],spec["station"]):
			var agent: Dictionary=staff_agent_state["agents"][spec["person_id"]]
			if (agent.get("route",[]) as Array).is_empty():
				var dispatched: Dictionary=staff_agent_runtime.dispatch(operation_graph,staff_agent_state,spec["person_id"],spec["station"])
				if not dispatched.get("accepted",false): return dispatched
			traveling=true
	if traveling:
		staff_agent_runtime.tick(staff_agent_state)
		return {"accepted":true,"status":"traveling","displaced_actor_person_id":displaced_id,"primary_actor_person_id":primary_id}
	var displaced_agent: Dictionary=staff_agent_state["agents"][displaced_id]; var primary_agent: Dictionary=staff_agent_state["agents"][primary_id]
	return environmental_observation_runtime.request_primary_command_restoration(environmental_observation_state,finding_id,{"person_id":displaced_id,"job":displaced_agent["job_id"],"current_room":displaced_agent["current_room"]},{"person_id":primary_id,"job":primary_agent["job_id"],"current_room":primary_agent["current_room"]},rationale)

func resume_environmental_primary_command_restoration(finding_id: String) -> Dictionary:
	var work: Dictionary=environmental_observation_state.get("active_command_restoration",{})
	if work.is_empty(): return {"accepted":false,"reason":"no active primary command restoration"}
	var locations: Dictionary={}
	for person_id in [work["displaced_actor_person_id"],work["primary_actor_person_id"]]: locations[person_id]=staff_agent_state.get("agents",{}).get(person_id,{}).get("current_room","")
	return environmental_observation_runtime.resume_primary_command_restoration(environmental_observation_state,finding_id,locations)

func tick_environmental_primary_command_restoration() -> Dictionary:
	var work: Dictionary=environmental_observation_state.get("active_command_restoration",{})
	if work.is_empty(): return {"accepted":false,"reason":"no active primary command restoration"}
	var locations: Dictionary={}
	for person_id in [work["displaced_actor_person_id"],work["primary_actor_person_id"]]: locations[person_id]=staff_agent_state.get("agents",{}).get(person_id,{}).get("current_room","")
	var result: Dictionary=environmental_observation_runtime.tick_primary_command_restoration(environmental_observation_state,locations)
	if result.get("status","")=="restored":
		for holdover_person_id in staffing_state.get("incident_holdovers",{}).keys(): _release_incident_holdover(holdover_person_id,"primary_command_restored")
	return result

func _release_incident_holdover(person_id: String, release_reason: String) -> void:
	if person_id.is_empty() or not staffing_state.get("incident_holdovers",{}).has(person_id): return
	var holdover: Dictionary=staffing_state["incident_holdovers"][person_id].duplicate(true); holdover["release_reason"]=release_reason; holdover["released_clock"]=mutual_aid_state.get("clock",0)
	staffing_state["incident_holdover_log"].append(holdover); staffing_state["incident_holdovers"].erase(person_id)
	if person_id not in staffing_runtime.active_staff_ids(staffing_state,holdover.get("job_id","")): staff_agent_state.get("agents",{}).erase(person_id)

func authorize_environmental_hazard_remediation(finding_id: String, rationale: String, actor_person_id: String) -> Dictionary:
	var agent: Dictionary=staff_agent_state.get("agents",{}).get(actor_person_id,{})
	if agent.is_empty(): return {"accepted":false,"reason":"named remediation authority not active"}
	return environmental_observation_runtime.authorize_hazard_remediation(environmental_observation_state,finding_id,rationale,{"person_id":actor_person_id,"job":agent.get("job_id",""),"current_room":agent.get("current_room","")})

func dispatch_environmental_hazard_remediation(finding_id: String) -> Dictionary:
	if not environmental_observation_state.get("active_hazard_work", {}).is_empty():
		var active_work: Dictionary = environmental_observation_state["active_hazard_work"]
		if active_work.get("finding_id", "") != finding_id: return {"accepted": false, "reason": "another environmental hazard work item is active"}
		var active_routes := false
		for dispatch_spec in [{"person_id":active_work["actor_person_id"],"station":active_work["station"]},{"person_id":active_work["verification_person_id"],"station":active_work["verification_station"]}]:
			if not staff_agent_state.get("agents", {}).has(dispatch_spec["person_id"]): return {"accepted": false, "reason": "bound hazard worker is not on active watch"}
			if not staff_agent_runtime.is_at_room(staff_agent_state, dispatch_spec["person_id"], dispatch_spec["station"]):
				var active_agent: Dictionary = staff_agent_state["agents"][dispatch_spec["person_id"]]
				if (active_agent.get("route", []) as Array).is_empty():
					var active_dispatched: Dictionary = staff_agent_runtime.dispatch(operation_graph, staff_agent_state, dispatch_spec["person_id"], dispatch_spec["station"])
					if not active_dispatched.get("accepted", false): return active_dispatched
				active_routes = true
		if active_routes: staff_agent_runtime.tick(staff_agent_state)
		if staff_agent_runtime.is_at_room(staff_agent_state, active_work["actor_person_id"], active_work["station"]) and staff_agent_runtime.is_at_room(staff_agent_state, active_work["verification_person_id"], active_work["verification_station"]): return {"accepted": true, "status": "ready", "work_id": active_work["work_id"]}
		return {"accepted": true, "status": "traveling", "work_id": active_work["work_id"]}
	var finding: Dictionary = {}
	for candidate_finding in environmental_observation_state.get("hazard_findings", []):
		if candidate_finding.get("finding_id", "") == finding_id: finding = candidate_finding; break
	if finding.is_empty() or finding.get("status", "") != "commanded": return {"accepted": false, "reason": "commanded environmental hazard not found"}
	var remediation_policy: Dictionary = {}
	for rule in environmental_observation_state.get("obligation", {}).get("hazard_rules", []):
		if rule.get("classification", "") == finding.get("classification", ""): remediation_policy = rule.get("remediation", {}); break
	if remediation_policy.is_empty(): return {"accepted": false, "reason": "hazard has no executable remediation policy"}
	if not remediation_policy.get("authorization",{}).is_empty():
		var authorized: bool=false
		for authorization in environmental_observation_state.get("remediation_authorizations",[]):
			if authorization.get("finding_id","")==finding_id: authorized=true; break
		if not authorized: return {"accepted":false,"reason":"hazard remediation lacks displaced-command authorization"}
	var technical_candidates: Array[String] = staffing_runtime.active_staff_ids(staffing_state, remediation_policy.get("actor_job", "")); technical_candidates.sort()
	var verification_candidates: Array[String] = staffing_runtime.active_staff_ids(staffing_state, remediation_policy.get("verification_job", "")); verification_candidates.sort()
	var technical_id: String = ""; var verification_id: String = ""
	for candidate_id in technical_candidates:
		if staff_agent_runtime.is_at_room(staff_agent_state,candidate_id,remediation_policy["station"]): technical_id=candidate_id; break
	if technical_id.is_empty():
		for candidate_id in technical_candidates:
			if staff_agent_state.get("agents", {}).has(candidate_id): technical_id = candidate_id; break
	for candidate_id in verification_candidates:
		if candidate_id!=technical_id and staff_agent_runtime.is_at_room(staff_agent_state,candidate_id,remediation_policy["verification_station"]): verification_id=candidate_id; break
	if verification_id.is_empty():
		for candidate_id in verification_candidates:
			if staff_agent_state.get("agents", {}).has(candidate_id) and candidate_id != technical_id: verification_id = candidate_id; break
	if technical_id.is_empty() or verification_id.is_empty(): return {"accepted": false, "reason": "hazard remediation lacks separated active-watch personnel"}
	var routes_changed := false
	for dispatch_spec in [{"person_id":technical_id,"station":remediation_policy["station"]},{"person_id":verification_id,"station":remediation_policy["verification_station"]}]:
		if not staff_agent_runtime.is_at_room(staff_agent_state, dispatch_spec["person_id"], dispatch_spec["station"]):
			var agent: Dictionary = staff_agent_state["agents"][dispatch_spec["person_id"]]
			if (agent.get("route", []) as Array).is_empty():
				var dispatched: Dictionary = staff_agent_runtime.dispatch(operation_graph, staff_agent_state, dispatch_spec["person_id"], dispatch_spec["station"])
				if not dispatched.get("accepted", false): return dispatched
			routes_changed = true
	if routes_changed: staff_agent_runtime.tick(staff_agent_state)
	if not staff_agent_runtime.is_at_room(staff_agent_state, technical_id, remediation_policy["station"]) or not staff_agent_runtime.is_at_room(staff_agent_state, verification_id, remediation_policy["verification_station"]): return {"accepted": true, "status": "traveling", "technical_person_id": technical_id, "verification_person_id": verification_id}
	var result: Dictionary = environmental_observation_runtime.request_hazard_remediation(environmental_observation_state, finding_id, {"person_id":technical_id,"roles":[staff_agent_state["agents"][technical_id]["job_id"]],"current_room":staff_agent_state["agents"][technical_id]["current_room"]}, {"person_id":verification_id,"roles":[staff_agent_state["agents"][verification_id]["job_id"]],"current_room":staff_agent_state["agents"][verification_id]["current_room"]})
	if result.get("accepted", false): result["status"] = "active"
	return result


func tick_environmental_hazard_work(readings_by_room: Dictionary) -> Dictionary:
	var work: Dictionary = environmental_observation_state.get("active_hazard_work", {})
	if work.is_empty(): return {"accepted": false, "reason": "no active environmental hazard work"}
	var locations: Dictionary = {}
	for person_id in [work.get("actor_person_id", ""), work.get("verification_person_id", "")]:
		if staff_agent_state.get("agents", {}).has(person_id): locations[person_id] = staff_agent_state["agents"][person_id].get("current_room", "")
	return environmental_observation_runtime.tick_hazard_work(environmental_observation_state, locations, readings_by_room)


func resume_environmental_hazard_work(finding_id: String) -> Dictionary:
	var work: Dictionary = environmental_observation_state.get("active_hazard_work", {})
	if work.is_empty(): return {"accepted": false, "reason": "no recovered environmental hazard work"}
	var locations: Dictionary = {}
	for person_id in [work.get("actor_person_id", ""), work.get("verification_person_id", "")]:
		if staff_agent_state.get("agents", {}).has(person_id): locations[person_id] = staff_agent_state["agents"][person_id].get("current_room", "")
	return environmental_observation_runtime.resume_hazard_work(environmental_observation_state, finding_id, locations)


func dispatch_environmental_escalation_authority(round_number: int) -> Dictionary:
	var pending: Dictionary = {}
	for escalation_event in environmental_observation_state.get("escalations", []):
		if int(escalation_event.get("round_number", 0)) == round_number and not escalation_event.get("consumed", false): pending = escalation_event; break
	if pending.is_empty(): return {"accepted": false, "reason": "pending environmental escalation not found"}
	var policy: Dictionary = environmental_observation_state.get("obligation", {}).get("escalation", {})
	var candidates: Array[String] = staffing_runtime.active_staff_ids(staffing_state, policy.get("actor_job", "")); candidates.sort()
	var actor_id: String = ""
	for candidate_id in candidates:
		if staff_agent_state.get("agents", {}).has(candidate_id): actor_id = candidate_id; break
	if actor_id.is_empty(): return {"accepted": false, "reason": "no named active command authority"}
	var station: String = policy.get("station", "")
	if not staff_agent_runtime.is_at_room(staff_agent_state, actor_id, station):
		var agent: Dictionary = staff_agent_state["agents"][actor_id]
		if (agent.get("route", []) as Array).is_empty():
			var dispatched: Dictionary = staff_agent_runtime.dispatch(operation_graph, staff_agent_state, actor_id, station)
			if not dispatched.get("accepted", false): return dispatched
		staff_agent_runtime.tick(staff_agent_state)
		return {"accepted": true, "status": "traveling", "actor_person_id": actor_id, "station": station}
	return {"accepted": true, "status": "ready", "actor_person_id": actor_id, "station": station}


func decide_environmental_escalation(round_number: int, decision: String, rationale: String, actor_person_id: String) -> Dictionary:
	var agent: Dictionary = staff_agent_state.get("agents", {}).get(actor_person_id, {})
	if agent.is_empty(): return {"accepted": false, "reason": "named command actor not active"}
	var result: Dictionary = environmental_observation_runtime.decide_escalation(environmental_observation_state, round_number, decision, rationale, {"person_id":actor_person_id,"roles":[agent.get("job_id","")],"current_room":agent.get("current_room","")})
	if result.get("accepted", false):
		for room_id in environmental_observation_state.get("protective_postures", {}): operation_runtime.set_room_protective_posture(mission_state, room_id, environmental_observation_state["protective_postures"][room_id])
	return result


func dispatch_environmental_release_authorities(room_id: String) -> Dictionary:
	if not environmental_observation_state.get("protective_postures", {}).has(room_id): return {"accepted": false, "reason": "protective posture is not active"}
	var policy: Dictionary = environmental_observation_state.get("obligation", {}).get("escalation", {}).get("release", {})
	var identities: Dictionary = {}
	var all_ready := true
	for authority_kind in ["authority", "concurrence"]:
		var job_id: String = policy.get(authority_kind + "_job", "")
		var station: String = policy.get(authority_kind + "_station", "")
		var actor_id: String = environmental_observation_state.get("active_release", {}).get(authority_kind + "_person_id", "")
		if actor_id.is_empty():
			var candidates: Array[String] = staffing_runtime.active_staff_ids(staffing_state, job_id); candidates.sort()
			for candidate_id in candidates:
				if staff_agent_state.get("agents", {}).has(candidate_id): actor_id = candidate_id; break
		if actor_id.is_empty() or not staff_agent_state.get("agents", {}).has(actor_id) or staff_agent_state["agents"][actor_id].get("job_id", "") != job_id: return {"accepted": false, "reason": "release lacks named active " + authority_kind}
		identities[authority_kind + "_person_id"] = actor_id
		if not staff_agent_runtime.is_at_room(staff_agent_state, actor_id, station):
			all_ready = false
			var agent: Dictionary = staff_agent_state["agents"][actor_id]
			if (agent.get("route", []) as Array).is_empty():
				var dispatched: Dictionary = staff_agent_runtime.dispatch(operation_graph, staff_agent_state, actor_id, station)
				if not dispatched.get("accepted", false): return dispatched
	staff_agent_runtime.tick(staff_agent_state)
	identities["accepted"] = true; identities["status"] = "ready" if all_ready else "traveling"
	return identities


func release_environmental_protective_posture(room_id: String, rationale: String, authority_person_id: String, concurrence_person_id: String) -> Dictionary:
	var authority: Dictionary = staff_agent_state.get("agents", {}).get(authority_person_id, {})
	var concurrence: Dictionary = staff_agent_state.get("agents", {}).get(concurrence_person_id, {})
	if authority.is_empty() or concurrence.is_empty(): return {"accepted": false, "reason": "release actors are not active"}
	var phase: String = infrastructure_runtime.service_phase(infrastructure_state, "environmental_monitoring")
	return environmental_observation_runtime.release_protective_posture(environmental_observation_state, room_id, rationale, phase, {"person_id":authority_person_id,"job_id":authority.get("job_id", ""),"current_room":authority.get("current_room", "")}, {"person_id":concurrence_person_id,"job_id":concurrence.get("job_id", ""),"current_room":concurrence.get("current_room", "")})


func tick_environmental_protective_release() -> Dictionary:
	var actor_locations: Dictionary = {}
	for staff_id in staff_agent_state.get("agents", {}): actor_locations[staff_id] = staff_agent_state["agents"][staff_id]["current_room"]
	var result: Dictionary = environmental_observation_runtime.tick_protective_release(environmental_observation_state, actor_locations)
	if result.get("status", "") == "committed": operation_runtime.set_room_protective_posture(mission_state, result["room"], "")
	return result


func resume_environmental_protective_release(room_id: String) -> Dictionary:
	var actor_locations: Dictionary = {}
	for staff_id in staff_agent_state.get("agents", {}): actor_locations[staff_id] = staff_agent_state["agents"][staff_id]["current_room"]
	return environmental_observation_runtime.resume_protective_release(environmental_observation_state, room_id, actor_locations)


func resume_environmental_observation_round(occurrence_id: String) -> Dictionary:
	var actor_locations: Dictionary = {}
	for staff_id in staff_agent_state.get("agents", {}): actor_locations[staff_id] = staff_agent_state["agents"][staff_id]["current_room"]
	return environmental_observation_runtime.resume(environmental_observation_state, occurrence_id, actor_locations)


func environmental_observation_restoration_gate(occurrence_id: String) -> Dictionary:
	if not environmental_observation_state.get("active", false) or occurrence_id != environmental_observation_state.get("occurrence_id", ""):
		return {"accepted": false, "reason": "manual observation occurrence mismatch"}
	if not environmental_observation_runtime.validate_state(environmental_observation_state, operation_graph.service_continuity_profiles["environmental_monitoring"]["degraded_obligations"][0]).is_empty():
		return {"accepted": false, "reason": "manual observation authority invalid"}
	for hazard_finding in environmental_observation_state.get("hazard_findings", []):
		if hazard_finding.get("status", "") != "closed": return {"accepted": false, "reason": "unresolved environmental hazard:" + String(hazard_finding.get("classification", ""))}
	if not environmental_observation_state.get("active_round", {}).is_empty() or environmental_observation_state.get("completed_rounds", []).is_empty():
		return {"accepted": false, "reason": "manual observation round incomplete"}
	return {"accepted": true, "occurrence_id": occurrence_id, "completed_rounds": environmental_observation_state["completed_rounds"].size()}


func activate_procedure_panel(panel_id: String, interactor: Node) -> Dictionary:
	if not procedure_panel_definitions.has(panel_id):
		return {"accepted": false, "reason": "unknown procedure panel"}
	if interactor != player or personnel_state.is_empty():
		return {"accepted": false, "reason": "panel interaction has no authoritative personnel identity"}
	var definition: Dictionary = procedure_panel_definitions[panel_id]
	if personnel_state.get("current_room", "") != definition["station"]:
		return {"accepted": false, "reason": "operator is not physically present at procedure station"}
	if not (personnel_state.get("roles", []) as Array).has(definition["actor_job"]):
		return {"accepted": false, "reason": "operator lacks panel role %s" % definition["actor_job"]}
	return _request_procedure_work(definition, personnel_state["person_id"])


func compile_custody_response_plan() -> Dictionary:
	_refresh_procedure_panels()
	var phase := _custody_procedure_phase()
	var panel_id := ""
	if phase == "archive_fire_water":
		panel_id = "custody:contain_incident"
	elif phase == "disposition_pending":
		panel_id = "custody:record_quarantine_disposition"
	if panel_id.is_empty() or not procedure_panel_definitions.has(panel_id):
		return {"queue": [], "recommended": {}}
	var definition: Dictionary = procedure_panel_definitions[panel_id]
	var available := false
	for panel in procedure_panels.get_children():
		if panel.get_meta("panel_id", "") == panel_id:
			available = bool(panel.get_meta("available", false))
			break
	var candidate := {
		"kind": "custody",
		"custody_identity": custody_state.get("custody_identity", ""),
		"phase": phase,
		"action": definition["action"],
		"panel_id": panel_id,
		"station": definition["station"],
		"actor_job": definition["actor_job"],
		"available": available,
	}
	return {"queue": [candidate], "recommended": candidate if available else {}}


func _operations_queue_candidates() -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var selected_failures: Dictionary = {}
	for candidate in compile_degraded_response_plan()["queue"]:
		var failure_id: String = candidate["failure_id"]
		if not selected_failures.has(failure_id) or (not bool(selected_failures[failure_id]["available"]) and bool(candidate["available"])):
			selected_failures[failure_id] = candidate
	for failure_id in selected_failures:
		var candidate: Dictionary = selected_failures[failure_id]
		var service_id: String = candidate["service"]
		var policy: Dictionary = operation_graph.operations_response_policies[service_id]
		candidates.append({
			"entry_id": "infrastructure:%s:%s" % [failure_id, candidate["action"]],
			"panel_id": candidate["panel_id"], "domain": "infrastructure", "action": candidate["action"],
			"actor_job": candidate["actor_job"], "station": candidate["station"], "base_priority": policy["priority"], "deadline_ticks": policy["deadline_ticks"],
			"retry_backoff_ticks": policy["retry_backoff_ticks"], "max_wait_ticks": policy["max_wait_ticks"], "abandonment_action": policy["abandonment_action"], "relief_failure_action": policy["relief_failure_action"], "reactivation_authority_job": policy["reactivation_authority_job"], "reactivation_station": policy["reactivation_station"],
		})
	var custody_plan: Dictionary = compile_custody_response_plan()
	if not custody_plan["queue"].is_empty():
		var custody_candidate: Dictionary = custody_plan["queue"][0]
		var history_sequence := 0
		for event in custody_state.get("history", []):
			if event.get("event", "") == "incident_declared":
				history_sequence = int(event.get("sequence", 0))
		var custody_policy: Dictionary = operation_graph.operations_response_policies["custody:%s" % custody_candidate["action"]]
		candidates.append({
			"entry_id": "custody:%s:%d:%s" % [custody_state.get("custody_identity", ""), history_sequence, custody_candidate["action"]],
			"panel_id": custody_candidate["panel_id"], "domain": "custody", "action": custody_candidate["action"],
			"actor_job": custody_candidate["actor_job"], "station": custody_candidate["station"], "base_priority": custody_policy["priority"],
			"deadline_ticks": custody_policy["deadline_ticks"], "retry_backoff_ticks": custody_policy["retry_backoff_ticks"], "max_wait_ticks": custody_policy["max_wait_ticks"], "abandonment_action": custody_policy["abandonment_action"],
		})
	return candidates


func autonomous_operations_tick(dispatch_work: bool = true) -> Dictionary:
	var arbitration: Dictionary = operations_queue_runtime.advance(operations_queue_state, _operations_queue_candidates())
	var continuity_actions: Array[Dictionary] = []
	for abandoned in arbitration.get("abandoned", []):
		var evidence: Dictionary = {}
		var accepted := false
		if abandoned["abandonment_action"] == "mobilize_qualified_relief":
			evidence = staffing_runtime.mobilize_qualified_relief(operation_graph, staffing_state, abandoned["actor_job"])
			accepted = evidence.get("accepted", false)
			staffing_runtime.apply_mission_availability(operation_graph, staffing_state, operation_runtime, mission_state)
			var rebuilt: Dictionary = staff_agent_runtime.build_active_watch(operation_graph, staffing_state, staffing_runtime)
			var protected_work_actors: Dictionary = {}
			for task in procedure_work_state.get("tasks", {}).values():
				if task.get("status", "") not in ["completed", "failed", "superseded"]:
					protected_work_actors[task.get("actor_person_id", "")] = true
			for existing_id in staff_agent_state["agents"].keys():
				if not rebuilt["agents"].has(existing_id) and not protected_work_actors.has(existing_id):
					staff_agent_state["agents"].erase(existing_id)
			if accepted:
				for staff_id in evidence.get("mobilized_staff", []):
					if rebuilt["agents"].has(staff_id):
						staff_agent_state["agents"][staff_id] = rebuilt["agents"][staff_id]
		else:
			accepted = true
			evidence = {"mode": "mission_safe_hold", "custody_identity": custody_state.get("custody_identity", ""), "incident": custody_state.get("incident", "")}
		var decision: Dictionary = operations_queue_runtime.record_continuity_decision(operations_queue_state, abandoned["entry_id"], accepted, evidence)
		if decision.get("status", "") == "mission_shutdown":
			if not mission_state.has("continuity_shutdowns"):
				mission_state["continuity_shutdowns"] = []
			mission_state["continuity_shutdowns"].append({
				"entry_id": abandoned["entry_id"], "domain": abandoned["domain"],
				"action": abandoned["action"], "clock": operations_queue_state["clock"],
				"reason": "qualified_relief_unavailable",
			})
			mission_state["status"] = "blocked"
		continuity_actions.append(decision)
	var selected: Dictionary = arbitration.get("selected", {})
	var dispatch: Dictionary = {}
	if dispatch_work and not selected.is_empty():
		var definition: Dictionary = procedure_panel_definitions.get(selected["panel_id"], {})
		if not definition.is_empty():
			dispatch = _request_procedure_work(definition, "autonomous-operations-controller")
			if dispatch.get("accepted", false):
				var bound: Dictionary = operations_queue_runtime.record_dispatch(operations_queue_state, selected["entry_id"], dispatch["task_id"], dispatch.get("actor_person_id", ""), definition["station"])
				if not bound.get("accepted", false):
					dispatch = bound
			else:
				var reason: String = dispatch.get("reason", "dispatch rejected")
				var retryable: bool = reason.contains("no named") or reason.contains("already has active") or reason.contains("unavailable") or reason.contains("required_service")
				operations_queue_runtime.record_dispatch_failure(operations_queue_state, selected["entry_id"], reason, retryable)
	_refresh_procedure_panels()
	_refresh_control_status_board()
	return {"accepted": true, "clock": operations_queue_state["clock"], "queue": arbitration["queue"], "selected": selected, "dispatch": dispatch, "continuity_actions": continuity_actions}


func authorize_mission_reactivation(entry_id: String) -> Dictionary:
	if not operations_queue_state["entries"].has(entry_id): return {"accepted": false, "reason": "shutdown occurrence is unknown"}
	var entry: Dictionary = operations_queue_state["entries"][entry_id]
	if not staffing_runtime.is_job_covered(staffing_state, entry.get("actor_job", "")):
		return {"accepted": false, "reason": "response capacity remains uncovered"}
	var actor: Dictionary = _named_panel_actor(entry.get("reactivation_authority_job", ""), entry.get("reactivation_station", ""))
	if actor.is_empty(): return {"accepted": false, "reason": "named reactivation authority is not physically present"}
	var result: Dictionary = operations_queue_runtime.authorize_reactivation(operations_queue_state, entry_id, actor["person_id"], entry["reactivation_authority_job"], entry["reactivation_station"])
	if not result.get("accepted", false): return result
	var retained: Array = []
	for shutdown in mission_state.get("continuity_shutdowns", []):
		if shutdown.get("entry_id", "") != entry_id: retained.append(shutdown)
	mission_state["continuity_shutdowns"] = retained
	_refresh_procedure_panels()
	_refresh_control_status_board()
	return result


func compile_degraded_response_plan() -> Dictionary:
	var queue: Array[Dictionary] = []
	for service_id in infrastructure_state.get("active_failures", {}):
		var failure: Dictionary = infrastructure_state["active_failures"][service_id]
		var profile: Dictionary = operation_graph.service_continuity_profiles[service_id]
		var phase: String = infrastructure_runtime.service_phase(infrastructure_state, service_id)
		var action: String = ""
		var panel_ids: Array[String] = []
		for transition in profile["transitions"]:
			if transition["from"] != phase:
				continue
			action = transition["action"]
			panel_ids.append("%s:%s" % [service_id, action])
			for alternate in transition.get("alternate_controls", []):
				panel_ids.append("%s:%s@%s" % [service_id, action, alternate["station"]])
			break
		if action.is_empty():
			match phase:
				"repair_pending":
					action = "record_repair" if procedure_receipts.has(service_id) else "begin_repair"
				"testing":
					action = "functional_test"
				"reconstitution_pending":
					action = "verify_reconstitution"
				_:
					continue
			panel_ids.append("%s:%s" % [service_id, action])
			if action == "verify_reconstitution":
				for control in profile.get("verification_controls", []):
					panel_ids.append("%s:%s@%s" % [service_id, action, control["station"]])
		for panel_id in panel_ids:
			var definition: Dictionary = procedure_panel_definitions.get(panel_id, {})
			if definition.is_empty():
				continue
			var panel: Node = null
			for candidate_panel in procedure_panels.get_children():
				if candidate_panel.get_meta("panel_id", "") == panel_id:
					panel = candidate_panel
					break
			queue.append({
				"failure_id": failure["failure_id"],
				"failure_order": int(String(failure["failure_id"]).get_slice("-", 2)),
				"service": service_id,
				"phase": phase,
				"action": action,
				"panel_id": panel_id,
				"station": definition["station"],
				"actor_job": definition["actor_job"],
				"control_mode": definition["control_mode"],
				"available": panel != null and bool(panel.get_meta("available", false)),
			})
	queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["failure_order"] != b["failure_order"]:
			return a["failure_order"] < b["failure_order"]
		var a_rank: int = 0 if a["control_mode"] == "primary_control" else 1
		var b_rank: int = 0 if b["control_mode"] == "primary_control" else 1
		return a_rank < b_rank
	)
	var recommended: Dictionary = {}
	for candidate in queue:
		if candidate["available"]:
			recommended = candidate.duplicate(true)
			break
	return {"queue": queue, "recommended": recommended}


func _procedure_condition_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for room_id in operation_graph.rooms:
		var room_services: Dictionary = {}
		for service_id in operation_graph.rooms[room_id].get("critical_requirements", []):
			room_services[service_id] = infrastructure_runtime.room_has_service(infrastructure_state, room_id, service_id)
		snapshot[room_id] = room_services
	return snapshot


func _request_procedure_work(definition: Dictionary, initiator_id: String) -> Dictionary:
	var service_id: String = definition["service"]
	var action: String = definition["action"]
	if service_id == "custody":
		if _custody_procedure_phase() != definition["required_phase"]:
			return {"accepted": false, "reason": "custody control is unavailable in current phase"}
	else:
		if not infrastructure_state["active_failures"].has(service_id):
			return {"accepted": false, "reason": "service has no active failure"}
		if infrastructure_runtime.service_phase(infrastructure_state, service_id) != definition["required_phase"]:
			return {"accepted": false, "reason": "panel is unavailable in current service phase"}
	if action == "begin_repair" and procedure_receipts.has(service_id):
		return {"accepted": false, "reason": "repair already has a procedure receipt"}
	if action in ["record_repair", "functional_test", "verify_reconstitution"] and not procedure_receipts.has(service_id):
		return {"accepted": false, "reason": "panel action has no procedure receipt"}
	for active_task_id in procedure_work_state.get("active_panel_tasks", {}).values():
		var active_task: Dictionary = procedure_work_state["tasks"][active_task_id]
		if active_task["service"] != service_id or active_task["action"] != action:
			continue
		var declared_fallback: bool = String(definition.get("control_mode", "primary_control")) != "primary_control"
		var replaces_blocked_primary: bool = declared_fallback and active_task["status"] == "interrupted" and active_task.get("control_mode", "primary_control") == "primary_control"
		if not replaces_blocked_primary:
			return {"accepted": false, "reason": "equivalent procedure action already has active work"}
	var conditions: Dictionary = procedure_work_runtime.task_conditions(operation_graph, definition, _procedure_condition_snapshot())
	if not conditions.get("available", false):
		return {"accepted": false, "reason": conditions["reason"]}
	var result: Dictionary = procedure_work_runtime.request_work(
		operation_graph, procedure_work_state, definition, initiator_id,
		staffing_state, staffing_runtime, staff_agent_state, staff_agent_runtime
	)
	_create_staffing_markers()
	_refresh_procedure_panels()
	return result


func tick_procedure_work() -> Dictionary:
	var condition_result: Dictionary = procedure_work_runtime.reconcile_conditions(
		operation_graph, procedure_work_state, _procedure_condition_snapshot(), staff_agent_state, staff_agent_runtime
	)
	var tick_result: Dictionary = procedure_work_runtime.tick(procedure_work_state, staff_agent_state, staff_agent_runtime)
	var external_task_ids: Array = procedure_work_state["tasks"].keys(); external_task_ids.sort()
	for external_task_id in external_task_ids:
		var external_task: Dictionary = procedure_work_state["tasks"][external_task_id]
		if external_task.get("control_mode", "") != "temporary_mutual_aid" or external_task.get("status", "") != "working": continue
		var external_conditions: Dictionary = procedure_work_runtime.task_conditions(operation_graph, external_task, _procedure_condition_snapshot())
		if not external_conditions.get("available", false): continue
		var external_tick: Dictionary = procedure_work_runtime.tick_external_work(procedure_work_state, external_task_id, mutual_aid_runtime, mutual_aid_state)
		if external_tick.get("completed", false): tick_result["completions"].append(external_tick["receipt"])
	var commits: Array[Dictionary] = []
	var failures: Array[Dictionary] = []
	for completion in tick_result["completions"]:
		var definition: Dictionary = procedure_panel_definitions.get(completion["panel_id"], {})
		var pending_task: Dictionary = procedure_work_state["tasks"].get(completion["task_id"], {})
		if pending_task.get("action", "") == "control_network_functional_test":
			var test_commit: Dictionary = record_control_network_functional_test(completion["initiator"], completion["actor_person_id"])
			if test_commit.get("accepted", false):
				procedure_work_runtime.consume_completion(procedure_work_state, completion)
				commits.append({"accepted":true,"action":"control_network_functional_test","work_receipt_id":completion["receipt_id"],"actor_person_id":completion["actor_person_id"]})
			else: failures.append({"receipt":completion,"result":test_commit})
			continue
		if pending_task.get("action", "") == "control_network_reconstitute":
			var reconstitution_commit: Dictionary = reconstitute_control_network(completion["initiator"], completion["actor_person_id"])
			if reconstitution_commit.get("accepted", false):
				procedure_work_runtime.consume_completion(procedure_work_state, completion)
				commits.append({"accepted":true,"action":"control_network_reconstitute","work_receipt_id":completion["receipt_id"],"actor_person_id":completion["actor_person_id"]})
			else: failures.append({"receipt":completion,"result":reconstitution_commit})
			continue
		var temporary_authority: Dictionary = {}
		var external_scene_before: Dictionary = {}
		if pending_task.get("control_mode", "") == "temporary_mutual_aid":
			external_scene_before = {"infrastructure":infrastructure_state.duplicate(true),"mission":mission_state.duplicate(true),"work":procedure_work_state.duplicate(true),"queue":operations_queue_state.duplicate(true),"mutual":mutual_aid_state.duplicate(true),"receipts":procedure_receipts.duplicate(true),"panel_log":procedure_panel_log.duplicate(true)}
			var case: Dictionary = mutual_aid_state["cases"].get(pending_task.get("mutual_aid_case_id", ""), {})
			temporary_authority = {"mode":"incident_scoped_temporary","failure_id":infrastructure_state["active_failures"].get(pending_task["service"],{}).get("failure_id",""),"action":pending_task["action"],"person_id":pending_task["actor_person_id"],"actor_job":pending_task["actor_job"],"station":pending_task["station"],"credential_id":case.get("credential_id","")}
		var committed: Dictionary = _execute_procedure_panel(definition, completion["initiator"], completion["actor_person_id"], temporary_authority)
		if committed.get("accepted", false):
			var supersession: Dictionary = procedure_work_runtime.supersede_conflicting_work(
				procedure_work_state, completion["task_id"], staff_agent_state, staff_agent_runtime
			)
			var completed_task: Dictionary = procedure_work_state["tasks"][completion["task_id"]]
			if completed_task.get("control_mode", "") == "temporary_mutual_aid":
				var external_entry_id := ""
				for reserved_entry in mutual_aid_state["capacity_reservations"]:
					if mutual_aid_state["capacity_reservations"][reserved_entry]["task_id"] == completion["task_id"]: external_entry_id = reserved_entry; break
				var semantic_evidence := {"accepted": true, "task_id": completion["task_id"], "receipt_id": completion["receipt_id"], "panel_id": completion["panel_id"], "actor_person_id": completion["actor_person_id"], "occurrence_id": completed_task["occurrence_id"], "service": completed_task["service"], "action": completed_task["action"], "station": completed_task["station"], "source_commit": committed.duplicate(true)}
				var external_finalized: Dictionary = operations_queue_runtime.finalize_external_semantic_commit(operations_queue_state, procedure_work_runtime, procedure_work_state, mutual_aid_runtime, mutual_aid_state, external_entry_id, completion, semantic_evidence)
				if not external_finalized.get("accepted", false):
					infrastructure_state.clear(); infrastructure_state.merge(external_scene_before["infrastructure"],true); mission_state.clear(); mission_state.merge(external_scene_before["mission"],true); procedure_work_state.clear(); procedure_work_state.merge(external_scene_before["work"],true); operations_queue_state.clear(); operations_queue_state.merge(external_scene_before["queue"],true); mutual_aid_state.clear(); mutual_aid_state.merge(external_scene_before["mutual"],true); procedure_receipts = external_scene_before["receipts"]; procedure_panel_log = external_scene_before["panel_log"]
					failures.append(external_finalized); continue
			else:
				procedure_work_runtime.consume_completion(procedure_work_state, completion)
				operations_queue_runtime.record_task_outcome(operations_queue_state, completion["task_id"], "committed", "")
			committed["superseded_task_ids"] = supersession.get("superseded", [])
			committed["work_receipt_id"] = completion["receipt_id"]
			commits.append(committed)
		else:
			failures.append({"receipt": completion, "result": committed})
			operations_queue_runtime.record_task_outcome(operations_queue_state, completion["task_id"], "failed", committed.get("reason", "semantic commit rejected"))
	_create_staffing_markers()
	_refresh_procedure_panels()
	_refresh_control_status_board()
	return {"movement": tick_result["movement"], "suspended": condition_result["suspended"], "completions": tick_result["completions"], "commits": commits, "failures": failures}


func interrupt_procedure_work(task_id: String, reason: String) -> Dictionary:
	var result: Dictionary = procedure_work_runtime.interrupt(
		procedure_work_state, task_id, reason, staff_agent_state, staff_agent_runtime
	)
	_create_staffing_markers()
	_refresh_procedure_panels()
	return result


func resume_procedure_work(task_id: String) -> Dictionary:
	if not procedure_work_state["tasks"].has(task_id):
		return {"accepted": false, "reason": "procedure task does not exist"}
	var conditions: Dictionary = procedure_work_runtime.task_conditions(
		operation_graph, procedure_work_state["tasks"][task_id], _procedure_condition_snapshot()
	)
	if not conditions.get("available", false):
		return {"accepted": false, "reason": conditions["reason"]}
	var result: Dictionary = procedure_work_runtime.resume(
		procedure_work_state, task_id, staff_agent_state, staff_agent_runtime
	)
	_create_staffing_markers()
	_refresh_procedure_panels()
	return result


func _execute_procedure_panel(definition: Dictionary, initiator_id: String, bound_actor_id: String = "", temporary_authority: Dictionary = {}) -> Dictionary:
	var service_id: String = definition["service"]
	var action: String = definition["action"]
	if service_id == "custody":
		if _custody_procedure_phase() != definition["required_phase"]:
			return {"accepted": false, "reason": "custody control is unavailable in current phase"}
	else:
		if not infrastructure_state["active_failures"].has(service_id):
			return {"accepted": false, "reason": "service has no active failure"}
		if infrastructure_runtime.service_phase(infrastructure_state, service_id) != definition["required_phase"]:
			return {"accepted": false, "reason": "panel is unavailable in current service phase"}
	var actor_job: String = definition["actor_job"]
	var preferred_actor := bound_actor_id
	if preferred_actor.is_empty() and procedure_receipts.has(service_id):
		preferred_actor = procedure_receipts[service_id].get("actor_person_id", "")
	var actor: Dictionary = {}
	if not temporary_authority.is_empty():
		actor = {"person_id":temporary_authority.get("person_id",""),"roles":[temporary_authority.get("actor_job","")],"current_room":temporary_authority.get("station","")}
	else:
		actor = _named_panel_actor(actor_job, definition["station"], preferred_actor)
	if actor.is_empty() or actor.get("person_id", "").is_empty():
		return {"accepted": false, "reason": "panel has no named on-duty operator"}
	var result: Dictionary
	if action == "contain_incident":
		result = custody_runtime.resolve_incident(operation_graph, custody_state, {"roles": [actor_job]})
	elif action == "record_quarantine_disposition":
		result = custody_runtime.clear_quarantine(custody_state, {"roles": [actor_job]})
	elif _is_failure_transition_action(service_id,action):
		result = infrastructure_runtime.advance_failure_response(
			operation_graph, infrastructure_state, infrastructure_state["active_failures"][service_id]["failure_id"],
			action, actor, staffing_state, staffing_runtime, temporary_authority
		)
	elif action == "begin_repair":
		var failure: Dictionary = infrastructure_state["active_failures"][service_id]
		result = infrastructure_runtime.begin_recovery(
			operation_graph, infrastructure_state, failure["procedure"], failure["failure_id"], actor, staffing_state, staffing_runtime
		)
		if result.get("accepted", false):
			procedure_receipts[service_id] = result.duplicate(true)
	elif action == "record_repair":
		if not procedure_receipts.has(service_id):
			return {"accepted": false, "reason": "repair has no procedure receipt"}
		result = infrastructure_runtime.record_remediation(
			infrastructure_state, procedure_receipts[service_id], actor,
			{"action": "repair_completed", "service": service_id, "station": definition["station"]}
		)
	elif action == "functional_test":
		if not procedure_receipts.has(service_id):
			return {"accepted": false, "reason": "test has no procedure receipt"}
		result = infrastructure_runtime.record_service_test(
			infrastructure_state, procedure_receipts[service_id], actor,
			{"action": "functional_test_passed", "service": service_id, "station": definition["station"]}
		)
	elif action == "verify_reconstitution":
		if not procedure_receipts.has(service_id):
			return {"accepted": false, "reason": "verification has no procedure receipt"}
		var observation_failure_id := ""
		if service_id == "environmental_monitoring":
			observation_failure_id = infrastructure_state.get("active_failures", {}).get(service_id, {}).get("failure_id", "")
			var observation_gate: Dictionary = environmental_observation_restoration_gate(observation_failure_id)
			if not observation_gate.get("accepted", false): return observation_gate
		var infrastructure_before_verification: Dictionary = infrastructure_state.duplicate(true)
		result = infrastructure_runtime.verify_and_restore(
			operation_graph, infrastructure_state, procedure_receipts[service_id], actor, staffing_state, staffing_runtime
		)
		if result.get("accepted", false) and service_id == "environmental_monitoring":
			var observation_close: Dictionary = environmental_observation_runtime.close(environmental_observation_state, observation_failure_id)
			if not observation_close.get("accepted", false):
				infrastructure_state = infrastructure_before_verification
				result = observation_close
		if result.get("accepted", false):
			procedure_receipts.erase(service_id)
			infrastructure_runtime.apply_mission_snapshot(operation_graph, infrastructure_state, operation_runtime, mission_state)
	else:
		return {"accepted": false, "reason": "panel action is not implemented"}
	if result.get("accepted", false):
		if service_id != "custody":
			infrastructure_runtime.apply_mission_snapshot(operation_graph, infrastructure_state, operation_runtime, mission_state)
		else:
			_sync_custody_marker()
		result["actor_person_id"] = actor["person_id"]
		procedure_panel_log.append({
			"panel_id": definition["panel_id"],
			"service": service_id,
			"action": action,
			"station": definition["station"],
			"initiator": initiator_id,
			"actor_person_id": actor["person_id"],
			"phase": _custody_procedure_phase() if service_id == "custody" else infrastructure_runtime.service_phase(infrastructure_state, service_id),
		})
	_refresh_procedure_panels()
	_apply_service_snapshot()
	_refresh_control_status_board()
	return result


func dispatch_staff_agent(staff_id: String, destination: String) -> Dictionary:
	var result: Dictionary = staff_agent_runtime.dispatch(operation_graph, staff_agent_state, staff_id, destination)
	_reconcile_physical_staff()
	_create_staffing_markers()
	_refresh_procedure_panels()
	return result


func tick_staff_agents() -> Dictionary:
	var result: Dictionary = staff_agent_runtime.tick(staff_agent_state)
	_reconcile_physical_staff()
	_create_staffing_markers()
	_refresh_procedure_panels()
	return result


func _named_panel_actor(job_id: String, station: String, preferred_id: String = "") -> Dictionary:
	var staff_ids: Array[String] = staffing_runtime.active_staff_ids(staffing_state, job_id)
	if staff_ids.has(preferred_id):
		staff_ids.erase(preferred_id)
		staff_ids.push_front(preferred_id)
	for staff_id in staff_ids:
		if staff_agent_runtime.is_at_room(staff_agent_state, staff_id, station):
			return {
				"person_id": staff_id,
				"roles": [job_id],
				"current_room": staff_agent_state["agents"][staff_id]["current_room"],
			}
	return {}


func execute_service_recovery(service_kind: String) -> Dictionary:
	if not infrastructure_state["active_failures"].has(service_kind):
		return {"accepted": false, "reason": "service has no active failure"}
	var failure: Dictionary = infrastructure_state["active_failures"][service_kind]
	var owner_job: String = operation_graph.failure_procedures[failure["procedure"]]["owner_job"]
	if not staffing_runtime.is_job_covered(staffing_state, owner_job):
		var mobilization: Dictionary = staffing_runtime.mobilize_on_call(operation_graph, staffing_state, owner_job)
		if not mobilization.get("accepted", false):
			return mobilization
		_release_all_physical_staff(staff_agent_state)
		staff_agent_state = staff_agent_runtime.build_active_watch(operation_graph, staffing_state, staffing_runtime)
	var actions: Array[String] = []
	for transition in operation_graph.service_continuity_profiles[service_kind]["transitions"]:
		actions.append(transition["action"])
	actions.append_array(["begin_repair", "record_repair", "functional_test", "verify_reconstitution"])
	var result: Dictionary = {"accepted": false, "reason": "recovery has no panel actions"}
	for action in actions:
		var panel_id := "%s:%s" % [service_kind, action]
		if not procedure_panel_definitions.has(panel_id):
			return {"accepted": false, "reason": "generated recovery panel is missing: %s" % panel_id}
		var definition: Dictionary = procedure_panel_definitions[panel_id]
		if infrastructure_runtime.service_phase(infrastructure_state, service_kind) != definition["required_phase"]:
			continue
		var requested: Dictionary = _request_procedure_work(definition, "scheduled_watch")
		if not requested.get("accepted", false):
			return requested
		var committed := false
		for _tick in 64:
			var work_tick: Dictionary = tick_procedure_work()
			if not (work_tick["failures"] as Array).is_empty():
				return work_tick["failures"][0]["result"]
			if not (work_tick["commits"] as Array).is_empty():
				result = work_tick["commits"][0]
				committed = true
				break
		if not committed:
			return {"accepted": false, "reason": "procedure work did not complete within bounded scheduler ticks"}
	_create_staffing_markers()
	return result


func _response_plan_signature() -> Dictionary:
	var plan: Dictionary = compile_degraded_response_plan()
	var queue: Array[Dictionary] = []
	for candidate in plan.get("queue", []):
		queue.append({
			"failure_id": candidate["failure_id"],
			"service": candidate["service"],
			"phase": candidate["phase"],
			"action": candidate["action"],
			"panel_id": candidate["panel_id"],
			"station": candidate["station"],
			"actor_job": candidate["actor_job"],
			"control_mode": candidate["control_mode"],
			"available": candidate["available"],
		})
	var recommended: Dictionary = plan.get("recommended", {})
	return {
		"queue": queue,
		"recommended_panel_id": recommended.get("panel_id", ""),
	}


func _variants_semantically_equal(left: Variant, right: Variant) -> bool:
	if (left is int or left is float) and (right is int or right is float):
		return float(left) == float(right)
	if left is Dictionary and right is Dictionary:
		if left.size() != right.size():
			return false
		for key in left:
			if not right.has(key) or not _variants_semantically_equal(left[key], right[key]):
				return false
		return true
	if left is Array and right is Array:
		if left.size() != right.size():
			return false
		for index in left.size():
			if not _variants_semantically_equal(left[index], right[index]):
				return false
		return true
	return left == right


func _register_control_network_procedure_definitions() -> void:
	procedure_panel_definitions["control-network:functional-test"] = {"panel_id":"control-network:functional-test","service":"communications","action":"control_network_functional_test","station":"security_control","actor_job":"cyber_analyst","duration_ticks":2,"required_services":["power"],"control_mode":"hardwired_local","equipment":""}
	procedure_panel_definitions["control-network:reconstitute"] = {"panel_id":"control-network:reconstitute","service":"communications","action":"control_network_reconstitute","station":"security_control","actor_job":"duty_officer","duration_ticks":2,"required_services":["power"],"control_mode":"hardwired_local","equipment":""}


func start_control_network_functional_test(occurrence_id: String, actor_id: String) -> Dictionary:
	if not _control_actor_at(actor_id, "cyber_analyst", "security_control"):
		return {"accepted": false, "reason": "functional test requires named cyber analyst at security control"}
	if control_network_state.get("posture", "") != "isolated" or control_network_state.get("active_incident", {}).get("occurrence_id", "") != occurrence_id or not control_network_state.get("functional_test", {}).is_empty():
		return {"accepted": false, "reason": "control-network occurrence is not awaiting functional test"}
	var definition: Dictionary = procedure_panel_definitions["control-network:functional-test"]
	var work_before: Dictionary = procedure_work_state.duplicate(true)
	var agents_before: Dictionary = staff_agent_state.duplicate(true)
	var result: Dictionary = procedure_work_runtime.request_work(operation_graph, procedure_work_state, definition, occurrence_id, staffing_state, staffing_runtime, staff_agent_state, staff_agent_runtime)
	if result.get("accepted", false) and result.get("actor_person_id", "") != actor_id:
		procedure_work_state = work_before
		staff_agent_state = agents_before
		return {"accepted": false, "reason": "functional-test scheduler selected wrong named actor"}
	return result


func record_control_network_functional_test(occurrence_id: String, actor_id: String) -> Dictionary:
	if not _control_actor_at(actor_id, "cyber_analyst", "security_control"):
		return {"accepted": false, "reason": "functional test requires named cyber analyst at security control"}
	var result: Dictionary = control_network_runtime.record_functional_test(control_network_state, occurrence_id, actor_id, true)
	if result.get("accepted", false): _refresh_control_status_board()
	return result


func start_control_network_reconstitution(occurrence_id: String, actor_id: String) -> Dictionary:
	if not _control_actor_at(actor_id, "duty_officer", "security_control"):
		return {"accepted": false, "reason": "reconstitution requires named duty officer at security control"}
	var test: Dictionary = control_network_state.get("functional_test", {})
	if control_network_state.get("posture", "") != "isolated" or control_network_state.get("active_incident", {}).get("occurrence_id", "") != occurrence_id or test.get("occurrence_id", "") != occurrence_id or not test.get("passed", false) or actor_id == test.get("actor_id", ""):
		return {"accepted": false, "reason": "control network is not eligible for separated reconstitution"}
	var definition: Dictionary = procedure_panel_definitions["control-network:reconstitute"]
	var work_before: Dictionary = procedure_work_state.duplicate(true)
	var agents_before: Dictionary = staff_agent_state.duplicate(true)
	var result: Dictionary = procedure_work_runtime.request_work(operation_graph, procedure_work_state, definition, occurrence_id, staffing_state, staffing_runtime, staff_agent_state, staff_agent_runtime)
	if result.get("accepted", false) and result.get("actor_person_id", "") != actor_id:
		procedure_work_state = work_before
		staff_agent_state = agents_before
		return {"accepted": false, "reason": "reconstitution scheduler selected wrong named actor"}
	return result


func reconstitute_control_network(occurrence_id: String, actor_id: String) -> Dictionary:
	if not _control_actor_at(actor_id, "duty_officer", "security_control"):
		return {"accepted": false, "reason": "reconstitution requires named duty officer at security control"}
	var result: Dictionary = control_network_runtime.reconstitute(control_network_state, occurrence_id, actor_id, true)
	if result.get("accepted", false):
		_refresh_procedure_panels()
		_refresh_control_status_board()
	return result


func _control_actor_at(actor_id: String, job_id: String, station: String) -> bool:
	var shift: String = staffing_state.get("active_shift", "")
	if actor_id not in staffing_state.get("assignments", {}).get(shift, {}).get(job_id, []): return false
	return staff_agent_state.get("agents", {}).get(actor_id, {}).get("current_room", "") == station


func declare_control_network_compromise(occurrence_id: String, detecting_actor: String) -> Dictionary:
	var result: Dictionary = control_network_runtime.declare_compromise(control_network_state, occurrence_id, detecting_actor)
	if result.get("accepted", false):
		_refresh_procedure_panels()
		_refresh_control_status_board()
	return result


func export_scene_checkpoint() -> Dictionary:
	var route_validation: Dictionary = mutual_aid_runtime.validate_route_provenance(mutual_aid_state, generated_route_plan)
	if not route_validation.get("accepted", false): return route_validation
	_refresh_control_status_board()
	var work_snapshot: Dictionary = procedure_work_runtime.export_snapshot(procedure_work_state)
	if not work_snapshot.get("accepted", false):
		return work_snapshot
	var epoch: int = next_scene_checkpoint_epoch
	var checkpoint: Dictionary = scene_checkpoint_runtime.build_checkpoint(
		epoch, facility_seed, operation_graph.generation_fingerprint(),
		infrastructure_state, staffing_state, staff_agent_state, work_snapshot,
		procedure_receipts, mission_state, _response_plan_signature(),
		custody_state, personnel_state, {
			"interlock_occupancy": personnel_security_runtime.interlock_occupancy.duplicate(true),
			"active_receipts": personnel_security_runtime.active_receipts.duplicate(true),
			"next_receipt_id": personnel_security_runtime.next_receipt_id,
		}, control_console_state, control_snapshot, operations_queue_state, mutual_aid_state, control_network_state, environmental_observation_state
	)
	if not checkpoint.get("accepted", false):
		return checkpoint
	var validated: Dictionary = scene_checkpoint_runtime.prepare_recovery(
		checkpoint, facility_seed, operation_graph.generation_fingerprint(), operation_graph,
		staffing_runtime, procedure_work_runtime, procedure_panel_definitions, mutual_aid_runtime, control_network_runtime, environmental_observation_runtime
	)
	if not validated.get("accepted", false):
		return validated
	next_scene_checkpoint_epoch = epoch + 1
	return checkpoint


func recover_scene_checkpoint(checkpoint: Dictionary) -> Dictionary:
	var supplied_epoch: int = int(checkpoint.get("epoch", 0))
	if supplied_epoch <= last_recovered_scene_epoch:
		return {"accepted": false, "reason": "scene checkpoint epoch is stale or replayed"}
	var prepared: Dictionary = scene_checkpoint_runtime.prepare_recovery(
		checkpoint, facility_seed, operation_graph.generation_fingerprint(), operation_graph,
		staffing_runtime, procedure_work_runtime, procedure_panel_definitions, mutual_aid_runtime, control_network_runtime, environmental_observation_runtime
	)
	if not prepared.get("accepted", false):
		return prepared
	var recovered_route_validation: Dictionary = mutual_aid_runtime.validate_route_provenance(prepared["mutual_aid_state"], generated_route_plan)
	if not recovered_route_validation.get("accepted", false): return recovered_route_validation
	var prior: Dictionary = {
		"infrastructure": infrastructure_state,
		"staffing": staffing_state,
		"agents": staff_agent_state,
		"work": procedure_work_state,
		"receipts": procedure_receipts,
		"mission": mission_state,
		"custody": custody_state,
		"personnel": personnel_state,
		"personnel_runtime": {
			"interlock_occupancy": personnel_security_runtime.interlock_occupancy,
			"active_receipts": personnel_security_runtime.active_receipts,
			"next_receipt_id": personnel_security_runtime.next_receipt_id,
		},
		"control_console": control_console_state,
		"control_snapshot": control_snapshot,
		"operations_queue": operations_queue_state,
		"mutual_aid": mutual_aid_state,
		"control_network": control_network_state,
		"environmental_observations": environmental_observation_state,
	}
	infrastructure_state = prepared["infrastructure_state"]
	staffing_state = prepared["staffing_state"]
	staff_agent_state = prepared["agent_state"]
	procedure_work_state = prepared["procedure_work_state"]
	procedure_receipts = prepared["procedure_receipts"]
	mission_state = prepared["mission_state"]
	custody_state = prepared["custody_state"]
	personnel_state = prepared["personnel_state"]
	personnel_security_runtime.interlock_occupancy = prepared["personnel_runtime_state"]["interlock_occupancy"]
	personnel_security_runtime.active_receipts = prepared["personnel_runtime_state"]["active_receipts"]
	personnel_security_runtime.next_receipt_id = int(prepared["personnel_runtime_state"]["next_receipt_id"])
	control_console_state = prepared["control_console_state"]
	control_snapshot = prepared["control_snapshot"]
	operations_queue_state = prepared["operations_queue_state"]
	mutual_aid_state = prepared["mutual_aid_state"]
	control_network_state = prepared["control_network_state"]
	environmental_observation_state = prepared["environmental_observation_state"]
	staff_agent_state["room_entry_blocks"] = {}
	for room_id in environmental_observation_state.get("protective_postures", {}):
		if environmental_observation_state["protective_postures"][room_id] == "evacuate": staff_agent_runtime.set_room_entry_block(staff_agent_state, room_id, "environmental_evacuation")
	_refresh_procedure_panels()
	var compiled_signature: Dictionary = _response_plan_signature()
	_refresh_control_status_board()
	var response_projection_matches: bool = compiled_signature == prepared["response_plan_signature"]
	var staged_control_snapshot: Dictionary = control_snapshot.duplicate(true)
	var control_projection_matches: bool = _variants_semantically_equal(staged_control_snapshot, prepared["control_snapshot"])
	if not response_projection_matches or not control_projection_matches:
		infrastructure_state = prior["infrastructure"]
		staffing_state = prior["staffing"]
		staff_agent_state = prior["agents"]
		procedure_work_state = prior["work"]
		procedure_receipts = prior["receipts"]
		mission_state = prior["mission"]
		custody_state = prior["custody"]
		personnel_state = prior["personnel"]
		personnel_security_runtime.interlock_occupancy = prior["personnel_runtime"]["interlock_occupancy"]
		personnel_security_runtime.active_receipts = prior["personnel_runtime"]["active_receipts"]
		personnel_security_runtime.next_receipt_id = prior["personnel_runtime"]["next_receipt_id"]
		control_console_state = prior["control_console"]
		control_snapshot = prior["control_snapshot"]
		operations_queue_state = prior["operations_queue"]
		mutual_aid_state = prior["mutual_aid"]
		control_network_state = prior["control_network"]
		environmental_observation_state = prior["environmental_observations"]
		_refresh_procedure_panels()
		_refresh_control_status_board()
		return {
			"accepted": false,
			"reason": "scene checkpoint derived projection identity mismatch response=%s control=%s" % [response_projection_matches, control_projection_matches],
		}
	last_recovered_scene_epoch = supplied_epoch
	next_scene_checkpoint_epoch = maxi(next_scene_checkpoint_epoch, supplied_epoch + 1)
	_release_all_physical_staff(prior["agents"])
	# Embodiment is scene-local and the physical bodies were just released;
	# a recovered ledger must not inherit embodied flags, or tick() would
	# skip those agents forever and freeze their routes.
	for recovered_staff_id in staff_agent_state.get("agents", {}).keys():
		staff_agent_runtime.set_embodied(staff_agent_state, recovered_staff_id, false)
	_create_staffing_markers()
	_sync_custody_marker()
	_sync_personnel_position()
	_refresh_procedure_panels()
	_apply_service_snapshot()
	_refresh_control_status_board()
	return {
		"accepted": true,
		"epoch": supplied_epoch,
		"recovered_tasks": procedure_work_state["tasks"].size(),
		"active_failures": infrastructure_state["active_failures"].size(),
	}


func commit_scene_journal(directory: String) -> Dictionary:
	var checkpoint: Dictionary = export_scene_checkpoint()
	if not checkpoint.get("accepted", false):
		return checkpoint
	return scene_journal_runtime.commit_checkpoint(directory, checkpoint)


func recover_scene_journal(directory: String, requested_epoch: int = -1) -> Dictionary:
	var loaded: Dictionary = scene_journal_runtime.load_committed(directory, requested_epoch)
	if not loaded.get("accepted", false):
		return loaded
	var recovered: Dictionary = recover_scene_checkpoint(loaded["checkpoint"])
	if recovered.get("accepted", false):
		recovered["journal_epoch"] = loaded["epoch"]
		recovered["journal_checksum"] = loaded["checksum"]
	return recovered


func export_procedure_work_snapshot() -> Dictionary:
	return procedure_work_runtime.export_snapshot(procedure_work_state)


func recover_procedure_work_snapshot(snapshot: Dictionary) -> Dictionary:
	var recovered: Dictionary = procedure_work_runtime.recover_snapshot(snapshot)
	if not recovered.get("accepted", false):
		return recovered
	procedure_work_state = recovered["state"]
	_release_all_physical_staff(staff_agent_state)
	staff_agent_state = staff_agent_runtime.build_active_watch(operation_graph, staffing_state, staffing_runtime)
	_create_staffing_markers()
	_refresh_procedure_panels()
	_refresh_control_status_board()
	return {"accepted": true, "recovered_tasks": recovered.get("recovered_tasks", 0)}


func advance_mission(max_steps: int = -1) -> Dictionary:
	if operation_runtime == null or mission_state.is_empty():
		return {"status": "unavailable"}
	var result: Dictionary = operation_runtime.advance_mission(operation_graph, mission_state, max_steps)
	_apply_service_snapshot()
	_refresh_control_status_board()
	return result


func advance_institution_mission(max_steps: int = -1) -> Dictionary:
	return advance_mission(max_steps)


func run_institution_workday() -> Dictionary:
	return advance_mission(-1)


func start_player_contract(contract_id: String, run_id: String = "") -> Dictionary:
	if player_mission_runtime == null:
		return {"accepted": false, "reason": "player mission unavailable"}
	var started: Dictionary = player_mission_runtime.start_contract(contract_id, run_id if not run_id.is_empty() else "run-%d" % facility_seed)
	if started.get("accepted", true) == false:
		return started
	player_mission_state = started
	var infiltrated: Dictionary = player_mission_runtime.mark_infiltrated(player_mission_state, personnel_state)
	_sync_player_mission_hud()
	return {"accepted": true, "infiltrated": infiltrated, "state": player_mission_state}


func observe_player_mission_target() -> Dictionary:
	if player_mission_runtime == null or player_mission_state.is_empty():
		return {"accepted": false, "reason": "player mission unavailable"}
	var result: Dictionary = player_mission_runtime.observe_target(player_mission_state, personnel_state, mission_state)
	_sync_player_mission_hud()
	return result


func acquire_player_mission_target() -> Dictionary:
	if player_mission_runtime == null or player_mission_state.is_empty():
		return {"accepted": false, "reason": "player mission unavailable"}
	var result: Dictionary = player_mission_runtime.acquire_target(player_mission_state, personnel_state, mission_state, custody_state)
	if result.get("accepted", false) and not result.get("already_committed", false):
		var artifact_id: String = str(result.get("artifact", player_mission_state.get("target_artifact", "")))
		var room: String = str(personnel_state.get("current_room", ""))
		var actor_person_id: String = str(personnel_state.get("person_id", ""))
		var run_id: String = str(player_mission_state.get("run_id", ""))
		if custody_runtime != null and not custody_state.is_empty():
			custody_runtime.record_unauthorized_removal(custody_state, artifact_id, room, actor_person_id, run_id)
		if mission_state.get("artifacts", {}).has(artifact_id):
			var artifact_record: Dictionary = mission_state["artifacts"][artifact_id]
			artifact_record["compromised"] = true
			artifact_record["stolen_by"] = actor_person_id
			artifact_record["stolen_run"] = run_id
		_refresh_control_status_board()
	_sync_player_mission_hud()
	return result


func try_player_exfiltrate() -> Dictionary:
	if player_mission_runtime == null or player_mission_state.is_empty():
		return {"accepted": false, "reason": "player mission unavailable"}
	var result: Dictionary = player_mission_runtime.try_exfiltrate(player_mission_state, personnel_state, mission_state)
	if result.get("accepted", false) and result.get("status", "") == "won":
		if ObjectiveTracker.has_method("mission_won"):
			ObjectiveTracker.mission_won({
				"rating": result.get("rating", "ASSAULT"),
				"heat": result.get("heat", 0),
				"artifact": result.get("artifact", ""),
			})
	_sync_player_mission_hud()
	return result


func teleport_personnel_to_room(room_id: String) -> Dictionary:
	if operation_graph == null or not operation_graph.rooms.has(room_id):
		return {"accepted": false, "reason": "unknown room"}
	if personnel_state.is_empty():
		return {"accepted": false, "reason": "personnel unavailable"}
	personnel_state["current_room"] = room_id
	_sync_personnel_position()
	return {"accepted": true, "room": room_id}


func _sync_player_mission_hud() -> void:
	if player_mission_state.is_empty() or player_mission_runtime == null:
		return
	ObjectiveTracker.objectives = player_mission_runtime.project_objectives(player_mission_state)
	ObjectiveTracker.objectives_changed.emit()
	var prompt: String = str(player_mission_state.get("label", "CONTRACT"))
	if player_mission_state.get("status", "") == "won":
		prompt = "CONTRACT COMPLETE — %s" % player_mission_runtime.compute_rating(player_mission_state)
	ObjectiveTracker.set_prompt(prompt)


func _apply_service_snapshot() -> void:
	if generated_facility == null or mission_state.is_empty():
		return
	var equipment_group := generated_facility.get_node_or_null("Equipment")
	if equipment_group == null:
		return
	for equipment_node in equipment_group.get_children():
		if equipment_node.has_method("apply_service_snapshot"):
			var equipment_snapshot: Dictionary = mission_state["service_available"].duplicate(true)
			var room_id: String = equipment_node.get_meta("room", "")
			for service_id in mission_state["room_service_available"]:
				if mission_state["room_service_available"][service_id].has(room_id):
					equipment_snapshot[service_id] = mission_state["room_service_available"][service_id][room_id]
			equipment_node.apply_service_snapshot(equipment_snapshot)


func transfer_material(to_room: String, roles: Array) -> Dictionary:
	var protective_posture: String = environmental_observation_state.get("protective_postures", {}).get(to_room, "")
	if not protective_posture.is_empty(): return {"accepted": false, "reason": "destination under environmental protective posture: " + protective_posture}
	var result: Dictionary = custody_runtime.transfer(operation_graph, custody_state, to_room, {"roles": roles.duplicate()})
	if result.get("accepted", false):
		_sync_custody_marker()
	_refresh_control_status_board()
	return result


func declare_custody_incident(procedure_id: String) -> Dictionary:
	var result: Dictionary = custody_runtime.declare_incident(operation_graph, custody_state, procedure_id)
	_sync_custody_marker()
	_refresh_procedure_panels()
	_refresh_control_status_board()
	return result


func resolve_custody_incident(_roles: Array) -> Dictionary:
	_refresh_procedure_panels()
	_refresh_control_status_board()
	return {"accepted": false, "reason": "custody incident resolution requires durable staffed procedure work"}


func clear_material_quarantine(_roles: Array) -> Dictionary:
	_refresh_procedure_panels()
	_refresh_control_status_board()
	return {"accepted": false, "reason": "quarantine disposition requires durable staffed procedure work"}


func _create_custody_marker() -> void:
	custody_marker = MeshInstance3D.new()
	custody_marker.name = "CustodyMaterial"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.65, 0.45, 0.9)
	custody_marker.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.86, 0.45, 0.08)
	custody_marker.material_override = material
	add_child(custody_marker)
	_sync_custody_marker()


func _sync_custody_marker() -> void:
	if custody_marker == null or generated_facility == null or custody_state.is_empty():
		return
	var room_id: String = custody_state["current_room"]
	var room_node := _find_room(generated_facility, room_id)
	if room_node != null:
		custody_marker.global_position = room_node.global_position + Vector3(0.0, 0.55, 0.0)
	custody_marker.set_meta("custody_identity", custody_state["custody_identity"])
	custody_marker.set_meta("current_room", room_id)
	custody_marker.set_meta("active_incident", custody_state["active_incident"])
	custody_marker.set_meta("history_length", custody_state["history"].size())


func _find_room(facility: Node3D, room_id: String) -> Node3D:
	for room_node in facility.get_node("Rooms").get_children():
		if room_node.get_meta("room_id", "") == room_id:
			return room_node
	return null


func _create_player_mission_stations() -> void:
	if generated_facility == null or player_mission_state.is_empty():
		return
	var existing := get_node_or_null("PlayerMissionStations")
	if existing != null:
		existing.queue_free()
	var group := Node3D.new()
	group.name = "PlayerMissionStations"
	add_child(group)
	var target_room: String = str(player_mission_state.get("target_room", ""))
	if not target_room.is_empty():
		var acquire_station: StaticBody3D = _make_mission_station("AcquireTarget", target_room, "acquire", Color(0.82, 0.18, 0.22))
		group.add_child(acquire_station)
		_place_mission_station(acquire_station, target_room, "acquire")
	var exfil_rooms: Array = player_mission_state.get("exfil_rooms", ["screened_entry", "emergency_exit"])
	var primary_exfil := "screened_entry"
	if exfil_rooms.has(primary_exfil) or exfil_rooms.is_empty():
		var entry_station: StaticBody3D = _make_mission_station("ExfilScreenedEntry", primary_exfil, "exfil", Color(0.18, 0.55, 0.82))
		group.add_child(entry_station)
		_place_mission_station(entry_station, primary_exfil, "exfil")
	if exfil_rooms.has("emergency_exit") and _find_room(generated_facility, "emergency_exit") != null:
		var emergency_station: StaticBody3D = _make_mission_station("ExfilEmergencyExit", "emergency_exit", "exfil", Color(0.72, 0.42, 0.12))
		group.add_child(emergency_station)
		_place_mission_station(emergency_station, "emergency_exit", "exfil")


func _make_mission_station(station_name: String, room_id: String, action: String, color: Color) -> StaticBody3D:
	var station := StaticBody3D.new()
	station.name = station_name
	station.set_meta("room", room_id)
	station.set_meta("action", action)
	station.set_meta("mission_station", true)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "StationFace"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.8, 0.7, 0.18)
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color.darkened(0.45)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.85
	mesh_instance.material_override = material
	station.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	collision.name = "InteractionCollider"
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	collision.shape = shape
	station.add_child(collision)
	var label := Label3D.new()
	label.name = "StationLabel"
	label.text = "ACQUIRE TARGET" if action == "acquire" else "EXFILTRATE"
	label.font_size = 28
	label.outline_size = 6
	label.pixel_size = 0.004
	label.no_depth_test = true
	label.modulate = color.lightened(0.35)
	label.position = Vector3(0.0, 0.0, 0.1)
	station.add_child(label)
	var station_script := GDScript.new()
	var tab := "\t"
	station_script.source_code = "\n".join([
		"extends StaticBody3D",
		"var facility: Node",
		"var action: String = \"\"",
		"var last_result: Dictionary = {}",
		"func interact(interactor: Node) -> void:",
		tab + "if facility == null or not facility.has_method(\"activate_player_mission_station\"):",
		tab + tab + "last_result = {\"accepted\": false, \"reason\": \"mission station controller unavailable\"}",
		tab + tab + "set_meta(\"last_result\", last_result.duplicate(true))",
		tab + tab + "return",
		tab + "last_result = facility.activate_player_mission_station(action, interactor)",
		tab + "set_meta(\"last_result\", last_result.duplicate(true))",
		"",
	])
	var reload_err: Error = station_script.reload()
	if reload_err != OK:
		push_error("Player mission station script failed to reload: %s" % reload_err)
	station.set_script(station_script)
	station.set("facility", self)
	station.set("action", action)
	return station


func _place_mission_station(station: StaticBody3D, room_id: String, action: String) -> void:
	var room_node := _find_room(generated_facility, room_id)
	if room_node == null:
		return
	var offset := Vector3(1.2, 1.1, 1.35) if action == "acquire" else Vector3(-1.2, 1.1, 1.35)
	if room_id == "emergency_exit":
		offset = Vector3(1.2, 1.1, -1.15)
	station.global_position = room_node.global_position + offset


func activate_player_mission_station(action: String, interactor: Node) -> Dictionary:
	if interactor != player:
		return {"accepted": false, "reason": "no personnel identity"}
	if player_mission_runtime == null or player_mission_state.is_empty() or personnel_state.is_empty():
		return {"accepted": false, "reason": "player mission unavailable"}
	var current_room: String = str(personnel_state.get("current_room", ""))
	match action:
		"acquire":
			var target_room: String = str(player_mission_state.get("target_room", ""))
			if current_room != target_room:
				return {"accepted": false, "reason": "operator is not at mission station room"}
			var observed: Dictionary = observe_player_mission_target()
			var acquired: Dictionary = acquire_player_mission_target()
			return {
				"accepted": bool(acquired.get("accepted", false)),
				"action": action,
				"room": current_room,
				"observe": observed,
				"acquire": acquired,
			}
		"exfil":
			var exfil_rooms: Array = player_mission_state.get("exfil_rooms", [])
			if not exfil_rooms.has(current_room):
				return {"accepted": false, "reason": "operator is not at mission station room"}
			var exfil: Dictionary = try_player_exfiltrate()
			return {
				"accepted": bool(exfil.get("accepted", false)),
				"action": action,
				"room": current_room,
				"exfil": exfil,
			}
		_:
			return {"accepted": false, "reason": "unknown mission station action"}

