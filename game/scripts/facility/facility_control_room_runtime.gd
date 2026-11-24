class_name FacilityControlRoomRuntime
extends RefCounted
## Read-only operational projection with occurrence-scoped acknowledgement.
## Acknowledgement records operator awareness; it never mutates or resolves source truth.


func start_console(console_id: String) -> Dictionary:
	return {
		"console_id": console_id,
		"active_occurrences": {},
		"acknowledgements": [],
		"denials": [],
		"next_occurrence_number": 1,
		"next_acknowledgement_number": 1,
	}


func compile_status(
	graph: RefCounted,
	console_state: Dictionary,
	mission_state: Dictionary,
	custody_state: Dictionary,
	personnel_state: Dictionary,
	staffing_state: Dictionary,
	staffing_runtime: RefCounted,
	infrastructure_state: Dictionary = {}
) -> Dictionary:
	var by_key: Dictionary = {}
	var service_ids: Array = mission_state["service_available"].keys()
	service_ids.sort()
	for service_id in service_ids:
		if not bool(mission_state["service_available"][service_id]):
			_add_condition(by_key, _owned_condition(
				graph,
				"service:%s" % service_id,
				"service",
				service_id,
				_procedure_for_capability(graph, service_id),
				_service_priority(service_id)
			))
			if infrastructure_state.has("service_states") and infrastructure_state["service_states"].has(service_id):
				by_key["service:%s" % service_id]["phase"] = infrastructure_state["service_states"][service_id]["phase"]
	var uncovered_jobs: Array[String] = []
	var job_ids: Array = graph.jobs.keys()
	job_ids.sort()
	for job_id in job_ids:
		if not staffing_runtime.is_job_covered(staffing_state, job_id):
			uncovered_jobs.append(job_id)
			_add_condition(by_key, _owned_condition(
				graph,
				"staffing:%s" % job_id,
				"staffing",
				job_id,
				_procedure_for_capability(graph, "staffing"),
				100
			))
	for blocker in mission_state["active_blockers"]:
		var blocker_key := "%s:%s" % [blocker["kind"], blocker["id"]]
		var condition: Dictionary = by_key.get(blocker_key, _owned_condition(
			graph,
			blocker_key,
			blocker["kind"],
			blocker["id"],
			blocker["procedure"],
			_service_priority(blocker["id"]) if blocker["kind"] == "service" else 100
		))
		condition["mission_step"] = mission_state["failed_step"]
		condition["blocks_mission"] = true
		_add_condition(by_key, condition)
	if mission_state["status"] == "failed":
		_add_condition(by_key, {
			"key": "mission:failed",
			"kind": "mission",
			"id": mission_state["failed_step"],
			"procedure": "",
			"owner_job": "duty_officer",
			"priority": 10,
			"mission_step": mission_state["failed_step"],
			"blocks_mission": true,
		})
	var incident_id: String = custody_state["active_incident"]
	if not incident_id.is_empty():
		_add_condition(by_key, {
			"key": "custody:%s" % incident_id,
			"kind": "custody",
			"id": incident_id,
			"procedure": incident_id,
			"owner_job": _procedure_owner(graph, incident_id),
			"priority": 20,
			"blocks_mission": false,
		})
	for investigation in custody_state.get("open_investigations", []):
		if not bool(investigation.get("open", false)):
			continue
		var investigation_id: String = String(investigation.get("investigation_id", ""))
		if investigation_id.is_empty():
			continue
		var owner_job := "security_officer"
		if String(investigation.get("kind", "")) != "unauthorized_removal":
			owner_job = "records_officer"
		_add_condition(by_key, {
			"key": "investigation:%s" % investigation_id,
			"kind": "investigation",
			"id": investigation_id,
			"procedure": "",
			"owner_job": owner_job,
			"priority": 25,
			"blocks_mission": false,
			"artifact_id": investigation.get("artifact_id", ""),
			"room": investigation.get("room", ""),
		})

	_sync_occurrences(console_state, by_key.keys())
	var conditions: Array[Dictionary] = []
	for key in by_key:
		var condition: Dictionary = by_key[key]
		condition["occurrence_id"] = console_state["active_occurrences"][key]
		condition["active"] = true
		condition["acknowledged"] = _is_acknowledged(console_state, condition["occurrence_id"])
		conditions.append(condition)
	conditions.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if int(left["priority"]) == int(right["priority"]):
			return String(left["key"]) < String(right["key"])
		return int(left["priority"]) < int(right["priority"])
	)
	return {
		"console_id": console_state["console_id"],
		"severity": "alarm" if not conditions.is_empty() else "normal",
		"conditions": conditions,
		"mission": {
			"mission_id": mission_state["mission_id"],
			"status": mission_state["status"],
			"next_step": _next_step(graph, mission_state),
			"committed_steps": mission_state["trace"].size(),
			"active_procedure": mission_state["active_procedure"],
		},
		"services": mission_state["service_available"].duplicate(true),
		"custody": {
			"custody_identity": custody_state["custody_identity"],
			"current_room": custody_state["current_room"],
			"active_incident": custody_state["active_incident"],
			"history_length": custody_state["history"].size(),
		},
		"personnel": {
			"person_id": personnel_state["person_id"],
			"current_room": personnel_state["current_room"],
			"screened": personnel_state["screened"],
			"inside": personnel_state["inside"],
			"denial_count": personnel_state["denials"].size(),
		},
		"staffing": {
			"active_shift": staffing_state["active_shift"],
			"uncovered_jobs": uncovered_jobs,
			"pending_turnover": (staffing_state["pending_turnover"] as Dictionary).get("turnover_id", ""),
		},
		"acknowledgement_count": console_state["acknowledgements"].size(),
	}


func acknowledge(
	console_state: Dictionary,
	snapshot: Dictionary,
	occurrence_id: String,
	credentials: Dictionary
) -> Dictionary:
	var target: Dictionary = {}
	for condition in snapshot.get("conditions", []):
		if condition["occurrence_id"] == occurrence_id and bool(condition["active"]):
			target = condition
			break
	if target.is_empty() or console_state["active_occurrences"].values().find(occurrence_id) < 0:
		return _deny(console_state, occurrence_id, "condition occurrence is not active")
	var roles: Array = credentials.get("roles", [])
	var actor_role := ""
	if roles.has(target["owner_job"]):
		actor_role = target["owner_job"]
	elif roles.has("duty_officer"):
		actor_role = "duty_officer"
	else:
		return _deny(console_state, occurrence_id, "acknowledgement requires duty officer or procedure owner")
	if _is_acknowledged(console_state, occurrence_id):
		return {"accepted": true, "already_committed": true, "occurrence_id": occurrence_id}
	var acknowledgement_id := "ack-%d" % int(console_state["next_acknowledgement_number"])
	console_state["next_acknowledgement_number"] = int(console_state["next_acknowledgement_number"]) + 1
	console_state["acknowledgements"].append({
		"sequence": console_state["acknowledgements"].size(),
		"acknowledgement_id": acknowledgement_id,
		"occurrence_id": occurrence_id,
		"condition_key": target["key"],
		"actor_role": actor_role,
	})
	return {
		"accepted": true,
		"already_committed": false,
		"acknowledgement_id": acknowledgement_id,
		"occurrence_id": occurrence_id,
		"actor_role": actor_role,
	}


func _owned_condition(
	graph: RefCounted,
	key: String,
	kind: String,
	condition_id: String,
	procedure_id: String,
	priority: int
) -> Dictionary:
	var result := _condition(key, kind, condition_id, procedure_id, priority)
	result["owner_job"] = _procedure_owner(graph, procedure_id)
	return result


func _condition(key: String, kind: String, condition_id: String, procedure_id: String, priority: int) -> Dictionary:
	return {
		"key": key,
		"kind": kind,
		"id": condition_id,
		"procedure": procedure_id,
		"owner_job": "duty_officer" if procedure_id.is_empty() else "",
		"priority": priority,
		"blocks_mission": false,
	}


func _add_condition(by_key: Dictionary, condition: Dictionary) -> void:
	if condition["owner_job"].is_empty() and not condition["procedure"].is_empty():
		condition["owner_job"] = "duty_officer"
	by_key[condition["key"]] = condition


func _sync_occurrences(console_state: Dictionary, active_keys: Array) -> void:
	var active_lookup: Dictionary = {}
	for key in active_keys:
		active_lookup[key] = true
	var previous_keys: Array = console_state["active_occurrences"].keys()
	for key in previous_keys:
		if not active_lookup.has(key):
			console_state["active_occurrences"].erase(key)
	active_keys.sort()
	for key in active_keys:
		if not console_state["active_occurrences"].has(key):
			var occurrence_id := "%s-occurrence-%d" % [console_state["console_id"], int(console_state["next_occurrence_number"])]
			console_state["next_occurrence_number"] = int(console_state["next_occurrence_number"]) + 1
			console_state["active_occurrences"][key] = occurrence_id


func _is_acknowledged(console_state: Dictionary, occurrence_id: String) -> bool:
	for acknowledgement in console_state["acknowledgements"]:
		if acknowledgement["occurrence_id"] == occurrence_id:
			return true
	return false


func _deny(console_state: Dictionary, occurrence_id: String, reason: String) -> Dictionary:
	console_state["denials"].append({
		"sequence": console_state["denials"].size(),
		"occurrence_id": occurrence_id,
		"reason": reason,
	})
	return {"accepted": false, "reason": reason}


func _next_step(graph: RefCounted, mission_state: Dictionary) -> String:
	var index: int = mission_state["next_step_index"]
	if index >= 0 and index < graph.mission_steps.size():
		return graph.mission_steps[index]["id"]
	return ""


func _procedure_for_capability(graph: RefCounted, capability: String) -> String:
	for procedure_id in graph.failure_procedures:
		if (graph.failure_procedures[procedure_id]["capabilities"] as Array).has(capability):
			return procedure_id
	return ""


func _procedure_owner(graph: RefCounted, procedure_id: String) -> String:
	if graph.failure_procedures.has(procedure_id):
		return graph.failure_procedures[procedure_id]["owner_job"]
	return "duty_officer"


func _service_priority(service_id: String) -> int:
	match service_id:
		"power": return 0
		"cooling": return 1
		"communications": return 2
		"maintenance": return 3
	return 4
