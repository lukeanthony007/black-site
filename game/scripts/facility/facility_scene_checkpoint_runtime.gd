class_name FacilitySceneCheckpointRuntime
extends RefCounted
## Versioned, epoch-coupled checkpoint boundary for live facility operational owners.

const CHECKPOINT_VERSION := "generated-facility-scene/v1"
const OWNER_IDS: Array[String] = [
	"infrastructure", "staffing", "agents", "procedure_work",
	"procedure_receipts", "mission", "response_plan",
	"custody", "personnel_security", "control_room",
	"operations_queue",
	"mutual_aid",
	"control_network",
	"environmental_observations",
]


func build_checkpoint(
	epoch: int,
	facility_seed: int,
	graph_fingerprint: String,
	infrastructure_state: Dictionary,
	staffing_state: Dictionary,
	agent_state: Dictionary,
	work_snapshot: Dictionary,
	procedure_receipts: Dictionary,
	mission_state: Dictionary,
	response_plan_signature: Dictionary,
	custody_state: Dictionary,
	personnel_state: Dictionary,
	personnel_runtime_state: Dictionary,
	control_console_state: Dictionary,
	control_snapshot: Dictionary,
	operations_queue_state: Dictionary,
	mutual_aid_state: Dictionary,
	control_network_state: Dictionary = {"schema":"facility-control-network/v1","posture":"normal","active_incident":{},"functional_test":{},"history":[]},
	environmental_observation_state: Dictionary = {"active":false,"occurrence_id":"","clock":0,"next_round_clock":0,"round_counter":0,"obligation":{},"actors_by_job":{},"active_round":{},"completed_rounds":[],"observations":[]}
) -> Dictionary:
	if epoch < 1:
		return _denied("scene checkpoint epoch is invalid")
	var owners: Dictionary = {
		"infrastructure": {"epoch": epoch, "state": infrastructure_state.duplicate(true)},
		"staffing": {"epoch": epoch, "state": staffing_state.duplicate(true)},
		"agents": {"epoch": epoch, "state": agent_state.duplicate(true)},
		"procedure_work": {"epoch": epoch, "snapshot": work_snapshot.duplicate(true)},
		"procedure_receipts": {"epoch": epoch, "state": procedure_receipts.duplicate(true)},
		"mission": {"epoch": epoch, "state": mission_state.duplicate(true)},
		"response_plan": {"epoch": epoch, "signature": response_plan_signature.duplicate(true)},
		"custody": {"epoch": epoch, "state": custody_state.duplicate(true)},
		"personnel_security": {"epoch": epoch, "personnel_state": personnel_state.duplicate(true), "runtime_state": personnel_runtime_state.duplicate(true)},
		"control_room": {"epoch": epoch, "console_state": control_console_state.duplicate(true), "snapshot": control_snapshot.duplicate(true)},
		"operations_queue": {"epoch": epoch, "state": operations_queue_state.duplicate(true)},
		"mutual_aid": {"epoch": epoch, "state": mutual_aid_state.duplicate(true)},
		"control_network": {"epoch": epoch, "state": control_network_state.duplicate(true)},
		"environmental_observations": {"epoch": epoch, "state": environmental_observation_state.duplicate(true)},
	}
	return {
		"accepted": true,
		"version": CHECKPOINT_VERSION,
		"epoch": epoch,
		"facility_seed": facility_seed,
		"graph_fingerprint": graph_fingerprint,
		"owners": owners,
	}


func prepare_recovery(
	checkpoint: Dictionary,
	expected_seed: int,
	expected_fingerprint: String,
	graph: RefCounted,
	staffing_runtime: RefCounted,
	work_runtime: RefCounted,
	panel_definitions: Dictionary,
	mutual_aid_runtime: RefCounted,
	control_network_runtime: RefCounted = null,
	environmental_observation_runtime: RefCounted = null
) -> Dictionary:
	if checkpoint.get("version", "") != CHECKPOINT_VERSION:
		return _denied("scene checkpoint version is unsupported")
	var epoch: int = int(checkpoint.get("epoch", 0))
	if epoch < 1 or int(checkpoint.get("facility_seed", -1)) != expected_seed or checkpoint.get("graph_fingerprint", "") != expected_fingerprint:
		return _denied("scene checkpoint generation identity mismatch")
	if not checkpoint.get("owners", null) is Dictionary:
		return _denied("scene checkpoint owners are invalid")
	var owners: Dictionary = checkpoint["owners"]
	for owner_id in OWNER_IDS:
		if not owners.get(owner_id, null) is Dictionary or int(owners[owner_id].get("epoch", 0)) != epoch:
			return _denied("scene checkpoint owner epoch mismatch: %s" % owner_id)
	var infrastructure: Variant = owners["infrastructure"].get("state")
	var staffing: Variant = owners["staffing"].get("state")
	var agents: Variant = owners["agents"].get("state")
	var receipts: Variant = owners["procedure_receipts"].get("state")
	var mission: Variant = owners["mission"].get("state")
	var plan_signature: Variant = owners["response_plan"].get("signature")
	var custody: Variant = owners["custody"].get("state")
	var personnel: Variant = owners["personnel_security"].get("personnel_state")
	var personnel_runtime_state: Variant = owners["personnel_security"].get("runtime_state")
	var control_console: Variant = owners["control_room"].get("console_state")
	var control_snapshot: Variant = owners["control_room"].get("snapshot")
	var operations_queue: Variant = owners["operations_queue"].get("state")
	var mutual_aid: Variant = owners["mutual_aid"].get("state")
	var control_network: Variant = owners["control_network"].get("state")
	var environmental_observations: Variant = owners["environmental_observations"].get("state")
	if not infrastructure is Dictionary or not staffing is Dictionary or not agents is Dictionary or not receipts is Dictionary or not mission is Dictionary or not plan_signature is Dictionary or not custody is Dictionary or not personnel is Dictionary or not personnel_runtime_state is Dictionary or not control_console is Dictionary or not control_snapshot is Dictionary or not operations_queue is Dictionary or not mutual_aid is Dictionary or not control_network is Dictionary or not environmental_observations is Dictionary:
		return _denied("scene checkpoint owner state is invalid")
	var infrastructure_result: Dictionary = _validate_infrastructure(graph, infrastructure)
	var mutual_aid_result: Dictionary = mutual_aid_runtime.validate_state(mutual_aid)
	if not mutual_aid_result.get("accepted", false): return mutual_aid_result
	if mutual_aid_runtime.has_method("prepare_recovered_state"):
		var mutual_aid_recovery: Dictionary=mutual_aid_runtime.prepare_recovered_state(mutual_aid)
		if not mutual_aid_recovery.get("accepted",false): return mutual_aid_recovery
		mutual_aid=mutual_aid_recovery["state"]
	if control_network_runtime != null:
		var control_network_result: Dictionary = control_network_runtime.validate_state(control_network)
		if not control_network_result.get("accepted", false): return control_network_result
	elif control_network.get("schema", "") != "facility-control-network/v1": return _denied("scene checkpoint control-network state is invalid")
	if environmental_observation_runtime != null:
		var observation_recovery: Dictionary = environmental_observation_runtime.prepare_recovered_state(environmental_observations, graph.service_continuity_profiles["environmental_monitoring"]["degraded_obligations"][0])
		if not observation_recovery.get("accepted", false): return _denied("scene checkpoint environmental observations are invalid: %s" % observation_recovery.get("reason", "unknown"))
		environmental_observations = observation_recovery["state"]
	var monitoring_failure: Dictionary = infrastructure.get("active_failures", {}).get("environmental_monitoring", {})
	if environmental_observations.get("active", false):
		if monitoring_failure.is_empty() or environmental_observations.get("occurrence_id", "") != monitoring_failure.get("failure_id", ""):
			return _denied("scene checkpoint environmental observation occurrence mismatch")
	elif not monitoring_failure.is_empty():
		return _denied("scene checkpoint active monitoring failure lacks observation authority")
	if not infrastructure_result.get("accepted", false):
		return infrastructure_result
	var staffing_result: Dictionary = _validate_staffing(graph, staffing, staffing_runtime, operations_queue)
	if not staffing_result.get("accepted", false):
		return staffing_result
	var agent_result: Dictionary = _prepare_agents(graph, staffing, staffing_runtime, agents)
	if not agent_result.get("accepted", false):
		return agent_result
	var work_result: Dictionary = work_runtime.recover_snapshot(owners["procedure_work"].get("snapshot", {}))
	if not work_result.get("accepted", false):
		return _denied("scene checkpoint procedure work is invalid: %s" % work_result.get("reason", "unknown"))
	var receipt_result: Dictionary = _validate_receipts(infrastructure, receipts)
	if not receipt_result.get("accepted", false):
		return receipt_result
	var task_result: Dictionary = _validate_tasks(graph, staffing, work_result["state"], panel_definitions, control_network)
	if not task_result.get("accepted", false):
		return task_result
	var custody_work_result: Dictionary = _validate_custody_work(custody, work_result["state"])
	if not custody_work_result.get("accepted", false):
		return custody_work_result
	var mission_result: Dictionary = _validate_mission_services(graph, infrastructure, mission)
	if not mission_result.get("accepted", false):
		return mission_result
	if mission.get("room_protective_postures", {}) != environmental_observations.get("protective_postures", {}):
		return _denied("scene checkpoint mission protective-posture projection mismatch")
	var custody_result: Dictionary = _validate_custody(graph, custody)
	if not custody_result.get("accepted", false):
		return custody_result
	var personnel_result: Dictionary = _validate_personnel_security(graph, personnel, personnel_runtime_state)
	if not personnel_result.get("accepted", false):
		return personnel_result
	var control_result: Dictionary = _validate_control_room(graph, control_console, control_snapshot)
	if not control_result.get("accepted", false):
		return control_result
	var queue_result: Dictionary = _validate_operations_queue(operations_queue, work_result["state"], panel_definitions, mission, mutual_aid)
	if not queue_result.get("accepted", false):
		return queue_result
	return {
		"accepted": true,
		"epoch": epoch,
		"infrastructure_state": infrastructure.duplicate(true),
		"staffing_state": staffing.duplicate(true),
		"agent_state": agent_result["state"],
		"procedure_work_state": work_result["state"],
		"procedure_receipts": receipts.duplicate(true),
		"mission_state": mission.duplicate(true),
		"response_plan_signature": plan_signature.duplicate(true),
		"custody_state": custody.duplicate(true),
		"personnel_state": personnel.duplicate(true),
		"personnel_runtime_state": personnel_runtime_state.duplicate(true),
		"control_console_state": control_console.duplicate(true),
		"control_snapshot": control_snapshot.duplicate(true),
		"operations_queue_state": operations_queue.duplicate(true),
		"mutual_aid_state": mutual_aid.duplicate(true),
		"control_network_state": control_network.duplicate(true),
		"environmental_observation_state": environmental_observations.duplicate(true),
	}


func _validate_infrastructure(graph: RefCounted, state: Dictionary) -> Dictionary:
	for field in ["services", "service_states", "active_failures", "active_receipts"]:
		if not state.get(field, null) is Dictionary:
			return _denied("scene checkpoint infrastructure field is invalid: %s" % field)
	if not state.get("history", null) is Array or int(state.get("next_failure_number", 0)) < 1 or int(state.get("next_receipt_number", 0)) < 1:
		return _denied("scene checkpoint infrastructure history or counters are invalid")
	var expected_services: Dictionary = {}
	for edge in graph.dependency_edges:
		expected_services[edge["kind"]] = true
	for service_id in graph.service_continuity_profiles:
		expected_services[service_id] = true
	if not _same_keys(state["services"], expected_services) or not _same_keys(state["service_states"], expected_services):
		return _denied("scene checkpoint infrastructure service identity mismatch")
	for service_id in state["services"]:
		var available: bool = bool(state["services"][service_id])
		var has_failure: bool = state["active_failures"].has(service_id)
		if available == has_failure:
			return _denied("scene checkpoint infrastructure availability contradiction")
		if not available:
			if not graph.service_continuity_profiles.has(service_id):
				return _denied("scene checkpoint has unsupported active service failure")
			var failure: Dictionary = state["active_failures"][service_id]
			if failure.get("service", "") != service_id or String(failure.get("failure_id", "")).is_empty() or not graph.failure_procedures.has(failure.get("procedure", "")):
				return _denied("scene checkpoint active failure provenance mismatch")
			var allowed_phases: Array[String] = [graph.service_continuity_profiles[service_id]["failure_phase"], "repair_pending", "testing", "reconstitution_pending"]
			for transition in graph.service_continuity_profiles[service_id]["transitions"]:
				if not allowed_phases.has(transition["to"]):
					allowed_phases.append(transition["to"])
			if state["service_states"][service_id].get("phase", "") != failure.get("phase", "") or not allowed_phases.has(failure.get("phase", "")):
				return _denied("scene checkpoint active failure phase contradiction")
		elif state["service_states"][service_id].get("phase", "") != "normal":
			return _denied("scene checkpoint available service is not normal")
	for receipt_id in state["active_receipts"]:
		var receipt: Variant = state["active_receipts"][receipt_id]
		if not receipt is Dictionary or receipt.get("receipt_id", "") != receipt_id:
			return _denied("scene checkpoint infrastructure receipt identity mismatch")
		var service_id: String = receipt.get("service", "")
		if not state["active_failures"].has(service_id) or receipt.get("failure_id", "") != state["active_failures"][service_id].get("failure_id", ""):
			return _denied("scene checkpoint infrastructure receipt failure mismatch")
	return {"accepted": true}


func _validate_staffing(graph: RefCounted, state: Dictionary, staffing_runtime: RefCounted, operations_queue: Dictionary) -> Dictionary:
	var shutdown_jobs: Dictionary = {}
	for entry in operations_queue.get("entries", {}).values():
		if entry.get("status", "") == "mission_shutdown": shutdown_jobs[entry.get("actor_job", "")] = true
	for field in ["staff", "assignments", "relief", "active_relief", "incident_holdovers", "unavailable", "pending_turnover"]:
		if not state.get(field, null) is Dictionary:
			return _denied("scene checkpoint staffing field is invalid: %s" % field)
	if not state.get("incident_holdover_log",null) is Array: return _denied("scene checkpoint incident holdover log is invalid")
	if int(state.get("seed", -1)) != graph.seed or state.get("shift_ids", []) != ["day", "swing", "night"] or not (state.get("shift_ids", []) as Array).has(state.get("active_shift", "")):
		return _denied("scene checkpoint staffing generation or shift mismatch")
	for staff_id in state["staff"]:
		var member: Variant = state["staff"][staff_id]
		if not member is Dictionary or member.get("staff_id", "") != staff_id or not graph.jobs.has(member.get("job_id", "")):
			return _denied("scene checkpoint staffing member provenance mismatch")
	for shift_id in state["shift_ids"]:
		if not state["assignments"].get(shift_id, null) is Dictionary or not _same_keys(state["assignments"][shift_id], graph.jobs):
			return _denied("scene checkpoint staffing assignment identity mismatch")
		for job_id in graph.jobs:
			if not state["assignments"][shift_id][job_id] is Array:
				return _denied("scene checkpoint staffing assignment list is invalid")
			for staff_id in state["assignments"][shift_id][job_id]:
				if not state["staff"].has(staff_id) or state["staff"][staff_id]["job_id"] != job_id or state["staff"][staff_id]["shift"] != shift_id:
					return _denied("scene checkpoint staffing assignment provenance mismatch")
	if not _same_keys(state["relief"], graph.jobs) or not _same_keys(state["active_relief"], graph.jobs):
		return _denied("scene checkpoint relief identity mismatch")
	for job_id in graph.jobs:
		for staff_id in state["relief"][job_id]:
			if not state["staff"].has(staff_id) or state["staff"][staff_id]["job_id"] != job_id or state["staff"][staff_id]["assignment_type"] != "relief":
				return _denied("scene checkpoint relief provenance mismatch")
		for staff_id in state["active_relief"][job_id]:
			if not (state["relief"][job_id] as Array).has(staff_id):
				return _denied("scene checkpoint active relief is not a declared relief member")
		if bool(graph.jobs[job_id]["continuous"]) and staffing_runtime.active_staff_ids(state, job_id).size() < int(graph.jobs[job_id]["minimum_on_shift"]) and not shutdown_jobs.has(job_id):
			return _denied("scene checkpoint continuous staffing post is uncovered")
	for staff_id in state["incident_holdovers"]:
		var holdover: Dictionary=state["incident_holdovers"][staff_id]
		if not state["staff"].has(staff_id) or state["staff"][staff_id].get("job_id","")!=holdover.get("job_id","") or String(holdover.get("case_id","")).is_empty() or String(holdover.get("turnover_id","")).is_empty(): return _denied("scene checkpoint incident holdover provenance mismatch")
	for staff_id in state["unavailable"]:
		if not state["staff"].has(staff_id):
			return _denied("scene checkpoint unavailable staff identity is unknown")
	if not state["pending_turnover"].is_empty():
		var pending: Dictionary = state["pending_turnover"]
		if String(pending.get("turnover_id", "")).is_empty() or pending.get("from_shift", "") != state["active_shift"] or not (state["shift_ids"] as Array).has(pending.get("to_shift", "")):
			return _denied("scene checkpoint pending turnover provenance mismatch")
	return {"accepted": true}


func _prepare_agents(graph: RefCounted, staffing: Dictionary, staffing_runtime: RefCounted, supplied: Dictionary) -> Dictionary:
	if not supplied.get("agents", null) is Dictionary or not supplied.get("movement_log", null) is Array or int(supplied.get("next_event_number", 0)) < 1:
		return _denied("scene checkpoint agent state is invalid")
	var expected: Dictionary = {}
	for job_id in graph.jobs:
		for staff_id in staffing_runtime.active_staff_ids(staffing, job_id):
			expected[staff_id] = job_id
	if not _same_keys(supplied["agents"], expected):
		return _denied("scene checkpoint active-watch identity mismatch")
	var state: Dictionary = supplied.duplicate(true)
	for staff_id in state["agents"]:
		var agent: Dictionary = state["agents"][staff_id]
		if agent.get("staff_id", "") != staff_id or agent.get("job_id", "") != expected[staff_id] or not graph.rooms.has(agent.get("current_room", "")) or not graph.rooms.has(agent.get("destination", "")) or not agent.get("route", null) is Array:
			return _denied("scene checkpoint agent provenance mismatch")
		for room_id in agent["route"]:
			if not graph.rooms.has(room_id):
				return _denied("scene checkpoint agent route contains an unknown room")
		if not (agent["route"] as Array).is_empty() and agent["route"][-1] != agent["destination"]:
			return _denied("scene checkpoint agent route/destination mismatch")
		agent["route"] = []
		agent["destination"] = agent["current_room"]
		agent["status"] = "arrived"
		agent.erase("work_action")
		state["agents"][staff_id] = agent
	state["movement_log"].append({"event": "checkpoint_intent_reconciled", "event_number": state["next_event_number"]})
	state["next_event_number"] = int(state["next_event_number"]) + 1
	return {"accepted": true, "state": state}


func _validate_receipts(infrastructure: Dictionary, procedure_receipts: Dictionary) -> Dictionary:
	if procedure_receipts.size() != infrastructure["active_receipts"].size():
		return _denied("scene checkpoint recovery receipt ownership mismatch")
	for service_id in procedure_receipts:
		var receipt: Variant = procedure_receipts[service_id]
		if not receipt is Dictionary:
			return _denied("scene checkpoint procedure receipt is invalid")
		var receipt_id: String = receipt.get("receipt_id", "")
		if receipt.get("service", "") != service_id or not infrastructure["active_receipts"].has(receipt_id):
			return _denied("scene checkpoint procedure receipt identity mismatch")
		var authoritative: Dictionary = infrastructure["active_receipts"][receipt_id]
		for field in ["failure_id", "service", "procedure", "actor_person_id", "station"]:
			if receipt.get(field) != authoritative.get(field):
				return _denied("scene checkpoint procedure receipt provenance mismatch")
	return {"accepted": true}


func _validate_tasks(graph: RefCounted, staffing: Dictionary, work_state: Dictionary, panel_definitions: Dictionary, control_network: Dictionary) -> Dictionary:
	for task_id in work_state["tasks"]:
		var task: Dictionary = work_state["tasks"][task_id]
		if not panel_definitions.has(task["panel_id"]):
			return _denied("scene checkpoint work references unknown generated panel")
		var definition: Dictionary = panel_definitions[task["panel_id"]]
		for field in ["service", "action", "station", "actor_job", "control_mode", "equipment"]:
			if field == "control_mode" and task.get(field, "") == "temporary_mutual_aid":
				continue
			if task.get(field, "") != definition.get(field, ""):
				return _denied("scene checkpoint work/panel provenance mismatch")
		var task_services: Array = (task.get("required_services", []) as Array).duplicate()
		var definition_services: Array = (definition.get("required_services", []) as Array).duplicate()
		task_services.sort()
		definition_services.sort()
		if task_services != definition_services:
			return _denied("scene checkpoint work support provenance mismatch")
		if task.get("control_mode", "") != "temporary_mutual_aid" and (not staffing["staff"].has(task["actor_person_id"]) or staffing["staff"][task["actor_person_id"]]["job_id"] != task["actor_job"]):
			return _denied("scene checkpoint work/staff provenance mismatch")
		if not graph.rooms.has(task["station"]):
			return _denied("scene checkpoint work station is missing")
		if task.get("action", "") in ["control_network_functional_test", "control_network_reconstitute"]:
			var occurrence: String=task.get("initiator", ""); var matching_open: bool=false
			for event in control_network.get("history",[]):
				if event.get("kind","")=="automation_isolated" and event.get("occurrence_id","")==occurrence: matching_open=true; break
			if occurrence.is_empty() or not matching_open: return _denied("scene checkpoint control work has no matching lifecycle occurrence")
			if task.get("status","") == "committed":
				var expected_kind: String="functional_test_passed" if task["action"]=="control_network_functional_test" else "reconstituted"; var matching_terminal: bool=false
				for event in control_network.get("history",[]):
					if event.get("kind","")==expected_kind and event.get("occurrence_id","")==occurrence and event.get("actor","")==task.get("actor_person_id",""): matching_terminal=true; break
				if not matching_terminal: return _denied("scene checkpoint committed control work lacks matching lifecycle evidence")
			elif task.get("status","") != "superseded":
				var active: Dictionary=control_network.get("active_incident",{}); var test: Dictionary=control_network.get("functional_test",{})
				if control_network.get("posture","") != "isolated" or active.get("occurrence_id","") != occurrence: return _denied("scene checkpoint active control work contradicts active lifecycle")
				if task["action"]=="control_network_functional_test" and not test.is_empty(): return _denied("scene checkpoint active functional test duplicates accepted evidence")
				if task["action"]=="control_network_reconstitute" and (test.get("occurrence_id","") != occurrence or not test.get("passed",false) or task.get("actor_person_id","") in [test.get("actor_id",""),active.get("incident_owner","")]): return _denied("scene checkpoint active reconstitution contradicts test authority")
	return {"accepted": true}


func _validate_custody_work(custody: Dictionary, work_state: Dictionary) -> Dictionary:
	for task in work_state["tasks"].values():
		if task.get("service", "") != "custody" or task.get("status", "") in ["committed", "superseded"]:
			continue
		match task.get("action", ""):
			"contain_incident":
				if custody.get("active_incident", "") != "archive_fire_water":
					return _denied("scene checkpoint custody containment work has no matching active incident")
			"record_quarantine_disposition":
				if not String(custody.get("active_incident", "")).is_empty() or custody.get("current_room", "") != "quarantine" or bool(custody.get("quarantine_cleared", false)):
					return _denied("scene checkpoint quarantine disposition work has no matching custody hold")
			_:
				return _denied("scene checkpoint custody work action is unknown")
	return {"accepted": true}


func _validate_mission_services(graph: RefCounted, infrastructure: Dictionary, mission: Dictionary) -> Dictionary:
	if not mission.get("service_available", null) is Dictionary or not mission.get("room_service_available", null) is Dictionary:
		return _denied("scene checkpoint mission service state is invalid")
	for service_id in infrastructure["services"]:
		if bool(mission["service_available"].get(service_id, not bool(infrastructure["services"][service_id]))) != bool(infrastructure["services"][service_id]):
			return _denied("scene checkpoint mission/infrastructure service mismatch")
	for edge in graph.dependency_edges:
		var service_id: String = edge["kind"]
		var room_id: String = edge["consumer"]
		var available: bool = bool(infrastructure["services"][service_id])
		if not available and infrastructure["active_failures"].has(service_id):
			var failure: Dictionary = infrastructure["active_failures"][service_id]
			available = infrastructure["service_states"][service_id]["phase"] == failure["preservation_phase"] and (failure["preserved_rooms"] as Array).has(room_id)
		if bool(mission["room_service_available"].get(service_id, {}).get(room_id, not available)) != available:
			return _denied("scene checkpoint mission room-service mismatch")
	return {"accepted": true}


func _validate_custody(graph: RefCounted, state: Dictionary) -> Dictionary:
	for field in ["material_id", "custody_identity", "current_room", "active_incident"]:
		if not state.get(field, null) is String:
			return _denied("scene checkpoint custody identity field is invalid: %s" % field)
	for field in ["screened", "accessioned", "quarantine_cleared", "processed", "stored"]:
		if not state.get(field, null) is bool:
			return _denied("scene checkpoint custody milestone field is invalid: %s" % field)
	if state["custody_identity"] != "custody:%s" % state["material_id"] or not state.get("history", null) is Array or state["history"].is_empty():
		return _denied("scene checkpoint custody identity or history mismatch")
	var chain: Array = graph.MATERIAL_CUSTODY_CHAIN
	var current_room := "loading"
	var reached_index := 0
	var quarantine_cleared := false
	var active_incident := ""
	for index in state["history"].size():
		var event: Variant = state["history"][index]
		if not event is Dictionary or int(event.get("sequence", -1)) != index or event.get("custody_identity", "") != state["custody_identity"]:
			return _denied("scene checkpoint custody history sequence mismatch")
		match event.get("event", ""):
			"received":
				if index != 0 or event.get("room", "") != "loading":
					return _denied("scene checkpoint custody receipt provenance mismatch")
			"transfer":
				var to_room: String = event.get("to", "")
				if not active_incident.is_empty() or event.get("from", "") != current_room or reached_index + 1 >= chain.size() or chain[reached_index + 1] != to_room:
					return _denied("scene checkpoint custody transfer order mismatch")
				current_room = to_room
				reached_index += 1
			"quarantine_cleared":
				if current_room != "quarantine" or quarantine_cleared or not active_incident.is_empty():
					return _denied("scene checkpoint quarantine disposition mismatch")
				quarantine_cleared = true
			"incident_declared":
				var procedure_id: String = event.get("procedure", "")
				if not active_incident.is_empty() or not graph.failure_procedures.has(procedure_id) or not (graph.failure_procedures[procedure_id]["capabilities"] as Array).has("custody"):
					return _denied("scene checkpoint custody incident provenance mismatch")
				active_incident = procedure_id
			"incident_resolved":
				if active_incident.is_empty() or event.get("procedure", "") != active_incident:
					return _denied("scene checkpoint custody incident resolution mismatch")
				active_incident = ""
			_:
				return _denied("scene checkpoint custody history event is unknown")
	if state["current_room"] != current_room or state["active_incident"] != active_incident:
		return _denied("scene checkpoint custody current authority mismatch")
	if bool(state["screened"]) != (reached_index >= 1) or bool(state["accessioned"]) != (reached_index >= 2) or bool(state["quarantine_cleared"]) != quarantine_cleared or bool(state["processed"]) != (reached_index >= 4) or bool(state["stored"]) != (reached_index >= 5):
		return _denied("scene checkpoint custody milestone contradiction")
	return {"accepted": true}


func _validate_personnel_security(graph: RefCounted, state: Dictionary, runtime_state: Dictionary) -> Dictionary:
	for field in ["person_id", "current_room", "active_receipt"]:
		if not state.get(field, null) is String:
			return _denied("scene checkpoint personnel identity field is invalid: %s" % field)
	if not state.get("roles", null) is Array or not state.get("audit", null) is Array or not state.get("denials", null) is Array or not state.get("screened", null) is bool or not state.get("inside", null) is bool:
		return _denied("scene checkpoint personnel state is malformed")
	var clearance_value: Variant = state.get("clearance_tier", null)
	if not (clearance_value is int or clearance_value is float) or float(clearance_value) != float(int(clearance_value)):
		return _denied("scene checkpoint personnel clearance is invalid")
	if state["person_id"].is_empty() or (state["current_room"] not in ["perimeter", "emergency_exit"] and not graph.rooms.has(state["current_room"])):
		return _denied("scene checkpoint personnel location is invalid")
	for role in state["roles"]:
		if not graph.jobs.has(role):
			return _denied("scene checkpoint personnel role is unknown")
	if state["current_room"] == "perimeter" and bool(state["inside"]):
		return _denied("scene checkpoint perimeter personnel is marked inside")
	if state["current_room"] == "emergency_exit" and (bool(state["inside"]) or bool(state["screened"])):
		return _denied("scene checkpoint emergency-exit trust was not cleared")
	if state["current_room"] not in ["perimeter", "emergency_exit"] and graph.rooms.has(state["current_room"]) and not bool(state["inside"]):
		return _denied("scene checkpoint interior personnel is marked outside")
	for index in state["audit"].size():
		var event: Variant = state["audit"][index]
		if not event is Dictionary or int(event.get("sequence", -1)) != index or event.get("person_id", "") != state["person_id"]:
			return _denied("scene checkpoint personnel audit sequence mismatch")
	for field in ["interlock_occupancy", "active_receipts"]:
		if not runtime_state.get(field, null) is Dictionary:
			return _denied("scene checkpoint personnel runtime field is invalid: %s" % field)
	if int(runtime_state.get("next_receipt_id", 0)) < 1:
		return _denied("scene checkpoint personnel receipt counter is invalid")
	var active_id: String = state["active_receipt"]
	if active_id.is_empty():
		if not runtime_state["active_receipts"].is_empty() or not runtime_state["interlock_occupancy"].is_empty():
			return _denied("scene checkpoint personnel runtime has orphan interlock authority")
		return {"accepted": true}
	if runtime_state["active_receipts"].size() != 1 or not runtime_state["active_receipts"].has(active_id):
		return _denied("scene checkpoint personnel active receipt mismatch")
	var receipt: Dictionary = runtime_state["active_receipts"][active_id]
	var endpoints: Array = [receipt.get("from", ""), receipt.get("to", "")]
	endpoints.sort()
	var expected_boundary := "%s|%s" % endpoints
	if receipt.get("receipt_id", "") != active_id or receipt.get("person_id", "") != state["person_id"] or receipt.get("from", "") != state["current_room"] or receipt.get("boundary", "") != expected_boundary:
		return _denied("scene checkpoint personnel receipt provenance mismatch")
	if runtime_state["interlock_occupancy"].size() != 1 or runtime_state["interlock_occupancy"].get(expected_boundary, "") != state["person_id"]:
		return _denied("scene checkpoint personnel interlock occupancy mismatch")
	var edge_exists := false
	for edge in graph.circulation_edges:
		if edge["from"] == receipt.get("from", "") and edge["to"] == receipt.get("to", "") and edge["flow"] == receipt.get("flow", ""):
			edge_exists = true
			break
	if not edge_exists:
		return _denied("scene checkpoint personnel receipt has no authoritative circulation edge")
	return {"accepted": true}


func _validate_control_room(graph: RefCounted, console: Dictionary, snapshot: Dictionary) -> Dictionary:
	if console.get("console_id", "") != "duty-console-%d" % graph.seed:
		return _denied("scene checkpoint control console identity mismatch")
	if not console.get("active_occurrences", null) is Dictionary or not console.get("acknowledgements", null) is Array or not console.get("denials", null) is Array or int(console.get("next_occurrence_number", 0)) < 1 or int(console.get("next_acknowledgement_number", 0)) < 1:
		return _denied("scene checkpoint control console state is malformed")
	var occurrence_ids: Array = console["active_occurrences"].values()
	var unique_occurrences: Dictionary = {}
	for occurrence_id in occurrence_ids:
		if String(occurrence_id).is_empty() or unique_occurrences.has(occurrence_id):
			return _denied("scene checkpoint control occurrence identity mismatch")
		unique_occurrences[occurrence_id] = true
	for index in console["acknowledgements"].size():
		var acknowledgement: Variant = console["acknowledgements"][index]
		if not acknowledgement is Dictionary or int(acknowledgement.get("sequence", -1)) != index or String(acknowledgement.get("acknowledgement_id", "")).is_empty() or String(acknowledgement.get("occurrence_id", "")).is_empty():
			return _denied("scene checkpoint control acknowledgement provenance mismatch")
	if snapshot.get("console_id", "") != console["console_id"] or not snapshot.get("conditions", null) is Array:
		return _denied("scene checkpoint control projection is malformed")
	for condition in snapshot["conditions"]:
		if not condition is Dictionary or console["active_occurrences"].get(condition.get("key", ""), "") != condition.get("occurrence_id", ""):
			return _denied("scene checkpoint control projection occurrence mismatch")
	return {"accepted": true}


func _validate_operations_queue(state: Dictionary, work_state: Dictionary, panel_definitions: Dictionary, mission_state: Dictionary, mutual_aid_state: Dictionary) -> Dictionary:
	if state.get("schema", "") != "facility-operations-queue/v1" or not state.get("reactivation_receipts", null) is Dictionary or int(state.get("next_reactivation_number", 0)) < 1 or int(state.get("clock", -1)) < 0 or not state.get("entries", null) is Dictionary or not state.get("reservations", null) is Dictionary or not state["reservations"].get("actors", null) is Dictionary or not state["reservations"].get("stations", null) is Dictionary or not state.get("continuity_decisions", null) is Array or not state.get("history", null) is Array or int(state.get("next_event_number", 0)) < 1:
		return _denied("scene checkpoint operations queue shape is invalid")
	for task_value in work_state.get("tasks", {}).values():
		var external_task: Dictionary = task_value
		if external_task.get("control_mode", "") != "temporary_mutual_aid": continue
		var case_id: String = external_task.get("mutual_aid_case_id", "")
		if not mutual_aid_state.get("cases", {}).has(case_id): return _denied("temporary work references unknown mutual-aid case")
		var aid_case: Dictionary = mutual_aid_state["cases"][case_id]
		if aid_case.get("occurrence_id", "") != external_task.get("occurrence_id", "") or aid_case.get("responder_id", "") != external_task.get("actor_person_id", "") or aid_case.get("response_job", "") != external_task.get("actor_job", "") or aid_case.get("destination", "") != external_task.get("station", "") or aid_case.get("credential_id", "") != external_task.get("credential_id", ""):
			return _denied("temporary work/mutual-aid provenance mismatch")
		var terminal_external: bool = external_task.get("status", "") in ["committed", "superseded"]
		if (not terminal_external and aid_case.get("phase", "") != "admitted") or (terminal_external and aid_case.get("phase", "") not in ["admitted", "revoked"]):
			return _denied("temporary work has invalid mutual-aid lifecycle phase")
	var sequence := 0
	for event in state["history"]:
		sequence += 1
		if not event is Dictionary or int(event.get("sequence", 0)) != sequence or int(event.get("clock", -1)) > int(state["clock"]):
			return _denied("scene checkpoint operations queue history is invalid")
	for entry_id in state["entries"]:
		var entry: Variant = state["entries"][entry_id]
		if not entry is Dictionary or entry.get("entry_id", "") != entry_id or not panel_definitions.has(entry.get("panel_id", "")):
			return _denied("scene checkpoint operations queue entry identity is invalid")
		if entry.get("status", "") not in ["waiting", "dispatched", "resolved", "terminal_failed", "abandoned", "safe_hold", "mission_shutdown"] or entry.get("abandonment_action", "") not in ["mobilize_qualified_relief", "mission_safe_hold"] or String(entry.get("station", "")).is_empty() or int(entry.get("first_seen", -1)) < 0 or int(entry.get("deadline_ticks", 0)) < 1 or int(entry.get("retry_backoff_ticks", 0)) < 1 or int(entry.get("max_wait_ticks", 0)) < int(entry.get("deadline_ticks", 0)) or int(entry.get("next_attempt_clock", -1)) < int(entry.get("first_seen", 0)) or int(entry.get("base_priority", 0)) < 1 or int(entry.get("attempts", -1)) < 0 or int(entry.get("reassignments", -1)) < 0:
			return _denied("scene checkpoint operations queue entry state is invalid")
		var task_id: String = entry.get("task_id", "")
		if entry["status"] == "dispatched":
			if not work_state["tasks"].has(task_id) or work_state["tasks"][task_id]["panel_id"] != entry["panel_id"] or work_state["tasks"][task_id]["status"] in ["committed", "superseded"]:
				return _denied("scene checkpoint operations queue dispatch/work mismatch")
			if state["reservations"]["stations"].get(entry["station"], "") != entry_id or (not String(entry.get("actor_person_id", "")).is_empty() and state["reservations"]["actors"].get(entry["actor_person_id"], "") != entry_id):
				return _denied("scene checkpoint operations queue reservation mismatch")
		elif entry["status"] == "waiting" and not task_id.is_empty():
			return _denied("scene checkpoint waiting operations queue entry has task authority")
	var decision_counts: Dictionary = {}
	for decision in state["continuity_decisions"]:
		if not decision is Dictionary or not state["entries"].has(decision.get("entry_id", "")) or not decision.get("evidence", null) is Dictionary or int(decision.get("clock", -1)) < 0 or int(decision.get("clock", -1)) > int(state["clock"]):
			return _denied("scene checkpoint continuity decision provenance is invalid")
		var decision_entry: Dictionary = state["entries"][decision["entry_id"]]
		if decision.get("action", "") not in [decision_entry["abandonment_action"], decision_entry.get("relief_failure_action", "")] or not decision.get("accepted", null) is bool:
			return _denied("scene checkpoint continuity decision contradicts queue policy")
		decision_counts[decision["entry_id"]] = int(decision_counts.get(decision["entry_id"], 0)) + 1
	for entry_id in state["entries"]:
		var continuity_entry: Dictionary = state["entries"][entry_id]
		if continuity_entry["status"] == "safe_hold" and not decision_counts.has(entry_id):
			return _denied("scene checkpoint safe hold lacks continuity decision")
		if continuity_entry["status"] == "mission_shutdown" and not state["continuity_decisions"].any(func(decision): return decision.get("entry_id", "") == entry_id and decision.get("action", "") == "mission_shutdown"):
			return _denied("scene checkpoint mission shutdown lacks command decision")
		if int(continuity_entry.get("reassignments", 0)) > int(decision_counts.get(entry_id, 0)):
			return _denied("scene checkpoint reassignment lacks continuity decision")
	var receipt_counts: Dictionary = {}
	for receipt_id in state["reactivation_receipts"]:
		var receipt: Variant = state["reactivation_receipts"][receipt_id]
		if not receipt is Dictionary or receipt.get("receipt_id", "") != receipt_id or not state["entries"].has(receipt.get("entry_id", "")) or not bool(receipt.get("consumed", false)):
			return _denied("scene checkpoint reactivation receipt identity is invalid")
		var receipt_entry: Dictionary = state["entries"][receipt["entry_id"]]
		if receipt.get("actor_job", "") != receipt_entry.get("reactivation_authority_job", "") or receipt.get("station", "") != receipt_entry.get("reactivation_station", "") or String(receipt.get("actor_person_id", "")).is_empty() or int(receipt.get("clock", -1)) > int(state["clock"]):
			return _denied("scene checkpoint reactivation receipt authority is invalid")
		receipt_counts[receipt["entry_id"]] = int(receipt_counts.get(receipt["entry_id"], 0)) + 1
	for entry_id in state["entries"]:
		if int(state["entries"][entry_id].get("reactivations", 0)) != int(receipt_counts.get(entry_id, 0)):
			return _denied("scene checkpoint reactivation count contradicts receipts")
	var shutdown_entries: Dictionary = {}
	for entry_id in state["entries"]:
		if state["entries"][entry_id]["status"] == "mission_shutdown": shutdown_entries[entry_id] = state["entries"][entry_id]
	var mission_shutdowns: Variant = mission_state.get("continuity_shutdowns", [])
	if not mission_shutdowns is Array:
		return _denied("scene checkpoint mission shutdown projection is invalid")
	var projected_shutdowns: Dictionary = {}
	for projection in mission_shutdowns:
		if not projection is Dictionary or projected_shutdowns.has(projection.get("entry_id", "")) or not shutdown_entries.has(projection.get("entry_id", "")):
			return _denied("scene checkpoint mission shutdown projection identity mismatch")
		var shutdown_entry: Dictionary = shutdown_entries[projection["entry_id"]]
		if projection.get("domain", "") != shutdown_entry["domain"] or projection.get("action", "") != shutdown_entry["action"] or projection.get("reason", "") != "qualified_relief_unavailable" or int(projection.get("clock", -1)) < 0 or int(projection.get("clock", -1)) > int(state["clock"]):
			return _denied("scene checkpoint mission shutdown projection contradicts queue authority")
		projected_shutdowns[projection["entry_id"]] = true
	if not _same_keys(shutdown_entries, projected_shutdowns) or (not shutdown_entries.is_empty() and mission_state.get("status", "") != "blocked"):
		return _denied("scene checkpoint mission shutdown projection is incomplete")
	for station in state["reservations"]["stations"]:
		var station_entry: String = state["reservations"]["stations"][station]
		if not state["entries"].has(station_entry) or state["entries"][station_entry]["status"] != "dispatched" or state["entries"][station_entry]["station"] != station:
			return _denied("scene checkpoint operations queue has orphan station reservation")
	for actor_id in state["reservations"]["actors"]:
		var actor_entry: String = state["reservations"]["actors"][actor_id]
		if not state["entries"].has(actor_entry) or state["entries"][actor_entry]["status"] != "dispatched" or state["entries"][actor_entry].get("actor_person_id", "") != actor_id:
			return _denied("scene checkpoint operations queue has orphan actor reservation")
	for entry_id in mutual_aid_state.get("capacity_reservations", {}):
		var external: Dictionary = mutual_aid_state["capacity_reservations"][entry_id]
		if not state["entries"].has(entry_id): return _denied("mutual-aid capacity reservation lacks queue entry")
		var queue_entry: Dictionary = state["entries"][entry_id]
		if queue_entry.get("status", "") != "dispatched" or queue_entry.get("task_id", "") != external.get("task_id", "") or queue_entry.get("actor_person_id", "") != external.get("responder_id", "") or queue_entry.get("actor_job", "") != external.get("response_job", "") or queue_entry.get("station", "") != external.get("destination", ""):
			return _denied("mutual-aid capacity reservation contradicts queue dispatch")
		if state["reservations"]["actors"].get(external["responder_id"], "") != entry_id or state["reservations"]["stations"].get(external["destination"], "") != entry_id:
			return _denied("mutual-aid capacity reservation lacks queue resources")
	return {"accepted": true}


func _same_keys(left: Dictionary, right: Dictionary) -> bool:
	var left_keys: Array = left.keys()
	var right_keys: Array = right.keys()
	left_keys.sort()
	right_keys.sort()
	return left_keys == right_keys


func _denied(reason: String) -> Dictionary:
	return {"accepted": false, "reason": reason}
