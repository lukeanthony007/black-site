class_name FacilityStaffAgentRuntime
extends RefCounted
## Authoritative room-level location and policy-valid dispatch for named active-watch staff.


func build_active_watch(graph: RefCounted, staffing_state: Dictionary, staffing_runtime: RefCounted) -> Dictionary:
	var agents: Dictionary = {}
	var job_ids: Array = graph.jobs.keys()
	job_ids.sort()
	for job_id in job_ids:
		var staff_ids: Array[String] = staffing_runtime.active_staff_ids(staffing_state, job_id)
		staff_ids.sort()
		for staff_id in staff_ids:
			agents[staff_id] = {
				"staff_id": staff_id,
				"job_id": job_id,
				"current_room": graph.jobs[job_id]["station"],
				"destination": graph.jobs[job_id]["station"],
				"route": [],
				"status": "at_post",
			}
	return {
		"agents": agents,
		"movement_log": [],
		"next_event_number": 1,
		"room_entry_blocks": {},
	}


func is_at_room(state: Dictionary, staff_id: String, room_id: String) -> bool:
	return state["agents"].has(staff_id) and state["agents"][staff_id]["current_room"] == room_id and (state["agents"][staff_id]["route"] as Array).is_empty()


func is_mutual_aid_bound(state: Dictionary, staff_id: String) -> bool:
	return state["agents"].has(staff_id) and bool(state["agents"][staff_id].get("mutual_aid_bound", false))


func set_embodied(state: Dictionary, staff_id: String, embodied: bool) -> Dictionary:
	if not state["agents"].has(staff_id):
		return _denied("named staff agent is not on active watch")
	var agent: Dictionary = state["agents"][staff_id]
	if embodied:
		agent["embodied"] = true
	else:
		agent.erase("embodied")
	state["agents"][staff_id] = agent
	return {"accepted": true, "staff_id": staff_id, "embodied": embodied}


func next_route_room(state: Dictionary, staff_id: String) -> String:
	if not state["agents"].has(staff_id):
		return ""
	var route: Array = state["agents"][staff_id]["route"]
	if route.is_empty():
		return ""
	return route.front()


func commit_physical_arrival(state: Dictionary, staff_id: String, room_id: String) -> Dictionary:
	if not state["agents"].has(staff_id):
		return _denied("named staff agent is not on active watch")
	var agent: Dictionary = state["agents"][staff_id]
	if not bool(agent.get("embodied", false)):
		return _denied("staff agent is not embodied")
	var route: Array = agent["route"]
	if route.is_empty() or route.front() != room_id:
		return _denied("physical arrival does not match the next route room")
	var committed := _commit_route_edge(state, staff_id)
	return {
		"accepted": true,
		"staff_id": staff_id,
		"room": room_id,
		"arrived": committed["arrived"],
	}


func sync_mutual_aid_bindings(state: Dictionary, mutual_aid_state: Dictionary) -> Dictionary:
	var temporary_locations: Dictionary = mutual_aid_state.get("temporary_locations", {})
	var bound: Array[String] = []
	var released: Array[String] = []
	var person_ids: Array = temporary_locations.keys()
	person_ids.sort()
	for person_id in person_ids:
		if not state["agents"].has(person_id):
			continue
		var room_id: String = String(temporary_locations[person_id])
		var agent: Dictionary = state["agents"][person_id]
		agent["current_room"] = room_id
		agent["destination"] = room_id
		agent["route"] = []
		agent["status"] = "mutual_aid_bound"
		agent["mutual_aid_bound"] = true
		agent["mutual_aid_case_id"] = _find_mutual_aid_case_id(mutual_aid_state, person_id)
		state["agents"][person_id] = agent
		bound.append(person_id)
	var staff_ids: Array = state["agents"].keys()
	staff_ids.sort()
	for staff_id in staff_ids:
		var agent: Dictionary = state["agents"][staff_id]
		if not bool(agent.get("mutual_aid_bound", false)):
			continue
		if temporary_locations.has(staff_id):
			continue
		agent.erase("mutual_aid_bound")
		agent.erase("mutual_aid_case_id")
		agent["route"] = []
		agent["destination"] = agent["current_room"]
		agent["status"] = "arrived"
		state["agents"][staff_id] = agent
		released.append(staff_id)
	return {"accepted": true, "bound": bound, "released": released}


func _find_mutual_aid_case_id(mutual_aid_state: Dictionary, person_id: String) -> String:
	var cases: Dictionary = mutual_aid_state.get("cases", {})
	var case_ids: Array = cases.keys()
	case_ids.sort()
	for case_id in case_ids:
		var c: Dictionary = cases[case_id]
		if String(c.get("phase", "")) == "closed":
			continue
		if String(c.get("responder_id", "")) == person_id or String(c.get("escort_actor", "")) == person_id:
			return String(case_id)
	return ""


func set_room_entry_block(state: Dictionary, room_id: String, reason: String) -> void:
	if reason.is_empty(): state.get("room_entry_blocks", {}).erase(room_id)
	else: state.get("room_entry_blocks", {})[room_id] = reason


func dispatch(graph: RefCounted, state: Dictionary, staff_id: String, destination: String) -> Dictionary:
	if not state["agents"].has(staff_id):
		return _denied("named staff agent is not on active watch")
	if is_mutual_aid_bound(state, staff_id):
		return _denied("staff agent is bound to mutual-aid duty")
	if not graph.rooms.has(destination):
		return _denied("dispatch destination does not exist")
	if state.get("room_entry_blocks", {}).has(destination):
		return _denied("dispatch destination is under room-entry block: " + String(state["room_entry_blocks"][destination]))
	var agent: Dictionary = state["agents"][staff_id]
	if not (agent["route"] as Array).is_empty():
		return _denied("staff agent already has an active dispatch")
	var job_id: String = agent["job_id"]
	if not (graph.rooms[destination].get("access_roles", []) as Array).has(job_id):
		return _denied("staff role is not authorized for dispatch destination")
	if agent["current_room"] == destination:
		return {"accepted": true, "already_committed": true, "staff_id": staff_id, "route": []}
	var route := _personnel_route(graph, agent["current_room"], destination, job_id, state.get("room_entry_blocks", {}))
	if route.is_empty():
		return _denied("no policy-valid personnel route to dispatch destination")
	agent["destination"] = destination
	agent["route"] = route.duplicate()
	agent["status"] = "traveling"
	state["agents"][staff_id] = agent
	_append_event(state, {
		"event": "dispatch_started",
		"staff_id": staff_id,
		"job_id": job_id,
		"from_room": agent["current_room"],
		"destination": destination,
		"route": route.duplicate(),
	})
	return {"accepted": true, "already_committed": false, "staff_id": staff_id, "route": route.duplicate()}


func dispatch_egress(graph: RefCounted, state: Dictionary, staff_id: String, destination: String) -> Dictionary:
	if not state["agents"].has(staff_id) or not graph.rooms.has(destination) or graph.rooms[destination].get("zone", "") != "egress": return _denied("emergency egress dispatch is invalid")
	if is_mutual_aid_bound(state, staff_id): return _denied("staff agent is bound to mutual-aid duty")
	var agent: Dictionary = state["agents"][staff_id]
	if not (agent["route"] as Array).is_empty(): return _denied("staff agent already has an active dispatch")
	var route := _egress_route(graph, agent["current_room"], destination, agent["job_id"])
	if route.is_empty(): return _denied("no policy-valid emergency egress route")
	agent["destination"] = destination; agent["route"] = route.duplicate(); agent["status"] = "evacuating"; state["agents"][staff_id] = agent
	_append_event(state, {"event":"egress_started","staff_id":staff_id,"job_id":agent["job_id"],"from_room":agent["current_room"],"destination":destination,"route":route.duplicate()})
	return {"accepted": true, "staff_id": staff_id, "route": route.duplicate()}


func cancel_dispatch(state: Dictionary, staff_id: String, reason: String) -> Dictionary:
	if not state["agents"].has(staff_id):
		return _denied("named staff agent is not on active watch")
	var agent: Dictionary = state["agents"][staff_id]
	var cancelled_route: Array = (agent["route"] as Array).duplicate()
	agent["route"] = []
	agent["destination"] = agent["current_room"]
	agent["status"] = "arrived"
	state["agents"][staff_id] = agent
	_append_event(state, {
		"event": "dispatch_cancelled",
		"staff_id": staff_id,
		"job_id": agent["job_id"],
		"current_room": agent["current_room"],
		"cancelled_route": cancelled_route,
		"reason": reason,
	})
	return {"accepted": true, "staff_id": staff_id, "current_room": agent["current_room"], "reason": reason}


func tick(state: Dictionary) -> Dictionary:
	var moved: Array[String] = []
	var arrivals: Array[String] = []
	var staff_ids: Array = state["agents"].keys()
	staff_ids.sort()
	for staff_id in staff_ids:
		var agent: Dictionary = state["agents"][staff_id]
		if bool(agent.get("embodied", false)) or (agent["route"] as Array).is_empty():
			continue
		var committed := _commit_route_edge(state, staff_id)
		moved.append(staff_id)
		if committed["arrived"]:
			arrivals.append(staff_id)
	return {"moved": moved, "arrivals": arrivals}


func _commit_route_edge(state: Dictionary, staff_id: String) -> Dictionary:
	var agent: Dictionary = state["agents"][staff_id]
	var route: Array = agent["route"]
	var from_room: String = agent["current_room"]
	var to_room: String = route.pop_front()
	agent["current_room"] = to_room
	agent["route"] = route
	var arrived := route.is_empty()
	if arrived:
		agent["status"] = "arrived"
	state["agents"][staff_id] = agent
	_append_event(state, {
		"event": "agent_moved",
		"staff_id": staff_id,
		"from_room": from_room,
		"to_room": to_room,
	})
	if arrived:
		_append_event(state, {
			"event": "dispatch_arrived",
			"staff_id": staff_id,
			"room": to_room,
		})
	return {"arrived": arrived}


func begin_work(state: Dictionary, staff_id: String, station: String, action: String) -> Dictionary:
	if not is_at_room(state, staff_id, station):
		return _denied("staff agent has not arrived at work station")
	var agent: Dictionary = state["agents"][staff_id]
	if agent["status"] == "working":
		return _denied("staff agent is already working")
	agent["status"] = "working"
	agent["work_action"] = action
	state["agents"][staff_id] = agent
	_append_event(state, {"event": "work_started", "staff_id": staff_id, "room": station, "action": action})
	return {"accepted": true, "staff_id": staff_id, "action": action}


func end_work(state: Dictionary, staff_id: String, outcome: String) -> Dictionary:
	if not state["agents"].has(staff_id):
		return _denied("staff agent is not active")
	var agent: Dictionary = state["agents"][staff_id]
	if agent["status"] != "working":
		return _denied("staff agent has no active work")
	var action: String = agent.get("work_action", "")
	agent["status"] = "arrived"
	agent.erase("work_action")
	state["agents"][staff_id] = agent
	_append_event(state, {"event": "work_ended", "staff_id": staff_id, "action": action, "outcome": outcome})
	return {"accepted": true, "staff_id": staff_id, "action": action, "outcome": outcome}


func _egress_route(graph: RefCounted, from_room: String, destination: String, job_id: String) -> Array[String]:
	var pending: Array[String] = [from_room]; var previous: Dictionary = {from_room: ""}
	while not pending.is_empty():
		var current: String = pending.pop_front()
		for edge in graph.circulation_edges:
			if edge["flow"] != "egress" or edge["from"] != current: continue
			var next_room: String = edge["to"]
			if previous.has(next_room) or not graph.rooms.has(next_room) or not (graph.rooms[next_room].get("access_roles", []) as Array).has(job_id): continue
			previous[next_room] = current
			if next_room == destination: return _reconstruct_route(previous, from_room, destination)
			pending.append(next_room)
	return []


func _personnel_route(graph: RefCounted, from_room: String, destination: String, job_id: String, blocked_rooms: Dictionary = {}) -> Array[String]:
	var pending: Array[String] = [from_room]
	var previous: Dictionary = {from_room: ""}
	while not pending.is_empty():
		var current: String = pending.pop_front()
		for edge in graph.circulation_edges:
			if edge["flow"] != "personnel" or edge["from"] != current:
				continue
			var next_room: String = edge["to"]
			if previous.has(next_room) or blocked_rooms.has(next_room) or not graph.rooms.has(next_room):
				continue
			if not (graph.rooms[next_room].get("access_roles", []) as Array).has(job_id):
				continue
			previous[next_room] = current
			if next_room == destination:
				return _reconstruct_route(previous, from_room, destination)
			pending.append(next_room)
	return []


func _reconstruct_route(previous: Dictionary, from_room: String, destination: String) -> Array[String]:
	var reverse_route: Array[String] = []
	var current := destination
	while current != from_room:
		reverse_route.append(current)
		current = previous[current]
	reverse_route.reverse()
	return reverse_route


func _append_event(state: Dictionary, event: Dictionary) -> void:
	event["event_number"] = state["next_event_number"]
	state["next_event_number"] = int(state["next_event_number"]) + 1
	state["movement_log"].append(event)


func _denied(reason: String) -> Dictionary:
	return {"accepted": false, "reason": reason}
