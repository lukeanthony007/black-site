class_name FacilityStaffingRuntime
extends RefCounted
## Deterministic staffing schedule and responsibility-local shortage handling.

const SHIFT_IDS: Array[String] = ["day", "swing", "night"]


func build_schedule(graph: RefCounted) -> Dictionary:
	var state := {
		"seed": graph.seed,
		"shift_ids": SHIFT_IDS.duplicate(),
		"active_shift": "day",
		"staff": {},
		"assignments": {},
		"relief": {},
		"active_relief": {},
		"incident_holdovers": {},
		"incident_holdover_log": [],
		"unavailable": {},
		"shortage_log": [],
		"on_call_log": [],
		"pending_turnover": {},
		"turnover_log": [],
		"turnover_cancellation_log": [],
		"next_turnover_number": 1,
		"next_staff_number": 1,
	}
	var job_ids: Array = graph.jobs.keys()
	job_ids.sort()
	for shift_id in SHIFT_IDS:
		state["assignments"][shift_id] = {}
		for job_id in job_ids:
			state["assignments"][shift_id][job_id] = []
	for job_id in job_ids:
		state["relief"][job_id] = []
		state["active_relief"][job_id] = []
		var minimum: int = graph.jobs[job_id]["minimum_on_shift"]
		if bool(graph.jobs[job_id]["continuous"]):
			for shift_id in SHIFT_IDS:
				for _position in minimum:
					_add_staff(state, job_id, "primary", shift_id)
		else:
			for _position in minimum:
				_add_staff(state, job_id, "primary", "day")
		_add_staff(state, job_id, "relief", "relief")

	var capacity: int = graph.generation_profile["staff_capacity"]
	var extra_index := 0
	while state["staff"].size() < capacity:
		var job_id: String = job_ids[extra_index % job_ids.size()]
		if bool(graph.jobs[job_id]["continuous"]):
			var shift_id: String = SHIFT_IDS[(extra_index / job_ids.size()) % SHIFT_IDS.size()]
			_add_staff(state, job_id, "primary", shift_id)
		elif extra_index % 2 == 0:
			_add_staff(state, job_id, "primary", "day")
		else:
			_add_staff(state, job_id, "relief", "relief")
		extra_index += 1
	state.erase("next_staff_number")
	return state


func set_active_shift(state: Dictionary, shift_id: String) -> void:
	if (state["shift_ids"] as Array).has(shift_id):
		state["active_shift"] = shift_id


func begin_shift_turnover(graph: RefCounted, state: Dictionary, to_shift: String) -> Dictionary:
	if not (state["pending_turnover"] as Dictionary).is_empty():
		return {"accepted": false, "reason": "turnover already pending"}
	var from_shift: String = state["active_shift"]
	var from_index: int = SHIFT_IDS.find(from_shift)
	if from_index < 0 or to_shift != SHIFT_IDS[(from_index + 1) % SHIFT_IDS.size()]:
		return {"accepted": false, "reason": "turnover is not the next scheduled shift"}
	var handoffs: Array[Dictionary] = []
	var planned_relief: Dictionary = {}
	var job_ids: Array = graph.jobs.keys()
	job_ids.sort()
	for job_id in job_ids:
		if not bool(graph.jobs[job_id]["continuous"]):
			continue
		var minimum: int = graph.jobs[job_id]["minimum_on_shift"]
		var incoming: Array[String] = []
		for staff_id in state["assignments"][to_shift][job_id]:
			if not state["unavailable"].has(staff_id):
				incoming.append(staff_id)
		var relief_for_job: Array[String] = []
		for relief_id in state["relief"][job_id]:
			if incoming.size() >= minimum:
				break
			if not state["unavailable"].has(relief_id):
				incoming.append(relief_id)
				relief_for_job.append(relief_id)
		if incoming.size() < minimum:
			return {"accepted": false, "reason": "incoming continuous post is uncovered", "job_id": job_id}
		planned_relief[job_id] = relief_for_job
		handoffs.append({
			"job_id": job_id,
			"outgoing": _active_staff_ids(state, job_id),
			"incoming": incoming,
		})
	var turnover_id := "turnover-%d" % int(state["next_turnover_number"])
	state["next_turnover_number"] = int(state["next_turnover_number"]) + 1
	var receipt := {
		"accepted": true,
		"turnover_id": turnover_id,
		"from_shift": from_shift,
		"to_shift": to_shift,
		"handoffs": handoffs,
		"planned_relief": planned_relief,
	}
	state["pending_turnover"] = receipt.duplicate(true)
	return receipt


func cancel_shift_turnover(state: Dictionary, receipt: Dictionary, reason: String) -> Dictionary:
	var pending: Dictionary = state["pending_turnover"]
	if pending.is_empty() or receipt.get("turnover_id", "") != pending.get("turnover_id", ""):
		return {"accepted": false, "reason": "turnover receipt is unknown or consumed"}
	state["turnover_cancellation_log"].append({
		"turnover_id": pending["turnover_id"],
		"from_shift": pending["from_shift"],
		"to_shift": pending["to_shift"],
		"reason": reason,
	})
	state["pending_turnover"] = {}
	return {"accepted": true, "turnover_id": pending["turnover_id"], "active_shift": state["active_shift"]}


func complete_shift_turnover(graph: RefCounted, state: Dictionary, receipt: Dictionary) -> Dictionary:
	var pending: Dictionary = state["pending_turnover"]
	if pending.is_empty() or receipt.get("turnover_id", "") != pending.get("turnover_id", ""):
		return {"accepted": false, "reason": "turnover receipt is unknown or consumed"}
	if state["active_shift"] != pending["from_shift"]:
		return {"accepted": false, "reason": "outgoing shift no longer matches receipt"}
	for job_id in state["active_relief"]:
		state["active_relief"][job_id] = []
	for job_id in pending["planned_relief"]:
		state["active_relief"][job_id] = (pending["planned_relief"][job_id] as Array).duplicate()
	state["active_shift"] = pending["to_shift"]
	for job_id in graph.jobs:
		if bool(graph.jobs[job_id]["continuous"]) and _active_coverage(state, job_id) < int(graph.jobs[job_id]["minimum_on_shift"]):
			state["active_shift"] = pending["from_shift"]
			return {"accepted": false, "reason": "post-completion continuous coverage contradiction", "job_id": job_id}
	state["turnover_log"].append(pending.duplicate(true))
	state["pending_turnover"] = {}
	return {"accepted": true, "turnover_id": receipt["turnover_id"], "active_shift": state["active_shift"]}


func coverage_for_shift(state: Dictionary, job_id: String, shift_id: String) -> int:
	if not state["assignments"].has(shift_id) or not state["assignments"][shift_id].has(job_id):
		return 0
	var count := 0
	for staff_id in state["assignments"][shift_id][job_id]:
		if not state["unavailable"].has(staff_id):
			count += 1
	return count


func relief_staff_ids(state: Dictionary, job_id: String) -> Array[String]:
	var result: Array[String] = []
	for staff_id in state["relief"].get(job_id, []):
		if not state["unavailable"].has(staff_id):
			result.append(staff_id)
	return result


func active_primary_staff_ids(state: Dictionary, job_id: String) -> Array[String]:
	var result: Array[String] = []
	for staff_id in state["assignments"][state["active_shift"]].get(job_id, []):
		if not state["unavailable"].has(staff_id):
			result.append(staff_id)
	return result


func active_staff_ids(state: Dictionary, job_id: String) -> Array[String]:
	return _active_staff_ids(state, job_id)


func mobilize_qualified_relief(graph: RefCounted, state: Dictionary, job_id: String) -> Dictionary:
	if not graph.jobs.has(job_id):
		return {"accepted": false, "reason": "job is unknown"}
	if not bool(graph.jobs[job_id]["continuous"]):
		return mobilize_on_call(graph, state, job_id)
	var mobilized: Array[String] = []
	var coverage: int = _active_coverage(state, job_id)
	var minimum: int = graph.jobs[job_id]["minimum_on_shift"]
	for staff_id in state["relief"][job_id]:
		if coverage >= minimum: break
		if state["unavailable"].has(staff_id) or (state["active_relief"][job_id] as Array).has(staff_id): continue
		state["active_relief"][job_id].append(staff_id)
		mobilized.append(staff_id)
		coverage += 1
	var result := {"accepted": coverage >= minimum, "job_id": job_id, "shift": state["active_shift"], "mobilized_staff": mobilized, "mode": "continuous_relief"}
	state["on_call_log"].append(result.duplicate(true))
	return result


func mobilize_on_call(graph: RefCounted, state: Dictionary, job_id: String) -> Dictionary:
	if not graph.jobs.has(job_id):
		return {"accepted": false, "reason": "job is unknown"}
	if bool(graph.jobs[job_id]["continuous"]):
		return {"accepted": false, "reason": "continuous watch must use ordinary relief"}
	var mobilized: Array[String] = []
	var minimum: int = graph.jobs[job_id]["minimum_on_shift"]
	var coverage := _active_coverage(state, job_id)
	for staff_id in state["relief"][job_id]:
		if coverage >= minimum:
			break
		if state["unavailable"].has(staff_id) or (state["active_relief"][job_id] as Array).has(staff_id):
			continue
		state["active_relief"][job_id].append(staff_id)
		mobilized.append(staff_id)
		coverage += 1
	var result := {
		"accepted": coverage >= minimum,
		"job_id": job_id,
		"shift": state["active_shift"],
		"mobilized_staff": mobilized,
	}
	if not result["accepted"]:
		result["reason"] = "on-call relief cannot cover job"
	state["on_call_log"].append(result.duplicate(true))
	return result


func all_staff_ids_for_job(state: Dictionary, job_id: String) -> Array[String]:
	var result: Array[String] = []
	for staff_id in state["staff"]:
		if state["staff"][staff_id]["job_id"] == job_id:
			result.append(staff_id)
	result.sort()
	return result


func apply_shortage(graph: RefCounted, state: Dictionary, unavailable_staff_ids: Array) -> Dictionary:
	for staff_id in unavailable_staff_ids:
		if state["staff"].has(staff_id):
			state["unavailable"][staff_id] = true
	var relief_assignments: Array[Dictionary] = []
	var uncovered_jobs: Array[String] = []
	var job_ids: Array = graph.jobs.keys()
	job_ids.sort()
	for job_id in job_ids:
		_prune_active_relief(state, job_id)
		var minimum: int = graph.jobs[job_id]["minimum_on_shift"]
		var covered := _active_coverage(state, job_id)
		for relief_id in state["relief"][job_id]:
			if covered >= minimum:
				break
			if state["unavailable"].has(relief_id) or (state["active_relief"][job_id] as Array).has(relief_id):
				continue
			state["active_relief"][job_id].append(relief_id)
			relief_assignments.append({"staff_id": relief_id, "job_id": job_id, "shift": state["active_shift"]})
			covered += 1
		if covered < minimum:
			uncovered_jobs.append(job_id)
	var procedure: Dictionary = graph.failure_procedures.get("staffing_shortage", {})
	var result := {
		"procedure": procedure.get("id", ""),
		"owner_job": procedure.get("owner_job", ""),
		"preserves": (procedure.get("preserves", []) as Array).duplicate(),
		"relief_assignments": relief_assignments,
		"uncovered_jobs": uncovered_jobs,
	}
	state["shortage_log"].append(result.duplicate(true))
	return result


func is_staff_on_duty(state: Dictionary, staff_id: String, job_id: String) -> bool:
	if not state["staff"].has(staff_id) or state["staff"][staff_id]["job_id"] != job_id:
		return false
	return _active_staff_ids(state, job_id).has(staff_id)


func is_job_covered(state: Dictionary, job_id: String) -> bool:
	if not state["staff"].values().any(func(record: Dictionary) -> bool: return record["job_id"] == job_id):
		return false
	var minimum := 1
	return _active_coverage(state, job_id) >= minimum


func mission_step_available(graph: RefCounted, state: Dictionary, step_id: String) -> bool:
	for step in graph.mission_steps:
		if step["id"] == step_id:
			return is_job_covered(state, step["owner_job"])
	return false


func apply_mission_availability(
	graph: RefCounted,
	state: Dictionary,
	operation_runtime: RefCounted,
	mission_state: Dictionary
) -> void:
	for job_id in graph.jobs:
		operation_runtime.set_job_available(mission_state, job_id, is_job_covered(state, job_id))


func security_function_available(state: Dictionary, function_id: String) -> bool:
	if function_id == "entry_screening":
		return is_job_covered(state, "security_officer")
	return false


func custody_destination_available(graph: RefCounted, state: Dictionary, room_id: String) -> bool:
	if not graph.rooms.has(room_id):
		return false
	for owner_job in graph.rooms[room_id]["owners"]:
		if is_job_covered(state, owner_job):
			return true
	return false


func _add_staff(state: Dictionary, job_id: String, assignment_type: String, shift_id: String) -> void:
	var number: int = state["next_staff_number"]
	state["next_staff_number"] = number + 1
	var staff_id := "%s-%03d" % [job_id, number]
	state["staff"][staff_id] = {
		"staff_id": staff_id,
		"job_id": job_id,
		"assignment_type": assignment_type,
		"shift": shift_id,
	}
	if assignment_type == "relief":
		state["relief"][job_id].append(staff_id)
	else:
		state["assignments"][shift_id][job_id].append(staff_id)


func _active_staff_ids(state: Dictionary, job_id: String) -> Array[String]:
	var result := active_primary_staff_ids(state, job_id)
	for staff_id in state["active_relief"].get(job_id, []):
		if not state["unavailable"].has(staff_id):
			result.append(staff_id)
	for staff_id in state.get("incident_holdovers",{}):
		var holdover: Dictionary=state["incident_holdovers"][staff_id]
		if holdover.get("job_id","")==job_id and not state["unavailable"].has(staff_id) and staff_id not in result: result.append(staff_id)
	return result


func _active_coverage(state: Dictionary, job_id: String) -> int:
	return _active_staff_ids(state, job_id).size()


func _prune_active_relief(state: Dictionary, job_id: String) -> void:
	var retained: Array[String] = []
	for staff_id in state["active_relief"][job_id]:
		if not state["unavailable"].has(staff_id):
			retained.append(staff_id)
	state["active_relief"][job_id] = retained
