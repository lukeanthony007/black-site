class_name FacilityControlNetworkRuntime
extends RefCounted

func start_state() -> Dictionary:
	return {"schema":"facility-control-network/v1","posture":"normal","active_incident":{},"functional_test":{},"history":[]}

func declare_compromise(state: Dictionary, occurrence_id: String, detecting_actor: String) -> Dictionary:
	if state["posture"] != "normal" or occurrence_id.is_empty() or detecting_actor.is_empty(): return _deny("control-network compromise declaration is invalid")
	state["posture"]="isolated"; state["active_incident"]={"occurrence_id":occurrence_id,"incident_owner":detecting_actor}; state["functional_test"]={}
	state["history"].append({"kind":"automation_isolated","occurrence_id":occurrence_id,"actor":detecting_actor})
	return {"accepted":true,"posture":"isolated"}

func authorize_control(state: Dictionary, mode: String, actor_id: String, station: String) -> Dictionary:
	if actor_id.is_empty() or station.is_empty(): return _deny("control authority identity is incomplete")
	if state["posture"] == "isolated" and mode != "hardwired_local": return _deny("remote automation is isolated")
	if mode == "hardwired_local" and station != "security_control": return _deny("hardwired control requires exact local station")
	return {"accepted":true,"mode":mode,"actor_id":actor_id,"station":station}

func record_functional_test(state: Dictionary, occurrence_id: String, actor_id: String, passed: bool) -> Dictionary:
	if state["posture"] != "isolated" or state["active_incident"].get("occurrence_id","") != occurrence_id or actor_id.is_empty() or actor_id == state["active_incident"].get("incident_owner","") or not passed: return _deny("control-network functional test is invalid")
	state["functional_test"]={"occurrence_id":occurrence_id,"actor_id":actor_id,"passed":true}
	state["history"].append({"kind":"functional_test_passed","occurrence_id":occurrence_id,"actor":actor_id})
	return {"accepted":true}

func reconstitute(state: Dictionary, occurrence_id: String, actor_id: String, authorized: bool) -> Dictionary:
	var test: Dictionary=state.get("functional_test",{})
	if state["posture"] != "isolated" or state["active_incident"].get("occurrence_id","") != occurrence_id or actor_id.is_empty() or actor_id == state["active_incident"].get("incident_owner","") or actor_id == test.get("actor_id", "") or not authorized or test.get("occurrence_id","") != occurrence_id or not test.get("passed",false): return _deny("control-network reconstitution is invalid")
	state["posture"]="normal"; state["history"].append({"kind":"reconstituted","occurrence_id":occurrence_id,"actor":actor_id,"test_actor":test["actor_id"]}); state["active_incident"]={}
	return {"accepted":true,"posture":"normal"}

func validate_state(state: Dictionary) -> Dictionary:
	if state.get("schema","") != "facility-control-network/v1" or state.get("posture","") not in ["normal","isolated"] or not state.get("active_incident",null) is Dictionary or not state.get("functional_test",null) is Dictionary or not state.get("history",null) is Array: return _deny("control-network state shape is invalid")
	var history: Array=state["history"]
	var test: Dictionary=state["functional_test"]
	if state["posture"] == "isolated":
		var incident: Dictionary=state["active_incident"]
		var current_size: int=1 if test.is_empty() else 2
		var prefix_size: int=history.size()-current_size
		if String(incident.get("occurrence_id","")).is_empty() or String(incident.get("incident_owner","")).is_empty() or prefix_size < 0 or prefix_size % 3 != 0: return _deny("isolated control network lacks incident authority")
		var prefix_result: Dictionary=_validate_completed_cycles(history,prefix_size)
		if not prefix_result.get("accepted",false): return prefix_result
		var opened: Dictionary=history[prefix_size]
		if opened.get("kind","") != "automation_isolated" or opened.get("occurrence_id","") != incident["occurrence_id"] or opened.get("actor","") != incident["incident_owner"]: return _deny("control-network incident contradicts history")
		if not test.is_empty():
			var tested_event: Dictionary=history[prefix_size+1]
			if test.get("occurrence_id","") != incident["occurrence_id"] or String(test.get("actor_id","")).is_empty() or test.get("actor_id","") == incident["incident_owner"] or not test.get("passed",false) or tested_event.get("kind","") != "functional_test_passed" or tested_event.get("occurrence_id","") != test["occurrence_id"] or tested_event.get("actor","") != test["actor_id"]: return _deny("control-network functional test contradicts incident authority")
	elif not state["active_incident"].is_empty(): return _deny("normal control network retains active incident")
	else:
		if history.size() % 3 != 0: return _deny("control-network reconstitution history is incomplete")
		var cycles_result: Dictionary=_validate_completed_cycles(history,history.size())
		if not cycles_result.get("accepted",false): return cycles_result
		if not history.is_empty():
			var last_test: Dictionary=history[history.size()-2]
			if test.get("occurrence_id","") != last_test.get("occurrence_id","") or test.get("actor_id","") != last_test.get("actor","") or not test.get("passed",false): return _deny("control-network terminal test summary contradicts history")
	return {"accepted":true}

func _validate_completed_cycles(history: Array, limit: int) -> Dictionary:
	for offset in range(0,limit,3):
		var opened: Dictionary=history[offset]; var tested: Dictionary=history[offset+1]; var closed: Dictionary=history[offset+2]
		var occurrence: String=opened.get("occurrence_id",""); var test_actor: String=tested.get("actor","")
		if opened.get("kind","") != "automation_isolated" or occurrence.is_empty() or String(opened.get("actor","")).is_empty() or tested.get("kind","") != "functional_test_passed" or tested.get("occurrence_id","") != occurrence or test_actor.is_empty() or test_actor == opened.get("actor","") or closed.get("kind","") != "reconstituted" or closed.get("occurrence_id","") != occurrence or closed.get("test_actor","") != test_actor or String(closed.get("actor","")).is_empty() or closed.get("actor","") in [test_actor,opened.get("actor","")]: return _deny("control-network completed lifecycle history is contradictory")
	return {"accepted":true}

func _deny(reason: String)->Dictionary: return {"accepted":false,"reason":reason}
