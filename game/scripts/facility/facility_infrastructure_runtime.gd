class_name FacilityInfrastructureRuntime
extends RefCounted
## Authoritative utility-service failure and recovery lifecycle.
## Repair evidence and independent verification precede restoration; mission state consumes a snapshot.


func start_services(graph: RefCounted) -> Dictionary:
	var services: Dictionary = {}
	var service_states: Dictionary = {}
	for edge in graph.dependency_edges:
		services[edge["kind"]] = true
		service_states[edge["kind"]] = {"phase": "normal"}
	for service_id in graph.service_continuity_profiles:
		services[service_id] = true
		service_states[service_id] = {"phase": "normal"}
	return {
		"services": services,
		"service_states": service_states,
		"active_failures": {},
		"active_receipts": {},
		"history": [],
		"next_failure_number": 1,
		"next_receipt_number": 1,
	}


func declare_service_failure(graph: RefCounted, state: Dictionary, service_id: String) -> Dictionary:
	if not state["services"].has(service_id):
		return _denied("service is not authoritative")
	if not bool(state["services"][service_id]):
		var existing: Dictionary = state["active_failures"].get(service_id, {})
		return {
			"accepted": true,
			"already_committed": true,
			"failure_id": existing.get("failure_id", ""),
			"procedure": existing.get("procedure", ""),
		}
	var procedure_id := _procedure_for_capability(graph, service_id)
	if procedure_id.is_empty():
		return _denied("service has no governing failure procedure")
	if not graph.service_continuity_profiles.has(service_id):
		return _denied("service has no staged continuity profile")
	var profile: Dictionary = graph.service_continuity_profiles[service_id]
	var failure_id := "service-failure-%d" % int(state["next_failure_number"])
	state["next_failure_number"] = int(state["next_failure_number"]) + 1
	var failure := {
		"failure_id": failure_id,
		"service": service_id,
		"procedure": procedure_id,
		"owner_job": graph.failure_procedures[procedure_id]["owner_job"],
		"station": graph.failure_procedures[procedure_id]["station"],
		"phase": profile["failure_phase"],
		"preservation_phase": profile["failure_phase"],
		"preserved_rooms": (profile["preserved_rooms"] as Array).duplicate(),
	}
	state["services"][service_id] = false
	state["service_states"][service_id] = {"phase": failure["phase"]}
	state["active_failures"][service_id] = failure
	_append_history(state, {
		"event": "service_failed",
		"failure_id": failure_id,
		"service": service_id,
		"procedure": procedure_id,
	})
	return {
		"accepted": true,
		"already_committed": false,
		"failure_id": failure_id,
		"service": service_id,
		"procedure": procedure_id,
	}


func service_phase(state: Dictionary, service_id: String) -> String:
	return state["service_states"].get(service_id, {}).get("phase", "unknown")


func room_has_service(state: Dictionary, room_id: String, service_id: String) -> bool:
	if bool(state["services"].get(service_id, false)):
		return true
	if not state["active_failures"].has(service_id):
		return false
	var failure: Dictionary = state["active_failures"][service_id]
	return service_phase(state, service_id) == failure["preservation_phase"] and (failure["preserved_rooms"] as Array).has(room_id)


func advance_failure_response(
	graph: RefCounted,
	state: Dictionary,
	failure_id: String,
	action: String,
	actor_state: Dictionary,
	staffing_state: Dictionary,
	staffing_runtime: RefCounted,
	temporary_authority: Dictionary = {}
) -> Dictionary:
	var service_id := _service_for_failure(state, failure_id)
	if service_id.is_empty() or not graph.service_continuity_profiles.has(service_id):
		return _denied("failure has no active continuity response")
	var current_phase := service_phase(state, service_id)
	var transition: Dictionary = {}
	for candidate in graph.service_continuity_profiles[service_id]["transitions"]:
		if candidate["from"] == current_phase and candidate["action"] == action:
			transition = candidate
			break
	if transition.is_empty():
		return _denied("response action is not valid from current service phase")
	var controls: Array[Dictionary] = [{
		"actor_job": transition["actor_job"],
		"station": transition["station"],
		"mode": "primary_control",
		"equipment": "",
	}]
	for alternate in transition.get("alternate_controls", []):
		controls.append(alternate)
	var selected_control: Dictionary = {}
	for control in controls:
		if (actor_state.get("roles", []) as Array).has(control["actor_job"]) and actor_state.get("current_room", "") == control["station"]:
			selected_control = control
			break
	if selected_control.is_empty():
		return _denied("response actor is not authorized at a declared control")
	var actor_job: String = selected_control["actor_job"]
	var temporary_authorized: bool = temporary_authority.get("mode", "") == "incident_scoped_temporary" and temporary_authority.get("failure_id", "") == failure_id and temporary_authority.get("action", "") == action and temporary_authority.get("person_id", "") == actor_state.get("person_id", "") and temporary_authority.get("actor_job", "") == actor_job and temporary_authority.get("station", "") == selected_control["station"] and not temporary_authority.get("credential_id", "").is_empty()
	if not temporary_authorized and not staffing_runtime.is_staff_on_duty(staffing_state, actor_state.get("person_id", ""), actor_job):
		return _denied("response actor is neither named on-duty staff nor exact temporary authority")
	state["active_failures"][service_id]["phase"] = transition["to"]
	state["service_states"][service_id] = {"phase": transition["to"]}
	_append_history(state, {
		"event": "failure_response_advanced",
		"failure_id": failure_id,
		"service": service_id,
		"from_phase": current_phase,
		"action": action,
		"to_phase": transition["to"],
		"actor_person_id": actor_state["person_id"],
		"actor_job": actor_job,
		"station": selected_control["station"],
		"control_mode": selected_control["mode"],
		"equipment": selected_control.get("equipment", ""),
	})
	return {"accepted": true, "service": service_id, "phase": transition["to"], "action": action, "actor_job": actor_job, "station": selected_control["station"], "control_mode": selected_control["mode"], "equipment": selected_control.get("equipment", "")}


func begin_recovery(
	graph: RefCounted,
	state: Dictionary,
	procedure_id: String,
	failure_id: String,
	actor_state: Dictionary,
	staffing_state: Dictionary,
	staffing_runtime: RefCounted
) -> Dictionary:
	if not graph.failure_procedures.has(procedure_id):
		return _denied("recovery procedure is unknown")
	var procedure: Dictionary = graph.failure_procedures[procedure_id]
	var service_id := _service_for_failure(state, failure_id)
	if service_id.is_empty():
		return _denied("service failure occurrence is not active")
	var failure: Dictionary = state["active_failures"][service_id]
	if failure["procedure"] != procedure_id:
		return _denied("procedure does not govern active failure")
	if service_phase(state, service_id) != "repair_pending":
		return _denied("service response has not reached repair isolation")
	var owner_job: String = procedure["owner_job"]
	if not (actor_state.get("roles", []) as Array).has(owner_job):
		return _denied("recovery requires procedure owner %s" % owner_job)
	if actor_state.get("current_room", "") != procedure["station"]:
		return _denied("procedure owner is not present at recovery station")
	if not staffing_runtime.is_job_covered(staffing_state, owner_job):
		return _denied("procedure owner job is uncovered")
	if not staffing_runtime.is_staff_on_duty(staffing_state, actor_state.get("person_id", ""), owner_job):
		return _denied("recovery actor is not the named on-duty procedure owner")
	for active in state["active_receipts"].values():
		if active["service"] == service_id:
			return _denied("service recovery is already reserved")
	var receipt_id := "recovery-%d" % int(state["next_receipt_number"])
	state["next_receipt_number"] = int(state["next_receipt_number"]) + 1
	var receipt := {
		"accepted": true,
		"receipt_id": receipt_id,
		"failure_id": failure_id,
		"service": service_id,
		"procedure": procedure_id,
		"owner_job": owner_job,
		"station": procedure["station"],
		"actor_person_id": actor_state.get("person_id", ""),
		"remediation": {},
	}
	state["active_receipts"][receipt_id] = receipt.duplicate(true)
	_append_history(state, {
		"event": "recovery_reserved",
		"receipt_id": receipt_id,
		"failure_id": failure_id,
		"service": service_id,
		"procedure": procedure_id,
		"actor_person_id": receipt["actor_person_id"],
	})
	return receipt


func record_remediation(
	state: Dictionary,
	receipt: Dictionary,
	actor_state: Dictionary,
	evidence: Dictionary
) -> Dictionary:
	var authoritative := _active_receipt(state, receipt)
	if authoritative.is_empty():
		return _denied("recovery receipt is unknown or consumed")
	if actor_state.get("person_id", "") != authoritative["actor_person_id"]:
		return _denied("remediation actor does not own recovery receipt")
	if actor_state.get("current_room", "") != authoritative["station"]:
		return _denied("remediation actor left procedure station")
	if evidence.get("action", "") != "repair_completed":
		return _denied("recovery lacks completed repair evidence")
	if evidence.get("service", "") != authoritative["service"] or evidence.get("station", "") != authoritative["station"]:
		return _denied("repair evidence does not match service and station")
	if not (authoritative["remediation"] as Dictionary).is_empty():
		return {"accepted": true, "already_committed": true, "receipt_id": authoritative["receipt_id"]}
	authoritative["remediation"] = {
		"action": evidence["action"],
		"service": evidence["service"],
		"station": evidence["station"],
		"actor_person_id": actor_state["person_id"],
	}
	state["active_receipts"][authoritative["receipt_id"]] = authoritative
	state["active_failures"][authoritative["service"]]["phase"] = "testing"
	state["service_states"][authoritative["service"]] = {"phase": "testing"}
	_append_history(state, {
		"event": "remediation_recorded",
		"receipt_id": authoritative["receipt_id"],
		"service": authoritative["service"],
		"actor_person_id": actor_state["person_id"],
	})
	return {"accepted": true, "already_committed": false, "receipt_id": authoritative["receipt_id"]}


func record_service_test(
	state: Dictionary,
	receipt: Dictionary,
	actor_state: Dictionary,
	evidence: Dictionary
) -> Dictionary:
	var authoritative := _active_receipt(state, receipt)
	if authoritative.is_empty():
		return _denied("recovery receipt is unknown or consumed")
	if service_phase(state, authoritative["service"]) != "testing":
		return _denied("service is not ready for functional testing")
	if actor_state.get("person_id", "") != authoritative["actor_person_id"] or actor_state.get("current_room", "") != authoritative["station"]:
		return _denied("functional test requires receipt owner at procedure station")
	if evidence.get("action", "") != "functional_test_passed" or evidence.get("service", "") != authoritative["service"] or evidence.get("station", "") != authoritative["station"]:
		return _denied("functional test evidence does not match recovery")
	authoritative["test_evidence"] = evidence.duplicate(true)
	state["active_receipts"][authoritative["receipt_id"]] = authoritative
	state["active_failures"][authoritative["service"]]["phase"] = "reconstitution_pending"
	state["service_states"][authoritative["service"]] = {"phase": "reconstitution_pending"}
	_append_history(state, {
		"event": "functional_test_passed",
		"receipt_id": authoritative["receipt_id"],
		"service": authoritative["service"],
		"actor_person_id": actor_state["person_id"],
	})
	return {"accepted": true, "receipt_id": authoritative["receipt_id"], "phase": "reconstitution_pending"}


func verify_and_restore(
	graph: RefCounted,
	state: Dictionary,
	receipt: Dictionary,
	verifier_state: Dictionary,
	staffing_state: Dictionary,
	staffing_runtime: RefCounted
) -> Dictionary:
	var authoritative := _active_receipt(state, receipt)
	if authoritative.is_empty():
		return _denied("recovery receipt is unknown or consumed")
	if (authoritative["remediation"] as Dictionary).is_empty():
		return _denied("service has no remediation evidence")
	if service_phase(state, authoritative["service"]) != "reconstitution_pending" or not authoritative.has("test_evidence"):
		return _denied("service has no passed functional test")
	if verifier_state.get("person_id", "") == authoritative["actor_person_id"]:
		return _denied("repair actor cannot independently verify restoration")
	var service_id: String = authoritative["service"]
	var verification_controls: Array[Dictionary] = [{
		"actor_job": "duty_officer",
		"station": graph.jobs["duty_officer"]["station"],
		"mode": "primary_reconstitution_authority",
		"equipment": "mission_command_console",
		"required_evidence": "passed_functional_test",
		"separation": "not_repair_actor",
	}]
	for control in graph.service_continuity_profiles[service_id].get("verification_controls", []):
		verification_controls.append(control)
	var selected_control: Dictionary = {}
	for control in verification_controls:
		if (verifier_state.get("roles", []) as Array).has(control["actor_job"]) and verifier_state.get("current_room", "") == control["station"]:
			selected_control = control
			break
	if selected_control.is_empty():
		return _denied("verifier is not authorized at a declared reconstitution control")
	var verifier_job: String = selected_control["actor_job"]
	if not staffing_runtime.is_staff_on_duty(staffing_state, verifier_state.get("person_id", ""), verifier_job):
		return _denied("verifier is not named on-duty reconstitution authority")
	if not state["active_failures"].has(service_id) or state["active_failures"][service_id]["failure_id"] != authoritative["failure_id"]:
		return _denied("recovery receipt no longer matches active failure")
	state["services"][service_id] = true
	state["service_states"][service_id] = {"phase": "normal"}
	state["active_failures"].erase(service_id)
	state["active_receipts"].erase(authoritative["receipt_id"])
	_append_history(state, {
		"event": "service_restored",
		"receipt_id": authoritative["receipt_id"],
		"failure_id": authoritative["failure_id"],
		"service": service_id,
		"repair_actor": authoritative["actor_person_id"],
		"verified_by": verifier_state["person_id"],
		"verified_by_job": verifier_job,
		"station": selected_control["station"],
		"control_mode": selected_control["mode"],
		"equipment": selected_control.get("equipment", ""),
	})
	return {
		"accepted": true,
		"receipt_id": authoritative["receipt_id"],
		"service": service_id,
		"procedure": authoritative["procedure"],
		"repair_actor": authoritative["actor_person_id"],
		"verified_by": verifier_state["person_id"],
		"verified_by_job": verifier_job,
		"station": selected_control["station"],
		"control_mode": selected_control["mode"],
		"equipment": selected_control.get("equipment", ""),
	}


func apply_mission_snapshot(graph: RefCounted, state: Dictionary, operation_runtime: RefCounted, mission_state: Dictionary) -> void:
	for service_id in state["services"]:
		operation_runtime.set_service_available(mission_state, service_id, bool(state["services"][service_id]))
	for edge in graph.dependency_edges:
		operation_runtime.set_room_service_available(
			mission_state,
			edge["kind"],
			edge["consumer"],
			room_has_service(state, edge["consumer"], edge["kind"])
		)


func _active_receipt(state: Dictionary, supplied: Dictionary) -> Dictionary:
	var receipt_id: String = supplied.get("receipt_id", "")
	if receipt_id.is_empty() or not state["active_receipts"].has(receipt_id):
		return {}
	var authoritative: Dictionary = state["active_receipts"][receipt_id]
	if supplied.get("failure_id", "") != authoritative["failure_id"]:
		return {}
	return authoritative


func _service_for_failure(state: Dictionary, failure_id: String) -> String:
	for service_id in state["active_failures"]:
		if state["active_failures"][service_id]["failure_id"] == failure_id:
			return service_id
	return ""


func _procedure_for_capability(graph: RefCounted, capability: String) -> String:
	for procedure_id in graph.failure_procedures:
		if (graph.failure_procedures[procedure_id]["capabilities"] as Array).has(capability):
			return procedure_id
	return ""


func _append_history(state: Dictionary, event: Dictionary) -> void:
	event["sequence"] = state["history"].size()
	state["history"].append(event)


func _denied(reason: String) -> Dictionary:
	return {"accepted": false, "reason": reason}
