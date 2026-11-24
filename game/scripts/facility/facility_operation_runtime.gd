class_name FacilityOperationRuntime
extends RefCounted
## Resumable execution of the authoritative mission handoff.
## Step commits are atomic: blocked or failed attempts produce no artifacts.


func start_mission(graph: RefCounted, mission_id: String) -> Dictionary:
	var services: Dictionary = {}
	var room_services: Dictionary = {}
	for edge in graph.dependency_edges:
		services[edge["kind"]] = true
		if not room_services.has(edge["kind"]):
			room_services[edge["kind"]] = {}
		room_services[edge["kind"]][edge["consumer"]] = true
	var jobs_available: Dictionary = {}
	for job_id in graph.jobs:
		jobs_available[job_id] = true
	return {
		"mission_id": mission_id,
		"next_step_index": 0,
		"artifacts": {},
		"trace": [],
		"service_available": services,
		"room_service_available": room_services,
		"job_available": jobs_available,
		"status": "running",
		"active_procedure": "",
		"blocked_service": "",
		"blocked_job": "",
		"blocked_posture": "",
		"room_protective_postures": {},
		"active_blockers": [],
		"failed_step": "",
		"failure": "",
		"procedure_log": [],
	}


func set_service_available(state: Dictionary, service_kind: String, available: bool) -> void:
	state["service_available"][service_kind] = available
	if state["room_service_available"].has(service_kind):
		for room_id in state["room_service_available"][service_kind]:
			state["room_service_available"][service_kind][room_id] = available
	if available and state["status"] == "blocked":
		_remove_active_blocker(state, "service", service_kind)
		_refresh_blocked_state(state)


func set_room_service_available(state: Dictionary, service_kind: String, room_id: String, available: bool) -> void:
	if not state["room_service_available"].has(service_kind):
		state["room_service_available"][service_kind] = {}
	state["room_service_available"][service_kind][room_id] = available


func set_room_protective_posture(state: Dictionary, room_id: String, posture: String) -> void:
	if posture.is_empty():
		state.get("room_protective_postures", {}).erase(room_id)
		var retained: Array[Dictionary] = []
		for blocker in state.get("active_blockers", []):
			if blocker.get("kind", "") != "protective_posture" or blocker.get("room", "") != room_id: retained.append(blocker)
		state["active_blockers"] = retained; _refresh_blocked_state(state)
	else: state["room_protective_postures"][room_id] = posture


func set_job_available(state: Dictionary, job_id: String, available: bool) -> void:
	state["job_available"][job_id] = available
	if available and state["status"] == "blocked":
		_remove_active_blocker(state, "staffing", job_id)
		_refresh_blocked_state(state)


func advance_mission(graph: RefCounted, state: Dictionary, max_steps: int = -1) -> Dictionary:
	if state["status"] == "completed":
		return _status_result(state)
	if state["status"] == "failed":
		return _status_result(state)
	var committed_this_call := 0
	while int(state["next_step_index"]) < graph.mission_steps.size():
		if max_steps >= 0 and committed_this_call >= max_steps:
			state["status"] = "running"
			return _status_result(state)
		var step: Dictionary = graph.mission_steps[int(state["next_step_index"])]
		var preflight: Dictionary = _preflight_step(graph, step, state)
		if not preflight.is_empty():
			state["failed_step"] = step["id"]
			state["failure"] = preflight["message"]
			if preflight["kind"] == "blocked":
				state["active_blockers"] = (preflight["blockers"] as Array).duplicate(true)
				_refresh_blocked_state(state)
				for blocker in state["active_blockers"]:
					state["procedure_log"].append({
						"procedure": blocker["procedure"],
						"blocker_kind": blocker["kind"],
						"blocker_id": blocker["id"],
						"step": step["id"],
						"owner_job": _procedure_owner(graph, blocker["procedure"]),
					})
			else:
				state["status"] = "failed"
			return _status_result(state)
		_commit_step(step, state)
		state["next_step_index"] = int(state["next_step_index"]) + 1
		committed_this_call += 1
	if int(state["next_step_index"]) == graph.mission_steps.size():
		state["status"] = "completed"
		state["active_procedure"] = ""
		state["blocked_service"] = ""
		state["blocked_job"] = ""
		state["blocked_posture"] = ""
		state["active_blockers"] = []
		state["failed_step"] = ""
		state["failure"] = ""
	return _status_result(state)


func run_normal_mission(graph: RefCounted, mission_id: String) -> Dictionary:
	var state := start_mission(graph, mission_id)
	var result := advance_mission(graph, state)
	return {
		"completed": result["status"] == "completed",
		"mission_id": mission_id,
		"failed_step": result["failed_step"],
		"failure": result["failure"],
		"trace": state["trace"],
		"artifacts": state["artifacts"],
		"active_procedure": result["active_procedure"],
	}


func _commit_step(step: Dictionary, state: Dictionary) -> void:
	var consumed: Array[String] = step["inputs"].duplicate()
	var produced: Array[String] = []
	for output_name in step["outputs"]:
		state["artifacts"][output_name] = {
			"artifact": output_name,
			"mission_id": state["mission_id"],
			"produced_by_step": step["id"],
			"owner_job": step["owner_job"],
			"station": step["station"],
			"inputs": consumed.duplicate(),
		}
		produced.append(output_name)
	state["trace"].append({
		"step": step["id"],
		"owner_job": step["owner_job"],
		"station": step["station"],
		"equipment": step["required_equipment"].duplicate(),
		"consumed": consumed,
		"produced": produced,
	})


func _preflight_step(graph: RefCounted, step: Dictionary, state: Dictionary) -> Dictionary:
	var step_id: String = step["id"]
	if not graph.jobs.has(step["owner_job"]):
		return {"kind": "structural", "message": "step %s owner is unavailable" % step_id}
	if not graph.rooms.has(step["station"]):
		return {"kind": "structural", "message": "step %s station is unavailable" % step_id}
	for input_name in step["inputs"]:
		if not state["artifacts"].has(input_name):
			return {"kind": "structural", "message": "step %s lacks input %s" % [step_id, input_name]}
	var blockers: Array[Dictionary] = []
	var room_posture: String = state.get("room_protective_postures", {}).get(step["station"], "")
	if not room_posture.is_empty():
		blockers.append({"kind":"protective_posture","id":room_posture,"room":step["station"],"procedure":"review_protective_safe_hold"})
	var blocked_services: Dictionary = {}
	for equipment_id in step["required_equipment"]:
		if not graph.equipment.has(equipment_id):
			return {"kind": "equipment", "message": "step %s lacks equipment %s" % [step_id, equipment_id]}
		var item: Dictionary = graph.equipment[equipment_id]
		if item["room"] != step["station"]:
			return {"kind": "equipment", "message": "step %s equipment %s is outside station" % [step_id, equipment_id]}
		for requirement in item["utility_requirements"]:
			if not _has_service(graph, state, item["room"], requirement) and not blocked_services.has(requirement):
				blocked_services[requirement] = true
				blockers.append({
					"kind": "service",
					"id": requirement,
					"procedure": _procedure_for_capability(graph, requirement),
				})
	if not bool(state["job_available"].get(step["owner_job"], false)):
		blockers.append({
			"kind": "staffing",
			"id": step["owner_job"],
			"procedure": _procedure_for_capability(graph, "staffing"),
		})
	if not blockers.is_empty():
		blockers.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			return _blocker_priority(left) < _blocker_priority(right)
		)
		return {
			"kind": "blocked",
			"message": "step %s has unresolved safety conditions" % step_id,
			"blockers": blockers,
		}
	return {}


func _blocker_priority(blocker: Dictionary) -> int:
	if blocker["kind"] == "protective_posture": return -1
	if blocker["kind"] == "service":
		match blocker["id"]:
			"power": return 0
			"cooling": return 1
			"communications": return 2
			"maintenance": return 3
		return 4
	return 100


func _remove_active_blocker(state: Dictionary, kind: String, blocker_id: String) -> void:
	var retained: Array[Dictionary] = []
	for blocker in state["active_blockers"]:
		if blocker["kind"] != kind or blocker["id"] != blocker_id:
			retained.append(blocker)
	state["active_blockers"] = retained


func _refresh_blocked_state(state: Dictionary) -> void:
	state["blocked_service"] = ""
	state["blocked_job"] = ""
	state["blocked_posture"] = ""
	if (state["active_blockers"] as Array).is_empty():
		state["status"] = "running"
		state["active_procedure"] = ""
		state["failed_step"] = ""
		state["failure"] = ""
		return
	state["status"] = "blocked"
	var primary: Dictionary = state["active_blockers"][0]
	state["active_procedure"] = primary["procedure"]
	if primary["kind"] == "protective_posture":
		state["blocked_posture"] = primary["id"]
	elif primary["kind"] == "service":
		state["blocked_service"] = primary["id"]
	else:
		state["blocked_job"] = primary["id"]


func _has_service(graph: RefCounted, state: Dictionary, room_id: String, kind: String) -> bool:
	var room_snapshot: Dictionary = state["room_service_available"].get(kind, {})
	var available := bool(room_snapshot.get(room_id, state["service_available"].get(kind, false)))
	if not available:
		return false
	for edge in graph.dependency_edges:
		if edge["consumer"] == room_id and edge["kind"] == kind and graph.rooms.has(edge["provider"]):
			return true
	return false


func _procedure_for_capability(graph: RefCounted, capability: String) -> String:
	for procedure_id in graph.failure_procedures:
		if (graph.failure_procedures[procedure_id]["capabilities"] as Array).has(capability):
			return procedure_id
	return ""


func _procedure_owner(graph: RefCounted, procedure_id: String) -> String:
	if graph.failure_procedures.has(procedure_id):
		return graph.failure_procedures[procedure_id]["owner_job"]
	return ""


func _status_result(state: Dictionary) -> Dictionary:
	return {
		"status": state["status"],
		"failed_step": state["failed_step"],
		"failure": state["failure"],
		"active_procedure": state["active_procedure"],
		"blocked_service": state["blocked_service"],
		"blocked_job": state["blocked_job"],
		"blocked_posture": state.get("blocked_posture", ""),
		"active_blockers": (state["active_blockers"] as Array).duplicate(true),
	}
