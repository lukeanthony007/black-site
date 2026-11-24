class_name FacilityMutualAidRuntime
extends RefCounted
## Occurrence-bound external responder admission. This owner grants no facility role until every gate commits.
const STATE_SCHEMA := "facility-mutual-aid/v2"
const PHASES := ["requested", "arrived", "screened", "authorized", "credentialed", "escorted", "admitted", "revoked", "demobilizing", "closed"]

func start_state() -> Dictionary:
	return {"schema": STATE_SCHEMA, "clock": 0, "cases": {}, "capacity_reservations": {}, "temporary_locations": {}, "escort_routes": {}, "admissions": {}, "demobilizations": {}, "history": [], "next_case_number": 1, "next_event_number": 1}

func tick(state: Dictionary) -> void: state["clock"] = int(state["clock"]) + 1

func request(state: Dictionary, occurrence_id: String, response_job: String, destination: String, responder_id: String, policy: Dictionary) -> Dictionary:
	if occurrence_id.is_empty() or response_job.is_empty() or destination.is_empty() or responder_id.is_empty(): return _deny("mutual-aid request identity is incomplete")
	for case in state["cases"].values():
		if case["occurrence_id"] == occurrence_id and case["phase"] != "revoked" and case["phase"] != "closed": return _deny("active mutual-aid case already exists")
	var case_id := "mutual-aid-%d" % int(state["next_case_number"]); state["next_case_number"] += 1
	var case := {"case_id": case_id, "occurrence_id": occurrence_id, "response_job": response_job, "destination": destination, "responder_id": responder_id, "phase": "requested", "staging_room": policy["staging_room"], "authority_job": policy["authority_job"], "authority_station": policy["authority_station"], "escort_job": policy["escort_job"], "escort_station": policy["escort_station"], "credential_mode": policy["credential_mode"], "screening_actor": "", "authority_actor": "", "escort_actor": "", "credential_id": ""}
	state["cases"][case_id] = case; _event(state, case_id, "requested", responder_id)
	return {"accepted": true, "case_id": case_id}

func advance(state: Dictionary, case_id: String, action: String, evidence: Dictionary) -> Dictionary:
	if not state["cases"].has(case_id): return _deny("mutual-aid case is unknown")
	var c: Dictionary = state["cases"][case_id]
	var expected: String = {"requested":"record_arrival", "arrived":"record_screening", "screened":"authorize", "authorized":"issue_credential", "credentialed":"assign_escort", "escorted":"record_escorted_arrival"}.get(c["phase"], "")
	if action != expected: return _deny("mutual-aid transition is out of order")
	match action:
		"record_arrival":
			if evidence.get("responder_id", "") != c["responder_id"] or evidence.get("room", "") != c["staging_room"]: return _deny("responder did not arrive at screened staging")
			c["phase"] = "arrived"; state["temporary_locations"][c["responder_id"]] = c["staging_room"]
		"record_screening":
			if not _actor(evidence, c["escort_job"], c["staging_room"]): return _deny("named security screening evidence is invalid")
			c["screening_actor"] = evidence["actor_id"]; c["phase"] = "screened"
		"authorize":
			if not _actor(evidence, c["authority_job"], c["authority_station"]): return _deny("named duty authority is invalid")
			c["authority_actor"] = evidence["actor_id"]; c["phase"] = "authorized"
		"issue_credential":
			if evidence.get("mode", "") != c["credential_mode"] or evidence.get("occurrence_id", "") != c["occurrence_id"] or evidence.get("destination", "") != c["destination"] or String(evidence.get("credential_id", "")).is_empty(): return _deny("temporary credential scope is invalid")
			c["credential_id"] = evidence["credential_id"]; c["phase"] = "credentialed"
		"assign_escort":
			if not _actor(evidence, c["escort_job"], c["escort_station"]): return _deny("named escort assignment is invalid")
			c["escort_actor"] = evidence["actor_id"]; c["phase"] = "escorted"; state["temporary_locations"][c["escort_actor"]] = c["escort_station"]
		"record_escorted_arrival":
			return begin_escorted_travel(state, case_id, evidence.get("responder_route", []), evidence.get("escort_route", []), evidence)
	state["cases"][case_id] = c; _event(state, case_id, action, evidence.get("actor_id", evidence.get("responder_id", "")))
	return {"accepted": true, "phase": c["phase"]}

func begin_escorted_travel(state: Dictionary, case_id: String, responder_route: Array, escort_route: Array, evidence: Dictionary = {}) -> Dictionary:
	if not state["cases"].has(case_id): return _deny("mutual-aid case is unknown")
	var c: Dictionary = state["cases"][case_id]
	if c.get("phase", "") != "escorted" or state.get("admissions", {}).has(case_id): return _deny("escorted travel cannot begin")
	if not evidence.is_empty():
		if evidence.get("responder_id", "") != c["responder_id"] or evidence.get("escort_id", "") != c["escort_actor"]: return _deny("escorted travel identity is invalid")
		if evidence.get("responder_room", "") != c["destination"] or evidence.get("escort_room", "") != c["destination"]: return _deny("escorted destination arrival is invalid")
	if responder_route.size() < 2 or responder_route[0] != c["staging_room"] or responder_route[-1] != c["destination"] or escort_route.size() < 2 or escort_route[0] != c["escort_station"] or escort_route[-1] != c["destination"]: return _deny("escorted destination arrival is invalid")
	var pickup_index := _route_index_of(escort_route, c["staging_room"])
	if pickup_index < 0: return _deny("escort route does not pass through staging for pickup")
	if state["temporary_locations"].get(c["responder_id"], "") != c["staging_room"] or state["temporary_locations"].get(c["escort_actor"], "") != c["escort_station"]: return _deny("escorted travel start locations are invalid")
	state["admissions"][case_id] = {
		"case_id": case_id,
		"responder_route": responder_route.duplicate(),
		"escort_route": escort_route.duplicate(),
		"responder_index": 0,
		"escort_index": 0,
		"picked_up": pickup_index == 0,
		"pickup_room": c["staging_room"],
	}
	_event(state, case_id, "escorted_travel_started", c["escort_actor"])
	return {"accepted": true, "phase": "escorted", "status": "traveling" if pickup_index > 0 else "picked_up", "responder_room": c["staging_room"], "escort_room": c["escort_station"], "picked_up": pickup_index == 0}

func tick_escorted_travel(state: Dictionary, case_id: String) -> Dictionary:
	if not state.get("admissions", {}).has(case_id) or not state["cases"].has(case_id) or state["cases"][case_id].get("phase", "") != "escorted": return _deny("escorted travel is not active")
	var work: Dictionary = state["admissions"][case_id]
	var c: Dictionary = state["cases"][case_id]
	if work.get("suspended", false): return _deny("escorted travel requires explicit restart reconciliation")
	var responder_route: Array = work["responder_route"]
	var escort_route: Array = work["escort_route"]
	var responder_id: String = c["responder_id"]
	var escort_id: String = c["escort_actor"]
	var staging: String = c["staging_room"]
	var destination: String = c["destination"]

	if not bool(work.get("picked_up", false)):
		# Escort pickup: only the escort advances until colocated with the waiting responder at staging,
		# or until the escort reaches a declared staging room on its own path.
		work["escort_index"] = mini(int(work["escort_index"]) + 1, escort_route.size() - 1)
		state["temporary_locations"][escort_id] = escort_route[work["escort_index"]]
		state["temporary_locations"][responder_id] = responder_route[work["responder_index"]]
		var escort_room: String = state["temporary_locations"][escort_id]
		if escort_room == staging or escort_room == state["temporary_locations"][responder_id]:
			work["picked_up"] = true
			_event(state, case_id, "escort_pickup", escort_id)
		state["admissions"][case_id] = work
		if state["temporary_locations"][responder_id] == destination and state["temporary_locations"][escort_id] == destination and bool(work["picked_up"]):
			return _complete_escorted_admission(state, case_id, work, c)
		return {"accepted": true, "status": "pickup" if not bool(work["picked_up"]) else "traveling", "phase": "escorted", "responder_room": state["temporary_locations"][responder_id], "escort_room": state["temporary_locations"][escort_id], "picked_up": bool(work["picked_up"])}

	# Joint travel: both advance one edge per tick after pickup.
	work["responder_index"] = mini(int(work["responder_index"]) + 1, responder_route.size() - 1)
	work["escort_index"] = mini(int(work["escort_index"]) + 1, escort_route.size() - 1)
	state["temporary_locations"][responder_id] = responder_route[work["responder_index"]]
	state["temporary_locations"][escort_id] = escort_route[work["escort_index"]]
	if int(work["responder_index"]) < responder_route.size() - 1 or int(work["escort_index"]) < escort_route.size() - 1:
		state["admissions"][case_id] = work
		return {"accepted": true, "status": "traveling", "phase": "escorted", "responder_room": state["temporary_locations"][responder_id], "escort_room": state["temporary_locations"][escort_id], "picked_up": true}
	return _complete_escorted_admission(state, case_id, work, c)

func resume_escorted_travel(state: Dictionary, case_id: String, responder_id: String, escort_id: String) -> Dictionary:
	if not state.get("admissions", {}).has(case_id) or not state.get("cases", {}).has(case_id): return _deny("escorted travel is unknown")
	var work: Dictionary = state["admissions"][case_id]
	var c: Dictionary = state["cases"][case_id]
	if not work.get("suspended", false) or work.get("suspension_reason", "") != "restart_reconciliation" or c.get("phase", "") != "escorted" or c.get("responder_id", "") != responder_id or c.get("escort_actor", "") != escort_id or state["temporary_locations"].get(responder_id, "") != work["responder_route"][work["responder_index"]] or state["temporary_locations"].get(escort_id, "") != work["escort_route"][work["escort_index"]]: return _deny("escorted travel reconciliation is invalid")
	work["suspended"] = false
	work["suspension_reason"] = ""
	state["admissions"][case_id] = work
	return {"accepted": true, "responder_index": work["responder_index"], "escort_index": work["escort_index"], "picked_up": bool(work.get("picked_up", false))}

func active_capacity(state: Dictionary, occurrence_id: String) -> Dictionary:
	for case in state["cases"].values():
		if case["occurrence_id"] == occurrence_id and case["phase"] == "admitted":
			return {"accepted": true, "case_id": case["case_id"], "occurrence_id":case["occurrence_id"], "responder_id": case["responder_id"], "response_job": case["response_job"], "destination": case["destination"], "credential_id": case["credential_id"], "escort_actor": case["escort_actor"]}
	return _deny("no admitted mutual-aid capacity exists for occurrence")

func reserve_capacity(state: Dictionary, occurrence_id: String, queue_entry_id: String, response_job: String, destination: String, task_id: String) -> Dictionary:
	if queue_entry_id.is_empty() or task_id.is_empty() or state["capacity_reservations"].has(queue_entry_id): return _deny("temporary capacity reservation identity is invalid or occupied")
	var capacity: Dictionary = active_capacity(state, occurrence_id)
	if not capacity.get("accepted", false) or capacity["response_job"] != response_job or capacity["destination"] != destination: return _deny("temporary capacity does not match occurrence job and destination")
	for existing in state["capacity_reservations"].values():
		if existing["case_id"] == capacity["case_id"]: return _deny("mutual-aid responder is already reserved")
	var reservation: Dictionary = {"queue_entry_id": queue_entry_id, "task_id": task_id, "case_id": capacity["case_id"], "occurrence_id": occurrence_id, "responder_id": capacity["responder_id"], "response_job": response_job, "destination": destination, "credential_id": capacity["credential_id"]}
	state["capacity_reservations"][queue_entry_id] = reservation; _event(state, capacity["case_id"], "capacity_reserved", capacity["responder_id"])
	return {"accepted": true, "reservation": reservation}

func release_capacity(state: Dictionary, queue_entry_id: String) -> Dictionary:
	if not state["capacity_reservations"].has(queue_entry_id): return _deny("temporary capacity reservation is unknown")
	var reservation: Dictionary = state["capacity_reservations"][queue_entry_id]; state["capacity_reservations"].erase(queue_entry_id)
	_event(state, reservation["case_id"], "capacity_released", reservation["responder_id"]); return {"accepted": true, "reservation": reservation}

func revoke_closed_occurrences(state: Dictionary, active_occurrences: Array) -> Array[Dictionary]:
	var revoked: Array[Dictionary] = []
	for case_id in state["cases"]:
		var c: Dictionary = state["cases"][case_id]
		if c["phase"] == "admitted" and not active_occurrences.has(c["occurrence_id"]):
			var result: Dictionary = revoke(state, case_id, c["occurrence_id"])
			if result.get("accepted", false): revoked.append({"case_id": case_id, "credential_id": result["credential_id"], "reason": "source_occurrence_closed"})
	return revoked

func revoke(state: Dictionary, case_id: String, occurrence_id: String) -> Dictionary:
	if not state["cases"].has(case_id) or state["cases"][case_id]["phase"] != "admitted" or state["cases"][case_id]["occurrence_id"] != occurrence_id: return _deny("mutual-aid revocation is invalid")
	for entry_id in state["capacity_reservations"].keys():
		if state["capacity_reservations"][entry_id]["case_id"] == case_id: state["capacity_reservations"].erase(entry_id)
	state["cases"][case_id]["phase"] = "revoked"; _event(state, case_id, "revoked", "system")
	return {"accepted": true, "credential_id": state["cases"][case_id]["credential_id"]}

func begin_demobilization(state: Dictionary, case_id: String, responder_route: Array, escort_route: Array) -> Dictionary:
	if not state["cases"].has(case_id) or state["cases"][case_id].get("phase","")!="revoked" or state["demobilizations"].has(case_id): return _deny("mutual-aid demobilization is invalid")
	var c: Dictionary=state["cases"][case_id]
	if responder_route.size()<2 or responder_route[0]!=c["destination"] or responder_route[-1]!=c["staging_room"] or escort_route.size()<2 or escort_route[0]!=c["destination"] or escort_route[-1]!=c["escort_station"]: return _deny("mutual-aid departure routes are invalid")
	state["demobilizations"][case_id]={"case_id":case_id,"responder_route":responder_route.duplicate(),"escort_route":escort_route.duplicate(),"responder_index":0,"escort_index":0}
	state["cases"][case_id]["phase"]="demobilizing"; _event(state,case_id,"demobilization_started",c["escort_actor"])
	return {"accepted":true,"status":"demobilizing"}

func compose_escort_route_via_staging(escort_to_staging: Array, staging_to_destination: Array) -> Array:
	if escort_to_staging.is_empty() or staging_to_destination.is_empty(): return []
	if escort_to_staging[-1] != staging_to_destination[0]: return []
	var route: Array = escort_to_staging.duplicate()
	for index in range(1, staging_to_destination.size()):
		route.append(staging_to_destination[index])
	return route

func complete_escorted_travel(state: Dictionary, case_id: String, max_ticks: int = 64) -> Dictionary:
	var last: Dictionary = {"accepted": true, "phase": state.get("cases", {}).get(case_id, {}).get("phase", ""), "status": "pending"}
	if state.get("cases", {}).get(case_id, {}).get("phase", "") == "admitted":
		return {"accepted": true, "phase": "admitted", "status": "admitted"}
	for _tick in max_ticks:
		if not state.get("admissions", {}).has(case_id):
			if state.get("cases", {}).get(case_id, {}).get("phase", "") == "admitted":
				return {"accepted": true, "phase": "admitted", "status": "admitted"}
			return _deny("escorted travel is not active")
		last = tick_escorted_travel(state, case_id)
		if not last.get("accepted", false):
			return last
		if last.get("phase", "") == "admitted" or last.get("status", "") == "admitted":
			return last
	return _deny("escorted travel did not complete within tick budget")

func prepare_recovered_state(state: Dictionary) -> Dictionary:
	var valid: Dictionary=validate_state(state)
	if not valid.get("accepted",false): return valid
	var recovered: Dictionary=state.duplicate(true)
	for case_id in recovered.get("demobilizations",{}):
		recovered["demobilizations"][case_id]["suspended"]=true
		recovered["demobilizations"][case_id]["suspension_reason"]="restart_reconciliation"
	for case_id in recovered.get("admissions",{}):
		recovered["admissions"][case_id]["suspended"]=true
		recovered["admissions"][case_id]["suspension_reason"]="restart_reconciliation"
	return {"accepted":true,"state":recovered}

func resume_demobilization(state: Dictionary, case_id: String, responder_id: String, escort_id: String) -> Dictionary:
	if not state.get("demobilizations",{}).has(case_id) or not state.get("cases",{}).has(case_id): return _deny("mutual-aid demobilization is unknown")
	var work: Dictionary=state["demobilizations"][case_id]; var c: Dictionary=state["cases"][case_id]
	if not work.get("suspended",false) or work.get("suspension_reason","")!="restart_reconciliation" or c.get("phase","")!="demobilizing" or c.get("responder_id","")!=responder_id or c.get("escort_actor","")!=escort_id or state["temporary_locations"].get(responder_id,"")!=work["responder_route"][work["responder_index"]] or state["temporary_locations"].get(escort_id,"")!=work["escort_route"][work["escort_index"]]: return _deny("mutual-aid demobilization reconciliation is invalid")
	work["suspended"]=false; work["suspension_reason"]=""; state["demobilizations"][case_id]=work
	return {"accepted":true,"responder_index":work["responder_index"],"escort_index":work["escort_index"]}

func tick_demobilization(state: Dictionary, case_id: String) -> Dictionary:
	if not state["demobilizations"].has(case_id) or not state["cases"].has(case_id) or state["cases"][case_id].get("phase","")!="demobilizing": return _deny("mutual-aid demobilization is not active")
	var work: Dictionary=state["demobilizations"][case_id]; var c: Dictionary=state["cases"][case_id]
	if work.get("suspended",false): return _deny("mutual-aid demobilization requires explicit restart reconciliation")
	work["responder_index"]=min(int(work["responder_index"])+1,work["responder_route"].size()-1); work["escort_index"]=min(int(work["escort_index"])+1,work["escort_route"].size()-1)
	state["temporary_locations"][c["responder_id"]]=work["responder_route"][work["responder_index"]]; state["temporary_locations"][c["escort_actor"]]=work["escort_route"][work["escort_index"]]
	if work["responder_index"]<work["responder_route"].size()-1 or work["escort_index"]<work["escort_route"].size()-1: state["demobilizations"][case_id]=work; return {"accepted":true,"status":"traveling","responder_room":state["temporary_locations"][c["responder_id"]],"escort_room":state["temporary_locations"][c["escort_actor"]]}
	state["cases"][case_id]["phase"]="closed"; state["demobilizations"].erase(case_id); state["escort_routes"][case_id]["departure_responder_route"]=work["responder_route"]; state["escort_routes"][case_id]["departure_escort_route"]=work["escort_route"]; _event(state,case_id,"demobilization_closed",c["escort_actor"])
	return {"accepted":true,"status":"closed","responder_room":c["staging_room"],"escort_room":c["escort_station"]}

func validate_route_provenance(state: Dictionary, route_plan: Dictionary) -> Dictionary:
	var allowed: Dictionary = {}
	for route_value in route_plan.get("routes", []):
		var route: Dictionary = route_value
		if route.get("kind", "") == "circulation" and route.get("flow", "") == "personnel" and bool(route.get("ordinary_access", false)) and not bool(route.get("emergency_only", false)):
			allowed["%s>%s" % [route.get("from", ""), route.get("to", "")]] = route.get("id", "")
	for case_id in state.get("escort_routes", {}):
		var proof: Dictionary = state["escort_routes"][case_id]
		for route_key in ["responder_route", "escort_route", "departure_responder_route", "departure_escort_route"]:
			if not proof.has(route_key): continue
			var rooms: Array = proof.get(route_key, [])
			for index in range(rooms.size() - 1):
				if not allowed.has("%s>%s" % [rooms[index], rooms[index + 1]]): return _deny("escort route uses a non-personnel or unknown generated edge")
	for case_id in state.get("admissions", {}):
		var work: Dictionary = state["admissions"][case_id]
		for route_key in ["responder_route", "escort_route"]:
			var rooms: Array = work.get(route_key, [])
			for index in range(rooms.size() - 1):
				if not allowed.has("%s>%s" % [rooms[index], rooms[index + 1]]): return _deny("escort route uses a non-personnel or unknown generated edge")
	return {"accepted": true}

func validate_state(state: Dictionary) -> Dictionary:
	if state.get("schema", "") != STATE_SCHEMA or not state.get("cases", null) is Dictionary or not state.get("capacity_reservations", null) is Dictionary or not state.get("temporary_locations", null) is Dictionary or not state.get("escort_routes", null) is Dictionary or not state.get("admissions", null) is Dictionary or not state.get("demobilizations",null) is Dictionary or not state.get("history", null) is Array or int(state.get("clock", -1)) < 0: return _deny("mutual-aid state shape is invalid")
	var sequence := 0
	for event in state["history"]:
		sequence += 1
		if int(event.get("sequence", 0)) != sequence or not state["cases"].has(event.get("case_id", "")): return _deny("mutual-aid history is invalid")
	for case_id in state["cases"]:
		var c: Dictionary = state["cases"][case_id]
		if c.get("case_id", "") != case_id or c.get("phase", "") not in PHASES: return _deny("mutual-aid case is invalid")
		if c["phase"] in ["credentialed", "escorted", "admitted", "revoked", "demobilizing", "closed"] and String(c.get("credential_id", "")).is_empty(): return _deny("advanced mutual-aid case lacks credential")
		if c["phase"] in ["admitted", "revoked"]:
			if not state["escort_routes"].has(case_id) or state["temporary_locations"].get(c["responder_id"], "") != c["destination"] or state["temporary_locations"].get(c["escort_actor"], "") != c["destination"]: return _deny("admitted mutual-aid case lacks durable escorted location authority")
		if c["phase"] == "escorted" and state["admissions"].has(case_id):
			pass
		elif c["phase"] == "escorted":
			if state["temporary_locations"].get(c["escort_actor"], "") != c["escort_station"]: return _deny("assigned escort lacks station location authority")
		if c["phase"]=="demobilizing" and not state["demobilizations"].has(case_id): return _deny("demobilizing mutual-aid case lacks active route")
		if c["phase"]=="closed" and (state["demobilizations"].has(case_id) or state["temporary_locations"].get(c["responder_id"],"")!=c["staging_room"] or state["temporary_locations"].get(c["escort_actor"],"")!=c["escort_station"]): return _deny("closed mutual-aid case lacks terminal departure evidence")
		if state["admissions"].has(case_id) and c["phase"] != "escorted": return _deny("active escorted admission contradicts case phase")
	for case_id in state["admissions"]:
		var work: Dictionary = state["admissions"][case_id]
		var admitting_case: Dictionary = state.get("cases", {}).get(case_id, {})
		if admitting_case.get("phase", "") != "escorted" or int(work.get("responder_index", -1)) < 0 or int(work.get("responder_index", -1)) >= work.get("responder_route", []).size() or int(work.get("escort_index", -1)) < 0 or int(work.get("escort_index", -1)) >= work.get("escort_route", []).size() or state["temporary_locations"].get(admitting_case.get("responder_id", ""), "") != work.get("responder_route", [])[work.get("responder_index", 0)] or state["temporary_locations"].get(admitting_case.get("escort_actor", ""), "") != work.get("escort_route", [])[work.get("escort_index", 0)] or (work.get("suspended", false) and work.get("suspension_reason", "") != "restart_reconciliation") or (not work.get("suspended", false) and not String(work.get("suspension_reason", "")).is_empty()): return _deny("escorted admission route authority is invalid")
	for case_id in state["demobilizations"]:
		var work: Dictionary=state["demobilizations"][case_id]; var demobilizing_case: Dictionary=state.get("cases",{}).get(case_id,{})
		if demobilizing_case.get("phase","")!="demobilizing" or int(work.get("responder_index",-1))<0 or int(work.get("responder_index",-1))>=work.get("responder_route",[]).size() or int(work.get("escort_index",-1))<0 or int(work.get("escort_index",-1))>=work.get("escort_route",[]).size() or state["temporary_locations"].get(demobilizing_case.get("responder_id",""),"")!=work.get("responder_route",[])[work.get("responder_index",0)] or state["temporary_locations"].get(demobilizing_case.get("escort_actor",""),"")!=work.get("escort_route",[])[work.get("escort_index",0)] or (work.get("suspended",false) and work.get("suspension_reason","")!="restart_reconciliation") or (not work.get("suspended",false) and not String(work.get("suspension_reason","")).is_empty()): return _deny("demobilization route authority is invalid")
	for entry_id in state["capacity_reservations"]:
		var r: Dictionary = state["capacity_reservations"][entry_id]
		if r.get("queue_entry_id", "") != entry_id or not state["cases"].has(r.get("case_id", "")): return _deny("temporary capacity reservation identity is invalid")
		var rc: Dictionary = state["cases"][r["case_id"]]
		if rc["phase"] != "admitted" or r.get("occurrence_id", "") != rc["occurrence_id"] or r.get("responder_id", "") != rc["responder_id"] or r.get("response_job", "") != rc["response_job"] or r.get("destination", "") != rc["destination"] or r.get("credential_id", "") != rc["credential_id"] or String(r.get("task_id", "")).is_empty(): return _deny("temporary capacity reservation contradicts admission authority")
	return {"accepted": true}

func _complete_escorted_admission(state: Dictionary, case_id: String, work: Dictionary, c: Dictionary) -> Dictionary:
	state["temporary_locations"][c["responder_id"]] = c["destination"]
	state["temporary_locations"][c["escort_actor"]] = c["destination"]
	state["escort_routes"][case_id] = {
		"responder_id": c["responder_id"],
		"escort_id": c["escort_actor"],
		"responder_route": work["responder_route"].duplicate(),
		"escort_route": work["escort_route"].duplicate(),
		"destination": c["destination"],
	}
	state["admissions"].erase(case_id)
	c["phase"] = "admitted"
	state["cases"][case_id] = c
	_event(state, case_id, "record_escorted_arrival", c["escort_actor"])
	return {"accepted": true, "status": "admitted", "phase": "admitted", "responder_room": c["destination"], "escort_room": c["destination"], "picked_up": true}

func _route_index_of(route: Array, room_id: String) -> int:
	for index in range(route.size()):
		if route[index] == room_id:
			return index
	return -1

func _actor(e: Dictionary, job: String, room: String) -> bool: return not String(e.get("actor_id", "")).is_empty() and e.get("job", "") == job and e.get("room", "") == room
func _event(state: Dictionary, case_id: String, kind: String, actor: String) -> void:
	state["history"].append({"sequence": state["next_event_number"], "clock": state["clock"], "case_id": case_id, "kind": kind, "actor": actor}); state["next_event_number"] += 1
func _deny(reason: String) -> Dictionary: return {"accepted": false, "reason": reason}
