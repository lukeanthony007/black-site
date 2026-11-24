class_name FacilityPlayerMissionRuntime
extends RefCounted
## Player contract layer on the generated Cyber/Archives institution.
## Does not invent facility authority: acquisition and exfil read mission artifacts,
## personnel location, protective posture, and custody state.

const STATE_SCHEMA := "facility-player-mission/v1"
const CONTRACTS := {
	"foreign_extract_evidence": {
		"label": "Foreign extraction — evidence package",
		"target_artifact": "evidence_package",
		"target_room": "contained_lab",
		"exfil_rooms": ["screened_entry", "emergency_exit"],
		"required_objectives": ["infiltrate", "locate", "acquire", "exfiltrate"],
	},
	"foreign_extract_record": {
		"label": "Foreign extraction — preserved record",
		"target_artifact": "preserved_record",
		"target_room": "archive_stack",
		"exfil_rooms": ["screened_entry", "emergency_exit"],
		"required_objectives": ["infiltrate", "locate", "acquire", "exfiltrate"],
	},
}


func start_contract(contract_id: String, run_id: String = "") -> Dictionary:
	if not CONTRACTS.has(contract_id):
		return _deny("unknown player contract")
	var contract: Dictionary = CONTRACTS[contract_id]
	var objectives: Dictionary = {}
	for objective_id in contract["required_objectives"]:
		objectives[objective_id] = {
			"id": objective_id,
			"done": false,
			"required": true,
			"label": _objective_label(objective_id, contract),
		}
	return {
		"schema": STATE_SCHEMA,
		"contract_id": contract_id,
		"run_id": run_id if not run_id.is_empty() else "player-run-1",
		"label": contract["label"],
		"target_artifact": contract["target_artifact"],
		"target_room": contract["target_room"],
		"exfil_rooms": (contract["exfil_rooms"] as Array).duplicate(),
		"status": "active",
		"objectives": objectives,
		"inventory": [],
		"audit": [],
		"heat": 0,
		"next_audit_number": 1,
		"acquired_artifact": "",
		"failure": "",
	}


func validate_state(state: Dictionary) -> Dictionary:
	if state.get("schema", "") != STATE_SCHEMA:
		return _deny("player mission schema invalid")
	if not CONTRACTS.has(state.get("contract_id", "")):
		return _deny("player mission contract unknown")
	if not state.get("objectives", null) is Dictionary or not state.get("inventory", null) is Array or not state.get("audit", null) is Array:
		return _deny("player mission shape invalid")
	if int(state.get("heat", -1)) < 0 or int(state.get("next_audit_number", 0)) < 1:
		return _deny("player mission counters invalid")
	if state.get("status", "") not in ["active", "won", "failed"]:
		return _deny("player mission status invalid")
	return {"accepted": true}


func mark_infiltrated(state: Dictionary, personnel_state: Dictionary) -> Dictionary:
	var gate := validate_state(state)
	if not gate.get("accepted", false):
		return gate
	if state["status"] != "active":
		return _deny("player mission is not active")
	if not bool(personnel_state.get("screened", false)):
		return _deny("player is not screened into the facility")
	if not String(personnel_state.get("current_room", "")).is_empty():
		_complete_objective(state, "infiltrate")
		_audit(state, "infiltrated", personnel_state.get("current_room", ""), {"person_id": personnel_state.get("person_id", "")})
		return {"accepted": true, "objective": "infiltrate", "status": state["status"]}
	return _deny("player personnel room is unknown")


func observe_target(state: Dictionary, personnel_state: Dictionary, mission_state: Dictionary) -> Dictionary:
	var gate := validate_state(state)
	if not gate.get("accepted", false):
		return gate
	if state["status"] != "active":
		return _deny("player mission is not active")
	if not bool(state["objectives"]["infiltrate"]["done"]):
		return _deny("player has not infiltrated")
	var room: String = personnel_state.get("current_room", "")
	if room != state["target_room"]:
		return _deny("player is not at the target room")
	if not _artifact_available(mission_state, state["target_artifact"]):
		return _deny("target artifact is not yet produced by the institution")
	_complete_objective(state, "locate")
	_audit(state, "located_target", room, {"artifact": state["target_artifact"]})
	return {"accepted": true, "objective": "locate", "room": room, "artifact": state["target_artifact"]}


func acquire_target(state: Dictionary, personnel_state: Dictionary, mission_state: Dictionary, custody_state: Dictionary = {}) -> Dictionary:
	var gate := validate_state(state)
	if not gate.get("accepted", false):
		return gate
	if state["status"] != "active":
		return _deny("player mission is not active")
	if not bool(state["objectives"]["infiltrate"]["done"]):
		return _deny("player has not infiltrated")
	var room: String = personnel_state.get("current_room", "")
	if room != state["target_room"]:
		return _deny("player is not at the target room")
	if not _artifact_available(mission_state, state["target_artifact"]):
		return _deny("target artifact is not available to acquire")
	if state["target_artifact"] == "preserved_record":
		if custody_state.is_empty() or not bool(custody_state.get("stored", false)) or custody_state.get("current_room", "") != "archive_stack":
			# Institution artifact is enough if custody not tracking this package; soft-require stored when custody present.
			if not custody_state.is_empty() and custody_state.get("current_room", "") != "archive_stack":
				return _deny("preserved holdings are not at archive storage")
	if state["inventory"].has(state["target_artifact"]):
		return {"accepted": true, "already_committed": true, "artifact": state["target_artifact"]}
	state["inventory"].append(state["target_artifact"])
	state["acquired_artifact"] = state["target_artifact"]
	state["heat"] = int(state["heat"]) + 2
	_complete_objective(state, "locate")
	_complete_objective(state, "acquire")
	_audit(state, "acquired_target", room, {"artifact": state["target_artifact"], "heat": state["heat"]})
	return {"accepted": true, "objective": "acquire", "artifact": state["target_artifact"], "heat": state["heat"]}


func try_exfiltrate(state: Dictionary, personnel_state: Dictionary, mission_state: Dictionary) -> Dictionary:
	var gate := validate_state(state)
	if not gate.get("accepted", false):
		return gate
	if state["status"] != "active":
		return _deny("player mission is not active")
	if not bool(state["objectives"]["acquire"]["done"]) or not state["inventory"].has(state["target_artifact"]):
		return _deny("player has not acquired the target artifact")
	var room: String = personnel_state.get("current_room", "")
	if not (state["exfil_rooms"] as Array).has(room):
		return _deny("player is not at an authorized exfil room")
	var postures: Dictionary = mission_state.get("room_protective_postures", {})
	if postures.has(room) and not String(postures[room]).is_empty():
		state["heat"] = int(state["heat"]) + 1
		_audit(state, "exfil_denied_posture", room, {"posture": postures[room], "heat": state["heat"]})
		return _deny("exfil room is under protective posture: %s" % postures[room])
	if mission_state.get("status", "") == "blocked" and room != "emergency_exit":
		# Ordinary screened exit denied during mission_shutdown; emergency egress still allowed.
		state["heat"] = int(state["heat"]) + 1
		_audit(state, "exfil_denied_mission_blocked", room, {"heat": state["heat"]})
		return _deny("ordinary exfil denied while facility mission is blocked")
	_complete_objective(state, "exfiltrate")
	state["status"] = "won"
	_audit(state, "exfiltrated", room, {"artifact": state["target_artifact"], "heat": state["heat"]})
	return {
		"accepted": true,
		"status": "won",
		"room": room,
		"artifact": state["target_artifact"],
		"heat": state["heat"],
		"rating": compute_rating(state),
	}


func fail_contract(state: Dictionary, reason: String, room: String = "") -> Dictionary:
	var gate := validate_state(state)
	if not gate.get("accepted", false):
		return gate
	if state["status"] != "active":
		return _deny("player mission is not active")
	state["status"] = "failed"
	state["failure"] = reason
	_audit(state, "failed", room, {"reason": reason})
	return {"accepted": true, "status": "failed", "reason": reason}


func record_access_denial(state: Dictionary, room: String, reason: String = "") -> Dictionary:
	var gate := validate_state(state)
	if not gate.get("accepted", false):
		return gate
	if state["status"] != "active":
		return _deny("player mission is not active")
	state["heat"] = int(state["heat"]) + 1
	_audit(state, "access_denied", room, {"reason": reason, "heat": state["heat"]})
	return {"accepted": true, "heat": state["heat"]}

func project_objectives(state: Dictionary) -> Dictionary:
	var projected: Dictionary = {}
	var order := 1
	for objective_id in ["infiltrate", "locate", "acquire", "exfiltrate"]:
		if not state.get("objectives", {}).has(objective_id):
			continue
		var objective: Dictionary = state["objectives"][objective_id]
		projected[objective_id] = {
			"label": "%d. %s" % [order, objective.get("label", objective_id)],
			"done": bool(objective.get("done", false)),
			"required": true,
		}
		order += 1
	return projected


func compute_rating(state: Dictionary) -> String:
	var heat: int = int(state.get("heat", 0))
	if state.get("status", "") != "won":
		return "FAILED"
	if heat <= 2:
		return "GHOST"
	if heat <= 4:
		return "SHADOW"
	if heat <= 7:
		return "PANTHER"
	return "ASSAULT"


func _artifact_available(mission_state: Dictionary, artifact_id: String) -> bool:
	return mission_state.get("artifacts", {}).has(artifact_id)


func _complete_objective(state: Dictionary, objective_id: String) -> void:
	if state["objectives"].has(objective_id):
		state["objectives"][objective_id]["done"] = true


func _objective_label(objective_id: String, contract: Dictionary) -> String:
	match objective_id:
		"infiltrate":
			return "Infiltrate screened facility"
		"locate":
			return "Locate %s in %s" % [contract["target_artifact"].replace("_", " "), contract["target_room"]]
		"acquire":
			return "Acquire %s" % contract["target_artifact"].replace("_", " ")
		"exfiltrate":
			return "Exfiltrate with the package"
		_:
			return objective_id


func _audit(state: Dictionary, kind: String, room: String, detail: Dictionary) -> void:
	var event: Dictionary = {
		"sequence": state["next_audit_number"],
		"kind": kind,
		"room": room,
		"detail": detail.duplicate(true),
	}
	state["audit"].append(event)
	state["next_audit_number"] = int(state["next_audit_number"]) + 1


func _deny(reason: String) -> Dictionary:
	return {"accepted": false, "reason": reason}
