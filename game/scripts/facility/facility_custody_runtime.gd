class_name FacilityCustodyRuntime
extends RefCounted
## Stateful admission for one material identity across the authoritative custody graph.
## Rejected moves never mutate custody history.


func receive_material(material_id: String) -> Dictionary:
	return {
		"material_id": material_id,
		"custody_identity": "custody:%s" % material_id,
		"current_room": "loading",
		"screened": false,
		"accessioned": false,
		"quarantine_cleared": false,
		"processed": false,
		"stored": false,
		"active_incident": "",
		"open_investigations": [],
		"history": [{
			"sequence": 0,
			"event": "received",
			"room": "loading",
			"custody_identity": "custody:%s" % material_id,
		}],
	}


func record_unauthorized_removal(
	state: Dictionary,
	artifact_id: String,
	room: String,
	actor_person_id: String,
	run_id: String = ""
) -> Dictionary:
	if artifact_id.is_empty() or room.is_empty():
		return _denied("artifact_id and room are required")
	_append_event(state, {
		"event": "unauthorized_removal",
		"artifact_id": artifact_id,
		"room": room,
		"actor_person_id": actor_person_id,
		"run_id": run_id,
	})
	var history_seq: int = (state["history"] as Array).size() - 1
	var investigation_id := "theft-%d" % history_seq
	if not state.has("open_investigations") or not (state["open_investigations"] is Array):
		state["open_investigations"] = []
	(state["open_investigations"] as Array).append({
		"investigation_id": investigation_id,
		"kind": "unauthorized_removal",
		"artifact_id": artifact_id,
		"room": room,
		"actor_person_id": actor_person_id,
		"run_id": run_id,
		"open": true,
	})
	return {"accepted": true, "investigation_id": investigation_id}


func transfer(graph: RefCounted, state: Dictionary, to_room: String, credentials: Dictionary) -> Dictionary:
	var from_room: String = state["current_room"]
	if not String(state["active_incident"]).is_empty():
		return _denied("active custody incident prevents transfer")
	if not _has_directed_material_edge(graph, from_room, to_room):
		return _denied("no authoritative material edge %s -> %s" % [from_room, to_room])
	if not graph.rooms.has(to_room):
		return _denied("destination room is unavailable")
	var authorized_role := _authorized_destination_role(graph, to_room, credentials)
	if authorized_role.is_empty():
		return _denied("credentials do not own destination %s" % to_room)
	var guard_failure := _transition_guard(state, to_room)
	if not guard_failure.is_empty():
		return _denied(guard_failure)

	state["current_room"] = to_room
	match to_room:
		"material_screening":
			state["screened"] = true
		"archive_accession":
			state["accessioned"] = true
		"archive_processing":
			state["processed"] = true
		"archive_stack":
			state["stored"] = true
	_append_event(state, {
		"event": "transfer",
		"from": from_room,
		"to": to_room,
		"actor_role": authorized_role,
	})
	return {"accepted": true, "room": to_room, "actor_role": authorized_role}


func clear_quarantine(state: Dictionary, credentials: Dictionary) -> Dictionary:
	if state["current_room"] != "quarantine":
		return _denied("material is not in quarantine")
	if not String(state["active_incident"]).is_empty():
		return _denied("active custody incident prevents disposition")
	if not _has_role(credentials, "accession_technician"):
		return _denied("quarantine disposition requires accession technician")
	if bool(state["quarantine_cleared"]):
		return {"accepted": true, "already_committed": true}
	state["quarantine_cleared"] = true
	_append_event(state, {"event": "quarantine_cleared", "actor_role": "accession_technician"})
	return {"accepted": true, "already_committed": false}


func declare_incident(graph: RefCounted, state: Dictionary, procedure_id: String) -> Dictionary:
	if not String(state["active_incident"]).is_empty():
		return _denied("custody incident already active")
	if not graph.failure_procedures.has(procedure_id):
		return _denied("unknown failure procedure")
	var procedure: Dictionary = graph.failure_procedures[procedure_id]
	if not (procedure["capabilities"] as Array).has("custody"):
		return _denied("procedure does not govern custody")
	state["active_incident"] = procedure_id
	_append_event(state, {
		"event": "incident_declared",
		"procedure": procedure_id,
		"owner_job": procedure["owner_job"],
		"station": procedure["station"],
	})
	return {"accepted": true, "procedure": procedure_id}


func resolve_incident(graph: RefCounted, state: Dictionary, credentials: Dictionary) -> Dictionary:
	var procedure_id: String = state["active_incident"]
	if procedure_id.is_empty() or not graph.failure_procedures.has(procedure_id):
		return _denied("no active authoritative incident")
	var procedure: Dictionary = graph.failure_procedures[procedure_id]
	var owner_job: String = procedure["owner_job"]
	if not _has_role(credentials, owner_job):
		return _denied("incident resolution requires procedure owner %s" % owner_job)
	state["active_incident"] = ""
	_append_event(state, {
		"event": "incident_resolved",
		"procedure": procedure_id,
		"actor_role": owner_job,
	})
	return {"accepted": true, "procedure": procedure_id}


func can_archive(state: Dictionary) -> bool:
	return (
		state["current_room"] == "archive_stack"
		and bool(state["screened"])
		and bool(state["accessioned"])
		and bool(state["quarantine_cleared"])
		and bool(state["processed"])
		and bool(state["stored"])
		and String(state["active_incident"]).is_empty()
	)


func _transition_guard(state: Dictionary, to_room: String) -> String:
	match to_room:
		"archive_accession":
			if not bool(state["screened"]):
				return "material has not passed screening"
		"quarantine":
			if not bool(state["accessioned"]):
				return "material has no accession identity"
		"archive_processing":
			if not bool(state["quarantine_cleared"]):
				return "quarantine disposition is not clear"
		"archive_stack":
			if not bool(state["processed"]):
				return "records processing is incomplete"
	return ""


func _has_directed_material_edge(graph: RefCounted, from_room: String, to_room: String) -> bool:
	for edge in graph.circulation_edges:
		if edge["from"] == from_room and edge["to"] == to_room and edge["flow"] == "material":
			return true
	return false


func _authorized_destination_role(graph: RefCounted, room_id: String, credentials: Dictionary) -> String:
	var credential_roles: Array = credentials.get("roles", [])
	for owner_role in graph.rooms[room_id]["owners"]:
		if credential_roles.has(owner_role):
			return owner_role
	return ""


func _has_role(credentials: Dictionary, role: String) -> bool:
	return (credentials.get("roles", []) as Array).has(role)


func _append_event(state: Dictionary, event: Dictionary) -> void:
	event["sequence"] = state["history"].size()
	event["custody_identity"] = state["custody_identity"]
	state["history"].append(event)


func _denied(reason: String) -> Dictionary:
	return {"accepted": false, "reason": reason}
