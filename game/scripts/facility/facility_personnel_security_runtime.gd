class_name FacilityPersonnelSecurityRuntime
extends RefCounted
## Stateful personnel admission with screening, role policy, and interlock receipts.

var interlock_occupancy: Dictionary = {}
var active_receipts: Dictionary = {}
var next_receipt_id: int = 1


func register_person(person_id: String, clearance_tier: int, roles: Array) -> Dictionary:
	return {
		"person_id": person_id,
		"clearance_tier": clearance_tier,
		"roles": roles.duplicate(),
		"current_room": "perimeter",
		"screened": false,
		"inside": false,
		"active_receipt": "",
		"audit": [],
		"denials": [],
	}


func complete_screening(state: Dictionary, screener_credentials: Dictionary) -> Dictionary:
	if state["current_room"] != "perimeter":
		return _deny(state, "screening", "screening must occur at perimeter")
	if not (screener_credentials.get("roles", []) as Array).has("security_officer"):
		return _deny(state, "screening", "entry screening requires security officer")
	if bool(state["screened"]):
		return {"accepted": true, "already_committed": true}
	state["screened"] = true
	_append_audit(state, {"event": "screening_completed", "screener_role": "security_officer"})
	return {"accepted": true, "already_committed": false}


func begin_transition(
	graph: RefCounted,
	state: Dictionary,
	to_room: String,
	emergency_mode: bool = false
) -> Dictionary:
	var from_room: String = state["current_room"]
	if not String(state["active_receipt"]).is_empty():
		return _deny(state, "transition", "person already occupies an interlock")
	var flow := "egress" if emergency_mode else "personnel"
	if not _has_directed_edge(graph, from_room, to_room, flow):
		return _deny(state, "transition", "no authorized %s edge %s -> %s" % [flow, from_room, to_room])
	if flow == "egress" and to_room != "emergency_exit":
		return _deny(state, "transition", "emergency route does not terminate at exit")
	if from_room == "perimeter" and to_room == "screened_entry" and not bool(state["screened"]):
		return _deny(state, "transition", "entry screening is incomplete")
	if not emergency_mode:
		var policy_failure := _ordinary_access_failure(graph, state, to_room)
		if not policy_failure.is_empty():
			return _deny(state, "transition", policy_failure)
	var boundary := _boundary_key(from_room, to_room)
	if interlock_occupancy.has(boundary):
		return _deny(state, "transition", "interlock is occupied")
	var receipt_id := "personnel-%d" % next_receipt_id
	next_receipt_id += 1
	var receipt := {
		"accepted": true,
		"receipt_id": receipt_id,
		"person_id": state["person_id"],
		"from": from_room,
		"to": to_room,
		"flow": flow,
		"boundary": boundary,
	}
	interlock_occupancy[boundary] = state["person_id"]
	active_receipts[receipt_id] = receipt.duplicate(true)
	state["active_receipt"] = receipt_id
	_append_audit(state, {
		"event": "interlock_reserved",
		"receipt_id": receipt_id,
		"from": from_room,
		"to": to_room,
		"flow": flow,
	})
	return receipt


func complete_transition(state: Dictionary, receipt: Dictionary) -> Dictionary:
	var receipt_id: String = receipt.get("receipt_id", "")
	if receipt_id.is_empty() or not active_receipts.has(receipt_id):
		return _deny(state, "transition", "receipt is unknown or already consumed")
	var authoritative: Dictionary = active_receipts[receipt_id]
	if authoritative["person_id"] != state["person_id"] or authoritative["from"] != state["current_room"]:
		return _deny(state, "transition", "receipt does not match person location")
	if state["active_receipt"] != receipt_id or interlock_occupancy.get(authoritative["boundary"], "") != state["person_id"]:
		return _deny(state, "transition", "interlock reservation is not authoritative")
	state["current_room"] = authoritative["to"]
	state["active_receipt"] = ""
	interlock_occupancy.erase(authoritative["boundary"])
	active_receipts.erase(receipt_id)
	if authoritative["flow"] == "egress":
		state["inside"] = false
		state["screened"] = false
	elif authoritative["from"] == "perimeter":
		state["inside"] = true
	_append_audit(state, {
		"event": "transition_completed",
		"receipt_id": receipt_id,
		"from": authoritative["from"],
		"to": authoritative["to"],
		"flow": authoritative["flow"],
	})
	return {"accepted": true, "room": state["current_room"], "receipt_id": receipt_id}


func _ordinary_access_failure(graph: RefCounted, state: Dictionary, to_room: String) -> String:
	if not graph.rooms.has(to_room):
		return "destination room is unavailable"
	var required_tier: int = graph.rooms[to_room]["security_tier"]
	if int(state["clearance_tier"]) < required_tier:
		return "credential tier is below destination requirement"
	var roles: Array = state["roles"]
	if roles.has("security_officer"):
		return ""
	for access_role in graph.rooms[to_room]["access_roles"]:
		if roles.has(access_role):
			return ""
	return "credential roles are not authorized for destination"


func _has_directed_edge(graph: RefCounted, from_room: String, to_room: String, flow: String) -> bool:
	for edge in graph.circulation_edges:
		if edge["from"] == from_room and edge["to"] == to_room and edge["flow"] == flow:
			return true
	return false


func _boundary_key(from_room: String, to_room: String) -> String:
	var endpoints := [from_room, to_room]
	endpoints.sort()
	return "%s|%s" % endpoints


func _deny(state: Dictionary, operation: String, reason: String) -> Dictionary:
	var event := {
		"event": "denied",
		"operation": operation,
		"reason": reason,
		"room": state["current_room"],
	}
	state["denials"].append(event.duplicate(true))
	_append_audit(state, event)
	return {"accepted": false, "reason": reason}


func _append_audit(state: Dictionary, event: Dictionary) -> void:
	event["sequence"] = state["audit"].size()
	event["person_id"] = state["person_id"]
	state["audit"].append(event)
