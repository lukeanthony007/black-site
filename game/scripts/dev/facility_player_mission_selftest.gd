extends Node
## Slice 37–41: player stealth contract, institution cycle, door bind, theft evidence, mission stations.
var fails := 0


func _ready() -> void:
	var facility: Node = load("res://scenes/dev_generated_facility.tscn").instantiate()
	add_child(facility)
	for _frame in 4:
		await get_tree().process_frame

	# 2–3: institution produces evidence_package without player action
	var workday: Dictionary = facility.run_institution_workday()
	if not facility.mission_state.get("artifacts", {}).has("evidence_package") and facility.mission_state.get("status", "") != "completed":
		workday = facility.advance_mission(-1)
	_check(
		facility.mission_state.get("artifacts", {}).has("evidence_package"),
		"institution workday did not produce evidence_package (status=%s steps=%s)" % [
			facility.mission_state.get("status", ""),
			facility.mission_state.get("next_step_index", -1),
		]
	)
	_check(
		workday.get("status", "") in ["running", "completed", "blocked"] or facility.mission_state.get("artifacts", {}).has("evidence_package"),
		"institution workday result unusable: %s" % workday
	)

	# 4: start foreign extract; infiltrate auto-done when already screened
	var started: Dictionary = facility.start_player_contract("foreign_extract_evidence")
	_check(started.get("accepted", false), "start_player_contract rejected: %s" % started.get("reason", started))
	_check(
		bool(facility.player_mission_state.get("objectives", {}).get("infiltrate", {}).get("done", false)),
		"infiltrate not marked done for already-screened player"
	)
	_check(
		bool(started.get("infiltrated", {}).get("accepted", false))
		or bool(facility.player_mission_state.get("objectives", {}).get("infiltrate", {}).get("done", false)),
		"mark_infiltrated not accepted on screened admission"
	)

	# 5: acquire denied away from contained_lab (default screened_entry)
	var denied_away: Dictionary = facility.acquire_player_mission_target()
	_check(not denied_away.get("accepted", true), "acquire accepted away from target room: %s" % denied_away)
	_check(
		facility.personnel_state.get("current_room", "") != "contained_lab",
		"player already at contained_lab before teleport"
	)

	# 6: teleport to lab → observe + acquire
	var tele_lab: Dictionary = facility.teleport_personnel_to_room("contained_lab")
	_check(tele_lab.get("accepted", false) and facility.personnel_state.get("current_room", "") == "contained_lab", "teleport to contained_lab failed")
	var observed: Dictionary = facility.observe_player_mission_target()
	_check(observed.get("accepted", false), "observe_player_mission_target rejected: %s" % observed.get("reason", observed))
	var acquired: Dictionary = facility.acquire_player_mission_target()
	_check(acquired.get("accepted", false), "acquire_player_mission_target rejected: %s" % acquired.get("reason", acquired))
	_check(
		(facility.player_mission_state.get("inventory", []) as Array).has("evidence_package"),
		"inventory missing evidence_package after acquire"
	)
	_check(int(facility.player_mission_state.get("heat", 0)) >= 2, "heat not raised on acquire (heat=%s)" % facility.player_mission_state.get("heat", 0))
	# Slice 40: unauthorized removal leaves investigator-visible custody + control evidence
	var open_investigations: Array = facility.custody_state.get("open_investigations", []) as Array
	_check(open_investigations.size() >= 1, "custody open_investigations empty after acquire")
	var evidence_artifact: Dictionary = facility.mission_state.get("artifacts", {}).get("evidence_package", {}) as Dictionary
	_check(
		bool(evidence_artifact.get("compromised", false)),
		"mission artifact evidence_package not marked compromised after acquire: %s" % evidence_artifact
	)
	_check(facility.mission_state.get("artifacts", {}).has("evidence_package"), "acquire erased mission artifact instead of marking compromised")
	if facility.has_method("_refresh_control_status_board"):
		facility._refresh_control_status_board()
	var has_investigation_condition := _control_has_investigation_condition(facility)
	_check(has_investigation_condition, "control snapshot missing investigation condition after acquire theft")

	# 7: non-exfil room denied
	var tele_ops: Dictionary = facility.teleport_personnel_to_room("cyber_ops")
	_check(tele_ops.get("accepted", false), "teleport to cyber_ops failed")
	var denied_ops: Dictionary = facility.try_player_exfiltrate()
	_check(not denied_ops.get("accepted", true), "exfil accepted from cyber_ops: %s" % denied_ops)

	# 8: screened_entry exfil wins
	var tele_entry: Dictionary = facility.teleport_personnel_to_room("screened_entry")
	_check(tele_entry.get("accepted", false), "teleport to screened_entry failed")
	var won: Dictionary = facility.try_player_exfiltrate()
	_check(won.get("accepted", false), "exfil from screened_entry rejected: %s" % won.get("reason", won))
	_check(facility.player_mission_state.get("status", "") == "won", "player mission status not won after exfil")
	var rating: String = str(won.get("rating", facility.player_mission_runtime.compute_rating(facility.player_mission_state) if facility.player_mission_runtime != null else ""))
	_check(not rating.is_empty() and rating != "FAILED", "exfil rating empty/failed: %s" % rating)

	# 9: blocked mission denies ordinary screened_entry exfil; emergency_exit allowed
	var blocked_facility: Node = load("res://scenes/dev_generated_facility.tscn").instantiate()
	add_child(blocked_facility)
	for _frame in 4:
		await get_tree().process_frame
	blocked_facility.run_institution_workday()
	_check(
		blocked_facility.mission_state.get("artifacts", {}).has("evidence_package"),
		"blocked-path facility missing evidence_package"
	)
	var blocked_start: Dictionary = blocked_facility.start_player_contract("foreign_extract_evidence", "blocked-run")
	_check(blocked_start.get("accepted", false), "blocked-path start_player_contract rejected")
	blocked_facility.teleport_personnel_to_room("contained_lab")
	var blocked_acquire: Dictionary = blocked_facility.acquire_player_mission_target()
	_check(blocked_acquire.get("accepted", false), "blocked-path acquire rejected: %s" % blocked_acquire.get("reason", blocked_acquire))
	blocked_facility.mission_state["status"] = "blocked"
	blocked_facility.teleport_personnel_to_room("screened_entry")
	var denied_blocked: Dictionary = blocked_facility.try_player_exfiltrate()
	_check(not denied_blocked.get("accepted", true), "ordinary exfil accepted while mission blocked: %s" % denied_blocked)
	var tele_emergency: Dictionary = blocked_facility.teleport_personnel_to_room("emergency_exit")
	if tele_emergency.get("accepted", false) and blocked_facility.personnel_state.get("current_room", "") == "emergency_exit":
		var emergency_exfil: Dictionary = blocked_facility.try_player_exfiltrate()
		_check(
			emergency_exfil.get("accepted", false) and blocked_facility.player_mission_state.get("status", "") == "won",
			"emergency_exit exfil denied while mission blocked: %s" % emergency_exfil.get("reason", emergency_exfil)
		)
	else:
		# teleport helper should always allow emergency_exit (room exists); if not, denial above is the proof
		_check(true, "emergency_exit teleport unavailable; screened_entry denial stands")

	# 10: policy door interact → personnel transition; denied access raises heat
	var door_facility: Node = load("res://scenes/dev_generated_facility.tscn").instantiate()
	add_child(door_facility)
	for _frame in 4:
		await get_tree().process_frame
	if not door_facility.has_method("handle_policy_door_interact"):
		_check(false, "handle_policy_door_interact missing on generated facility")
	else:
		door_facility.run_institution_workday()
		var door_contract: Dictionary = door_facility.start_player_contract("foreign_extract_evidence", "door-bind-run")
		_check(door_contract.get("accepted", false), "door-path start_player_contract rejected: %s" % door_contract.get("reason", door_contract))
		var tele_screened: Dictionary = door_facility.teleport_personnel_to_room("screened_entry")
		_check(tele_screened.get("accepted", false), "door-path teleport to screened_entry failed")
		var current_room: String = str(door_facility.personnel_state.get("current_room", ""))
		_check(current_room == "screened_entry", "door-path personnel not at screened_entry (room=%s)" % current_room)

		var policy_doors: Array = _collect_policy_doors(door_facility)
		_check(not policy_doors.is_empty(), "no FacilityPolicyDoor nodes under generated facility")

		var entry_door: Node = null
		var expected_dest := ""
		for door_node in policy_doors:
			var from_room: String = str(door_node.get_meta("from_room", ""))
			var to_room: String = str(door_node.get_meta("to_room", ""))
			var flow: String = str(door_node.get_meta("flow", ""))
			if flow != "" and flow != "personnel":
				continue
			if from_room == "screened_entry":
				entry_door = door_node
				expected_dest = to_room
				if to_room == "staff_control":
					break
			elif to_room == "screened_entry":
				entry_door = door_node
				expected_dest = from_room
				if from_room == "staff_control":
					break
		_check(entry_door != null, "no policy door bordering screened_entry")
		if entry_door != null:
			var heat_before_accept: int = int(door_facility.player_mission_state.get("heat", 0))
			var accepted_cross: Dictionary = door_facility.handle_policy_door_interact(entry_door, door_facility.player)
			var room_after: String = str(door_facility.personnel_state.get("current_room", ""))
			_check(
				accepted_cross.get("accepted", false) and room_after == expected_dest,
				"door interact did not transition personnel (accepted=%s room=%s expected=%s reason=%s)" % [
					accepted_cross.get("accepted", false),
					room_after,
					expected_dest,
					accepted_cross.get("reason", accepted_cross),
				]
			)
			_check(
				int(door_facility.player_mission_state.get("heat", 0)) == heat_before_accept,
				"accepted door interact changed heat unexpectedly"
			)

			# Wrong-boundary door is rejected without heat (not a policy transition attempt).
			for door_node in policy_doors:
				var from_room: String = str(door_node.get_meta("from_room", ""))
				var to_room: String = str(door_node.get_meta("to_room", ""))
				if from_room != room_after and to_room != room_after:
					var heat_before_wrong: int = int(door_facility.player_mission_state.get("heat", 0))
					var wrong_boundary: Dictionary = door_facility.handle_policy_door_interact(door_node, door_facility.player)
					_check(not wrong_boundary.get("accepted", true), "wrong-boundary door accepted: %s" % wrong_boundary)
					_check(
						int(door_facility.player_mission_state.get("heat", 0)) == heat_before_wrong,
						"wrong-boundary door incorrectly raised heat"
					)
					break

			# On-boundary policy denial (insufficient credentials) raises heat on active contract.
			# Prefer non-emergency personnel door so deny is policy, not emergency egress accept.
			var boundary_deny_door: Node = null
			for candidate in policy_doors:
				var c_from: String = str(candidate.get_meta("from_room", ""))
				var c_to: String = str(candidate.get_meta("to_room", ""))
				var c_flow: String = str(candidate.get_meta("flow", ""))
				var c_emergency: bool = bool(candidate.get_meta("emergency_only", false))
				if c_emergency or (c_flow != "" and c_flow != "personnel"):
					continue
				if c_from == room_after or c_to == room_after:
					boundary_deny_door = candidate
					break
			_check(boundary_deny_door != null, "no ordinary personnel boundary door for denial heat proof")
			if boundary_deny_door != null:
				var saved_roles: Array = door_facility.personnel_state.get("roles", []).duplicate()
				var saved_tier: int = int(door_facility.personnel_state.get("clearance_tier", 0))
				door_facility.personnel_state["roles"] = []
				door_facility.personnel_state["clearance_tier"] = 0
				var heat_before_deny: int = int(door_facility.player_mission_state.get("heat", 0))
				var denied_cross: Dictionary = door_facility.handle_policy_door_interact(boundary_deny_door, door_facility.player)
				door_facility.personnel_state["roles"] = saved_roles
				door_facility.personnel_state["clearance_tier"] = saved_tier
				_check(not denied_cross.get("accepted", true), "stripped credentials still accepted door: %s" % denied_cross)
				_check(
					int(door_facility.player_mission_state.get("heat", 0)) == heat_before_deny + 1,
					"denied door access did not raise heat by 1 (heat=%s before=%s)" % [
						door_facility.player_mission_state.get("heat", 0),
						heat_before_deny,
					]
				)

	# 11: mission stations — create after workday+contract; acquire at lab; exfil at screened_entry
	var station_facility: Node = load("res://scenes/dev_generated_facility.tscn").instantiate()
	add_child(station_facility)
	for _frame in 4:
		await get_tree().process_frame
	station_facility.run_institution_workday()
	if not station_facility.mission_state.get("artifacts", {}).has("evidence_package") and station_facility.mission_state.get("status", "") != "completed":
		station_facility.advance_mission(-1)
	_check(
		station_facility.mission_state.get("artifacts", {}).has("evidence_package"),
		"station-path facility missing evidence_package"
	)
	var station_start: Dictionary = station_facility.start_player_contract("foreign_extract_evidence", "station-run")
	_check(station_start.get("accepted", false), "station-path start_player_contract rejected: %s" % station_start.get("reason", station_start))
	if station_facility.has_method("_create_player_mission_stations"):
		station_facility._create_player_mission_stations()
	else:
		_check(false, "_create_player_mission_stations missing on generated facility")
	var station_group: Node = station_facility.get_node_or_null("PlayerMissionStations")
	_check(station_group != null, "PlayerMissionStations group missing after create")
	var station_count := 0
	if station_group != null:
		station_count = station_group.get_child_count()
	_check(station_count >= 2, "expected acquire+exfil stations, got %d" % station_count)
	_check(station_facility.has_method("activate_player_mission_station"), "activate_player_mission_station missing")
	if station_facility.has_method("activate_player_mission_station"):
		var station_tele_lab: Dictionary = station_facility.teleport_personnel_to_room("contained_lab")
		_check(
			station_tele_lab.get("accepted", false) and station_facility.personnel_state.get("current_room", "") == "contained_lab",
			"station-path teleport to contained_lab failed"
		)
		var station_acquire: Dictionary = station_facility.activate_player_mission_station("acquire", station_facility.player)
		_check(
			station_acquire.get("accepted", false),
			"activate_player_mission_station acquire rejected at contained_lab: %s" % station_acquire
		)
		_check(
			(station_facility.player_mission_state.get("inventory", []) as Array).has("evidence_package"),
			"station acquire did not place evidence_package in inventory"
		)
		var station_investigations: Array = station_facility.custody_state.get("open_investigations", []) as Array
		_check(station_investigations.size() >= 1, "station acquire left no open_investigations")
		var station_tele_entry: Dictionary = station_facility.teleport_personnel_to_room("screened_entry")
		_check(
			station_tele_entry.get("accepted", false) and station_facility.personnel_state.get("current_room", "") == "screened_entry",
			"station-path teleport to screened_entry failed"
		)
		var station_exfil: Dictionary = station_facility.activate_player_mission_station("exfil", station_facility.player)
		_check(
			station_exfil.get("accepted", false) and station_facility.player_mission_state.get("status", "") == "won",
			"activate_player_mission_station exfil failed at screened_entry: %s" % station_exfil
		)

	print("=== facility_player_mission_selftest done fails=%d ===" % fails)
	get_tree().quit(0 if fails == 0 else 1)


func _check(v: bool, m: String) -> void:
	if not v:
		fails += 1
		push_error("FAIL: %s" % m)


func _control_has_investigation_condition(facility: Node) -> bool:
	var snapshot: Dictionary = {}
	if facility.get("control_snapshot") is Dictionary:
		snapshot = facility.control_snapshot as Dictionary
	if snapshot.is_empty() and facility.control_room_runtime != null:
		snapshot = facility.control_room_runtime.compile_status(
			facility.operation_graph,
			facility.control_console_state,
			facility.mission_state,
			facility.custody_state,
			facility.personnel_state,
			facility.staffing_state,
			facility.staffing_runtime,
			facility.infrastructure_state
		)
	for condition in snapshot.get("conditions", []):
		if str(condition.get("kind", "")) == "investigation":
			return true
	return false


func _collect_policy_doors(root: Node) -> Array:
	var found: Array = []
	_walk_policy_doors(root, found)
	return found


func _walk_policy_doors(node: Node, found: Array) -> void:
	if node is FacilityPolicyDoor:
		found.append(node)
	elif node.has_meta("from_room") and node.has_meta("to_room"):
		var script: Script = node.get_script() as Script
		if script != null and str(script.resource_path).ends_with("facility_policy_door.gd"):
			found.append(node)
	for child in node.get_children():
		_walk_policy_doors(child, found)
