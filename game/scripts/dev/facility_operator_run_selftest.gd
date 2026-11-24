extends Node
## Playable operator run: restricted cover, door-walk steal path, institutional evidence.
var fails := 0


func _ready() -> void:
	var facility = load("res://scenes/dev_generated_facility.tscn").instantiate()
	facility.operator_run = true
	facility.operator_contract_id = "foreign_extract_evidence"
	add_child(facility)
	for _i in 8:
		await get_tree().process_frame

	_check(not facility.player_mission_state.is_empty() and facility.player_mission_state.get("status", "") == "active", "operator contract not active")
	_check(facility.mission_state.get("artifacts", {}).has("evidence_package"), "workday did not produce evidence_package")
	var stations: Node = facility.get_node_or_null("PlayerMissionStations")
	_check(stations != null and stations.get_child_count() >= 2, "player mission stations missing")
	_check(bool(facility.player_mission_state.get("objectives", {}).get("infiltrate", {}).get("done", false)), "operator not infiltrated")
	_check(facility.personnel_state.get("person_id", "") == "operator_player", "operator person id wrong")
	var roles: Array = facility.personnel_state.get("roles", [])
	_check(roles == ["cyber_researcher"], "operator roles not restricted to cyber_researcher cover")
	_check(not roles.has("duty_officer") and not roles.has("security_officer"), "operator still has god-mode security roles")
	_check(int(facility.player.keycard_tier) == 4, "operator keycard tier not limited")

	# Door-walk under cover: screened_entry → staff_control → cyber_ops → contained_lab
	_check(str(facility.personnel_state.get("current_room", "")) == "screened_entry", "operator not starting at screened_entry")
	_check(_door_to(facility, "staff_control"), "door to staff_control denied under researcher cover")
	_check(_door_to(facility, "cyber_ops"), "door to cyber_ops denied under researcher cover")
	_check(_door_to(facility, "contained_lab"), "door to contained_lab denied under researcher cover")
	_check(str(facility.personnel_state.get("current_room", "")) == "contained_lab", "operator not in contained_lab after door-walk")

	# Cover cannot cheat plant authority
	var plant_denied: Dictionary = facility.request_personnel_transition("plant", false)
	_check(not plant_denied.get("accepted", true), "researcher cover cheated plant access: %s" % plant_denied)

	var acquire: Dictionary = facility.activate_player_mission_station("acquire", facility.player)
	_check(acquire.get("accepted", false), "acquire station rejected after door-walk: %s" % acquire)
	_check((facility.player_mission_state.get("inventory", []) as Array).has("evidence_package"), "inventory missing evidence_package")
	_check((facility.custody_state.get("open_investigations", []) as Array).size() >= 1, "theft left no open investigation")
	var artifact: Dictionary = facility.mission_state.get("artifacts", {}).get("evidence_package", {}) as Dictionary
	_check(bool(artifact.get("compromised", false)), "institution artifact not marked compromised")
	_check(facility.mission_state.get("artifacts", {}).has("evidence_package"), "acquire erased institution artifact")

	# Door-walk exfil path back out
	_check(_door_to(facility, "cyber_ops"), "return door to cyber_ops denied")
	_check(_door_to(facility, "staff_control"), "return door to staff_control denied")
	_check(_door_to(facility, "screened_entry"), "return door to screened_entry denied")
	var exfil: Dictionary = facility.activate_player_mission_station("exfil", facility.player)
	_check(exfil.get("accepted", false) and facility.player_mission_state.get("status", "") == "won", "exfil station failed: %s" % exfil)

	print("=== facility_operator_run_selftest done fails=%d ===" % fails)
	get_tree().quit(0 if fails == 0 else 1)


func _door_to(facility: Node, dest: String) -> bool:
	var current: String = str(facility.personnel_state.get("current_room", ""))
	var door: Node = _find_personnel_door(facility, current, dest)
	if door == null:
		push_error("FAIL: no personnel door %s↔%s" % [current, dest])
		fails += 1
		return false
	var before: Vector3 = facility.player.global_position
	var result: Dictionary = facility.handle_policy_door_interact(door, facility.player)
	if not result.get("accepted", false) or str(facility.personnel_state.get("current_room", "")) != dest:
		push_error("FAIL: door to %s rejected: %s (room=%s)" % [dest, result, facility.personnel_state.get("current_room", "")])
		fails += 1
		return false
	if bool(result.get("relocated_body", true)):
		push_error("FAIL: door to %s relocated player body" % dest)
		fails += 1
		return false
	if facility.player.global_position.distance_to(before) > 0.05:
		push_error("FAIL: door to %s teleported player (before=%s after=%s)" % [dest, before, facility.player.global_position])
		fails += 1
		return false
	if not bool(door.is_open):
		push_error("FAIL: door to %s did not open physically" % dest)
		fails += 1
		return false
	return true


func _find_personnel_door(facility: Node, room_a: String, room_b: String) -> Node:
	if facility.generated_facility == null:
		return null
	for node in facility.generated_facility.find_children("*", "FacilityPolicyDoor", true, false):
		var flow: String = str(node.get_meta("flow", ""))
		if flow != "" and flow != "personnel":
			continue
		var from_room: String = str(node.get_meta("from_room", ""))
		var to_room: String = str(node.get_meta("to_room", ""))
		if (from_room == room_a and to_room == room_b) or (from_room == room_b and to_room == room_a):
			return node
	return null


func _check(v: bool, m: String) -> void:
	if not v:
		fails += 1
		push_error("FAIL: %s" % m)
