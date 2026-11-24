class_name FacilityProcedureWorkRuntime
extends RefCounted
## Durable dispatch, timed work, interruption, handoff, restart recovery, and one-use receipts.

const SNAPSHOT_SCHEMA := "facility-procedure-work/v1"


func start_scheduler() -> Dictionary:
	return {
		"tasks": {},
		"active_panel_tasks": {},
		"completion_receipts": {},
		"pending_handoffs": {},
		"work_log": [],
		"next_task_number": 1,
		"next_receipt_number": 1,
		"next_handoff_number": 1,
		"next_event_number": 1,
	}


func export_snapshot(state: Dictionary) -> Dictionary:
	var validated: Dictionary = _validated_snapshot_state(state)
	if not validated.get("accepted", false):
		return validated
	return {
		"accepted": true,
		"schema": SNAPSHOT_SCHEMA,
		"state": validated["state"],
	}


func recover_snapshot(snapshot: Dictionary) -> Dictionary:
	if snapshot.get("schema", "") != SNAPSHOT_SCHEMA or not snapshot.get("state", null) is Dictionary:
		return _denied("procedure work snapshot schema is invalid")
	var validated: Dictionary = _validated_snapshot_state(snapshot["state"])
	if not validated.get("accepted", false):
		return validated
	var state: Dictionary = validated["state"]
	var task_ids: Array = state["tasks"].keys()
	task_ids.sort()
	for task_id in task_ids:
		var task: Dictionary = state["tasks"][task_id]
		var prior_status: String = task["status"]
		if prior_status not in ["working", "dispatched", "handoff_pending"]:
			continue
		task["status"] = "interrupted"
		task["interruptions"].append({
			"reason": "restart_reconciliation_required",
			"remaining_ticks": task["remaining_ticks"],
			"prior_status": prior_status,
		})
		state["tasks"][task_id] = task
		_append_event(state, {"event": "work_recovered_interrupted", "task_id": task_id, "prior_status": prior_status, "remaining_ticks": task["remaining_ticks"]})
	state["pending_handoffs"] = {}
	return {"accepted": true, "state": state, "recovered_tasks": task_ids.size()}


func _validated_snapshot_state(supplied_state: Dictionary) -> Dictionary:
	var required_dictionaries := ["tasks", "active_panel_tasks", "completion_receipts", "pending_handoffs"]
	for field in required_dictionaries:
		if not supplied_state.get(field, null) is Dictionary:
			return _denied("procedure work snapshot field is invalid: %s" % field)
	if not supplied_state.get("work_log", null) is Array:
		return _denied("procedure work snapshot log is invalid")
	for counter in ["next_task_number", "next_receipt_number", "next_handoff_number", "next_event_number"]:
		if int(supplied_state.get(counter, 0)) < 1:
			return _denied("procedure work snapshot counter is invalid: %s" % counter)
	var state: Dictionary = supplied_state.duplicate(true)
	for counter in ["next_task_number", "next_receipt_number", "next_handoff_number", "next_event_number"]:
		state[counter] = int(state[counter])
	var expected_panels: Dictionary = {}
	var task_ids: Array = state["tasks"].keys()
	task_ids.sort()
	for task_id in task_ids:
		if not state["tasks"][task_id] is Dictionary:
			return _denied("procedure work snapshot task is invalid")
		var task: Dictionary = state["tasks"][task_id]
		for field in ["task_id", "panel_id", "service", "action", "station", "actor_job", "actor_person_id", "initiator", "status"]:
			if String(task.get(field, "")).is_empty():
				return _denied("procedure work snapshot task provenance is incomplete")
		if task["task_id"] != task_id:
			return _denied("procedure work snapshot task identity mismatch")
		var duration := int(task.get("duration_ticks", 0))
		var remaining := int(task.get("remaining_ticks", -1))
		if duration <= 0 or remaining < 0 or remaining > duration:
			return _denied("procedure work snapshot duration contradiction")
		task["duration_ticks"] = duration
		task["remaining_ticks"] = remaining
		if task["status"] not in ["dispatched", "working", "interrupted", "handoff_pending", "completed", "committed", "superseded"]:
			return _denied("procedure work snapshot task status is invalid")
		if not task.get("interruptions", null) is Array or not task.get("handoffs", null) is Array or not task.get("required_services", null) is Array:
			return _denied("procedure work snapshot task history or service requirements are invalid")
		if task["status"] == "completed" and remaining != 0:
			return _denied("completed procedure work retains remaining duration")
		if task["status"] not in ["committed", "superseded"]:
			if expected_panels.has(task["panel_id"]):
				return _denied("procedure work snapshot has duplicate active panel tasks")
			expected_panels[task["panel_id"]] = task_id
		state["tasks"][task_id] = task
	if state["active_panel_tasks"] != expected_panels:
		return _denied("procedure work snapshot active-panel index contradiction")
	for receipt_id in state["completion_receipts"]:
		var receipt: Variant = state["completion_receipts"][receipt_id]
		if not receipt is Dictionary or receipt.get("receipt_id", "") != receipt_id:
			return _denied("procedure work snapshot completion receipt identity mismatch")
		var task_id: String = receipt.get("task_id", "")
		if not state["tasks"].has(task_id) or state["tasks"][task_id]["status"] != "completed" or state["tasks"][task_id]["panel_id"] != receipt.get("panel_id", ""):
			return _denied("procedure work snapshot completion receipt provenance mismatch")
	for task_id in task_ids:
		var task: Dictionary = state["tasks"][task_id]
		if task["status"] == "completed":
			var receipt_matches := 0
			for receipt in state["completion_receipts"].values():
				if receipt.get("task_id", "") == task_id:
					receipt_matches += 1
			if receipt_matches != 1:
				return _denied("completed procedure work lacks exactly one receipt")
	for receipt_id in state["pending_handoffs"]:
		var receipt: Variant = state["pending_handoffs"][receipt_id]
		if not receipt is Dictionary or receipt.get("receipt_id", "") != receipt_id:
			return _denied("procedure work snapshot handoff receipt identity mismatch")
		var task_id: String = receipt.get("task_id", "")
		if not state["tasks"].has(task_id) or state["tasks"][task_id]["status"] != "handoff_pending" or int(state["tasks"][task_id]["remaining_ticks"]) != int(receipt.get("remaining_ticks", -1)):
			return _denied("procedure work snapshot handoff receipt provenance mismatch")
	for task_id in task_ids:
		if state["tasks"][task_id]["status"] == "handoff_pending":
			var handoff_matches := 0
			for receipt in state["pending_handoffs"].values():
				if receipt.get("task_id", "") == task_id:
					handoff_matches += 1
			if handoff_matches != 1:
				return _denied("handoff-pending work lacks exactly one receipt")
	return {"accepted": true, "state": state}


func tick_external_work(state: Dictionary, task_id: String, mutual_runtime: RefCounted, mutual_state: Dictionary) -> Dictionary:
	if not state["tasks"].has(task_id): return _denied("external procedure task is unknown")
	var task: Dictionary = state["tasks"][task_id]
	if task.get("control_mode", "") != "temporary_mutual_aid" or task["status"] != "working": return _denied("external procedure task is not working")
	var capacity: Dictionary = mutual_runtime.active_capacity(mutual_state, task["occurrence_id"])
	if not capacity.get("accepted", false) or capacity["responder_id"] != task["actor_person_id"] or capacity["credential_id"] != task["credential_id"] or capacity["destination"] != task["station"]: return _denied("external work lost occurrence-bound authority")
	task["remaining_ticks"] = int(task["remaining_ticks"]) - 1
	if task["remaining_ticks"] > 0: state["tasks"][task_id]=task; _append_event(state,{"event":"external_work_tick","task_id":task_id,"remaining_ticks":task["remaining_ticks"]}); return {"accepted":true,"completed":false,"remaining_ticks":task["remaining_ticks"]}
	task["remaining_ticks"]=0; task["status"]="completed"; state["tasks"][task_id]=task
	var receipt: Dictionary = _create_completion(state,task); return {"accepted":true,"completed":true,"receipt":receipt}


func revoke_external_work(state: Dictionary, task_id: String, reason: String) -> Dictionary:
	if not state["tasks"].has(task_id): return _denied("external procedure task is unknown")
	var task: Dictionary = state["tasks"][task_id]
	if task.get("control_mode", "") != "temporary_mutual_aid" or task["status"] not in ["working", "dispatched", "interrupted"]: return _denied("procedure task is not revocable external work")
	task["status"] = "superseded"; task["interruptions"].append({"reason":reason,"remaining_ticks":task["remaining_ticks"]}); state["tasks"][task_id]=task; state["active_panel_tasks"].erase(task["panel_id"])
	_append_event(state,{"event":"external_work_revoked","task_id":task_id,"reason":reason}); return {"accepted":true,"task_id":task_id}


func request_external_work(state: Dictionary, definition: Dictionary, initiator_id: String, mutual_runtime: RefCounted, mutual_state: Dictionary, occurrence_id: String) -> Dictionary:
	var capacity: Dictionary = mutual_runtime.active_capacity(mutual_state, occurrence_id)
	if not capacity.get("accepted", false): return _denied("no admitted external responder capacity")
	var panel_id: String = definition.get("panel_id", ""); var duration_ticks := int(definition.get("duration_ticks", 0))
	if panel_id.is_empty() or state["active_panel_tasks"].has(panel_id) or duration_ticks <= 0: return _denied("external procedure work definition is invalid or occupied")
	if capacity["response_job"] != definition.get("actor_job", "") or capacity["destination"] != definition.get("station", ""): return _denied("external capacity does not match work job and station")
	var task_id := "procedure-task-%d" % int(state["next_task_number"]); state["next_task_number"] = int(state["next_task_number"]) + 1
	var task := {"task_id":task_id,"panel_id":panel_id,"service":definition["service"],"action":definition["action"],"station":definition["station"],"actor_job":definition["actor_job"],"actor_person_id":capacity["responder_id"],"required_services":(definition.get("required_services",[]) as Array).duplicate(),"control_mode":"temporary_mutual_aid","equipment":definition.get("equipment",""),"initiator":initiator_id,"duration_ticks":duration_ticks,"remaining_ticks":duration_ticks,"status":"working","interruptions":[],"handoffs":[],"mutual_aid_case_id":capacity["case_id"],"occurrence_id":occurrence_id,"credential_id":capacity["credential_id"]}
	state["tasks"][task_id]=task; state["active_panel_tasks"][panel_id]=task_id; _append_event(state,{"event":"external_work_requested","task_id":task_id,"panel_id":panel_id,"actor_person_id":capacity["responder_id"],"status":"working"})
	return {"accepted":true,"task_id":task_id,"actor_person_id":capacity["responder_id"],"status":"working"}


func request_work(
	graph: RefCounted,
	state: Dictionary,
	definition: Dictionary,
	initiator_id: String,
	staffing_state: Dictionary,
	staffing_runtime: RefCounted,
	agent_state: Dictionary,
	agent_runtime: RefCounted
) -> Dictionary:
	var panel_id: String = definition.get("panel_id", "")
	if panel_id.is_empty() or state["active_panel_tasks"].has(panel_id):
		return _denied("panel already has active procedure work")
	var duration_ticks := int(definition.get("duration_ticks", 0))
	if duration_ticks <= 0:
		return _denied("procedure work requires nonzero duration")
	var job_id: String = definition.get("actor_job", "")
	var station: String = definition.get("station", "")
	var staff_ids: Array[String] = staffing_runtime.active_staff_ids(staffing_state, job_id)
	staff_ids.sort()
	var actor_id := ""
	var status := ""
	for staff_id in staff_ids:
		if agent_runtime.is_at_room(agent_state, staff_id, station):
			if agent_runtime.begin_work(agent_state, staff_id, station, definition["action"]).get("accepted", false):
				actor_id = staff_id
				status = "working"
				break
	if actor_id.is_empty():
		for staff_id in staff_ids:
			var dispatched: Dictionary = agent_runtime.dispatch(graph, agent_state, staff_id, station)
			if dispatched.get("accepted", false):
				actor_id = staff_id
				status = "dispatched"
				break
	if actor_id.is_empty():
		return _denied("no named active-watch actor can reach procedure station")
	var task_id := "procedure-task-%d" % int(state["next_task_number"])
	state["next_task_number"] = int(state["next_task_number"]) + 1
	var task := {
		"task_id": task_id,
		"panel_id": panel_id,
		"service": definition["service"],
		"action": definition["action"],
		"station": station,
		"actor_job": job_id,
		"actor_person_id": actor_id,
		"required_services": (definition.get("required_services", []) as Array).duplicate(),
		"control_mode": definition.get("control_mode", "primary_control"),
		"equipment": definition.get("equipment", ""),
		"initiator": initiator_id,
		"duration_ticks": duration_ticks,
		"remaining_ticks": duration_ticks,
		"status": status,
		"interruptions": [],
		"handoffs": [],
	}
	state["tasks"][task_id] = task
	state["active_panel_tasks"][panel_id] = task_id
	_append_event(state, {"event": "work_requested", "task_id": task_id, "panel_id": panel_id, "actor_person_id": actor_id, "status": status})
	return {"accepted": true, "task_id": task_id, "actor_person_id": actor_id, "status": status}


func task_conditions(graph: RefCounted, task: Dictionary, service_availability: Dictionary) -> Dictionary:
	var station: String = task.get("station", "")
	var actor_job: String = task.get("actor_job", "")
	if not graph.rooms.has(station) or not (graph.rooms[station].get("access_roles", []) as Array).has(actor_job):
		return {"available": false, "reason": "station_access_revoked", "station": station, "actor_job": actor_job}
	var required_services: Array = task.get("required_services", [])
	var station_services: Dictionary = service_availability.get(station, service_availability)
	for service_id in required_services:
		if not bool(station_services.get(service_id, false)):
			return {"available": false, "reason": "required_service_unavailable:%s" % service_id, "service": service_id, "station": station}
	return {"available": true, "station": station}


func reconcile_conditions(
	graph: RefCounted,
	state: Dictionary,
	service_availability: Dictionary,
	agent_state: Dictionary,
	agent_runtime: RefCounted
) -> Dictionary:
	var suspended: Array[Dictionary] = []
	var task_ids: Array = state["tasks"].keys()
	task_ids.sort()
	for task_id in task_ids:
		var task: Dictionary = state["tasks"][task_id]
		if task.get("control_mode", "") == "temporary_mutual_aid":
			continue
		if task["status"] not in ["working", "dispatched"]:
			continue
		var conditions: Dictionary = task_conditions(graph, task, service_availability)
		if conditions.get("available", false):
			continue
		var result: Dictionary = interrupt(state, task_id, conditions["reason"], agent_state, agent_runtime)
		if result.get("accepted", false):
			suspended.append({"task_id": task_id, "reason": conditions["reason"], "remaining_ticks": result["remaining_ticks"]})
	return {"suspended": suspended}


func tick(state: Dictionary, agent_state: Dictionary, agent_runtime: RefCounted) -> Dictionary:
	var movement: Dictionary = agent_runtime.tick(agent_state)
	var completions: Array[Dictionary] = []
	var task_ids: Array = state["tasks"].keys()
	task_ids.sort()
	for task_id in task_ids:
		var task: Dictionary = state["tasks"][task_id]
		if task.get("control_mode", "") == "temporary_mutual_aid":
			continue
		if task["status"] == "dispatched":
			if agent_runtime.is_at_room(agent_state, task["actor_person_id"], task["station"]):
				var started: Dictionary = agent_runtime.begin_work(agent_state, task["actor_person_id"], task["station"], task["action"])
				if started.get("accepted", false):
					task["status"] = "working"
					state["tasks"][task_id] = task
					_append_event(state, {"event": "work_started_after_arrival", "task_id": task_id, "actor_person_id": task["actor_person_id"]})
			continue
		if task["status"] != "working":
			continue
		if not agent_runtime.is_at_room(agent_state, task["actor_person_id"], task["station"]):
			interrupt(state, task_id, "actor_left_station", agent_state, agent_runtime)
			continue
		task["remaining_ticks"] = int(task["remaining_ticks"]) - 1
		_append_event(state, {"event": "work_progressed", "task_id": task_id, "remaining_ticks": task["remaining_ticks"]})
		if int(task["remaining_ticks"]) <= 0:
			task["status"] = "completed"
			agent_runtime.end_work(agent_state, task["actor_person_id"], "completed")
			var receipt := _create_completion(state, task)
			completions.append(receipt)
		state["tasks"][task_id] = task
	return {"movement": movement, "completions": completions}


func interrupt(
	state: Dictionary,
	task_id: String,
	reason: String,
	agent_state: Dictionary,
	agent_runtime: RefCounted
) -> Dictionary:
	if not state["tasks"].has(task_id):
		return _denied("procedure task does not exist")
	var task: Dictionary = state["tasks"][task_id]
	if task["status"] not in ["working", "dispatched"]:
		return _denied("procedure task is not interruptible")
	if task["status"] == "working":
		agent_runtime.end_work(agent_state, task["actor_person_id"], "interrupted")
	elif task["status"] == "dispatched" and agent_runtime.has_method("cancel_dispatch"):
		agent_runtime.cancel_dispatch(agent_state, task["actor_person_id"], reason)
	task["status"] = "interrupted"
	task["interruptions"].append({"reason": reason, "remaining_ticks": task["remaining_ticks"]})
	state["tasks"][task_id] = task
	_append_event(state, {"event": "work_interrupted", "task_id": task_id, "reason": reason, "remaining_ticks": task["remaining_ticks"]})
	return {"accepted": true, "task_id": task_id, "remaining_ticks": task["remaining_ticks"]}


func resume(state: Dictionary, task_id: String, agent_state: Dictionary, agent_runtime: RefCounted) -> Dictionary:
	if not state["tasks"].has(task_id):
		return _denied("procedure task does not exist")
	var task: Dictionary = state["tasks"][task_id]
	if task["status"] != "interrupted":
		return _denied("procedure task is not interrupted")
	if not agent_runtime.is_at_room(agent_state, task["actor_person_id"], task["station"]):
		return _denied("bound actor is not present to resume work")
	var started: Dictionary = agent_runtime.begin_work(agent_state, task["actor_person_id"], task["station"], task["action"])
	if not started.get("accepted", false):
		return started
	task["status"] = "working"
	state["tasks"][task_id] = task
	_append_event(state, {"event": "work_resumed", "task_id": task_id, "remaining_ticks": task["remaining_ticks"]})
	return {"accepted": true, "task_id": task_id, "actor_person_id": task["actor_person_id"], "remaining_ticks": task["remaining_ticks"]}


func begin_shift_handoffs(state: Dictionary, staffing_receipt: Dictionary) -> Dictionary:
	if not staffing_receipt.get("accepted", false) or staffing_receipt.get("turnover_id", "").is_empty():
		return _denied("staffing turnover receipt is invalid")
	if not (state["pending_handoffs"] as Dictionary).is_empty():
		return _denied("procedure work handoff already pending")
	var by_job: Dictionary = {}
	for handoff in staffing_receipt.get("handoffs", []):
		by_job[handoff["job_id"]] = handoff
	var reserved_incoming: Dictionary = {}
	var planned: Array[Dictionary] = []
	var task_ids: Array = state["tasks"].keys()
	task_ids.sort()
	for task_id in task_ids:
		var task: Dictionary = state["tasks"][task_id]
		if task["status"] not in ["working", "dispatched", "interrupted"]:
			continue
		var job_id: String = task["actor_job"]
		if not by_job.has(job_id):
			return _denied("active procedure work has no incoming shift handoff")
		var staffing_handoff: Dictionary = by_job[job_id]
		if not (staffing_handoff["outgoing"] as Array).has(task["actor_person_id"]):
			return _denied("active procedure actor is not in outgoing watch receipt")
		var incoming_ids: Array = (staffing_handoff["incoming"] as Array).duplicate()
		incoming_ids.sort()
		var incoming_id := ""
		for candidate in incoming_ids:
			if not reserved_incoming.has(candidate):
				incoming_id = candidate
				break
		if incoming_id.is_empty():
			return _denied("qualified incoming relief is already bound to other work")
		reserved_incoming[incoming_id] = task_id
		var receipt_id := "procedure-handoff-%d" % int(state["next_handoff_number"] + planned.size())
		planned.append({
			"receipt_id": receipt_id,
			"turnover_id": staffing_receipt["turnover_id"],
			"from_shift": staffing_receipt["from_shift"],
			"to_shift": staffing_receipt["to_shift"],
			"task_id": task_id,
			"panel_id": task["panel_id"],
			"actor_job": job_id,
			"station": task["station"],
			"outgoing_actor_person_id": task["actor_person_id"],
			"incoming_actor_person_id": incoming_id,
			"remaining_ticks": task["remaining_ticks"],
			"prior_status": task["status"],
		})
	state["next_handoff_number"] = int(state["next_handoff_number"]) + planned.size()
	for receipt in planned:
		state["pending_handoffs"][receipt["receipt_id"]] = receipt.duplicate(true)
		state["tasks"][receipt["task_id"]]["status"] = "handoff_pending"
		_append_event(state, {"event": "work_handoff_prepared", "task_id": receipt["task_id"], "receipt_id": receipt["receipt_id"], "turnover_id": receipt["turnover_id"], "outgoing_actor_person_id": receipt["outgoing_actor_person_id"], "incoming_actor_person_id": receipt["incoming_actor_person_id"], "remaining_ticks": receipt["remaining_ticks"]})
	return {"accepted": true, "turnover_id": staffing_receipt["turnover_id"], "receipts": planned}


func complete_shift_handoff(
	graph: RefCounted,
	state: Dictionary,
	supplied_receipt: Dictionary,
	agent_state: Dictionary,
	agent_runtime: RefCounted
) -> Dictionary:
	var receipt_id: String = supplied_receipt.get("receipt_id", "")
	if receipt_id.is_empty() or not state["pending_handoffs"].has(receipt_id):
		return _denied("procedure handoff receipt is unknown or consumed")
	var receipt: Dictionary = state["pending_handoffs"][receipt_id]
	for field in ["turnover_id", "task_id", "panel_id", "actor_job", "station", "outgoing_actor_person_id", "incoming_actor_person_id", "remaining_ticks"]:
		if supplied_receipt.get(field) != receipt.get(field):
			return _denied("procedure handoff receipt provenance mismatch")
	var task: Dictionary = state["tasks"].get(receipt["task_id"], {})
	if task.is_empty() or task["status"] != "handoff_pending" or int(task["remaining_ticks"]) != int(receipt["remaining_ticks"]):
		return _denied("procedure task no longer matches handoff receipt")
	var incoming_id: String = receipt["incoming_actor_person_id"]
	if not agent_state["agents"].has(incoming_id) or agent_state["agents"][incoming_id]["job_id"] != receipt["actor_job"]:
		return _denied("incoming handoff actor is not qualified active watch")
	var new_status := ""
	if agent_runtime.is_at_room(agent_state, incoming_id, receipt["station"]):
		var started: Dictionary = agent_runtime.begin_work(agent_state, incoming_id, receipt["station"], task["action"])
		if not started.get("accepted", false):
			return started
		new_status = "working"
	else:
		var dispatched: Dictionary = agent_runtime.dispatch(graph, agent_state, incoming_id, receipt["station"])
		if not dispatched.get("accepted", false):
			return dispatched
		new_status = "dispatched"
	task["actor_person_id"] = incoming_id
	task["status"] = new_status
	task["handoffs"].append(receipt.duplicate(true))
	state["tasks"][task["task_id"]] = task
	state["pending_handoffs"].erase(receipt_id)
	_append_event(state, {"event": "work_handoff_completed", "task_id": task["task_id"], "receipt_id": receipt_id, "turnover_id": receipt["turnover_id"], "actor_person_id": incoming_id, "remaining_ticks": task["remaining_ticks"], "status": new_status})
	return {"accepted": true, "task_id": task["task_id"], "receipt_id": receipt_id, "actor_person_id": incoming_id, "remaining_ticks": task["remaining_ticks"], "status": new_status}


func cancel_shift_handoffs(state: Dictionary, turnover_id: String) -> Dictionary:
	var cancelled: Array[String] = []
	var receipt_ids: Array = state["pending_handoffs"].keys()
	receipt_ids.sort()
	for receipt_id in receipt_ids:
		var receipt: Dictionary = state["pending_handoffs"][receipt_id]
		if receipt["turnover_id"] != turnover_id:
			continue
		var task: Dictionary = state["tasks"][receipt["task_id"]]
		task["status"] = receipt["prior_status"]
		state["tasks"][task["task_id"]] = task
		state["pending_handoffs"].erase(receipt_id)
		cancelled.append(receipt_id)
		_append_event(state, {"event": "work_handoff_cancelled", "task_id": task["task_id"], "receipt_id": receipt_id, "turnover_id": turnover_id})
	return {"accepted": true, "turnover_id": turnover_id, "cancelled": cancelled}


func supersede_conflicting_work(
	state: Dictionary,
	winning_task_id: String,
	agent_state: Dictionary,
	agent_runtime: RefCounted
) -> Dictionary:
	if not state["tasks"].has(winning_task_id):
		return _denied("winning procedure task does not exist")
	var winner: Dictionary = state["tasks"][winning_task_id]
	var superseded: Array[String] = []
	var task_ids: Array = state["tasks"].keys()
	task_ids.sort()
	for task_id in task_ids:
		if task_id == winning_task_id:
			continue
		var task: Dictionary = state["tasks"][task_id]
		if task["service"] != winner["service"] or task["action"] != winner["action"] or task["status"] not in ["working", "dispatched", "interrupted", "handoff_pending"]:
			continue
		if task["status"] == "working":
			agent_runtime.end_work(agent_state, task["actor_person_id"], "superseded")
		elif task["status"] == "dispatched" and agent_runtime.has_method("cancel_dispatch"):
			agent_runtime.cancel_dispatch(agent_state, task["actor_person_id"], "superseded")
		var pending_ids: Array = state["pending_handoffs"].keys()
		for receipt_id in pending_ids:
			if state["pending_handoffs"][receipt_id]["task_id"] == task_id:
				state["pending_handoffs"].erase(receipt_id)
		task["status"] = "superseded"
		task["superseded_by_task_id"] = winning_task_id
		state["active_panel_tasks"].erase(task["panel_id"])
		superseded.append(task_id)
		_append_event(state, {"event": "work_superseded", "task_id": task_id, "winning_task_id": winning_task_id, "service": task["service"], "action": task["action"], "remaining_ticks": task["remaining_ticks"]})
	return {"accepted": true, "winning_task_id": winning_task_id, "superseded": superseded}


func consume_completion(state: Dictionary, supplied_receipt: Dictionary) -> Dictionary:
	var receipt_id: String = supplied_receipt.get("receipt_id", "")
	if receipt_id.is_empty() or not state["completion_receipts"].has(receipt_id):
		return _denied("work completion receipt is unknown or consumed")
	var receipt: Dictionary = state["completion_receipts"][receipt_id]
	if receipt["task_id"] != supplied_receipt.get("task_id", "") or receipt["panel_id"] != supplied_receipt.get("panel_id", ""):
		return _denied("work completion receipt provenance mismatch")
	state["completion_receipts"].erase(receipt_id)
	state["active_panel_tasks"].erase(receipt["panel_id"])
	state["tasks"][receipt["task_id"]]["status"] = "committed"
	_append_event(state, {"event": "completion_consumed", "task_id": receipt["task_id"], "receipt_id": receipt_id})
	return {"accepted": true, "task_id": receipt["task_id"], "receipt_id": receipt_id}


func _create_completion(state: Dictionary, task: Dictionary) -> Dictionary:
	var receipt_id := "procedure-work-receipt-%d" % int(state["next_receipt_number"])
	state["next_receipt_number"] = int(state["next_receipt_number"]) + 1
	var receipt := {
		"receipt_id": receipt_id,
		"task_id": task["task_id"],
		"panel_id": task["panel_id"],
		"service": task["service"],
		"action": task["action"],
		"station": task["station"],
		"actor_person_id": task["actor_person_id"],
		"initiator": task["initiator"],
		"duration_ticks": task["duration_ticks"],
	}
	state["completion_receipts"][receipt_id] = receipt
	_append_event(state, {"event": "work_completed", "task_id": task["task_id"], "receipt_id": receipt_id})
	return receipt


func _append_event(state: Dictionary, event: Dictionary) -> void:
	event["event_number"] = state["next_event_number"]
	state["next_event_number"] = int(state["next_event_number"]) + 1
	state["work_log"].append(event)


func _denied(reason: String) -> Dictionary:
	return {"accepted": false, "reason": reason}
