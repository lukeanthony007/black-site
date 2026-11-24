class_name FacilityOperationGraph
extends RefCounted
## Pure operational model for a generated facility. No geometry or scene nodes.

const REQUIRED_MISSION_ROOMS: Array[String] = [
	"screened_entry",
	"cyber_ops",
	"contained_lab",
	"compute_core",
	"archive_accession",
	"archive_stack",
	"plant",
]

const REQUIRED_JOBS: Array[String] = [
	"duty_officer",
	"security_officer",
	"cyber_analyst",
	"cyber_researcher",
	"systems_administrator",
	"records_officer",
	"accession_technician",
	"archive_custodian",
	"facilities_engineer",
]

const MATERIAL_CUSTODY_CHAIN: Array[String] = [
	"loading",
	"material_screening",
	"archive_accession",
	"quarantine",
	"archive_processing",
	"archive_stack",
]

const REQUIRED_FAILURE_CAPABILITIES: Array[String] = [
	"power",
	"cooling",
	"communications",
	"security",
	"custody",
	"staffing",
]

var seed: int = 0
var generation_profile: Dictionary = {}
var rooms: Dictionary = {}
var jobs: Dictionary = {}
var equipment: Dictionary = {}
var circulation_edges: Array[Dictionary] = []
var dependency_edges: Array[Dictionary] = []
var mission_steps: Array[Dictionary] = []
var failure_procedures: Dictionary = {}
var service_continuity_profiles: Dictionary = {}
var operations_response_policies: Dictionary = {}
var mutual_aid_policy: Dictionary = {}
var facility_control_system_policy: Dictionary = {}


func configure_cyber_archives(facility_seed: int) -> void:
	seed = facility_seed
	generation_profile = _derive_generation_profile(facility_seed)
	rooms.clear()
	jobs.clear()
	equipment.clear()
	circulation_edges.clear()
	dependency_edges.clear()
	mission_steps.clear()
	failure_procedures.clear()
	service_continuity_profiles.clear()
	_build_cyber_archives()
	operations_response_policies = {
		"power": {"priority": 20, "deadline_ticks": 3, "retry_backoff_ticks": 2, "max_wait_ticks": 12, "station_capacity": 1, "abandonment_action": "mobilize_qualified_relief", "relief_failure_action": "mission_shutdown", "reactivation_authority_job": "security_officer", "reactivation_station": "security_control"},
		"cooling": {"priority": 30, "deadline_ticks": 3, "retry_backoff_ticks": 2, "max_wait_ticks": 12, "station_capacity": 1, "abandonment_action": "mobilize_qualified_relief", "relief_failure_action": "mission_shutdown", "reactivation_authority_job": "security_officer", "reactivation_station": "security_control"},
		"communications": {"priority": 40, "deadline_ticks": 3, "retry_backoff_ticks": 2, "max_wait_ticks": 12, "station_capacity": 1, "abandonment_action": "mobilize_qualified_relief", "relief_failure_action": "mission_shutdown", "reactivation_authority_job": "security_officer", "reactivation_station": "security_control"},
		"custody:contain_incident": {"priority": 10, "deadline_ticks": 2, "retry_backoff_ticks": 1, "max_wait_ticks": 8, "station_capacity": 1, "abandonment_action": "mission_safe_hold"},
		"custody:record_quarantine_disposition": {"priority": 50, "deadline_ticks": 4, "retry_backoff_ticks": 2, "max_wait_ticks": 16, "station_capacity": 1, "abandonment_action": "mission_safe_hold"},
	}
	mutual_aid_policy = {
		"staging_room": "screened_entry", "authority_job": "duty_officer", "authority_station": "cyber_ops",
		"escort_job": "security_officer", "escort_station": "security_control", "credential_mode": "incident_scoped_temporary",
	}
	facility_control_system_policy = {
		"source": "UFC 4-010-05 1-10/1-10.1", "cybersecurity_standard": "UFC 4-010-06", "mission_owner_coordination": true,
		"minimum_cia_categorization": {"confidentiality": "moderate", "integrity": "moderate", "availability": "moderate"},
		"applies_to": ["power", "cooling", "communications", "access_control", "environmental_monitoring"],
		"executable_recovery_services": ["power", "cooling", "communications", "access_control", "environmental_monitoring"],
		"policy_only_services": [],
	}


func generation_fingerprint() -> String:
	return "seed=%d|floors=%d|staff=%d|labs=%d|archive_bays=%d|service=%s" % [
		seed,
		generation_profile.get("floor_count", 0),
		generation_profile.get("staff_capacity", 0),
		generation_profile.get("contained_lab_count", 0),
		generation_profile.get("archive_bay_count", 0),
		generation_profile.get("service_spine", ""),
	]


func _derive_generation_profile(facility_seed: int) -> Dictionary:
	var normalized_seed: int = absi(facility_seed)
	return {
		"floor_count": 2 + normalized_seed % 2,
		"staff_capacity": 90 + normalized_seed % 51,
		"contained_lab_count": 2 + (normalized_seed / 2) % 2,
		"archive_bay_count": 2 + (normalized_seed / 4) % 2,
		"service_spine": "east" if (normalized_seed / 8) % 2 == 0 else "west",
	}


func has_room(room_id: String) -> bool:
	return rooms.has(room_id)


func has_job(job_id: String) -> bool:
	return jobs.has(job_id)


func add_room(
	room_id: String,
	zone: String,
	security_tier: int,
	owners: Array[String],
	occupied: bool = true,
	critical_requirements: Array[String] = []
) -> void:
	rooms[room_id] = {
		"id": room_id,
		"zone": zone,
		"security_tier": security_tier,
		"owners": owners.duplicate(),
		"access_roles": owners.duplicate(),
		"occupied": occupied,
		"critical_requirements": critical_requirements.duplicate(),
	}


func set_room_access_roles(room_id: String, roles: Array[String]) -> void:
	if rooms.has(room_id):
		rooms[room_id]["access_roles"] = roles.duplicate()


func add_job(job_id: String, station: String, continuous: bool = false, minimum_on_shift: int = 1) -> void:
	jobs[job_id] = {
		"id": job_id,
		"station": station,
		"continuous": continuous,
		"minimum_on_shift": minimum_on_shift,
	}


func add_equipment(
	equipment_id: String,
	room_id: String,
	owner_job: String,
	function_name: String,
	utility_requirements: Array[String] = []
) -> void:
	equipment[equipment_id] = {
		"id": equipment_id,
		"room": room_id,
		"owner_job": owner_job,
		"function": function_name,
		"utility_requirements": utility_requirements.duplicate(),
	}


func remove_equipment(equipment_id: String) -> void:
	equipment.erase(equipment_id)


func connect_rooms(
	from_room: String,
	to_room: String,
	flow: String,
	policy_transition: bool = false,
	bidirectional: bool = true
) -> void:
	circulation_edges.append({
		"from": from_room,
		"to": to_room,
		"flow": flow,
		"policy_transition": policy_transition,
	})
	if bidirectional:
		circulation_edges.append({
			"from": to_room,
			"to": from_room,
			"flow": flow,
			"policy_transition": policy_transition,
		})


func add_dependency(provider: String, consumer: String, kind: String) -> void:
	dependency_edges.append({"provider": provider, "consumer": consumer, "kind": kind})


func add_mission_step(
	step_id: String,
	owner_job: String,
	station: String,
	inputs: Array[String] = [],
	outputs: Array[String] = [],
	required_equipment: Array[String] = []
) -> void:
	mission_steps.append({
		"id": step_id,
		"owner_job": owner_job,
		"station": station,
		"inputs": inputs.duplicate(),
		"outputs": outputs.duplicate(),
		"required_equipment": required_equipment.duplicate(),
	})


func add_failure_procedure(
	procedure_id: String,
	owner_job: String,
	station: String,
	capabilities: Array[String],
	preserves: Array[String]
) -> void:
	failure_procedures[procedure_id] = {
		"id": procedure_id,
		"owner_job": owner_job,
		"station": station,
		"capabilities": capabilities.duplicate(),
		"preserves": preserves.duplicate(),
	}


func add_service_continuity_profile(
	service_id: String,
	failure_phase: String,
	preserved_rooms: Array[String],
	transitions: Array[Dictionary],
	verification_controls: Array[Dictionary] = [],
	recovery_controls: Array[Dictionary] = [],
	degraded_obligations: Array[Dictionary] = []
) -> void:
	service_continuity_profiles[service_id] = {
		"service": service_id,
		"failure_phase": failure_phase,
		"preserved_rooms": preserved_rooms.duplicate(),
		"transitions": transitions.duplicate(true),
		"verification_controls": verification_controls.duplicate(true),
		"recovery_controls": recovery_controls.duplicate(true),
		"degraded_obligations": degraded_obligations.duplicate(true),
	}


func has_failure_procedure(procedure_id: String) -> bool:
	return failure_procedures.has(procedure_id)


func remove_failure_procedure(procedure_id: String) -> void:
	failure_procedures.erase(procedure_id)


func remove_room(room_id: String) -> void:
	rooms.erase(room_id)
	circulation_edges = circulation_edges.filter(func(edge: Dictionary) -> bool:
		return edge["from"] != room_id and edge["to"] != room_id
	)
	dependency_edges = dependency_edges.filter(func(edge: Dictionary) -> bool:
		return edge["provider"] != room_id and edge["consumer"] != room_id
	)


func remove_dependencies(consumer: String, kind: String) -> void:
	dependency_edges = dependency_edges.filter(func(edge: Dictionary) -> bool:
		return edge["consumer"] != consumer or edge["kind"] != kind
	)


func validate() -> Array[String]:
	var errors: Array[String] = []
	_validate_required_content(errors)
	_validate_ownership(errors)
	_validate_equipment(errors)
	_validate_mission_cycle(errors)
	_validate_material_custody_path(errors)
	_validate_critical_dependencies(errors)
	_validate_security_transitions(errors)
	_validate_egress(errors)
	_validate_failure_procedures(errors)
	_validate_service_continuity_profiles(errors)
	_validate_operations_response_policies(errors)
	_validate_mutual_aid_policy(errors)
	_validate_facility_control_system_policy(errors)
	return errors


func has_path(from_room: String, to_room: String, flow: String) -> bool:
	if not rooms.has(from_room) or not rooms.has(to_room):
		return false
	var pending: Array[String] = [from_room]
	var visited: Dictionary = {from_room: true}
	while not pending.is_empty():
		var current: String = pending.pop_front()
		if current == to_room:
			return true
		for edge in circulation_edges:
			if edge["flow"] != flow or edge["from"] != current:
				continue
			var next_room: String = edge["to"]
			if not visited.has(next_room):
				visited[next_room] = true
				pending.append(next_room)
	return false


func _build_cyber_archives() -> void:
	# Jobs are owners of operating facts, not decorative NPC labels.
	add_job("duty_officer", "cyber_ops", true)
	add_job("security_officer", "security_control", true)
	add_job("cyber_analyst", "cyber_ops", true)
	add_job("cyber_researcher", "contained_lab")
	add_job("systems_administrator", "compute_core", true)
	add_job("records_officer", "archive_processing")
	add_job("accession_technician", "archive_accession")
	add_job("archive_custodian", "archive_stack", true)
	add_job("facilities_engineer", "plant", true)
	add_job("logistics_receiver", "loading")

	add_room("perimeter", "external", 0, ["security_officer"], false)
	add_room("screened_entry", "entry", 1, ["security_officer"])
	add_room("staff_control", "entry", 2, ["security_officer"])
	add_room("security_control", "operations", 4, ["security_officer", "duty_officer"], true, ["power", "communications"])
	add_room("cyber_ops", "cyber", 3, ["duty_officer", "cyber_analyst"], true, ["power", "cooling", "communications"])
	add_room("contained_lab", "research", 4, ["cyber_researcher"], true, ["power", "cooling", "communications"])
	add_room("compute_core", "infrastructure", 5, ["systems_administrator"], true, ["power", "cooling", "communications", "maintenance"])
	add_room("loading", "service", 1, ["logistics_receiver"])
	add_room("material_screening", "service", 2, ["security_officer", "logistics_receiver"])
	add_room("archive_accession", "archives", 3, ["accession_technician"], true, ["power", "communications"])
	add_room("quarantine", "archives", 4, ["accession_technician"])
	add_room("archive_processing", "archives", 3, ["records_officer"], true, ["power", "communications"])
	add_room("archive_stack", "archives", 4, ["archive_custodian"], true, ["power", "cooling", "communications", "maintenance"])
	add_room("plant", "plant", 4, ["facilities_engineer"], true, ["maintenance"])
	add_room("communications_entry", "plant", 4, ["systems_administrator"], false)
	add_room("emergency_exit", "egress", 1, ["security_officer"], false)
	for lab_number in range(2, int(generation_profile["contained_lab_count"]) + 1):
		add_room(
			"contained_lab_%02d" % lab_number,
			"research",
			4,
			["cyber_researcher"],
			true,
			["power", "cooling", "communications"]
		)
	for bay_number in range(2, int(generation_profile["archive_bay_count"]) + 1):
		add_room(
			"archive_stack_%02d" % bay_number,
			"archives",
			4,
			["archive_custodian"],
			true,
			["power", "cooling", "communications", "maintenance"]
		)

	# Access policy is distinct from operational ownership. Transit roles are explicit.
	var all_roles: Array[String] = []
	all_roles.assign(jobs.keys())
	for common_room in ["perimeter", "screened_entry", "staff_control", "emergency_exit"]:
		set_room_access_roles(common_room, all_roles)
	set_room_access_roles("security_control", ["security_officer", "cyber_analyst", "duty_officer"])
	set_room_access_roles("cyber_ops", ["duty_officer", "cyber_analyst", "cyber_researcher", "systems_administrator"])
	set_room_access_roles("contained_lab", ["cyber_researcher"])
	set_room_access_roles("compute_core", ["systems_administrator"])
	set_room_access_roles("archive_accession", ["accession_technician", "records_officer", "archive_custodian"])
	set_room_access_roles("archive_processing", ["records_officer", "archive_custodian"])
	set_room_access_roles("archive_stack", ["archive_custodian"])
	set_room_access_roles("plant", ["facilities_engineer"])
	for lab_number in range(2, int(generation_profile["contained_lab_count"]) + 1):
		set_room_access_roles("contained_lab_%02d" % lab_number, ["cyber_researcher"])
	for bay_number in range(2, int(generation_profile["archive_bay_count"]) + 1):
		set_room_access_roles("archive_stack_%02d" % bay_number, ["archive_custodian"])

	# Personnel circulation; every tier jump is explicit.
	connect_rooms("perimeter", "screened_entry", "personnel", true)
	connect_rooms("screened_entry", "staff_control", "personnel", true)
	connect_rooms("staff_control", "security_control", "personnel", true)
	connect_rooms("staff_control", "cyber_ops", "personnel", true)
	connect_rooms("cyber_ops", "contained_lab", "personnel", true)
	connect_rooms("cyber_ops", "compute_core", "personnel", true)
	connect_rooms("staff_control", "archive_accession", "personnel", true)
	connect_rooms("archive_accession", "quarantine", "personnel", true)
	connect_rooms("archive_accession", "archive_processing", "personnel", true)
	connect_rooms("archive_processing", "archive_stack", "personnel", true)
	connect_rooms("staff_control", "plant", "personnel", true)
	for lab_number in range(2, int(generation_profile["contained_lab_count"]) + 1):
		connect_rooms("cyber_ops", "contained_lab_%02d" % lab_number, "personnel", true)
	for bay_number in range(2, int(generation_profile["archive_bay_count"]) + 1):
		connect_rooms("archive_processing", "archive_stack_%02d" % bay_number, "personnel", true)

	# Material custody is deliberately one-way from uncontrolled receipt to storage.
	connect_rooms("loading", "material_screening", "material", true, false)
	connect_rooms("material_screening", "archive_accession", "material", true, false)
	connect_rooms("archive_accession", "quarantine", "material", true, false)
	connect_rooms("quarantine", "archive_processing", "material", true, false)
	connect_rooms("archive_processing", "archive_stack", "material", true, false)
	connect_rooms("material_screening", "contained_lab", "evidence", true, false)
	connect_rooms("contained_lab", "archive_accession", "evidence", true, false)
	for bay_number in range(2, int(generation_profile["archive_bay_count"]) + 1):
		connect_rooms("archive_processing", "archive_stack_%02d" % bay_number, "material", true, false)

	# Egress is a distinct graph so emergency reachability never implies ordinary access.
	for room_id in rooms:
		if bool(rooms[room_id]["occupied"]):
			connect_rooms(room_id, "emergency_exit", "egress", false, false)

	# Physical plant and service dependencies.
	for consumer in ["security_control", "cyber_ops", "contained_lab", "compute_core", "archive_accession", "archive_processing", "archive_stack"]:
		add_dependency("plant", consumer, "power")
	for consumer in ["cyber_ops", "contained_lab", "compute_core", "archive_stack"]:
		add_dependency("plant", consumer, "cooling")
	for consumer in ["security_control", "cyber_ops", "contained_lab", "compute_core", "archive_accession", "archive_processing", "archive_stack"]:
		add_dependency("communications_entry", consumer, "communications")
	for consumer in ["compute_core", "archive_stack", "plant"]:
		add_dependency("plant", consumer, "maintenance")
	for lab_number in range(2, int(generation_profile["contained_lab_count"]) + 1):
		var lab_id := "contained_lab_%02d" % lab_number
		add_dependency("plant", lab_id, "power")
		add_dependency("plant", lab_id, "cooling")
		add_dependency("communications_entry", lab_id, "communications")
	for bay_number in range(2, int(generation_profile["archive_bay_count"]) + 1):
		var bay_id := "archive_stack_%02d" % bay_number
		add_dependency("plant", bay_id, "power")
		add_dependency("plant", bay_id, "cooling")
		add_dependency("communications_entry", bay_id, "communications")
		add_dependency("plant", bay_id, "maintenance")

	add_equipment("mission_command_console", "cyber_ops", "duty_officer", "receive and track mission directives", ["power", "communications"])
	add_equipment("hardwired_emergency_service_control", "security_control", "security_officer", "execute declared degraded utility commands under incident authority", ["power", "communications"])
	add_equipment("local_power_isolation_control", "plant", "facilities_engineer", "physically isolate failed power equipment for repair when remote automation is unavailable", [])
	add_equipment("local_cooling_recovery_control", "plant", "facilities_engineer", "locally authorize, record, and test cooling repair without remote automation", [])
	add_equipment("local_communications_recovery_console", "compute_core", "systems_administrator", "locally authorize, record, and test communications repair while external automation is isolated", ["power"])
	add_equipment("local_access_control_recovery_console", "security_control", "security_officer", "maintain guarded-entry posture and locally repair access control while automation is isolated", ["power"])
	add_equipment("access_control_reconstitution_console", "security_control", "duty_officer", "independently verify access-control restoration before releasing guarded entry", ["power"])
	add_equipment("local_environmental_monitoring_console", "plant", "facilities_engineer", "record manual sensor rounds and locally repair environmental monitoring while automation is isolated", [])
	add_equipment("environmental_monitoring_reconstitution_control", "security_control", "security_officer", "independently verify environmental alarms and sensor reporting before reconstitution", ["power"])
	add_equipment("access_authorization_console", "security_control", "security_officer", "authorize personnel, devices, and task scope", ["power", "communications"])
	add_equipment("accession_workstation", "archive_accession", "accession_technician", "register incoming media and custody identity", ["power", "communications"])
	add_equipment("contained_analysis_bench", "contained_lab", "cyber_researcher", "execute isolated cyber experiments", ["power", "cooling", "communications"])
	add_equipment("analyst_workstation", "cyber_ops", "cyber_analyst", "review research findings", ["power", "communications"])
	add_equipment("records_system", "archive_processing", "records_officer", "accession reviewed evidence", ["power", "communications"])
	add_equipment("archive_catalog_terminal", "archive_stack", "archive_custodian", "index and locate preserved holdings", ["power", "communications"])
	add_equipment("controlled_shelving", "archive_stack", "archive_custodian", "physically preserve accessioned holdings", ["cooling", "maintenance"])
	add_equipment("baseline_admin_console", "compute_core", "systems_administrator", "restore clean experiment baseline", ["power", "cooling", "communications", "maintenance"])

	add_mission_step("receive_directive", "duty_officer", "cyber_ops", [], ["mission_request"], ["mission_command_console"])
	add_mission_step("authorize_work", "security_officer", "security_control", ["mission_request"], ["authorized_task"], ["access_authorization_console"])
	add_mission_step("stage_inputs", "accession_technician", "archive_accession", ["authorized_task"], ["staged_inputs"], ["accession_workstation"])
	add_mission_step("conduct_research", "cyber_researcher", "contained_lab", ["staged_inputs"], ["research_result", "evidence_package", "experiment_environment"], ["contained_analysis_bench"])
	add_mission_step("review_findings", "cyber_analyst", "cyber_ops", ["research_result"], ["reviewed_finding"], ["analyst_workstation"])
	add_mission_step("accession_evidence", "records_officer", "archive_processing", ["reviewed_finding", "evidence_package"], ["accessioned_record"], ["records_system"])
	add_mission_step("preserve_and_index", "archive_custodian", "archive_stack", ["accessioned_record"], ["preserved_record"], ["archive_catalog_terminal", "controlled_shelving"])
	add_mission_step("restore_baseline", "systems_administrator", "compute_core", ["experiment_environment"], ["restored_baseline"], ["baseline_admin_console"])

	add_failure_procedure("power_loss", "facilities_engineer", "plant", ["power"], ["security_control", "compute_core", "archive_stack"])
	add_failure_procedure("cooling_failure", "facilities_engineer", "plant", ["cooling"], ["compute_core", "archive_stack"])
	add_failure_procedure("communications_loss", "systems_administrator", "compute_core", ["communications"], ["cyber_ops", "security_control"])
	add_failure_procedure("access_control_failure", "security_officer", "security_control", ["access_control"], ["guarded_entry", "credential_audit"])
	add_failure_procedure("environmental_monitoring_failure", "facilities_engineer", "plant", ["environmental_monitoring"], ["manual_sensor_rounds", "local_alarm_log"])
	add_failure_procedure("cyber_incident", "duty_officer", "cyber_ops", ["security"], ["mission_command", "evidence"])
	add_failure_procedure("archive_fire_water", "records_officer", "archive_processing", ["custody"], ["archive_holdings", "custody_log"])
	add_failure_procedure("staffing_shortage", "duty_officer", "cyber_ops", ["staffing"], ["continuous_watch", "life_safety"])

	add_service_continuity_profile("cooling", "safe_hold", ["compute_core", "archive_stack"], [
		{"from": "safe_hold", "action": "enter_controlled_shutdown", "to": "controlled_shutdown", "actor_job": "duty_officer", "station": "cyber_ops", "alternate_controls": [{"station": "security_control", "actor_job": "security_officer", "mode": "hardwired_emergency_control", "equipment": "hardwired_emergency_service_control"}]},
		{"from": "controlled_shutdown", "action": "isolate_for_repair", "to": "repair_pending", "actor_job": "facilities_engineer", "station": "plant", "alternate_controls": [{"station": "plant", "actor_job": "facilities_engineer", "mode": "hardwired_local_isolation", "equipment": "local_cooling_recovery_control"}]},
	], [
		{"station": "security_control", "actor_job": "security_officer", "mode": "hardwired_reconstitution_authority", "equipment": "hardwired_emergency_service_control", "required_evidence": "passed_functional_test", "separation": "not_repair_actor"},
	], [
		{"action": "begin_repair", "station": "plant", "actor_job": "facilities_engineer", "mode": "hardwired_local_repair", "equipment": "local_cooling_recovery_control"},
		{"action": "record_repair", "station": "plant", "actor_job": "facilities_engineer", "mode": "hardwired_local_repair", "equipment": "local_cooling_recovery_control"},
		{"action": "functional_test", "station": "plant", "actor_job": "facilities_engineer", "mode": "hardwired_local_test", "equipment": "local_cooling_recovery_control"},
	])
	add_service_continuity_profile("power", "ride_through", ["security_control", "compute_core", "archive_stack"], [
		{"from": "ride_through", "action": "shed_noncritical_load", "to": "load_shed", "actor_job": "duty_officer", "station": "cyber_ops", "alternate_controls": [{"station": "security_control", "actor_job": "security_officer", "mode": "hardwired_emergency_control", "equipment": "hardwired_emergency_service_control"}]},
		{"from": "load_shed", "action": "isolate_for_repair", "to": "repair_pending", "actor_job": "facilities_engineer", "station": "plant", "alternate_controls": [{"station": "plant", "actor_job": "facilities_engineer", "mode": "hardwired_local_isolation", "equipment": "local_power_isolation_control"}]},
	], [
		{"station": "security_control", "actor_job": "security_officer", "mode": "hardwired_reconstitution_authority", "equipment": "hardwired_emergency_service_control", "required_evidence": "passed_functional_test", "separation": "not_repair_actor"},
	], [
		{"action": "begin_repair", "station": "plant", "actor_job": "facilities_engineer", "mode": "hardwired_local_repair", "equipment": "local_power_isolation_control"},
		{"action": "record_repair", "station": "plant", "actor_job": "facilities_engineer", "mode": "hardwired_local_repair", "equipment": "local_power_isolation_control"},
		{"action": "functional_test", "station": "plant", "actor_job": "facilities_engineer", "mode": "hardwired_local_test", "equipment": "local_power_isolation_control"},
	])
	add_service_continuity_profile("communications", "local_only", ["cyber_ops", "security_control"], [
		{"from": "local_only", "action": "isolate_external_links", "to": "isolated", "actor_job": "duty_officer", "station": "cyber_ops", "alternate_controls": [{"station": "security_control", "actor_job": "security_officer", "mode": "hardwired_emergency_control", "equipment": "hardwired_emergency_service_control"}]},
		{"from": "isolated", "action": "isolate_for_repair", "to": "repair_pending", "actor_job": "systems_administrator", "station": "compute_core", "alternate_controls": [{"station": "compute_core", "actor_job": "systems_administrator", "mode": "hardwired_local_isolation", "equipment": "local_communications_recovery_console"}]},
	], [
		{"station": "security_control", "actor_job": "security_officer", "mode": "hardwired_reconstitution_authority", "equipment": "hardwired_emergency_service_control", "required_evidence": "passed_functional_test", "separation": "not_repair_actor"},
	], [
		{"action": "begin_repair", "station": "compute_core", "actor_job": "systems_administrator", "mode": "hardwired_local_repair", "equipment": "local_communications_recovery_console"},
		{"action": "record_repair", "station": "compute_core", "actor_job": "systems_administrator", "mode": "hardwired_local_repair", "equipment": "local_communications_recovery_console"},
		{"action": "functional_test", "station": "compute_core", "actor_job": "systems_administrator", "mode": "hardwired_local_test", "equipment": "local_communications_recovery_console"},
	])
	add_service_continuity_profile("access_control", "manual_guard", ["screened_entry", "security_control"], [
		{"from": "manual_guard", "action": "enforce_guarded_entry", "to": "credential_lockout", "actor_job": "duty_officer", "station": "cyber_ops", "alternate_controls": [{"station": "security_control", "actor_job": "security_officer", "mode": "hardwired_guard_control", "equipment": "local_access_control_recovery_console"}]},
		{"from": "credential_lockout", "action": "isolate_for_repair", "to": "repair_pending", "actor_job": "security_officer", "station": "security_control", "alternate_controls": [{"station": "security_control", "actor_job": "security_officer", "mode": "hardwired_local_isolation", "equipment": "local_access_control_recovery_console"}]},
	], [
		{"station": "security_control", "actor_job": "duty_officer", "mode": "hardwired_reconstitution_authority", "equipment": "access_control_reconstitution_console", "required_evidence": "passed_functional_test", "separation": "not_repair_actor"},
	], [
		{"action": "begin_repair", "station": "security_control", "actor_job": "security_officer", "mode": "hardwired_local_repair", "equipment": "local_access_control_recovery_console"},
		{"action": "record_repair", "station": "security_control", "actor_job": "security_officer", "mode": "hardwired_local_repair", "equipment": "local_access_control_recovery_console"},
		{"action": "functional_test", "station": "security_control", "actor_job": "security_officer", "mode": "hardwired_local_test", "equipment": "local_access_control_recovery_console"},
	])
	add_service_continuity_profile("environmental_monitoring", "manual_rounds", ["archive_stack", "compute_core", "security_control"], [
		{"from": "manual_rounds", "action": "establish_manual_sensor_rounds", "to": "sensor_isolation", "actor_job": "duty_officer", "station": "cyber_ops", "alternate_controls": [{"station": "security_control", "actor_job": "security_officer", "mode": "hardwired_alarm_log", "equipment": "environmental_monitoring_reconstitution_control"}]},
		{"from": "sensor_isolation", "action": "isolate_for_repair", "to": "repair_pending", "actor_job": "facilities_engineer", "station": "plant", "alternate_controls": [{"station": "plant", "actor_job": "facilities_engineer", "mode": "hardwired_local_isolation", "equipment": "local_environmental_monitoring_console"}]},
	], [
		{"station": "security_control", "actor_job": "security_officer", "mode": "hardwired_reconstitution_authority", "equipment": "environmental_monitoring_reconstitution_control", "required_evidence": "passed_functional_test", "separation": "not_repair_actor"},
	], [
		{"action": "begin_repair", "station": "plant", "actor_job": "facilities_engineer", "mode": "hardwired_local_repair", "equipment": "local_environmental_monitoring_console"},
		{"action": "record_repair", "station": "plant", "actor_job": "facilities_engineer", "mode": "hardwired_local_repair", "equipment": "local_environmental_monitoring_console"},
		{"action": "functional_test", "station": "plant", "actor_job": "facilities_engineer", "mode": "hardwired_local_test", "equipment": "local_environmental_monitoring_console"},
	], [
		{"kind": "manual_observation_round", "room_assignments": [{"room": "archive_stack", "actor_job": "archive_custodian"}, {"room": "compute_core", "actor_job": "systems_administrator"}, {"room": "security_control", "actor_job": "security_officer"}], "observations": ["temperature", "relative_humidity", "water_intrusion", "smoke_or_local_alarm"], "interval_ticks": 4, "duration_ticks_per_room": 2, "max_round_ticks": 12, "escalation": {"action": "review_protective_safe_hold", "station": "security_control", "actor_job": "duty_officer", "decisions": ["archive_safe_hold", "compute_safe_shutdown", "evacuate_affected_rooms"], "release": {"action": "release_protective_posture", "authority_job": "duty_officer", "authority_station": "security_control", "concurrence_job": "archive_custodian", "concurrence_station": "archive_processing", "required_evidence": "monitoring_normal_and_post_decision_round", "duration_ticks": 2}}, "hazard_rules": [{"room": "archive_stack", "reading": "smoke_or_local_alarm", "classification": "archive_fire_or_local_alarm", "recommended_decision": "evacuate_affected_rooms", "evacuation": {"destination": "emergency_exit", "accountability_job": "security_officer", "accountability_station": "security_control"}, "remediation": {"actor_job": "facilities_engineer", "station": "plant", "duration_ticks": 2, "verification_job": "security_officer", "verification_station": "security_control", "verification_duration_ticks": 2, "clear_readings": ["water_intrusion", "smoke_or_local_alarm"], "closure_scope": "local_alarm_controls_only", "inspection": {"response_job":"fire_scene_inspector","destination":"archive_stack","duration_ticks":2,"authority_job":"duty_officer","authority_station":"security_control","required_evidence":["no_active_fire","atmosphere_safe_for_entry","structural_access_safe"],"clearance_scope":"limited_inspection_clearance", "reentry":{"action":"authorize_room_reentry","authority_job":"duty_officer","authority_station":"security_control","concurrence_job":"archive_custodian","concurrence_station":"archive_processing","duration_ticks":2}}}}, {"room": "archive_stack", "reading": "water_intrusion", "classification": "archive_water_intrusion", "recommended_decision": "archive_safe_hold", "remediation": {"actor_job": "facilities_engineer", "station": "plant", "duration_ticks": 2, "verification_job": "archive_custodian", "verification_station": "archive_stack", "verification_duration_ticks": 2, "clear_readings": ["water_intrusion", "smoke_or_local_alarm"]}}, {"room": "compute_core", "reading": "smoke_or_local_alarm", "classification": "compute_fire_or_local_alarm", "recommended_decision": "evacuate_affected_rooms", "evacuation":{"destination":"emergency_exit","accountability_job":"security_officer","accountability_station":"security_control"}, "remediation":{"actor_job":"facilities_engineer","station":"plant","duration_ticks":2,"verification_job":"security_officer","verification_station":"security_control","verification_duration_ticks":2,"clear_readings":["water_intrusion","smoke_or_local_alarm"],"closure_scope":"local_alarm_controls_only","inspection":{"response_job":"fire_scene_inspector","destination":"compute_core","duration_ticks":2,"authority_job":"duty_officer","authority_station":"security_control","required_evidence":["no_active_fire","atmosphere_safe_for_entry","structural_access_safe"],"clearance_scope":"limited_inspection_clearance","reentry":{"action":"authorize_room_reentry","authority_job":"duty_officer","authority_station":"security_control","concurrence_job":"systems_administrator","concurrence_station":"cyber_ops","duration_ticks":2,"post_reentry_posture":"safe_shutdown"}},"reactivation":{"action":"reactivate_compute_after_hazard","authority_job":"duty_officer","authority_station":"security_control","concurrence_job":"systems_administrator","concurrence_station":"compute_core","duration_ticks":2,"required_reentry":true}}}, {"room": "compute_core", "reading": "water_intrusion", "classification": "compute_water_intrusion", "recommended_decision": "compute_safe_shutdown", "remediation": {"actor_job": "facilities_engineer", "station": "plant", "duration_ticks": 2, "verification_job": "systems_administrator", "verification_station": "compute_core", "verification_duration_ticks": 2, "clear_readings": ["water_intrusion", "smoke_or_local_alarm"], "reactivation": {"action": "reactivate_compute_after_hazard", "authority_job": "duty_officer", "authority_station": "security_control", "concurrence_job": "systems_administrator", "concurrence_station": "compute_core", "duration_ticks": 2}}}, {"room": "security_control", "reading": "smoke_or_local_alarm", "classification": "security_control_fire_or_local_alarm", "recommended_decision": "evacuate_affected_rooms", "evacuation":{"destination":"emergency_exit","accountability_job":"security_officer","accountability_station":"staff_control","displaced_command":{"action":"establish_displaced_command","actor_job":"duty_officer","station":"staff_control"}},"remediation":{"authorization":{"action":"authorize_alarm_stabilization","actor_job":"duty_officer","station":"staff_control","required_displaced_command":true},"actor_job":"facilities_engineer","station":"plant","duration_ticks":2,"verification_job":"security_officer","verification_station":"staff_control","verification_duration_ticks":2,"clear_readings":["water_intrusion","smoke_or_local_alarm"],"closure_scope":"local_alarm_controls_only","inspection":{"response_job":"fire_scene_inspector","destination":"security_control","duration_ticks":2,"authority_job":"duty_officer","authority_station":"staff_control","escort_job":"security_officer","escort_station":"staff_control","required_displaced_command":true,"required_evidence":["no_active_fire","atmosphere_safe_for_entry","structural_access_safe"],"clearance_scope":"limited_inspection_clearance","reentry":{"action":"authorize_room_reentry","authority_job":"duty_officer","authority_station":"staff_control","concurrence_job":"security_officer","concurrence_station":"staff_control","duration_ticks":2,"required_displaced_command":true,"command_restoration":{"action":"restore_primary_command","displaced_job":"duty_officer","displaced_station":"staff_control","primary_job":"duty_officer","primary_station":"security_control","duration_ticks":2}}}}}, {"room": "security_control", "reading": "water_intrusion", "classification": "security_control_water_intrusion", "recommended_decision": "evacuate_affected_rooms"}], "log_station": "plant", "log_owner_job": "facilities_engineer"},
	])


func _validate_required_content(errors: Array[String]) -> void:
	for room_id in REQUIRED_MISSION_ROOMS:
		if not rooms.has(room_id):
			errors.append("missing required room: %s" % room_id)
	for job_id in REQUIRED_JOBS:
		if not jobs.has(job_id):
			errors.append("missing required job: %s" % job_id)


func _validate_ownership(errors: Array[String]) -> void:
	for room_id in rooms:
		var room: Dictionary = rooms[room_id]
		var owners: Array = room["owners"]
		if owners.is_empty():
			errors.append("room has no owner: %s" % room_id)
		for owner in owners:
			if not jobs.has(owner):
				errors.append("room %s references missing owner %s" % [room_id, owner])
		for access_role in room["access_roles"]:
			if not jobs.has(access_role):
				errors.append("room %s grants access to missing role %s" % [room_id, access_role])
	for job_id in jobs:
		var station: String = jobs[job_id]["station"]
		if not rooms.has(station):
			errors.append("job %s has missing station %s" % [job_id, station])


func _validate_equipment(errors: Array[String]) -> void:
	for equipment_id in equipment:
		var item: Dictionary = equipment[equipment_id]
		var room_id: String = item["room"]
		var owner_job: String = item["owner_job"]
		if not rooms.has(room_id):
			errors.append("equipment %s has missing room %s" % [equipment_id, room_id])
		if not jobs.has(owner_job):
			errors.append("equipment %s has missing owner %s" % [equipment_id, owner_job])
		for requirement in item["utility_requirements"]:
			var dependency_found := false
			for edge in dependency_edges:
				if edge["consumer"] == room_id and edge["kind"] == requirement and rooms.has(edge["provider"]):
					dependency_found = true
					break
			if not dependency_found:
				errors.append("equipment %s lacks %s service at %s" % [equipment_id, requirement, room_id])


func _validate_mission_cycle(errors: Array[String]) -> void:
	if mission_steps.is_empty():
		errors.append("mission cycle is empty")
		return
	var available_artifacts: Dictionary = {}
	for step in mission_steps:
		var step_id: String = step["id"]
		if not jobs.has(step["owner_job"]):
			errors.append("mission step %s has missing owner %s" % [step_id, step["owner_job"]])
		if not rooms.has(step["station"]):
			errors.append("mission step %s has missing station %s" % [step_id, step["station"]])
		for input_name in step["inputs"]:
			if not available_artifacts.has(input_name):
				errors.append("mission step %s lacks upstream input %s" % [step_id, input_name])
		for equipment_id in step["required_equipment"]:
			if not equipment.has(equipment_id):
				errors.append("mission step %s lacks equipment %s" % [step_id, equipment_id])
			elif equipment[equipment_id]["room"] != step["station"]:
				errors.append("mission step %s equipment %s is not at station %s" % [step_id, equipment_id, step["station"]])
		for output_name in step["outputs"]:
			available_artifacts[output_name] = step_id


func _validate_material_custody_path(errors: Array[String]) -> void:
	for room_id in MATERIAL_CUSTODY_CHAIN:
		if not rooms.has(room_id):
			errors.append("custody chain missing required room: %s" % room_id)
	for index in MATERIAL_CUSTODY_CHAIN.size() - 1:
		var from_room: String = MATERIAL_CUSTODY_CHAIN[index]
		var to_room: String = MATERIAL_CUSTODY_CHAIN[index + 1]
		if rooms.has(from_room) and rooms.has(to_room) and not has_path(from_room, to_room, "material"):
			errors.append("custody chain is broken between %s and %s" % [from_room, to_room])
	if not has_path("loading", "archive_stack", "material"):
		errors.append("no complete screened material path from loading to archive storage")


func _validate_critical_dependencies(errors: Array[String]) -> void:
	for room_id in rooms:
		var requirements: Array = rooms[room_id]["critical_requirements"]
		for kind in requirements:
			var found := false
			for edge in dependency_edges:
				if edge["consumer"] == room_id and edge["kind"] == kind and rooms.has(edge["provider"]):
					found = true
					break
			if not found:
				errors.append("critical room %s lacks %s dependency" % [room_id, kind])


func _validate_security_transitions(errors: Array[String]) -> void:
	for edge in circulation_edges:
		if edge["flow"] != "personnel":
			continue
		if not rooms.has(edge["from"]) or not rooms.has(edge["to"]):
			continue
		var from_tier: int = rooms[edge["from"]]["security_tier"]
		var to_tier: int = rooms[edge["to"]]["security_tier"]
		if to_tier - from_tier >= 2 and not bool(edge["policy_transition"]):
			errors.append("unguarded security-tier jump: %s -> %s" % [edge["from"], edge["to"]])


func _validate_egress(errors: Array[String]) -> void:
	if not rooms.has("emergency_exit"):
		errors.append("missing emergency exit")
		return
	for room_id in rooms:
		if bool(rooms[room_id]["occupied"]) and not has_path(room_id, "emergency_exit", "egress"):
			errors.append("occupied room has no emergency egress: %s" % room_id)


func _validate_failure_procedures(errors: Array[String]) -> void:
	var covered: Dictionary = {}
	for procedure_id in failure_procedures:
		var procedure: Dictionary = failure_procedures[procedure_id]
		var owner_job: String = procedure["owner_job"]
		var station: String = procedure["station"]
		if not jobs.has(owner_job):
			errors.append("failure procedure %s has missing owner %s" % [procedure_id, owner_job])
		if not rooms.has(station):
			errors.append("failure procedure %s has missing station %s" % [procedure_id, station])
		if (procedure["preserves"] as Array).is_empty():
			errors.append("failure procedure %s preserves no essential function" % procedure_id)
		for capability in procedure["capabilities"]:
			covered[capability] = true
	for capability in REQUIRED_FAILURE_CAPABILITIES:
		if not covered.has(capability):
			errors.append("no degraded-day procedure covers %s failure" % capability)


func _validate_operations_response_policies(errors: Array[String]) -> void:
	for policy_id in ["power", "cooling", "communications", "custody:contain_incident", "custody:record_quarantine_disposition"]:
		if not operations_response_policies.has(policy_id):
			errors.append("Missing operations response policy: %s" % policy_id)
			continue
		var policy: Dictionary = operations_response_policies[policy_id]
		var expected_action: String = "mission_safe_hold" if policy_id.begins_with("custody:") else "mobilize_qualified_relief"
		var failure_action_valid: bool = policy_id.begins_with("custody:") or policy.get("relief_failure_action", "") == "mission_shutdown"
		var reactivation_valid: bool = policy_id.begins_with("custody:") or (jobs.has(policy.get("reactivation_authority_job", "")) and rooms.has(policy.get("reactivation_station", "")) and bool(jobs[policy["reactivation_authority_job"]]["continuous"]) and jobs[policy["reactivation_authority_job"]]["station"] == policy["reactivation_station"])
		if int(policy.get("priority", 0)) < 1 or int(policy.get("deadline_ticks", 0)) < 1 or int(policy.get("retry_backoff_ticks", 0)) < 1 or int(policy.get("max_wait_ticks", 0)) < int(policy.get("deadline_ticks", 0)) or int(policy.get("station_capacity", 0)) < 1 or policy.get("abandonment_action", "") != expected_action or not failure_action_valid or not reactivation_valid:
			errors.append("Invalid operations response policy: %s" % policy_id)


func _validate_facility_control_system_policy(errors: Array[String]) -> void:
	var cia: Dictionary = facility_control_system_policy.get("minimum_cia_categorization", {})
	var required: Array = ["power", "cooling", "communications", "access_control", "environmental_monitoring"]
	if facility_control_system_policy.get("cybersecurity_standard", "") != "UFC 4-010-06" or not bool(facility_control_system_policy.get("mission_owner_coordination", false)) or cia.get("confidentiality", "") != "moderate" or cia.get("integrity", "") != "moderate" or cia.get("availability", "") != "moderate":
		errors.append("Invalid mission-critical facility control-system cybersecurity policy")
	for system_id in required:
		if system_id not in facility_control_system_policy.get("applies_to", []): errors.append("Facility control-system policy omits: %s" % system_id)
	var executable: Array = facility_control_system_policy.get("executable_recovery_services", [])
	var policy_only: Array = facility_control_system_policy.get("policy_only_services", [])
	for system_id in required:
		var classification_count: int = int(executable.has(system_id)) + int(policy_only.has(system_id))
		if classification_count != 1: errors.append("Facility control-system recovery scope is ambiguous: %s" % system_id)
		if executable.has(system_id) and not service_continuity_profiles.has(system_id): errors.append("Facility control-system service claims executable recovery without continuity authority: %s" % system_id)
		if policy_only.has(system_id) and service_continuity_profiles.has(system_id): errors.append("Facility control-system service is mislabeled policy-only: %s" % system_id)


func _validate_mutual_aid_policy(errors: Array[String]) -> void:
	for field in ["staging_room", "authority_job", "authority_station", "escort_job", "escort_station", "credential_mode"]:
		if String(mutual_aid_policy.get(field, "")).is_empty(): errors.append("Mutual-aid policy field is missing: %s" % field); return
	var authority_job: String = mutual_aid_policy["authority_job"]
	var escort_job: String = mutual_aid_policy["escort_job"]
	if not jobs.has(authority_job) or not jobs.has(escort_job) or not rooms.has(mutual_aid_policy["staging_room"]) or not rooms.has(mutual_aid_policy["authority_station"]) or not rooms.has(mutual_aid_policy["escort_station"]):
		errors.append("Mutual-aid policy references unknown graph identity"); return
	if not bool(jobs[authority_job]["continuous"]) or not bool(jobs[escort_job]["continuous"]) or jobs[authority_job]["station"] != mutual_aid_policy["authority_station"] or jobs[escort_job]["station"] != mutual_aid_policy["escort_station"]:
		errors.append("Mutual-aid authority or escort station is invalid")
	if mutual_aid_policy["staging_room"] != "screened_entry" or mutual_aid_policy["credential_mode"] != "incident_scoped_temporary":
		errors.append("Mutual-aid staging or credential mode is unsafe")


func _validate_service_continuity_profiles(errors: Array[String]) -> void:
	for service_id in facility_control_system_policy.get("executable_recovery_services", []):
		if not service_continuity_profiles.has(service_id):
			errors.append("critical service has no staged continuity profile: %s" % service_id)
			continue
		var profile: Dictionary = service_continuity_profiles[service_id]
		if String(profile["failure_phase"]).is_empty():
			errors.append("service continuity profile has no failure phase: %s" % service_id)
		for room_id in profile["preserved_rooms"]:
			if not rooms.has(room_id):
				errors.append("service continuity profile %s preserves missing room %s" % [service_id, room_id])
		var expected_from: String = profile["failure_phase"]
		for transition_index in profile["transitions"].size():
			var transition: Dictionary = profile["transitions"][transition_index]
			if transition["from"] != expected_from:
				errors.append("service continuity profile %s has discontinuous response" % service_id)
			if not jobs.has(transition["actor_job"]):
				errors.append("service continuity profile %s has missing actor job" % service_id)
			if not rooms.has(transition["station"]):
				errors.append("service continuity profile %s has missing response station" % service_id)
			if transition_index == 0:
				var alternates: Array = transition.get("alternate_controls", [])
				if alternates.is_empty():
					errors.append("service continuity profile %s initial response has no degraded alternate control" % service_id)
				for alternate in alternates:
					var station: String = alternate.get("station", "")
					var actor_job: String = alternate.get("actor_job", "")
					var equipment_id: String = alternate.get("equipment", "")
					if station == transition["station"] or not rooms.has(station):
						errors.append("service continuity profile %s has invalid alternate station" % service_id)
						continue
					if not jobs.has(actor_job) or not (rooms[station]["access_roles"] as Array).has(actor_job):
						errors.append("service continuity profile %s has unauthorized alternate actor" % service_id)
					if String(alternate.get("mode", "")).is_empty():
						errors.append("service continuity profile %s alternate control has no mode" % service_id)
					if not equipment.has(equipment_id) or equipment[equipment_id]["room"] != station or equipment[equipment_id]["owner_job"] != actor_job:
						errors.append("service continuity profile %s alternate control lacks owned station equipment" % service_id)
					for requirement in rooms[station]["critical_requirements"]:
						if requirement == service_id:
							continue
						if not service_continuity_profiles.has(requirement) or not (service_continuity_profiles[requirement]["preserved_rooms"] as Array).has(station):
							errors.append("service continuity profile %s alternate control is not survivable during %s failure" % [service_id, requirement])
			expected_from = transition["to"]
		if expected_from != "repair_pending":
			errors.append("service continuity profile %s never reaches repair isolation" % service_id)
		var recovery_actions: Dictionary = {}
		for control in profile.get("recovery_controls", []):
			var action: String = control.get("action", "")
			var station: String = control.get("station", "")
			var actor_job: String = control.get("actor_job", "")
			var equipment_id: String = control.get("equipment", "")
			if action not in ["begin_repair", "record_repair", "functional_test"] or recovery_actions.has(action):
				errors.append("service continuity profile %s has invalid or duplicate degraded recovery action" % service_id)
			recovery_actions[action] = true
			if not rooms.has(station):
				errors.append("service continuity profile %s has missing degraded recovery station" % service_id)
				continue
			if not jobs.has(actor_job) or not (rooms[station]["access_roles"] as Array).has(actor_job):
				errors.append("service continuity profile %s has unauthorized degraded recovery actor" % service_id)
			if String(control.get("mode", "")).is_empty() or control.get("mode", "") == "primary_control":
				errors.append("service continuity profile %s degraded recovery control has invalid mode" % service_id)
			if not equipment.has(equipment_id) or equipment[equipment_id]["room"] != station or equipment[equipment_id]["owner_job"] != actor_job:
				errors.append("service continuity profile %s degraded recovery control lacks owned station equipment" % service_id)
		for required_action in ["begin_repair", "record_repair", "functional_test"]:
			if not recovery_actions.has(required_action): errors.append("service continuity profile %s lacks degraded recovery action: %s" % [service_id, required_action])
		var verification_controls: Array = profile.get("verification_controls", [])
		if verification_controls.is_empty():
			errors.append("service continuity profile %s has no degraded independent verification control" % service_id)
		for control in verification_controls:
			var station: String = control.get("station", "")
			var actor_job: String = control.get("actor_job", "")
			var equipment_id: String = control.get("equipment", "")
			if not rooms.has(station):
				errors.append("service continuity profile %s has missing degraded verification station" % service_id)
				continue
			if not jobs.has(actor_job) or not bool(jobs[actor_job].get("continuous", false)) or not (rooms[station]["access_roles"] as Array).has(actor_job):
				errors.append("service continuity profile %s has unauthorized degraded verifier" % service_id)
			if actor_job == profile["transitions"][-1]["actor_job"] or control.get("separation", "") != "not_repair_actor":
				errors.append("service continuity profile %s degraded verification collapses repair separation" % service_id)
			if control.get("required_evidence", "") != "passed_functional_test":
				errors.append("service continuity profile %s degraded verification lacks passed-test evidence policy" % service_id)
			if control.get("mode", "") != "hardwired_reconstitution_authority":
				errors.append("service continuity profile %s degraded verification has invalid authority mode" % service_id)
			if not equipment.has(equipment_id) or equipment[equipment_id]["room"] != station or equipment[equipment_id]["owner_job"] != actor_job:
				errors.append("service continuity profile %s degraded verification lacks owned station equipment" % service_id)
			for requirement in rooms[station]["critical_requirements"]:
				if requirement == service_id:
					continue
				if not service_continuity_profiles.has(requirement) or not (service_continuity_profiles[requirement]["preserved_rooms"] as Array).has(station):
					errors.append("service continuity profile %s degraded verification is not survivable during %s failure" % [service_id, requirement])
		var degraded_obligations: Array = profile.get("degraded_obligations", [])
		if service_id == "environmental_monitoring" and degraded_obligations.size() != 1:
			errors.append("environmental monitoring requires exactly one manual observation round obligation")
		for obligation in degraded_obligations:
			var room_assignments: Array = obligation.get("room_assignments", [])
			var assigned_rooms: Array = room_assignments.map(func(assignment): return assignment.get("room", ""))
			var observation_kinds: Array = obligation.get("observations", [])
			var log_station: String = obligation.get("log_station", "")
			var log_owner_job: String = obligation.get("log_owner_job", "")
			if obligation.get("kind", "") != "manual_observation_round":
				errors.append("service continuity profile %s has invalid degraded observation kind" % service_id)
			if assigned_rooms != profile["preserved_rooms"] or room_assignments.any(func(assignment): return not rooms.has(assignment.get("room", "")) or not jobs.has(assignment.get("actor_job", "")) or not (rooms[assignment.get("room", "")]["access_roles"] as Array).has(assignment.get("actor_job", ""))):
				errors.append("service continuity profile %s degraded observation round does not cover preserved rooms with local authorized observers in order" % service_id)
			if observation_kinds != ["temperature", "relative_humidity", "water_intrusion", "smoke_or_local_alarm"]:
				errors.append("service continuity profile %s degraded observation round lacks required hazard observations" % service_id)
			if int(obligation.get("interval_ticks", 0)) < 1 or int(obligation.get("duration_ticks_per_room", 0)) < 1:
				errors.append("service continuity profile %s degraded observation round has invalid timing" % service_id)
			var maximum_round_ticks: int = int(obligation.get("max_round_ticks", 0))
			var escalation: Dictionary = obligation.get("escalation", {})
			var escalation_station: String = escalation.get("station", "")
			var escalation_job: String = escalation.get("actor_job", "")
			if maximum_round_ticks < int(obligation.get("duration_ticks_per_room", 0)) * room_assignments.size():
				errors.append("service continuity profile %s degraded observation deadline cannot cover nominal work" % service_id)
			if escalation.get("action", "") != "review_protective_safe_hold" or escalation.get("decisions", []) != ["archive_safe_hold", "compute_safe_shutdown", "evacuate_affected_rooms"] or not rooms.has(escalation_station) or not jobs.has(escalation_job) or not bool(jobs[escalation_job].get("continuous", false)) or not (rooms[escalation_station]["access_roles"] as Array).has(escalation_job):
				errors.append("service continuity profile %s degraded observation escalation lacks continuous command authority" % service_id)
			var release_policy: Dictionary = escalation.get("release", {})
			var release_authority_job: String = release_policy.get("authority_job", "")
			var release_concurrence_job: String = release_policy.get("concurrence_job", "")
			if release_policy.get("action", "") != "release_protective_posture" or release_policy.get("required_evidence", "") != "monitoring_normal_and_post_decision_round" or int(release_policy.get("duration_ticks", 0)) < 1 or release_authority_job == release_concurrence_job or not jobs.has(release_authority_job) or not jobs.has(release_concurrence_job) or not bool(jobs[release_authority_job].get("continuous", false)) or not rooms.has(release_policy.get("authority_station", "")) or not rooms.has(release_policy.get("concurrence_station", "")) or not (rooms[release_policy["authority_station"]]["access_roles"] as Array).has(release_authority_job) or not (rooms[release_policy["concurrence_station"]]["access_roles"] as Array).has(release_concurrence_job):
				errors.append("service continuity profile %s degraded observation release lacks separated authority" % service_id)
			var hazard_pairs: Dictionary = {}
			var hazard_classes: Dictionary = {}
			for hazard_rule in obligation.get("hazard_rules", []):
				var hazard_pair: String = String(hazard_rule.get("room", "")) + ":" + String(hazard_rule.get("reading", ""))
				var hazard_class: String = hazard_rule.get("classification", "")
				if hazard_rule.get("room", "") not in profile["preserved_rooms"] or hazard_rule.get("reading", "") not in ["water_intrusion", "smoke_or_local_alarm"] or hazard_class.is_empty() or hazard_pairs.has(hazard_pair) or hazard_classes.has(hazard_class) or hazard_rule.get("recommended_decision", "") not in escalation.get("decisions", []): errors.append("service continuity profile %s has invalid environmental hazard rule" % service_id)
				var remediation_policy: Dictionary = hazard_rule.get("remediation", {})
				if not remediation_policy.is_empty():
					if not jobs.has(remediation_policy.get("actor_job", "")) or not jobs.has(remediation_policy.get("verification_job", "")) or remediation_policy.get("actor_job", "") == remediation_policy.get("verification_job", ""): errors.append("service continuity profile %s hazard remediation requires distinct known jobs" % service_id)
					if not rooms.has(remediation_policy.get("station", "")) or not rooms.has(remediation_policy.get("verification_station", "")): errors.append("service continuity profile %s hazard remediation requires known stations" % service_id)
					elif not rooms[remediation_policy["station"]]["access_roles"].has(remediation_policy.get("actor_job", "")) or not rooms[remediation_policy["verification_station"]]["access_roles"].has(remediation_policy.get("verification_job", "")): errors.append("service continuity profile %s hazard remediation station access invalid" % service_id)
					if int(remediation_policy.get("duration_ticks", 0)) <= 0 or int(remediation_policy.get("verification_duration_ticks", 0)) <= 0: errors.append("service continuity profile %s hazard remediation durations must be positive" % service_id)
					if remediation_policy.get("clear_readings", []) != ["water_intrusion", "smoke_or_local_alarm"]: errors.append("service continuity profile %s hazard remediation clear readings invalid" % service_id)
					if hazard_class.ends_with("fire_or_local_alarm") and remediation_policy.get("closure_scope", "") != "local_alarm_controls_only": errors.append("service continuity profile %s alarm stabilization must not claim room re-entry clearance" % service_id)
					var remediation_authorization_policy: Dictionary=remediation_policy.get("authorization",{})
					if not remediation_authorization_policy.is_empty() and (remediation_authorization_policy.get("action","")!="authorize_alarm_stabilization" or remediation_authorization_policy.get("actor_job","")!="duty_officer" or not rooms.has(remediation_authorization_policy.get("station","")) or not (rooms[remediation_authorization_policy.get("station","")].get("access_roles",[]) as Array).has(remediation_authorization_policy.get("actor_job","")) or remediation_authorization_policy.get("required_displaced_command",false)!=true): errors.append("service continuity profile %s hazard remediation authorization invalid" % service_id)
					var inspection_policy: Dictionary=remediation_policy.get("inspection",{})
					if hazard_class.ends_with("fire_or_local_alarm") and not inspection_policy.is_empty():
						if inspection_policy.get("response_job","")!="fire_scene_inspector" or inspection_policy.get("destination","")!=hazard_rule.get("room","") or int(inspection_policy.get("duration_ticks",0))<1 or inspection_policy.get("authority_job","")!="duty_officer" or not rooms.has(inspection_policy.get("authority_station","")) or not (rooms[inspection_policy.get("authority_station","")].get("access_roles",[]) as Array).has(inspection_policy.get("authority_job","")) or inspection_policy.get("required_evidence",[])!=["no_active_fire","atmosphere_safe_for_entry","structural_access_safe"] or inspection_policy.get("clearance_scope","")!="limited_inspection_clearance": errors.append("service continuity profile %s fire inspection policy invalid" % service_id)
						var reentry_policy: Dictionary=inspection_policy.get("reentry",{})
						if not reentry_policy.is_empty():
							if reentry_policy.get("action","")!="authorize_room_reentry" or reentry_policy.get("authority_job","")!="duty_officer" or not rooms.has(reentry_policy.get("authority_station","")) or not (rooms[reentry_policy.get("authority_station","")].get("access_roles",[]) as Array).has(reentry_policy.get("authority_job","")) or not jobs.has(reentry_policy.get("concurrence_job","")) or reentry_policy.get("concurrence_job","")==reentry_policy.get("authority_job","") or not rooms.has(reentry_policy.get("concurrence_station","")) or not (rooms[reentry_policy.get("concurrence_station","")].get("access_roles",[]) as Array).has(reentry_policy.get("concurrence_job","")) or int(reentry_policy.get("duration_ticks",0))<1: errors.append("service continuity profile %s room re-entry policy invalid" % service_id)
							if reentry_policy.get("post_reentry_posture","") not in ["","safe_shutdown"]: errors.append("service continuity profile %s room re-entry terminal posture invalid" % service_id)
							if reentry_policy.get("required_displaced_command",false) and (not inspection_policy.get("required_displaced_command",false) or reentry_policy.get("authority_station","")!=inspection_policy.get("authority_station","")): errors.append("service continuity profile %s displaced-command re-entry policy invalid" % service_id)
							var command_restoration_policy: Dictionary=reentry_policy.get("command_restoration",{})
							if not command_restoration_policy.is_empty() and (command_restoration_policy.get("action","")!="restore_primary_command" or command_restoration_policy.get("displaced_job","")!="duty_officer" or command_restoration_policy.get("primary_job","")!="duty_officer" or command_restoration_policy.get("displaced_station","")!=reentry_policy.get("authority_station","") or command_restoration_policy.get("primary_station","")!=hazard_rule.get("room","") or int(command_restoration_policy.get("duration_ticks",0))<1): errors.append("service continuity profile %s primary command restoration policy invalid" % service_id)
					var reactivation_policy: Dictionary = remediation_policy.get("reactivation", {})
					if not reactivation_policy.is_empty():
						if reactivation_policy.get("action", "") != "reactivate_compute_after_hazard" or not jobs.has(reactivation_policy.get("authority_job", "")) or not jobs.has(reactivation_policy.get("concurrence_job", "")) or reactivation_policy.get("authority_job", "") == reactivation_policy.get("concurrence_job", ""): errors.append("service continuity profile %s compute reactivation authority invalid" % service_id)
						if not rooms.has(reactivation_policy.get("authority_station", "")) or not rooms.has(reactivation_policy.get("concurrence_station", "")) or int(reactivation_policy.get("duration_ticks", 0)) <= 0: errors.append("service continuity profile %s compute reactivation station or duration invalid" % service_id)
						elif not rooms[reactivation_policy["authority_station"]]["access_roles"].has(reactivation_policy.get("authority_job", "")) or not rooms[reactivation_policy["concurrence_station"]]["access_roles"].has(reactivation_policy.get("concurrence_job", "")): errors.append("service continuity profile %s compute reactivation station access invalid" % service_id)
				var evacuation_policy: Dictionary = hazard_rule.get("evacuation", {})
				if not evacuation_policy.is_empty():
					if hazard_rule.get("recommended_decision", "") != "evacuate_affected_rooms" or not rooms.has(evacuation_policy.get("destination", "")) or rooms.get(evacuation_policy.get("destination", ""), {}).get("zone", "") != "egress" or not jobs.has(evacuation_policy.get("accountability_job", "")) or not bool(jobs.get(evacuation_policy.get("accountability_job", ""), {}).get("continuous", false)) or not rooms.has(evacuation_policy.get("accountability_station", "")): errors.append("service continuity profile %s evacuation policy invalid" % service_id)
					elif not (rooms[evacuation_policy["accountability_station"]].get("access_roles", []) as Array).has(evacuation_policy["accountability_job"]): errors.append("service continuity profile %s evacuation accountability lacks station access" % service_id)
					var displaced_command_policy: Dictionary=evacuation_policy.get("displaced_command",{})
					if not displaced_command_policy.is_empty() and (displaced_command_policy.get("action","")!="establish_displaced_command" or displaced_command_policy.get("actor_job","")!="duty_officer" or not rooms.has(displaced_command_policy.get("station","")) or not (rooms[displaced_command_policy.get("station","")].get("access_roles",[]) as Array).has(displaced_command_policy.get("actor_job",""))): errors.append("service continuity profile %s displaced command policy invalid" % service_id)
				hazard_pairs[hazard_pair] = true; hazard_classes[hazard_class] = true
			if hazard_pairs.size() != (profile["preserved_rooms"] as Array).size() * 2: errors.append("service continuity profile %s environmental hazard rules lack protected-room coverage" % service_id)
			if not rooms.has(log_station) or not jobs.has(log_owner_job) or not (rooms[log_station]["access_roles"] as Array).has(log_owner_job):
				errors.append("service continuity profile %s degraded observation round has invalid local log station" % service_id)
