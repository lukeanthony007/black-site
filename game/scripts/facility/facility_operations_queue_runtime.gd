class_name FacilityOperationsQueueRuntime
extends RefCounted
## Durable cross-domain incident intake, deadline escalation, and one-at-a-time dispatch arbitration.

const STATE_SCHEMA := "facility-operations-queue/v1"


func start_queue() -> Dictionary:
	return {"schema": STATE_SCHEMA, "clock": 0, "entries": {}, "reservations": {"actors": {}, "stations": {}}, "continuity_decisions": [], "reactivation_receipts": {}, "next_reactivation_number": 1, "history": [], "next_event_number": 1}


func validate_state(state: Dictionary) -> Dictionary:
	if state.get("schema", "") != STATE_SCHEMA or not state.get("reactivation_receipts", null) is Dictionary or int(state.get("next_reactivation_number", 0)) < 1 or int(state.get("clock", -1)) < 0 or not state.get("entries", null) is Dictionary or not state.get("reservations", null) is Dictionary or not state["reservations"].get("actors", null) is Dictionary or not state["reservations"].get("stations", null) is Dictionary or not state.get("continuity_decisions", null) is Array or not state.get("history", null) is Array or int(state.get("next_event_number", 0)) < 1:
		return _denied("operations queue state shape is invalid")
	for entry_id in state["entries"]:
		var entry: Variant = state["entries"][entry_id]
		if not entry is Dictionary or entry.get("entry_id", "") != entry_id:
			return _denied("operations queue entry identity mismatch")
		for field in ["panel_id", "domain", "action", "actor_job", "station", "status"]:
			if String(entry.get(field, "")).is_empty():
				return _denied("operations queue entry provenance is incomplete")
		if entry["status"] not in ["waiting", "dispatched", "resolved", "terminal_failed", "abandoned", "safe_hold", "mission_shutdown"] or entry.get("abandonment_action", "") not in ["mobilize_qualified_relief", "mission_safe_hold"] or (entry.get("abandonment_action", "") == "mobilize_qualified_relief" and entry.get("relief_failure_action", "") != "mission_shutdown") or int(entry.get("first_seen", -1)) < 0 or int(entry.get("deadline_ticks", 0)) < 1 or int(entry.get("retry_backoff_ticks", 0)) < 1 or int(entry.get("max_wait_ticks", 0)) < int(entry.get("deadline_ticks", 0)) or int(entry.get("base_priority", 0)) < 1 or int(entry.get("attempts", -1)) < 0:
			return _denied("operations queue entry timing or status is invalid")
	return {"accepted": true, "state": state.duplicate(true)}


func advance(state: Dictionary, candidates: Array[Dictionary]) -> Dictionary:
	state["clock"] = int(state["clock"]) + 1
	var active_ids: Dictionary = {}
	for candidate in candidates:
		var entry_id: String = candidate["entry_id"]
		active_ids[entry_id] = true
		if not state["entries"].has(entry_id):
			state["entries"][entry_id] = {
				"entry_id": entry_id, "panel_id": candidate["panel_id"], "domain": candidate["domain"],
				"action": candidate["action"], "actor_job": candidate["actor_job"], "station": candidate["station"], "base_priority": candidate["base_priority"],
				"deadline_ticks": candidate["deadline_ticks"], "first_seen": state["clock"], "status": "waiting",
				"escalated": false, "task_id": "", "actor_person_id": "", "attempts": 0, "last_blocker": "", "retry_backoff_ticks": candidate["retry_backoff_ticks"], "max_wait_ticks": candidate["max_wait_ticks"], "abandonment_action": candidate["abandonment_action"], "relief_failure_action": candidate.get("relief_failure_action", ""), "reactivation_authority_job": candidate.get("reactivation_authority_job", ""), "reactivation_station": candidate.get("reactivation_station", ""), "next_attempt_clock": state["clock"], "reassignments": 0, "reactivations": 0,
			}
			_event(state, "incident_queued", entry_id)
		else:
			var current: Dictionary = state["entries"][entry_id]
			if current["status"] == "resolved":
				current["status"] = "waiting"
				current["first_seen"] = state["clock"]
				current["escalated"] = false
				current["task_id"] = ""
			state["entries"][entry_id] = current
	for entry_id in state["entries"]:
		var entry: Dictionary = state["entries"][entry_id]
		if entry["status"] != "resolved" and not active_ids.has(entry_id):
			_release_reservations(state, entry_id)
			entry["status"] = "resolved"
			state["entries"][entry_id] = entry
			_event(state, "incident_resolved", entry_id)
	var waiting: Array[Dictionary] = []
	var abandoned: Array[Dictionary] = []
	for entry_id in active_ids:
		var entry: Dictionary = state["entries"][entry_id]
		if entry["status"] != "waiting":
			continue
		var age: int = int(state["clock"]) - int(entry["first_seen"])
		if age >= int(entry["max_wait_ticks"]):
			entry["status"] = "abandoned"
			state["entries"][entry_id] = entry
			_event(state, "incident_abandoned", entry_id, {"reason": "continuity_limit_exceeded", "age": age})
			abandoned.append(entry.duplicate(true))
			continue
		if int(state["clock"]) < int(entry["next_attempt_clock"]):
			continue
		if state["reservations"]["stations"].has(entry["station"]):
			continue
		if age >= int(entry["deadline_ticks"]) and not bool(entry["escalated"]):
			entry["escalated"] = true
			state["entries"][entry_id] = entry
			_event(state, "incident_escalated", entry_id)
		entry["effective_priority"] = int(entry["base_priority"]) - (100 if entry["escalated"] else 0)
		entry["age"] = age
		waiting.append(entry)
	waiting.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["effective_priority"] != b["effective_priority"]:
			return a["effective_priority"] < b["effective_priority"]
		if a["first_seen"] != b["first_seen"]:
			return a["first_seen"] < b["first_seen"]
		return a["entry_id"] < b["entry_id"]
	)
	return {"accepted": true, "clock": state["clock"], "queue": waiting, "selected": waiting[0].duplicate(true) if not waiting.is_empty() else {}, "abandoned": abandoned}


func record_continuity_decision(state: Dictionary, entry_id: String, accepted: bool, evidence: Dictionary) -> Dictionary:
	if not state["entries"].has(entry_id) or state["entries"][entry_id]["status"] != "abandoned":
		return _denied("continuity decision has no abandoned occurrence")
	var entry: Dictionary = state["entries"][entry_id]
	var decision := {"entry_id": entry_id, "action": entry["abandonment_action"], "accepted": accepted, "clock": state["clock"], "evidence": evidence.duplicate(true)}
	state["continuity_decisions"].append(decision)
	if entry["abandonment_action"] == "mobilize_qualified_relief" and accepted:
		entry["status"] = "waiting"
		entry["first_seen"] = state["clock"]
		entry["next_attempt_clock"] = int(state["clock"]) + 1
		entry["escalated"] = false
		entry["reassignments"] = int(entry["reassignments"]) + 1
	elif entry["abandonment_action"] == "mobilize_qualified_relief":
		entry["status"] = "mission_shutdown"
		var shutdown := {"entry_id": entry_id, "action": "mission_shutdown", "accepted": true, "clock": state["clock"], "evidence": {"trigger": "qualified_relief_unavailable", "failed_decision": decision.duplicate(true)}}
		state["continuity_decisions"].append(shutdown)
		_event(state, "continuity_mission_shutdown", entry_id, {"trigger": "qualified_relief_unavailable"})
	else:
		entry["status"] = "safe_hold"
	state["entries"][entry_id] = entry
	if entry["status"] == "waiting":
		_event(state, "continuity_reassigned", entry_id, {"accepted": accepted, "action": entry["abandonment_action"]})
	elif entry["status"] == "safe_hold":
		_event(state, "continuity_safe_hold", entry_id, {"accepted": accepted, "action": entry["abandonment_action"]})
	return {"accepted": true, "status": entry["status"], "decision": decision}


func authorize_reactivation(state: Dictionary, entry_id: String, actor_person_id: String, actor_job: String, station: String) -> Dictionary:
	if not state["entries"].has(entry_id) or state["entries"][entry_id]["status"] != "mission_shutdown":
		return _denied("reactivation requires an active mission shutdown")
	var entry: Dictionary = state["entries"][entry_id]
	if actor_person_id.is_empty() or actor_job != entry["reactivation_authority_job"] or station != entry["reactivation_station"]:
		return _denied("reactivation authority identity or station is invalid")
	for receipt in state["reactivation_receipts"].values():
		if receipt["entry_id"] == entry_id: return _denied("reactivation receipt already exists for occurrence")
	var receipt_id := "reactivation-%d" % int(state["next_reactivation_number"])
	state["next_reactivation_number"] = int(state["next_reactivation_number"]) + 1
	var receipt := {"receipt_id": receipt_id, "entry_id": entry_id, "actor_person_id": actor_person_id, "actor_job": actor_job, "station": station, "clock": state["clock"], "consumed": true}
	state["reactivation_receipts"][receipt_id] = receipt
	entry["status"] = "waiting"
	entry["first_seen"] = state["clock"]
	entry["next_attempt_clock"] = int(state["clock"]) + 1
	entry["escalated"] = false
	entry["reactivations"] = int(entry["reactivations"]) + 1
	state["entries"][entry_id] = entry
	_event(state, "mission_reactivation_authorized", entry_id, {"receipt_id": receipt_id, "actor_person_id": actor_person_id, "station": station})
	return {"accepted": true, "receipt": receipt, "status": "waiting"}


func finalize_external_semantic_commit(state: Dictionary, work_runtime: RefCounted, work_state: Dictionary, mutual_runtime: RefCounted, mutual_state: Dictionary, entry_id: String, receipt: Dictionary, semantic_result: Dictionary) -> Dictionary:
	var task_id: String = receipt.get("task_id", "")
	if not work_state["tasks"].has(task_id): return _denied("semantic result references unknown external task")
	var task: Dictionary = work_state["tasks"][task_id]
	if not semantic_result.get("accepted", false) or semantic_result.get("task_id", "") != task_id or semantic_result.get("receipt_id", "") != receipt.get("receipt_id", "") or semantic_result.get("panel_id", "") != receipt.get("panel_id", "") or semantic_result.get("actor_person_id", "") != receipt.get("actor_person_id", "") or semantic_result.get("occurrence_id", "") != task.get("occurrence_id", "") or semantic_result.get("service", "") != task.get("service", "") or semantic_result.get("action", "") != task.get("action", "") or semantic_result.get("station", "") != task.get("station", ""):
		return _denied("semantic authority rejected or contradicted external completion")
	if not state["entries"].has(entry_id) or not mutual_state["capacity_reservations"].has(entry_id): return _denied("external completion dispatch is unknown")
	var queue_before: Dictionary=state.duplicate(true); var work_before: Dictionary=work_state.duplicate(true); var mutual_before: Dictionary=mutual_state.duplicate(true)
	var consumed: Dictionary=work_runtime.consume_completion(work_state,receipt)
	if not consumed.get("accepted",false): return consumed
	var outcome: Dictionary=record_task_outcome(state,consumed["task_id"],"committed","semantic_commit_accepted")
	var released: Dictionary=mutual_runtime.release_capacity(mutual_state,entry_id)
	if not outcome.get("accepted",false) or not released.get("accepted",false):
		state.clear();state.merge(queue_before,true);work_state.clear();work_state.merge(work_before,true);mutual_state.clear();mutual_state.merge(mutual_before,true);return _denied("external semantic commit closure rolled back")
	return {"accepted":true,"task_id":consumed["task_id"],"queue_status":outcome["status"],"credential_retained":true}


func revoke_external_dispatch_for_closed_occurrence(state: Dictionary, work_runtime: RefCounted, work_state: Dictionary, mutual_runtime: RefCounted, mutual_state: Dictionary, entry_id: String, occurrence_id: String) -> Dictionary:
	if not state["entries"].has(entry_id) or not mutual_state["capacity_reservations"].has(entry_id): return _denied("active external dispatch is unknown")
	var task_id: String = state["entries"][entry_id]["task_id"]; var queue_before: Dictionary = state.duplicate(true); var work_before: Dictionary = work_state.duplicate(true); var mutual_before: Dictionary = mutual_state.duplicate(true)
	var revoked: Dictionary = work_runtime.revoke_external_work(work_state, task_id, "source_occurrence_closed")
	if not revoked.get("accepted", false): return revoked
	var outcome: Dictionary = record_task_outcome(state, task_id, "failed", "source_occurrence_closed")
	var released: Dictionary = mutual_runtime.release_capacity(mutual_state, entry_id)
	var cases: Array[Dictionary] = mutual_runtime.revoke_closed_occurrences(mutual_state, [])
	if not outcome.get("accepted", false) or not released.get("accepted", false) or cases.is_empty():
		state.clear();state.merge(queue_before,true);work_state.clear();work_state.merge(work_before,true);mutual_state.clear();mutual_state.merge(mutual_before,true);return _denied("external closure rolled back")
	return {"accepted":true,"task_id":task_id,"queue_status":outcome["status"],"credential_id":cases[0]["credential_id"]}


func admit_external_work_dispatch(state: Dictionary, work_runtime: RefCounted, work_state: Dictionary, mutual_runtime: RefCounted, mutual_state: Dictionary, entry_id: String, definition: Dictionary, occurrence_id: String) -> Dictionary:
	var queue_before: Dictionary = state.duplicate(true); var work_before: Dictionary = work_state.duplicate(true); var mutual_before: Dictionary = mutual_state.duplicate(true)
	var work: Dictionary = work_runtime.request_external_work(work_state, definition, "operations_queue", mutual_runtime, mutual_state, occurrence_id)
	if not work.get("accepted", false): return work
	var dispatch: Dictionary = record_external_dispatch(state, mutual_runtime, mutual_state, entry_id, work["task_id"], occurrence_id)
	if not dispatch.get("accepted", false):
		state.clear(); state.merge(queue_before, true); work_state.clear(); work_state.merge(work_before, true); mutual_state.clear(); mutual_state.merge(mutual_before, true)
		return _denied("external work dispatch rolled back: %s" % dispatch.get("reason", "dispatch rejection"))
	return {"accepted":true,"task_id":work["task_id"],"responder_id":dispatch["responder_id"],"reservation":dispatch["reservation"]}


func record_external_dispatch(state: Dictionary, mutual_runtime: RefCounted, mutual_state: Dictionary, entry_id: String, task_id: String, occurrence_id: String) -> Dictionary:
	if not state["entries"].has(entry_id): return _denied("external dispatch queue entry is unknown")
	var entry: Dictionary = state["entries"][entry_id]
	var capacity: Dictionary = mutual_runtime.active_capacity(mutual_state, occurrence_id)
	if not capacity.get("accepted", false): return capacity
	var queue_before: Dictionary = state.duplicate(true)
	var mutual_before: Dictionary = mutual_state.duplicate(true)
	var dispatched: Dictionary = record_dispatch(state, entry_id, task_id, capacity["responder_id"], entry["station"])
	if not dispatched.get("accepted", false): return dispatched
	var reserved: Dictionary = mutual_runtime.reserve_capacity(mutual_state, occurrence_id, entry_id, entry["actor_job"], entry["station"], task_id)
	if not reserved.get("accepted", false):
		state.clear(); state.merge(queue_before, true); mutual_state.clear(); mutual_state.merge(mutual_before, true)
		return _denied("external dispatch rolled back: %s" % reserved.get("reason", "capacity rejection"))
	return {"accepted": true, "entry_id": entry_id, "task_id": task_id, "responder_id": capacity["responder_id"], "reservation": reserved["reservation"]}


func record_dispatch(state: Dictionary, entry_id: String, task_id: String, actor_person_id: String = "", station: String = "") -> Dictionary:
	if not state["entries"].has(entry_id) or state["entries"][entry_id]["status"] != "waiting" or task_id.is_empty():
		return _denied("operations queue dispatch receipt is invalid")
	var entry: Dictionary = state["entries"][entry_id]
	var reserved_station: String = station if not station.is_empty() else entry["station"]
	if state["reservations"]["stations"].has(reserved_station) or (not actor_person_id.is_empty() and state["reservations"]["actors"].has(actor_person_id)):
		return _denied("operations queue resource is already reserved")
	entry["status"] = "dispatched"
	entry["task_id"] = task_id
	entry["actor_person_id"] = actor_person_id
	entry["last_blocker"] = ""
	state["entries"][entry_id] = entry
	state["reservations"]["stations"][reserved_station] = entry_id
	if not actor_person_id.is_empty():
		state["reservations"]["actors"][actor_person_id] = entry_id
	_event(state, "incident_dispatched", entry_id, {"task_id": task_id, "actor_person_id": actor_person_id, "station": reserved_station})
	return {"accepted": true, "entry_id": entry_id, "task_id": task_id}


func record_dispatch_failure(state: Dictionary, entry_id: String, reason: String, retryable: bool) -> Dictionary:
	if not state["entries"].has(entry_id) or state["entries"][entry_id]["status"] != "waiting":
		return _denied("operations queue dispatch failure is stale")
	var entry: Dictionary = state["entries"][entry_id]
	entry["attempts"] = int(entry["attempts"]) + 1
	entry["last_blocker"] = reason
	if not retryable:
		entry["status"] = "terminal_failed"
	else:
		entry["next_attempt_clock"] = int(state["clock"]) + int(entry["retry_backoff_ticks"])
	state["entries"][entry_id] = entry
	_event(state, "dispatch_blocked" if retryable else "dispatch_terminal_failure", entry_id, {"reason": reason, "attempt": entry["attempts"]})
	return {"accepted": true, "retryable": retryable}


func record_task_outcome(state: Dictionary, task_id: String, outcome: String, reason: String) -> Dictionary:
	for entry_id in state["entries"]:
		var entry: Dictionary = state["entries"][entry_id]
		if entry.get("task_id", "") != task_id or entry["status"] != "dispatched":
			continue
		_release_reservations(state, entry_id)
		entry["status"] = "resolved" if outcome == "committed" else "terminal_failed"
		entry["last_blocker"] = reason
		state["entries"][entry_id] = entry
		_event(state, "task_committed" if outcome == "committed" else "task_terminal_failure", entry_id, {"task_id": task_id, "reason": reason})
		return {"accepted": true, "entry_id": entry_id, "status": entry["status"]}
	return _denied("operations queue task outcome has no active dispatch")


func _release_reservations(state: Dictionary, entry_id: String) -> void:
	for actor_id in state["reservations"]["actors"].keys():
		if state["reservations"]["actors"][actor_id] == entry_id:
			state["reservations"]["actors"].erase(actor_id)
	for station in state["reservations"]["stations"].keys():
		if state["reservations"]["stations"][station] == entry_id:
			state["reservations"]["stations"].erase(station)


func _event(state: Dictionary, event: String, entry_id: String, extra: Dictionary = {}) -> void:
	var record := {"sequence": int(state["next_event_number"]), "event": event, "entry_id": entry_id, "clock": int(state["clock"])}
	state["next_event_number"] = int(state["next_event_number"]) + 1
	for key in extra:
		record[key] = extra[key]
	state["history"].append(record)


func _denied(reason: String) -> Dictionary:
	return {"accepted": false, "reason": reason}
