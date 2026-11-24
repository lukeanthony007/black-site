class_name EnvironmentalObservationRoundRuntime
extends RefCounted

const REQUIRED_READINGS: Array[String] = ["temperature", "relative_humidity", "water_intrusion", "smoke_or_local_alarm"]

func new_state() -> Dictionary:
	return {"active": false, "occurrence_id": "", "clock": 0, "next_round_clock": 0, "round_counter": 0, "obligation": {}, "actors_by_job": {}, "active_round": {}, "completed_rounds": [], "observations": [], "hazard_findings": [], "hazard_decisions": [], "active_hazard_work": {}, "hazard_closures": [], "active_compute_reactivation": {}, "compute_reactivations": [], "active_room_evacuation": {}, "room_evacuations": [], "displaced_commands": [], "remediation_authorizations": [], "active_fire_inspection": {}, "fire_inspections": [], "active_room_reentry": {}, "room_reentries": [], "active_command_restoration": {}, "command_restorations": [], "escalations": [], "decisions": [], "active_release": {}, "releases": [], "protective_postures": {}}

func activate(state: Dictionary, occurrence_id: String, obligation: Dictionary, actors_by_job: Dictionary) -> Dictionary:
	if state.get("active", false): return {"accepted": false, "reason": "observation_authority_already_active"}
	if occurrence_id.is_empty(): return {"accepted": false, "reason": "missing_occurrence"}
	var errors: Array[String] = _validate_obligation(obligation, actors_by_job)
	if not errors.is_empty(): return {"accepted": false, "reason": errors[0]}
	state["active"] = true; state["occurrence_id"] = occurrence_id; state["obligation"] = obligation.duplicate(true); state["actors_by_job"] = actors_by_job.duplicate(true)
	_start_round(state)
	return {"accepted": true, "round_number": state["round_counter"]}

func tick(state: Dictionary, actor_locations: Dictionary, readings_by_room: Dictionary) -> Dictionary:
	if not state.get("active", false): return {"accepted": false, "reason": "observation_authority_inactive"}
	if not state.get("active_round", {}).is_empty() and state["active_round"].get("suspended", false): return {"accepted": false, "reason": "observation round requires explicit resume"}
	state["clock"] = int(state.get("clock", 0)) + 1
	_record_overdue_if_needed(state)
	if state["active_round"].is_empty():
		if state["clock"] < state["next_round_clock"]: return {"accepted": true, "status": "waiting"}
		_start_round(state)
	var round_state: Dictionary = state["active_round"]
	var assignment: Dictionary = round_state["assignments"][round_state["room_index"]]
	var room_id: String = assignment["room"]
	var actor_id: String = assignment["actor_person_id"]
	if actor_locations.get(actor_id, "") != room_id: return {"accepted": false, "reason": "observer_not_at_room:" + room_id}
	if int(round_state["remaining_ticks"]) == 1:
		var readings: Dictionary = readings_by_room.get(room_id, {})
		for reading_id in REQUIRED_READINGS:
			if not readings.has(reading_id): return {"accepted": false, "reason": "missing_observation:" + room_id + ":" + reading_id}
		round_state["remaining_ticks"] = 0
		var observation: Dictionary = {"observation_id": "%s:round:%d:room:%d" % [state["occurrence_id"], round_state["round_number"], round_state["room_index"]], "occurrence_id": state["occurrence_id"], "round_number": round_state["round_number"], "room": room_id, "actor_job": assignment["actor_job"], "actor_person_id": actor_id, "recorded_clock": state["clock"], "readings": readings.duplicate(true)}
		state["observations"].append(observation); round_state["observation_ids"].append(observation["observation_id"])
		_classify_hazards(state, observation)
		round_state["room_index"] += 1
		if round_state["room_index"] >= round_state["assignments"].size():
			round_state["completed_clock"] = state["clock"]; state["completed_rounds"].append(round_state.duplicate(true)); state["active_round"] = {}; state["next_round_clock"] = state["clock"] + int(state["obligation"]["interval_ticks"])
			return {"accepted": true, "status": "round_completed", "round_number": round_state["round_number"]}
		round_state["remaining_ticks"] = int(state["obligation"]["duration_ticks_per_room"]); state["active_round"] = round_state
		return {"accepted": true, "status": "room_recorded", "room": room_id}
	round_state["remaining_ticks"] -= 1; state["active_round"] = round_state
	return {"accepted": true, "status": "working", "room": room_id}

func prepare_recovered_state(state: Dictionary, obligation: Dictionary) -> Dictionary:
	var errors: Array[String] = validate_state(state, obligation)
	if not errors.is_empty(): return {"accepted": false, "reason": "invalid environmental observation state: %s" % [errors]}
	var recovered: Dictionary = state.duplicate(true)
	if not recovered.get("active_round", {}).is_empty():
		recovered["active_round"]["suspended"] = true
		recovered["active_round"]["suspension_reason"] = "restart_reconciliation"
	if not recovered.get("active_release", {}).is_empty():
		recovered["active_release"]["suspended"] = true
		recovered["active_release"]["suspension_reason"] = "restart_reconciliation"
	if not recovered.get("active_hazard_work", {}).is_empty():
		recovered["active_hazard_work"]["suspended"] = true
		recovered["active_hazard_work"]["suspension_reason"] = "restart_reconciliation"
	if not recovered.get("active_compute_reactivation", {}).is_empty():
		recovered["active_compute_reactivation"]["suspended"] = true
		recovered["active_compute_reactivation"]["suspension_reason"] = "restart_reconciliation"
	if not recovered.get("active_fire_inspection", {}).is_empty():
		recovered["active_fire_inspection"]["suspended"] = true
		recovered["active_fire_inspection"]["suspension_reason"] = "restart_reconciliation"
	if not recovered.get("active_room_reentry", {}).is_empty():
		recovered["active_room_reentry"]["suspended"] = true
		recovered["active_room_reentry"]["suspension_reason"] = "restart_reconciliation"
	if not recovered.get("active_command_restoration",{}).is_empty():
		recovered["active_command_restoration"]["suspended"]=true
		recovered["active_command_restoration"]["suspension_reason"]="restart_reconciliation"
	return {"accepted": true, "state": recovered}


func resume(state: Dictionary, occurrence_id: String, actor_locations: Dictionary) -> Dictionary:
	if not state.get("active", false) or occurrence_id != state.get("occurrence_id", ""): return {"accepted": false, "reason": "observation_occurrence_mismatch"}
	if state.get("active_round", {}).is_empty() or not state["active_round"].get("suspended", false): return {"accepted": false, "reason": "observation_round_not_suspended"}
	var assignment: Dictionary = state["active_round"]["assignments"][state["active_round"]["room_index"]]
	if actor_locations.get(assignment["actor_person_id"], "") != assignment["room"]: return {"accepted": false, "reason": "observer_not_at_recovered_room"}
	state["active_round"]["suspended"] = false; state["active_round"]["suspension_reason"] = ""
	return {"accepted": true, "remaining_ticks": state["active_round"]["remaining_ticks"]}


func resume_hazard_work(state: Dictionary, finding_id: String, actor_locations: Dictionary) -> Dictionary:
	var work: Dictionary = state.get("active_hazard_work", {})
	if work.is_empty() or work.get("finding_id", "") != finding_id or not work.get("suspended", false): return {"accepted": false, "reason": "hazard work is not suspended for finding"}
	if actor_locations.get(work.get("actor_person_id", ""), "") != work.get("station", "") or actor_locations.get(work.get("verification_person_id", ""), "") != work.get("verification_station", ""): return {"accepted": false, "reason": "hazard work participants not reconciled at stations"}
	work["suspended"] = false; work["suspension_reason"] = ""; state["active_hazard_work"] = work
	return {"accepted": true, "finding_id": finding_id, "phase": work["phase"], "remaining_ticks": work["remaining_ticks"]}


func resume_protective_release(state: Dictionary, room_id: String, actor_locations: Dictionary) -> Dictionary:
	var work: Dictionary = state.get("active_release", {})
	if work.is_empty() or work.get("room", "") != room_id or not work.get("suspended", false): return {"accepted": false, "reason": "protective release is not suspended for room"}
	if actor_locations.get(work["authority_person_id"], "") != work["authority_station"] or actor_locations.get(work["concurrence_person_id"], "") != work["concurrence_station"]: return {"accepted": false, "reason": "release participants not reconciled at stations"}
	work["suspended"] = false; work["suspension_reason"] = ""; state["active_release"] = work
	return {"accepted": true, "room": room_id, "remaining_ticks": work["remaining_ticks"]}


func close(state: Dictionary, occurrence_id: String) -> Dictionary:
	if not state.get("active", false): return {"accepted": false, "reason": "observation_authority_inactive"}
	if occurrence_id != state.get("occurrence_id", ""): return {"accepted": false, "reason": "observation_occurrence_mismatch"}
	if not state.get("active_round", {}).is_empty(): return {"accepted": false, "reason": "observation_round_still_active"}
	for finding in state.get("hazard_findings", []):
		if finding.get("status", "") != "closed": return {"accepted": false, "reason": "unresolved_environmental_hazard"}
	state["active"] = false; state["next_round_clock"] = 0
	return {"accepted": true, "observations_retained": state.get("observations", []).size()}


func validate_state(state: Dictionary, obligation: Dictionary) -> Array[String]:
	var errors: Array[String] = _validate_obligation(obligation, state.get("actors_by_job", {}), bool(state.get("active", false)) or not String(state.get("occurrence_id", "")).is_empty())
	if state.get("active", false) and String(state.get("occurrence_id", "")).is_empty(): errors.append("active observation authority lacks occurrence")
	var seen: Dictionary = {}
	for observation in state.get("observations", []):
		var observation_id: String = observation.get("observation_id", "")
		if observation_id.is_empty() or seen.has(observation_id): errors.append("invalid or duplicate observation identity")
		seen[observation_id] = true
		if observation.get("occurrence_id", "") != state.get("occurrence_id", ""): errors.append("observation occurrence mismatch")
		if String(observation.get("actor_person_id", "")).is_empty(): errors.append("observation lacks named actor")
		var readings: Dictionary = observation.get("readings", {})
		for reading_id in REQUIRED_READINGS:
			if not readings.has(reading_id): errors.append("observation lacks required reading: " + reading_id)
	var expected_findings: Dictionary = {}
	for observation in state.get("observations", []):
		for rule in obligation.get("hazard_rules", []):
			if rule.get("room", "") == observation.get("room", "") and bool(observation.get("readings", {}).get(rule.get("reading", ""), false)):
				var expected_id: String = observation["observation_id"] + ":hazard:" + rule["classification"]
				expected_findings[expected_id] = {"observation_id":observation["observation_id"],"classification":rule["classification"],"recommended_decision":rule["recommended_decision"],"room":rule["room"],"reading":rule["reading"]}
	var seen_findings: Dictionary = {}
	for finding in state.get("hazard_findings", []):
		var finding_id: String = finding.get("finding_id", "")
		var expected_finding: Dictionary = expected_findings.get(finding_id, {})
		if expected_finding.is_empty() or seen_findings.has(finding_id) or finding.get("occurrence_id", "") != state.get("occurrence_id", "") or finding.get("observation_id", "") != expected_finding.get("observation_id", "") or finding.get("classification", "") != expected_finding.get("classification", "") or finding.get("recommended_decision", "") != expected_finding.get("recommended_decision", "") or finding.get("room", "") != expected_finding.get("room", "") or finding.get("reading", "") != expected_finding.get("reading", "") or finding.get("status", "") not in ["unresolved", "commanded", "verification_pending", "closed"]: errors.append("invalid environmental hazard finding")
		seen_findings[finding_id] = true
	if seen_findings.size() != expected_findings.size(): errors.append("environmental hazard finding set is incomplete")
	var escalated_rounds: Dictionary = {}
	for escalation_event in state.get("escalations", []):
		var escalated_round: int = int(escalation_event.get("round_number", 0))
		if escalated_round < 1 or escalated_rounds.has(escalated_round) or escalation_event.get("occurrence_id", "") != state.get("occurrence_id", "") or escalation_event.get("action", "") != obligation.get("escalation", {}).get("action", ""):
			errors.append("invalid or duplicate observation escalation")
		escalated_rounds[escalated_round] = true
	var decided_rounds: Dictionary = {}
	var expected_postures: Dictionary = {}
	var hazard_decision_findings: Dictionary = {}
	for hazard_decision in state.get("hazard_decisions", []):
		var hazard_decision_id: String = hazard_decision.get("decision_id", "")
		var hazard_finding_id: String = hazard_decision.get("finding_id", "")
		var source_finding: Dictionary = {}
		for finding in state.get("hazard_findings", []):
			if finding.get("finding_id", "") == hazard_finding_id: source_finding = finding; break
		if hazard_decision_id.is_empty() or hazard_decision_findings.has(hazard_finding_id) or source_finding.is_empty() or source_finding.get("status", "") not in ["commanded", "verification_pending", "closed"] or source_finding.get("decision_id", "") != hazard_decision_id or hazard_decision.get("occurrence_id", "") != state.get("occurrence_id", "") or hazard_decision.get("observation_id", "") != source_finding.get("observation_id", "") or hazard_decision.get("decision", "") != source_finding.get("recommended_decision", "") or String(hazard_decision.get("actor_person_id", "")).is_empty() or hazard_decision.get("actor_job", "") != obligation["escalation"]["actor_job"] or hazard_decision.get("station", "") != obligation["escalation"]["station"] or String(hazard_decision.get("rationale", "")).strip_edges().is_empty(): errors.append("invalid environmental hazard decision")
		hazard_decision_findings[hazard_finding_id] = true
		if hazard_decision.get("decision", "") == "archive_safe_hold": expected_postures["archive_stack"] = "safe_hold"
		elif hazard_decision.get("decision", "") == "compute_safe_shutdown": expected_postures["compute_core"] = "safe_shutdown"
		elif hazard_decision.get("decision", "") == "evacuate_affected_rooms": expected_postures[source_finding["room"]] = "evacuate"
	for finding in state.get("hazard_findings", []):
		if (finding.get("status", "") != "unresolved") != hazard_decision_findings.has(finding.get("finding_id", "")): errors.append("hazard finding command status lacks exact decision")
	var active_hazard_work: Dictionary = state.get("active_hazard_work", {})
	if not active_hazard_work.is_empty():
		var active_work_finding: Dictionary = {}
		for finding in state.get("hazard_findings", []):
			if finding.get("finding_id", "") == active_hazard_work.get("finding_id", ""): active_work_finding = finding; break
		var active_work_rule: Dictionary = {}
		for rule in obligation.get("hazard_rules", []):
			if rule.get("classification", "") == active_work_finding.get("classification", ""): active_work_rule = rule; break
		var active_work_policy: Dictionary = active_work_rule.get("remediation", {})
		var expected_work_status: String = "commanded" if active_hazard_work.get("phase", "") == "remediation" else "verification_pending"
		var maximum_remaining: int = int(active_work_policy.get("duration_ticks", 0)) if active_hazard_work.get("phase", "") == "remediation" else int(active_work_policy.get("verification_duration_ticks", 0))
		if active_work_finding.is_empty() or active_work_policy.is_empty() or active_hazard_work.get("phase", "") not in ["remediation", "verification"] or active_work_finding.get("status", "") != expected_work_status or active_hazard_work.get("work_id", "") != active_hazard_work.get("finding_id", "") + ":remediation" or String(active_hazard_work.get("actor_person_id", "")).is_empty() or String(active_hazard_work.get("verification_person_id", "")).is_empty() or active_hazard_work.get("actor_person_id", "") == active_hazard_work.get("verification_person_id", "") or active_hazard_work.get("actor_job", "") != active_work_policy.get("actor_job", "") or active_hazard_work.get("station", "") != active_work_policy.get("station", "") or active_hazard_work.get("verification_job", "") != active_work_policy.get("verification_job", "") or active_hazard_work.get("verification_station", "") != active_work_policy.get("verification_station", "") or active_hazard_work.get("clear_readings", []) != active_work_policy.get("clear_readings", []) or int(active_hazard_work.get("remaining_ticks", 0)) < 1 or int(active_hazard_work.get("remaining_ticks", 0)) > maximum_remaining: errors.append("invalid active environmental hazard work")
		if active_hazard_work.get("closure_scope", "") != active_work_policy.get("closure_scope", "technical_hazard_clearance"): errors.append("active hazard work scope exceeds graph policy")
		var expected_active_samples: int = 0 if active_hazard_work.get("phase", "") == "remediation" else int(active_work_policy.get("verification_duration_ticks", 0)) - int(active_hazard_work.get("remaining_ticks", 0))
		if not _verification_samples_valid(active_hazard_work.get("verification_samples", []), expected_active_samples, active_work_policy, _hazard_verifier_ids(active_hazard_work)): errors.append("active hazard work verification samples are invalid")
		if active_hazard_work.get("suspended", false) and active_hazard_work.get("suspension_reason", "") not in ["restart_reconciliation", "shift_handoff_reconciliation"]: errors.append("suspended hazard work lacks restart reconciliation reason")
		if not active_hazard_work.get("suspended", false) and not String(active_hazard_work.get("suspension_reason", "")).is_empty(): errors.append("active hazard work retains stale suspension reason")
		var hazard_handoffs: Array = active_hazard_work.get("handoffs", [])
		if hazard_handoffs.size() not in [0, 2]: errors.append("active hazard work has incomplete shift handoff set")
		var handed_participants: Dictionary = {}; var handoff_turnover_id: String = ""; var handed_phase: String = ""; var handed_ticks := -1
		for handoff in hazard_handoffs:
			var participant: String = handoff.get("participant", "")
			var expected_job: String = active_hazard_work.get("actor_job", "") if participant == "technical" else active_hazard_work.get("verification_job", "")
			var expected_incoming: String = active_hazard_work.get("actor_person_id", "") if participant == "technical" else active_hazard_work.get("verification_person_id", "")
			if participant not in ["technical", "verification"] or handed_participants.has(participant) or String(handoff.get("turnover_id", "")).is_empty() or (not handoff_turnover_id.is_empty() and handoff.get("turnover_id", "") != handoff_turnover_id) or handoff.get("job_id", "") != expected_job or handoff.get("incoming_person_id", "") != expected_incoming or String(handoff.get("outgoing_person_id", "")).is_empty() or handoff.get("outgoing_person_id", "") == handoff.get("incoming_person_id", "") or handoff.get("phase", "") not in ["remediation", "verification"] or int(handoff.get("remaining_ticks", 0)) < 1 or (not handed_phase.is_empty() and handoff.get("phase", "") != handed_phase) or (handed_ticks >= 0 and int(handoff.get("remaining_ticks", -1)) != handed_ticks): errors.append("invalid environmental hazard shift handoff")
			handed_participants[participant] = true; handoff_turnover_id = handoff.get("turnover_id", ""); handed_phase = handoff.get("phase", ""); handed_ticks = int(handoff.get("remaining_ticks", -1))
		if hazard_handoffs.size() == 2 and handed_participants.size() != 2: errors.append("active hazard work shift handoffs lack both participants")
	for finding in state.get("hazard_findings", []):
		if finding.get("status", "") == "verification_pending" and (active_hazard_work.is_empty() or active_hazard_work.get("finding_id", "") != finding.get("finding_id", "") or active_hazard_work.get("phase", "") != "verification"): errors.append("hazard verification status lacks active work")
	var closed_findings: Dictionary = {}
	for closure in state.get("hazard_closures", []):
		var closure_finding: Dictionary = {}
		for finding in state.get("hazard_findings", []):
			if finding.get("finding_id", "") == closure.get("finding_id", ""): closure_finding = finding; break
		var closure_rule: Dictionary = {}
		for rule in obligation.get("hazard_rules", []):
			if rule.get("classification", "") == closure_finding.get("classification", ""): closure_rule = rule; break
		var remediation_policy: Dictionary = closure_rule.get("remediation", {})
		if closure_finding.is_empty() or closure_finding.get("status", "") != "closed" or closure_finding.get("closure_id", "") != closure.get("closure_id", "") or closure.get("closure_id", "") != closure.get("finding_id", "") + ":closure" or closure.get("occurrence_id", "") != state.get("occurrence_id", "") or closed_findings.has(closure.get("finding_id", "")) or String(closure.get("remediation_actor_person_id", "")).is_empty() or closure.get("remediation_actor_person_id", "") == closure.get("verification_actor_person_id", "") or closure.get("remediation_actor_job", "") != remediation_policy.get("actor_job", "") or closure.get("remediation_station", "") != remediation_policy.get("station", "") or closure.get("verification_actor_job", "") != remediation_policy.get("verification_job", "") or closure.get("verification_station", "") != remediation_policy.get("verification_station", "") or closure.get("clear_readings", []) != remediation_policy.get("clear_readings", []): errors.append("invalid environmental hazard closure")
		if closure.get("closure_scope", "") != remediation_policy.get("closure_scope", "technical_hazard_clearance"): errors.append("hazard closure scope exceeds graph policy")
		if not _verification_samples_valid(closure.get("verification_samples", []), int(remediation_policy.get("verification_duration_ticks", 0)), remediation_policy, _hazard_verifier_ids(closure)): errors.append("hazard closure lacks exact immutable verification samples")
		var closure_handoffs: Array = closure.get("handoffs", [])
		if closure_handoffs.size() not in [0, 2]: errors.append("hazard closure has incomplete handoff provenance")
		var closure_participants: Dictionary = {}; var closure_turnover_id: String = ""
		for closure_handoff in closure_handoffs:
			var closure_participant: String = closure_handoff.get("participant", "")
			var closure_job: String = closure.get("remediation_actor_job", "") if closure_participant == "technical" else closure.get("verification_actor_job", "")
			var closure_incoming: String = closure.get("remediation_actor_person_id", "") if closure_participant == "technical" else closure.get("verification_actor_person_id", "")
			if closure_participant not in ["technical", "verification"] or closure_participants.has(closure_participant) or String(closure_handoff.get("turnover_id", "")).is_empty() or (not closure_turnover_id.is_empty() and closure_handoff.get("turnover_id", "") != closure_turnover_id) or closure_handoff.get("job_id", "") != closure_job or closure_handoff.get("incoming_person_id", "") != closure_incoming or String(closure_handoff.get("outgoing_person_id", "")).is_empty() or closure_handoff.get("outgoing_person_id", "") == closure_incoming: errors.append("invalid environmental hazard closure handoff")
			closure_participants[closure_participant] = true; closure_turnover_id = closure_handoff.get("turnover_id", "")
		if closure_handoffs.size() == 2 and closure_participants.size() != 2: errors.append("hazard closure handoff lacks both participants")
		closed_findings[closure.get("finding_id", "")] = true
	for finding in state.get("hazard_findings", []):
		if (finding.get("status", "") == "closed") != closed_findings.has(finding.get("finding_id", "")): errors.append("closed hazard lacks exact closure evidence")
	for decision_event in state.get("decisions", []):
		var decision_round: int = int(decision_event.get("round_number", 0))
		var matching_escalation: Dictionary = {}
		for escalation_event in state.get("escalations", []):
			if int(escalation_event.get("round_number", 0)) == decision_round: matching_escalation = escalation_event; break
		if decision_round < 1 or decided_rounds.has(decision_round) or matching_escalation.is_empty() or not matching_escalation.get("consumed", false) or decision_event.get("occurrence_id", "") != state.get("occurrence_id", "") or decision_event.get("decision", "") not in obligation.get("escalation", {}).get("decisions", []) or String(decision_event.get("actor_person_id", "")).is_empty() or decision_event.get("actor_job", "") != obligation["escalation"]["actor_job"] or decision_event.get("station", "") != obligation["escalation"]["station"] or String(decision_event.get("rationale", "")).strip_edges().is_empty():
			errors.append("invalid environmental escalation decision")
		decided_rounds[decision_round] = true
		if decision_event.get("decision", "") == "archive_safe_hold": expected_postures["archive_stack"] = "safe_hold"
		elif decision_event.get("decision", "") == "compute_safe_shutdown": expected_postures["compute_core"] = "safe_shutdown"
		elif decision_event.get("decision", "") == "evacuate_affected_rooms":
			for assignment in obligation.get("room_assignments", []): expected_postures[assignment["room"]] = "evacuate"
	var active_release: Dictionary = state.get("active_release", {})
	if not active_release.is_empty():
		var active_release_policy: Dictionary = obligation.get("escalation", {}).get("release", {})
		if not state.get("protective_postures", {}).has(active_release.get("room", "")) or int(active_release.get("remaining_ticks", 0)) < 1 or int(active_release.get("remaining_ticks", 0)) > int(active_release_policy.get("duration_ticks", 0)) or int(active_release.get("duration_ticks", 0)) != int(active_release_policy.get("duration_ticks", 0)) or String(active_release.get("authority_person_id", "")).is_empty() or String(active_release.get("concurrence_person_id", "")).is_empty() or active_release.get("authority_person_id", "") == active_release.get("concurrence_person_id", "") or active_release.get("authority_station", "") != active_release_policy.get("authority_station", "") or active_release.get("concurrence_station", "") != active_release_policy.get("concurrence_station", ""):
			errors.append("invalid active environmental posture release work")
		var active_handoffs: Array = active_release.get("handoffs", [])
		if active_handoffs.size() not in [0, 2]: errors.append("active environmental release has incomplete handoff set")
		var handed_participants: Dictionary = {}
		var handoff_turnover_id: String = ""
		for handoff in active_handoffs:
			var handed_participant: String = handoff.get("participant", "")
			var candidate_turnover_id: String = handoff.get("turnover_id", "")
			if handoff_turnover_id.is_empty(): handoff_turnover_id = candidate_turnover_id
			if handed_participant not in ["authority", "concurrence"] or candidate_turnover_id.is_empty() or candidate_turnover_id != handoff_turnover_id or handed_participants.has(handed_participant) or handoff.get("job_id", "") != active_release_policy.get(handed_participant + "_job", "") or handoff.get("incoming_person_id", "") != active_release.get(handed_participant + "_person_id", "") or handoff.get("outgoing_person_id", "") == handoff.get("incoming_person_id", "") or int(handoff.get("remaining_ticks", -1)) != int(active_release.get("remaining_ticks", -2)):
				errors.append("invalid environmental release handoff")
			handed_participants[handed_participant] = true
	var released_rooms: Dictionary = {}
	for release_event in state.get("releases", []):
		var released_room: String = release_event.get("room", "")
		var release_source: Dictionary = {}
		for decision_event in state.get("decisions", []):
			if int(decision_event.get("round_number", 0)) == int(release_event.get("source_round_number", -1)): release_source = decision_event; break
		var release_evidence: Dictionary = {}
		for completed in state.get("completed_rounds", []):
			if int(completed.get("round_number", 0)) == int(release_event.get("evidence_round_number", -1)): release_evidence = completed; break
		if released_room.is_empty() or released_rooms.has(released_room) or release_event.get("occurrence_id", "") != state.get("occurrence_id", "") or String(release_event.get("authority_person_id", "")).is_empty() or String(release_event.get("concurrence_person_id", "")).is_empty() or release_event.get("authority_person_id", "") == release_event.get("concurrence_person_id", "") or String(release_event.get("rationale", "")).strip_edges().is_empty() or release_source.is_empty() or release_evidence.is_empty() or int(release_evidence.get("completed_clock", 0)) <= int(release_source.get("clock", 0)):
			errors.append("invalid or duplicate environmental posture release")
		released_rooms[released_room] = true; expected_postures.erase(released_room)
	var displaced_command_findings: Dictionary={}
	for command in state.get("displaced_commands",[]):
		var command_finding: Dictionary={}; var command_evacuation: Dictionary={}
		for finding in state.get("hazard_findings",[]):
			if finding.get("finding_id","")==command.get("finding_id",""): command_finding=finding; break
		for evacuation in state.get("room_evacuations",[]):
			if evacuation.get("evacuation_id","")==command.get("evacuation_id",""): command_evacuation=evacuation; break
		var command_policy: Dictionary=_hazard_rule_for(state,command_finding.get("classification","")).get("evacuation",{}).get("displaced_command",{})
		var command_actor_evacuated: bool=false
		for roster_entry in command_evacuation.get("roster",[]):
			if roster_entry.get("person_id","")==command.get("actor_person_id",""): command_actor_evacuated=true
		if command_finding.is_empty() or command_evacuation.get("finding_id","")!=command.get("finding_id","") or displaced_command_findings.has(command.get("finding_id","")) or command.get("command_id","")!=command.get("finding_id","")+":displaced_command" or command.get("action","")!=command_policy.get("action","") or command.get("actor_job","")!=command_policy.get("actor_job","") or command.get("station","")!=command_policy.get("station","") or String(command.get("actor_person_id","")).is_empty() or String(command.get("rationale","")).strip_edges().is_empty() or command_actor_evacuated: errors.append("invalid displaced environmental command")
		displaced_command_findings[command.get("finding_id","")]=true
	var remediation_authorization_findings: Dictionary={}
	for authorization in state.get("remediation_authorizations",[]):
		var authorization_finding: Dictionary={}; var authorization_command: Dictionary={}
		for finding in state.get("hazard_findings",[]):
			if finding.get("finding_id","")==authorization.get("finding_id",""): authorization_finding=finding; break
		for command in state.get("displaced_commands",[]):
			if command.get("command_id","")==authorization.get("command_id",""): authorization_command=command; break
		var authorization_policy: Dictionary=_hazard_rule_for(state,authorization_finding.get("classification","")).get("remediation",{}).get("authorization",{})
		if authorization_finding.is_empty() or authorization_command.get("finding_id","")!=authorization.get("finding_id","") or remediation_authorization_findings.has(authorization.get("finding_id","")) or authorization.get("authorization_id","")!=authorization.get("finding_id","")+":remediation_authorization" or authorization.get("action","")!=authorization_policy.get("action","") or authorization.get("actor_person_id","")!=authorization_command.get("actor_person_id","") or authorization.get("actor_job","")!=authorization_policy.get("actor_job","") or authorization.get("station","")!=authorization_policy.get("station","") or String(authorization.get("rationale","")).strip_edges().is_empty(): errors.append("invalid hazard remediation authorization")
		remediation_authorization_findings[authorization.get("finding_id","")]=true
	var active_fire_inspection: Dictionary=state.get("active_fire_inspection",{})
	if not active_fire_inspection.is_empty():
		var active_inspection_finding: Dictionary={}; var active_inspection_closure: Dictionary={}; var active_inspection_evacuation: Dictionary={}
		for finding in state.get("hazard_findings",[]):
			if finding.get("finding_id","")==active_fire_inspection.get("finding_id",""): active_inspection_finding=finding; break
		for closure in state.get("hazard_closures",[]):
			if closure.get("closure_id","")==active_fire_inspection.get("closure_id",""): active_inspection_closure=closure; break
		for evacuation in state.get("room_evacuations",[]):
			if evacuation.get("evacuation_id","")==active_fire_inspection.get("evacuation_id",""): active_inspection_evacuation=evacuation; break
		var active_inspection_policy: Dictionary=_hazard_rule_for(state,active_inspection_finding.get("classification","")).get("remediation",{}).get("inspection",{})
		var active_samples_valid: bool=active_fire_inspection.get("samples",[]).size()==int(active_inspection_policy.get("duration_ticks",0))-int(active_fire_inspection.get("remaining_ticks",0))
		for sample_index in active_fire_inspection.get("samples",[]).size():
			var sample: Dictionary=active_fire_inspection["samples"][sample_index]
			if int(sample.get("sequence",0))!=sample_index+1 or sample.get("responder_id","")!=active_fire_inspection.get("responder_id","") or sample.get("escort_actor","")!=active_fire_inspection.get("escort_actor","") or sample.get("room","")!=active_fire_inspection.get("destination",""): active_samples_valid=false
			for evidence_name in active_inspection_policy.get("required_evidence",[]):
				if sample.get("evidence",{}).get(evidence_name,null)!=true: active_samples_valid=false
		var active_displaced_authority_valid: bool=not active_inspection_policy.get("required_displaced_command",false)
		for command in state.get("displaced_commands",[]):
			if command.get("finding_id","")==active_fire_inspection.get("finding_id","") and command.get("actor_person_id","")==active_fire_inspection.get("authority_person_id",""): active_displaced_authority_valid=true; break
		if active_inspection_finding.is_empty() or active_inspection_closure.get("finding_id","")!=active_fire_inspection.get("finding_id","") or active_inspection_evacuation.get("finding_id","")!=active_fire_inspection.get("finding_id","") or active_fire_inspection.get("inspection_id","")!=active_fire_inspection.get("finding_id","")+":inspection" or active_fire_inspection.get("destination","")!=active_inspection_finding.get("room","") or active_fire_inspection.get("response_job","")!=active_inspection_policy.get("response_job","") or active_fire_inspection.get("clearance_scope","")!=active_inspection_policy.get("clearance_scope","") or int(active_fire_inspection.get("remaining_ticks",0))<1 or int(active_fire_inspection.get("remaining_ticks",0))>int(active_inspection_policy.get("duration_ticks",0)) or not active_samples_valid or not active_displaced_authority_valid: errors.append("invalid active fire inspection")
		if active_fire_inspection.get("suspended",false) and active_fire_inspection.get("suspension_reason","")!="restart_reconciliation": errors.append("suspended fire inspection lacks restart reconciliation reason")
		if not active_fire_inspection.get("suspended",false) and not String(active_fire_inspection.get("suspension_reason","")).is_empty(): errors.append("active fire inspection retains stale suspension reason")
	var inspected_findings: Dictionary={}
	for inspection in state.get("fire_inspections",[]):
		var inspection_finding: Dictionary={}; var inspection_closure: Dictionary={}; var inspection_evacuation: Dictionary={}
		for finding in state.get("hazard_findings",[]):
			if finding.get("finding_id","")==inspection.get("finding_id",""): inspection_finding=finding; break
		for closure in state.get("hazard_closures",[]):
			if closure.get("closure_id","")==inspection.get("closure_id",""): inspection_closure=closure; break
		for evacuation in state.get("room_evacuations",[]):
			if evacuation.get("evacuation_id","")==inspection.get("evacuation_id",""): inspection_evacuation=evacuation; break
		var inspection_rule: Dictionary=_hazard_rule_for(state,inspection_finding.get("classification","")); var inspection_policy: Dictionary=inspection_rule.get("remediation",{}).get("inspection",{})
		var valid_samples: bool=inspection.get("samples",[]).size()==int(inspection_policy.get("duration_ticks",0))
		for sample_index in inspection.get("samples",[]).size():
			var sample: Dictionary=inspection["samples"][sample_index]
			if int(sample.get("sequence",0))!=sample_index+1 or sample.get("responder_id","")!=inspection.get("responder_id","") or sample.get("escort_actor","")!=inspection.get("escort_actor","") or sample.get("room","")!=inspection.get("destination",""): valid_samples=false
			for evidence_name in inspection_policy.get("required_evidence",[]):
				if sample.get("evidence",{}).get(evidence_name,null)!=true: valid_samples=false
		var inspection_displaced_authority_valid: bool=not inspection_policy.get("required_displaced_command",false)
		for command in state.get("displaced_commands",[]):
			if command.get("finding_id","")==inspection.get("finding_id","") and command.get("actor_person_id","")==inspection.get("authority_person_id",""): inspection_displaced_authority_valid=true; break
		if inspection_finding.is_empty() or inspection_finding.get("status","")!="closed" or inspection_closure.get("finding_id","")!=inspection.get("finding_id","") or inspection_closure.get("closure_scope","")!="local_alarm_controls_only" or inspection_evacuation.get("finding_id","")!=inspection.get("finding_id","") or inspected_findings.has(inspection.get("finding_id","")) or inspection.get("inspection_id","")!=inspection.get("finding_id","")+":inspection" or inspection.get("response_job","")!=inspection_policy.get("response_job","") or inspection.get("destination","")!=inspection_policy.get("destination","") or inspection.get("authority_job","")!=inspection_policy.get("authority_job","") or inspection.get("authority_station","")!=inspection_policy.get("authority_station","") or inspection.get("required_evidence",[])!=inspection_policy.get("required_evidence",[]) or inspection.get("clearance_scope","")!=inspection_policy.get("clearance_scope","") or String(inspection.get("credential_id","")).is_empty() or String(inspection.get("responder_id","")).is_empty() or String(inspection.get("escort_actor","")).is_empty() or String(inspection.get("rationale","")).is_empty() or not valid_samples or not inspection_displaced_authority_valid: errors.append("invalid fire scene inspection evidence")
		inspected_findings[inspection.get("finding_id","")]=true
	var evacuated_findings: Dictionary = {}
	for evacuation in state.get("room_evacuations", []):
		var evacuation_finding: Dictionary = {}; var evacuation_policy: Dictionary = {}; var roster_people: Dictionary = {}
		for finding in state.get("hazard_findings", []):
			if finding.get("finding_id", "") == evacuation.get("finding_id", ""): evacuation_finding = finding; break
		for rule in obligation.get("hazard_rules", []):
			if rule.get("classification", "") == evacuation_finding.get("classification", ""): evacuation_policy = rule.get("evacuation", {}); break
		for entry in evacuation.get("roster", []):
			if String(entry.get("person_id", "")).is_empty() or String(entry.get("job", "")).is_empty() or entry.get("source_room", "") != evacuation.get("source_room", "") or roster_people.has(entry.get("person_id", "")): errors.append("invalid room evacuation roster")
			roster_people[entry.get("person_id", "")] = true
		if evacuation_finding.is_empty() or evacuation_finding.get("status", "") not in ["commanded", "verification_pending", "closed"] or evacuated_findings.has(evacuation.get("finding_id", "")) or evacuation.get("evacuation_id", "") != evacuation.get("finding_id", "") + ":evacuation" or evacuation.get("source_room", "") != evacuation_finding.get("room", "") or evacuation.get("destination", "") != evacuation_policy.get("destination", "") or evacuation.get("accountability_job", "") != evacuation_policy.get("accountability_job", "") or evacuation.get("accountability_station", "") != evacuation_policy.get("accountability_station", "") or String(evacuation.get("accountability_person_id", "")).is_empty() or evacuation.get("roster", []).is_empty(): errors.append("invalid room evacuation accountability record")
		evacuated_findings[evacuation.get("finding_id", "")] = true
	var active_room_reentry: Dictionary=state.get("active_room_reentry",{})
	if not active_room_reentry.is_empty():
		var active_reentry_finding: Dictionary={}; var active_reentry_inspection: Dictionary={}
		for finding in state.get("hazard_findings",[]):
			if finding.get("finding_id","")==active_room_reentry.get("finding_id",""): active_reentry_finding=finding; break
		for inspection in state.get("fire_inspections",[]):
			if inspection.get("inspection_id","")==active_room_reentry.get("inspection_id",""): active_reentry_inspection=inspection; break
		var active_reentry_policy: Dictionary=_hazard_rule_for(state,active_reentry_finding.get("classification","")).get("remediation",{}).get("inspection",{}).get("reentry",{})
		var active_reentry_displaced_authority_valid: bool=not active_reentry_policy.get("required_displaced_command",false)
		for command in state.get("displaced_commands",[]):
			if command.get("finding_id","")==active_room_reentry.get("finding_id","") and command.get("actor_person_id","")==active_room_reentry.get("authority_person_id",""): active_reentry_displaced_authority_valid=true; break
		if active_reentry_finding.is_empty() or active_reentry_inspection.get("finding_id","")!=active_room_reentry.get("finding_id","") or active_room_reentry.get("reentry_id","")!=active_room_reentry.get("finding_id","")+":reentry" or active_room_reentry.get("room","")!=active_reentry_finding.get("room","") or active_room_reentry.get("authority_job","")!=active_reentry_policy.get("authority_job","") or active_room_reentry.get("authority_station","")!=active_reentry_policy.get("authority_station","") or active_room_reentry.get("concurrence_job","")!=active_reentry_policy.get("concurrence_job","") or active_room_reentry.get("concurrence_station","")!=active_reentry_policy.get("concurrence_station","") or active_room_reentry.get("authority_person_id","")==active_room_reentry.get("concurrence_person_id","") or String(active_room_reentry.get("authority_person_id","")).is_empty() or int(active_room_reentry.get("remaining_ticks",0))<1 or int(active_room_reentry.get("remaining_ticks",0))>int(active_reentry_policy.get("duration_ticks",0)) or String(active_room_reentry.get("rationale","")).is_empty() or not active_reentry_displaced_authority_valid: errors.append("invalid active room re-entry authorization")
		if active_room_reentry.get("post_reentry_posture","")!=active_reentry_policy.get("post_reentry_posture",""): errors.append("active room re-entry post-entry posture diverges from policy")
		if not _reentry_handoffs_valid(active_room_reentry) or (active_room_reentry.get("suspension_reason","")=="shift_handoff_reconciliation" and active_room_reentry.get("handoffs",[]).size()!=2): errors.append("active room re-entry handoff provenance is invalid")
		if active_room_reentry.get("suspended",false) and active_room_reentry.get("suspension_reason","") not in ["restart_reconciliation","shift_handoff_reconciliation"]: errors.append("suspended room re-entry lacks restart reconciliation reason")
		if not active_room_reentry.get("suspended",false) and not String(active_room_reentry.get("suspension_reason","")).is_empty(): errors.append("active room re-entry retains stale suspension reason")
	var reentered_findings: Dictionary={}
	for reentry in state.get("room_reentries",[]):
		var reentry_finding: Dictionary={}; var reentry_inspection: Dictionary={}
		for finding in state.get("hazard_findings",[]):
			if finding.get("finding_id","")==reentry.get("finding_id",""): reentry_finding=finding; break
		for inspection in state.get("fire_inspections",[]):
			if inspection.get("inspection_id","")==reentry.get("inspection_id",""): reentry_inspection=inspection; break
		var reentry_policy: Dictionary=_hazard_rule_for(state,reentry_finding.get("classification","")).get("remediation",{}).get("inspection",{}).get("reentry",{})
		var reentry_displaced_authority_valid: bool=not reentry_policy.get("required_displaced_command",false)
		for command in state.get("displaced_commands",[]):
			if command.get("finding_id","")==reentry.get("finding_id","") and command.get("actor_person_id","")==reentry.get("authority_person_id",""): reentry_displaced_authority_valid=true; break
		if reentry_finding.is_empty() or reentry_inspection.get("finding_id","")!=reentry.get("finding_id","") or reentered_findings.has(reentry.get("finding_id","")) or reentry.get("reentry_id","")!=reentry.get("finding_id","")+":reentry" or reentry.get("room","")!=reentry_finding.get("room","") or reentry.get("authority_job","")!=reentry_policy.get("authority_job","") or reentry.get("authority_station","")!=reentry_policy.get("authority_station","") or reentry.get("concurrence_job","")!=reentry_policy.get("concurrence_job","") or reentry.get("concurrence_station","")!=reentry_policy.get("concurrence_station","") or reentry.get("authority_person_id","")==reentry.get("concurrence_person_id","") or String(reentry.get("authority_person_id","")).is_empty() or int(reentry.get("duration_ticks",0))!=int(reentry_policy.get("duration_ticks",-1)) or String(reentry.get("rationale","")).is_empty() or not reentry_displaced_authority_valid: errors.append("invalid room re-entry authorization")
		if reentry.get("post_reentry_posture","")!=reentry_policy.get("post_reentry_posture",""): errors.append("terminal room re-entry post-entry posture diverges from policy")
		if not _reentry_handoffs_valid(reentry): errors.append("terminal room re-entry handoff provenance is invalid")
		reentered_findings[reentry.get("finding_id","")]=true
		if String(reentry.get("post_reentry_posture","")).is_empty(): expected_postures.erase(reentry.get("room",""))
		else: expected_postures[reentry.get("room","")]=reentry["post_reentry_posture"]
	var active_command_restoration: Dictionary=state.get("active_command_restoration",{})
	if not active_command_restoration.is_empty():
		var restoration_finding: Dictionary={}; var restoration_reentry: Dictionary={}; var restoration_command: Dictionary={}
		for finding in state.get("hazard_findings",[]):
			if finding.get("finding_id","")==active_command_restoration.get("finding_id",""): restoration_finding=finding; break
		for reentry in state.get("room_reentries",[]):
			if reentry.get("reentry_id","")==active_command_restoration.get("reentry_id",""): restoration_reentry=reentry; break
		for command in state.get("displaced_commands",[]):
			if command.get("command_id","")==active_command_restoration.get("displaced_command_id",""): restoration_command=command; break
		var restoration_policy: Dictionary=_hazard_rule_for(state,restoration_finding.get("classification","")).get("remediation",{}).get("inspection",{}).get("reentry",{}).get("command_restoration",{})
		if restoration_finding.is_empty() or restoration_reentry.get("finding_id","")!=active_command_restoration.get("finding_id","") or restoration_command.get("finding_id","")!=active_command_restoration.get("finding_id","") or active_command_restoration.get("restoration_id","")!=active_command_restoration.get("finding_id","")+":command-restoration" or active_command_restoration.get("displaced_actor_person_id","")!=restoration_command.get("actor_person_id","") or active_command_restoration.get("action","")!=restoration_policy.get("action","") or active_command_restoration.get("displaced_job","")!=restoration_policy.get("displaced_job","") or active_command_restoration.get("displaced_station","")!=restoration_policy.get("displaced_station","") or active_command_restoration.get("primary_job","")!=restoration_policy.get("primary_job","") or active_command_restoration.get("primary_station","")!=restoration_policy.get("primary_station","") or active_command_restoration.get("primary_actor_person_id","")==active_command_restoration.get("displaced_actor_person_id","") or int(active_command_restoration.get("remaining_ticks",0))<1 or int(active_command_restoration.get("remaining_ticks",0))>int(restoration_policy.get("duration_ticks",0)) or (active_command_restoration.get("suspended",false) and active_command_restoration.get("suspension_reason","")!="restart_reconciliation") or (not active_command_restoration.get("suspended",false) and not String(active_command_restoration.get("suspension_reason","")).is_empty()): errors.append("invalid active primary command restoration")
	var restored_command_findings: Dictionary={}
	for restoration in state.get("command_restorations",[]):
		var restoration_finding: Dictionary={}; var restoration_reentry: Dictionary={}; var restoration_command: Dictionary={}
		for finding in state.get("hazard_findings",[]):
			if finding.get("finding_id","")==restoration.get("finding_id",""): restoration_finding=finding; break
		for reentry in state.get("room_reentries",[]):
			if reentry.get("reentry_id","")==restoration.get("reentry_id",""): restoration_reentry=reentry; break
		for command in state.get("displaced_commands",[]):
			if command.get("command_id","")==restoration.get("displaced_command_id",""): restoration_command=command; break
		var restoration_policy: Dictionary=_hazard_rule_for(state,restoration_finding.get("classification","")).get("remediation",{}).get("inspection",{}).get("reentry",{}).get("command_restoration",{})
		if restoration_finding.is_empty() or restoration_reentry.get("finding_id","")!=restoration.get("finding_id","") or restoration_command.get("finding_id","")!=restoration.get("finding_id","") or restored_command_findings.has(restoration.get("finding_id","")) or restoration.get("restoration_id","")!=restoration.get("finding_id","")+":command-restoration" or restoration.get("displaced_actor_person_id","")!=restoration_command.get("actor_person_id","") or restoration.get("action","")!=restoration_policy.get("action","") or restoration.get("displaced_station","")!=restoration_policy.get("displaced_station","") or restoration.get("primary_station","")!=restoration_policy.get("primary_station","") or restoration.get("primary_actor_person_id","")==restoration.get("displaced_actor_person_id","") or int(restoration.get("duration_ticks",0))!=int(restoration_policy.get("duration_ticks",-1)) or String(restoration.get("rationale","")).is_empty(): errors.append("invalid primary command restoration")
		restored_command_findings[restoration.get("finding_id","")]=true
	var active_room_evacuation: Dictionary = state.get("active_room_evacuation", {})
	if not active_room_evacuation.is_empty() and (active_room_evacuation.get("evacuation_id", "") != active_room_evacuation.get("finding_id", "") + ":evacuation" or active_room_evacuation.get("roster", []).is_empty()): errors.append("invalid active room evacuation")
	var compute_reactivation_findings: Dictionary = {}
	for reactivation in state.get("compute_reactivations", []):
		var reactivation_finding: Dictionary = {}
		for finding in state.get("hazard_findings", []):
			if finding.get("finding_id", "") == reactivation.get("finding_id", ""): reactivation_finding = finding; break
		var reactivation_policy: Dictionary = {}
		for rule in obligation.get("hazard_rules", []):
			if rule.get("classification", "") == reactivation_finding.get("classification", ""): reactivation_policy = rule.get("remediation", {}).get("reactivation", {}); break
		if reactivation_finding.is_empty() or reactivation_finding.get("status", "") != "closed" or reactivation_finding.get("closure_id", "") != reactivation.get("closure_id", "") or compute_reactivation_findings.has(reactivation.get("finding_id", "")) or reactivation.get("reactivation_id", "") != reactivation.get("finding_id", "") + ":reactivation" or reactivation.get("room", "") != "compute_core" or reactivation.get("prior_posture", "") != "safe_shutdown" or String(reactivation.get("authority_person_id", "")).is_empty() or String(reactivation.get("concurrence_person_id", "")).is_empty() or reactivation.get("authority_person_id", "") == reactivation.get("concurrence_person_id", "") or reactivation.get("authority_job", "") != reactivation_policy.get("authority_job", "") or reactivation.get("authority_station", "") != reactivation_policy.get("authority_station", "") or reactivation.get("concurrence_job", "") != reactivation_policy.get("concurrence_job", "") or reactivation.get("concurrence_station", "") != reactivation_policy.get("concurrence_station", "") or int(reactivation.get("duration_ticks", 0)) != int(reactivation_policy.get("duration_ticks", -1)) or String(reactivation.get("rationale", "")).strip_edges().is_empty(): errors.append("invalid compute hazard reactivation")
		compute_reactivation_findings[reactivation.get("finding_id", "")] = true; expected_postures.erase("compute_core")
	var active_compute_reactivation: Dictionary = state.get("active_compute_reactivation", {})
	if not active_compute_reactivation.is_empty():
		var active_reactivation_policy: Dictionary = {}; var active_reactivation_classification: String=""
		for finding in state.get("hazard_findings",[]):
			if finding.get("finding_id","")==active_compute_reactivation.get("finding_id",""): active_reactivation_classification=finding.get("classification",""); break
		for rule in obligation.get("hazard_rules", []):
			if rule.get("classification", "") == active_reactivation_classification: active_reactivation_policy = rule.get("remediation", {}).get("reactivation", {}); break
		if active_compute_reactivation.get("reactivation_id", "") != active_compute_reactivation.get("finding_id", "") + ":reactivation" or active_compute_reactivation.get("prior_posture", "") != "safe_shutdown" or int(active_compute_reactivation.get("remaining_ticks", 0)) < 1 or int(active_compute_reactivation.get("remaining_ticks", 0)) > int(active_reactivation_policy.get("duration_ticks", 0)) or String(active_compute_reactivation.get("rationale", "")).strip_edges().is_empty(): errors.append("invalid active compute hazard reactivation")
		if active_compute_reactivation.get("suspended", false) and active_compute_reactivation.get("suspension_reason", "") != "restart_reconciliation": errors.append("suspended compute reactivation lacks restart reconciliation reason")
		if not active_compute_reactivation.get("suspended", false) and not String(active_compute_reactivation.get("suspension_reason", "")).is_empty(): errors.append("active compute reactivation retains stale suspension reason")
	if state.get("protective_postures", {}) != expected_postures: errors.append("environmental protective posture projection mismatch")
	for completed in state.get("completed_rounds", []):
		if completed.get("observation_ids", []).size() != obligation.get("room_assignments", []).size(): errors.append("completed round lacks room observations")
	return errors

func begin_room_evacuation(state: Dictionary, finding_id: String, roster: Array) -> Dictionary:
	if not state.get("active_room_evacuation", {}).is_empty(): return {"accepted": false, "reason": "room evacuation already active"}
	var finding: Dictionary = {}; var rule: Dictionary = {}
	for candidate in state.get("hazard_findings", []):
		if candidate.get("finding_id", "") == finding_id: finding = candidate; break
	if finding.is_empty() or finding.get("status", "") != "commanded" or finding.get("recommended_decision", "") != "evacuate_affected_rooms": return {"accepted": false, "reason": "commanded evacuation finding not found"}
	for candidate_rule in state.get("obligation", {}).get("hazard_rules", []):
		if candidate_rule.get("classification", "") == finding.get("classification", ""): rule = candidate_rule; break
	var policy: Dictionary = rule.get("evacuation", {})
	if policy.is_empty() or roster.is_empty(): return {"accepted": false, "reason": "evacuation policy or occupied-room roster unavailable"}
	var people: Dictionary = {}; var retained: Array = []
	for entry in roster:
		var person_id: String = entry.get("person_id", "")
		if person_id.is_empty() or String(entry.get("job", "")).is_empty() or entry.get("source_room", "") != finding.get("room", "") or people.has(person_id): return {"accepted": false, "reason": "invalid evacuation roster"}
		people[person_id] = true; retained.append(entry.duplicate(true))
	state["active_room_evacuation"] = {"evacuation_id":finding_id + ":evacuation","finding_id":finding_id,"source_room":finding["room"],"destination":policy["destination"],"accountability_job":policy["accountability_job"],"accountability_station":policy["accountability_station"],"roster":retained,"started_clock":state["clock"]}
	return {"accepted": true, "status": "evacuating", "evacuation_id": finding_id + ":evacuation"}


func complete_room_evacuation(state: Dictionary, actor_locations: Dictionary, accountability_actor: Dictionary) -> Dictionary:
	var active: Dictionary = state.get("active_room_evacuation", {})
	if active.is_empty(): return {"accepted": false, "reason": "room evacuation not active"}
	for entry in active["roster"]:
		if actor_locations.get(entry["person_id"], "") != active["destination"]: return {"accepted": true, "status": "evacuating"}
	if String(accountability_actor.get("person_id", "")).is_empty() or accountability_actor.get("job", "") != active["accountability_job"] or accountability_actor.get("current_room", "") != active["accountability_station"]: return {"accepted": false, "reason": "evacuation accountability officer unavailable"}
	var record: Dictionary = active.duplicate(true); record["accountability_person_id"] = accountability_actor["person_id"]; record["accounted_clock"] = state["clock"]
	state["room_evacuations"].append(record); state["active_room_evacuation"] = {}
	return {"accepted": true, "status": "accounted", "evacuation_id": record["evacuation_id"]}

func establish_displaced_command(state: Dictionary, finding_id: String, rationale: String, actor: Dictionary) -> Dictionary:
	if String(rationale).strip_edges().is_empty(): return {"accepted":false,"reason":"displaced command rationale required"}
	var finding: Dictionary={}; var evacuation: Dictionary={}
	for candidate in state.get("hazard_findings",[]):
		if candidate.get("finding_id","")==finding_id: finding=candidate; break
	for candidate in state.get("room_evacuations",[]):
		if candidate.get("finding_id","")==finding_id: evacuation=candidate; break
	var policy: Dictionary=_hazard_rule_for(state,finding.get("classification","")).get("evacuation",{}).get("displaced_command",{})
	if finding.is_empty() or finding.get("status","")!="commanded" or evacuation.is_empty() or policy.is_empty(): return {"accepted":false,"reason":"accounted evacuation with displaced-command policy not found"}
	for existing in state.get("displaced_commands",[]):
		if existing.get("finding_id","")==finding_id: return {"accepted":false,"reason":"displaced command already established"}
	var actor_id: String=actor.get("person_id","")
	if actor_id.is_empty() or actor.get("job","")!=policy.get("actor_job","") or actor.get("current_room","")!=policy.get("station",""): return {"accepted":false,"reason":"displaced command actor unavailable at alternate station"}
	for roster_entry in evacuation.get("roster",[]):
		if roster_entry.get("person_id","")==actor_id: return {"accepted":false,"reason":"evacuated occupant cannot establish alternate command"}
	var record: Dictionary={"command_id":finding_id+":displaced_command","finding_id":finding_id,"evacuation_id":evacuation["evacuation_id"],"action":policy["action"],"actor_person_id":actor_id,"actor_job":policy["actor_job"],"station":policy["station"],"rationale":rationale,"established_clock":state["clock"]}
	state["displaced_commands"].append(record)
	return {"accepted":true,"status":"established","command_id":record["command_id"]}


func request_compute_reactivation(state: Dictionary, finding_id: String, monitoring_normal: bool, rationale: String, authority: Dictionary, concurrence: Dictionary) -> Dictionary:
	if not monitoring_normal: return {"accepted": false, "reason": "environmental monitoring not normal"}
	if not state.get("active_compute_reactivation", {}).is_empty(): return {"accepted": false, "reason": "compute reactivation already active"}
	var finding: Dictionary = {}
	for candidate in state.get("hazard_findings", []):
		if candidate.get("finding_id", "") == finding_id: finding = candidate; break
	if not String(finding.get("classification","")).begins_with("compute_") or finding.get("status", "") != "closed" or state.get("protective_postures", {}).get("compute_core", "") != "safe_shutdown": return {"accepted": false, "reason": "closed compute shutdown finding not found"}
	var remediation: Dictionary = _hazard_rule_for(state, finding["classification"]).get("remediation", {})
	var policy: Dictionary = remediation.get("reactivation", {})
	if policy.get("required_reentry",false):
		var has_terminal_reentry:=false
		for reentry in state.get("room_reentries",[]):
			if reentry.get("finding_id","")==finding_id and reentry.get("room","")=="compute_core": has_terminal_reentry=true; break
		if not has_terminal_reentry: return {"accepted":false,"reason":"compute fire reactivation lacks terminal room re-entry"}
	if policy.is_empty() or rationale.strip_edges().is_empty(): return {"accepted": false, "reason": "compute reactivation policy or rationale missing"}
	if String(authority.get("person_id", "")).is_empty() or not (authority.get("roles", []) as Array).has(policy["authority_job"]) or authority.get("current_room", "") != policy["authority_station"]: return {"accepted": false, "reason": "compute reactivation lacks command authority"}
	if String(concurrence.get("person_id", "")).is_empty() or concurrence.get("person_id", "") == authority.get("person_id", "") or not (concurrence.get("roles", []) as Array).has(policy["concurrence_job"]) or concurrence.get("current_room", "") != policy["concurrence_station"]: return {"accepted": false, "reason": "compute reactivation lacks independent systems concurrence"}
	state["active_compute_reactivation"] = {"reactivation_id":finding_id + ":reactivation","finding_id":finding_id,"closure_id":finding["closure_id"],"room":"compute_core","prior_posture":"safe_shutdown","authority_person_id":authority["person_id"],"authority_job":policy["authority_job"],"authority_station":policy["authority_station"],"concurrence_person_id":concurrence["person_id"],"concurrence_job":policy["concurrence_job"],"concurrence_station":policy["concurrence_station"],"rationale":rationale,"remaining_ticks":policy["duration_ticks"],"duration_ticks":policy["duration_ticks"],"started_clock":state["clock"],"suspended":false,"suspension_reason":""}
	return {"accepted": true, "status": "reactivation_started", "remaining_ticks": policy["duration_ticks"]}


func resume_compute_reactivation(state: Dictionary, finding_id: String, actor_locations: Dictionary) -> Dictionary:
	var work: Dictionary = state.get("active_compute_reactivation", {})
	if work.is_empty() or work.get("finding_id", "") != finding_id: return {"accepted": false, "reason": "compute reactivation not active for finding"}
	if not work.get("suspended", false) or work.get("suspension_reason", "") != "restart_reconciliation": return {"accepted": false, "reason": "compute reactivation does not require restart reconciliation"}
	if actor_locations.get(work["authority_person_id"], "") != work["authority_station"] or actor_locations.get(work["concurrence_person_id"], "") != work["concurrence_station"]: return {"accepted": false, "reason": "compute reactivation participants not at reconciliation stations"}
	work["suspended"] = false; work["suspension_reason"] = ""; state["active_compute_reactivation"] = work
	return {"accepted": true, "status": "resumed", "remaining_ticks": work["remaining_ticks"]}


func tick_compute_reactivation(state: Dictionary, actor_locations: Dictionary) -> Dictionary:
	var work: Dictionary = state.get("active_compute_reactivation", {})
	if work.is_empty(): return {"accepted": false, "reason": "compute reactivation not active"}
	if work.get("suspended", false): return {"accepted": false, "reason": "compute reactivation requires explicit resume"}
	if actor_locations.get(work["authority_person_id"], "") != work["authority_station"] or actor_locations.get(work["concurrence_person_id"], "") != work["concurrence_station"]: return {"accepted": false, "reason": "compute reactivation participants left stations"}
	work["remaining_ticks"] = int(work["remaining_ticks"]) - 1
	if work["remaining_ticks"] > 0: state["active_compute_reactivation"] = work; return {"accepted": true, "status": "working", "remaining_ticks": work["remaining_ticks"]}
	var event: Dictionary = work.duplicate(true); event.erase("remaining_ticks"); event["committed_clock"] = state["clock"]
	state["compute_reactivations"].append(event); state["protective_postures"].erase("compute_core"); state["active_compute_reactivation"] = {}
	return {"accepted": true, "status": "committed", "reactivation_id": work["reactivation_id"]}


func begin_fire_inspection(state: Dictionary, finding_id: String, closure_id: String, capacity: Dictionary, authority_actor: Dictionary, rationale: String) -> Dictionary:
	if not state.get("active_fire_inspection", {}).is_empty() or rationale.strip_edges().is_empty(): return {"accepted":false,"reason":"fire inspection identity or rationale is invalid"}
	var finding: Dictionary = {}
	for candidate in state.get("hazard_findings", []):
		if candidate.get("finding_id", "") == finding_id: finding = candidate; break
	var rule: Dictionary = _hazard_rule_for(state, finding.get("classification", "")); var policy: Dictionary = rule.get("remediation", {}).get("inspection", {})
	var closure: Dictionary = {}; var evacuation: Dictionary = {}
	for candidate in state.get("hazard_closures", []):
		if candidate.get("closure_id", "") == closure_id and candidate.get("finding_id", "") == finding_id: closure = candidate; break
	for candidate in state.get("room_evacuations", []):
		if candidate.get("finding_id", "") == finding_id: evacuation = candidate; break
	if finding.is_empty() or finding.get("status", "") != "closed" or closure.is_empty() or closure.get("closure_scope", "") != "local_alarm_controls_only" or evacuation.is_empty() or state.get("protective_postures", {}).get(finding.get("room", ""), "") != "evacuate" or policy.is_empty(): return {"accepted":false,"reason":"fire inspection prerequisites are incomplete"}
	if not capacity.get("accepted", false) or capacity.get("occurrence_id", "") != finding_id or capacity.get("response_job", "") != policy.get("response_job", "") or capacity.get("destination", "") != policy.get("destination", "") or String(capacity.get("responder_id", "")).is_empty() or String(capacity.get("credential_id", "")).is_empty() or String(capacity.get("escort_actor", "")).is_empty(): return {"accepted":false,"reason":"fire inspection lacks exact admitted mutual-aid capacity"}
	if String(authority_actor.get("person_id", "")).is_empty() or not (authority_actor.get("roles", []) as Array).has(policy.get("authority_job", "")) or authority_actor.get("current_room", "") != policy.get("authority_station", ""): return {"accepted":false,"reason":"fire inspection lacks named command authority"}
	if policy.get("required_displaced_command",false):
		var displaced_authority_valid: bool=false
		for command in state.get("displaced_commands",[]):
			if command.get("finding_id","")==finding_id and command.get("actor_person_id","")==authority_actor.get("person_id",""): displaced_authority_valid=true; break
		if not displaced_authority_valid: return {"accepted":false,"reason":"fire inspection authority is not active displaced command"}
	state["active_fire_inspection"]={"inspection_id":finding_id+":inspection","finding_id":finding_id,"closure_id":closure_id,"evacuation_id":evacuation.get("evacuation_id",""),"case_id":capacity.get("case_id",""),"credential_id":capacity["credential_id"],"responder_id":capacity["responder_id"],"response_job":capacity["response_job"],"escort_actor":capacity["escort_actor"],"destination":policy["destination"],"authority_person_id":authority_actor["person_id"],"authority_job":policy["authority_job"],"authority_station":policy["authority_station"],"remaining_ticks":policy["duration_ticks"],"duration_ticks":policy["duration_ticks"],"required_evidence":policy["required_evidence"].duplicate(true),"clearance_scope":policy["clearance_scope"],"samples":[],"rationale":rationale,"started_clock":state["clock"]}
	return {"accepted":true,"status":"active","inspection_id":state["active_fire_inspection"]["inspection_id"]}

func resume_fire_inspection(state: Dictionary, finding_id: String, temporary_locations: Dictionary) -> Dictionary:
	var work: Dictionary=state.get("active_fire_inspection",{})
	if work.is_empty() or work.get("finding_id","")!=finding_id or not work.get("suspended",false) or work.get("suspension_reason","")!="restart_reconciliation": return {"accepted":false,"reason":"fire inspection is not suspended for restart reconciliation"}
	if temporary_locations.get(work["responder_id"],"")!=work["destination"] or temporary_locations.get(work["escort_actor"],"")!=work["destination"]: return {"accepted":false,"reason":"fire inspection responder and escort not reconciled at scene"}
	work["suspended"]=false; work["suspension_reason"]=""; state["active_fire_inspection"]=work
	return {"accepted":true,"remaining_ticks":work["remaining_ticks"]}

func tick_fire_inspection(state: Dictionary, temporary_locations: Dictionary, evidence: Dictionary) -> Dictionary:
	var work: Dictionary=state.get("active_fire_inspection", {})
	if work.is_empty(): return {"accepted":false,"reason":"no active fire inspection"}
	if work.get("suspended",false): return {"accepted":false,"reason":"fire inspection requires explicit resume"}
	if temporary_locations.get(work["responder_id"],"") != work["destination"] or temporary_locations.get(work["escort_actor"],"") != work["destination"]: return {"accepted":false,"reason":"fire inspector and escort are not at the scene"}
	for evidence_name in work["required_evidence"]:
		if evidence.get(evidence_name, null) != true: return {"accepted":false,"reason":"fire inspection lacks positive evidence:"+String(evidence_name)}
	work["samples"].append({"sequence":work["samples"].size()+1,"responder_id":work["responder_id"],"escort_actor":work["escort_actor"],"room":work["destination"],"evidence":evidence.duplicate(true),"clock":state["clock"]})
	work["remaining_ticks"] = int(work["remaining_ticks"]) - 1
	if work["remaining_ticks"] > 0: state["active_fire_inspection"]=work; return {"accepted":true,"status":"working","remaining_ticks":work["remaining_ticks"]}
	var record: Dictionary=work.duplicate(true); record.erase("remaining_ticks"); record["completed_clock"]=state["clock"]
	state["fire_inspections"].append(record); state["active_fire_inspection"]={}
	return {"accepted":true,"status":"inspected","inspection":record}


func request_room_reentry(state: Dictionary, finding_id: String, inspection_id: String, authority_actor: Dictionary, concurrence_actor: Dictionary, rationale: String) -> Dictionary:
	if not state.get("active_room_reentry",{}).is_empty() or rationale.strip_edges().is_empty(): return {"accepted":false,"reason":"room re-entry identity or rationale is invalid"}
	var finding: Dictionary={}; var inspection: Dictionary={}
	for candidate in state.get("hazard_findings",[]):
		if candidate.get("finding_id","")==finding_id: finding=candidate; break
	for candidate in state.get("fire_inspections",[]):
		if candidate.get("inspection_id","")==inspection_id and candidate.get("finding_id","")==finding_id: inspection=candidate; break
	var policy: Dictionary=_hazard_rule_for(state,finding.get("classification","")).get("remediation",{}).get("inspection",{}).get("reentry",{})
	if finding.is_empty() or inspection.is_empty() or policy.is_empty() or state.get("protective_postures",{}).get(finding.get("room",""),"")!="evacuate": return {"accepted":false,"reason":"room re-entry prerequisites are incomplete"}
	if String(authority_actor.get("person_id","")).is_empty() or String(concurrence_actor.get("person_id","")).is_empty() or authority_actor.get("person_id","")==concurrence_actor.get("person_id","") or not (authority_actor.get("roles",[]) as Array).has(policy.get("authority_job","")) or authority_actor.get("current_room","")!=policy.get("authority_station","") or not (concurrence_actor.get("roles",[]) as Array).has(policy.get("concurrence_job","")) or concurrence_actor.get("current_room","")!=policy.get("concurrence_station",""): return {"accepted":false,"reason":"room re-entry lacks separated authority and concurrence"}
	if policy.get("required_displaced_command",false):
		var displaced_reentry_authority_valid: bool=false
		for command in state.get("displaced_commands",[]):
			if command.get("finding_id","")==finding_id and command.get("actor_person_id","")==authority_actor.get("person_id",""): displaced_reentry_authority_valid=true; break
		if not displaced_reentry_authority_valid: return {"accepted":false,"reason":"room re-entry authority is not active displaced command"}
	state["active_room_reentry"]={"reentry_id":finding_id+":reentry","finding_id":finding_id,"inspection_id":inspection_id,"room":finding["room"],"case_id":inspection["case_id"],"authority_person_id":authority_actor["person_id"],"authority_job":policy["authority_job"],"authority_station":policy["authority_station"],"concurrence_person_id":concurrence_actor["person_id"],"concurrence_job":policy["concurrence_job"],"concurrence_station":policy["concurrence_station"],"remaining_ticks":policy["duration_ticks"],"duration_ticks":policy["duration_ticks"],"post_reentry_posture":policy.get("post_reentry_posture",""),"rationale":rationale,"started_clock":state["clock"],"handoffs":[]}
	return {"accepted":true,"status":"active","reentry_id":state["active_room_reentry"]["reentry_id"]}

func resume_room_reentry(state: Dictionary, finding_id: String, actor_locations: Dictionary) -> Dictionary:
	var work: Dictionary=state.get("active_room_reentry",{})
	if work.is_empty() or work.get("finding_id","")!=finding_id or not work.get("suspended",false) or work.get("suspension_reason","") not in ["restart_reconciliation","shift_handoff_reconciliation"]: return {"accepted":false,"reason":"room re-entry is not suspended for restart reconciliation"}
	if actor_locations.get(work["authority_person_id"],"")!=work["authority_station"] or actor_locations.get(work["concurrence_person_id"],"")!=work["concurrence_station"]: return {"accepted":false,"reason":"room re-entry participants not reconciled at stations"}
	work["suspended"]=false; work["suspension_reason"]=""; state["active_room_reentry"]=work
	return {"accepted":true,"remaining_ticks":work["remaining_ticks"]}

func tick_room_reentry(state: Dictionary, actor_locations: Dictionary) -> Dictionary:
	var work: Dictionary=state.get("active_room_reentry",{})
	if work.is_empty(): return {"accepted":false,"reason":"no active room re-entry"}
	if work.get("suspended",false): return {"accepted":false,"reason":"room re-entry requires explicit resume"}
	if actor_locations.get(work["authority_person_id"],"")!=work["authority_station"] or actor_locations.get(work["concurrence_person_id"],"")!=work["concurrence_station"]: return {"accepted":false,"reason":"room re-entry participants left their stations"}
	work["remaining_ticks"]=int(work["remaining_ticks"])-1
	if work["remaining_ticks"]>0: state["active_room_reentry"]=work; return {"accepted":true,"status":"working","remaining_ticks":work["remaining_ticks"]}
	var record: Dictionary=work.duplicate(true); record.erase("remaining_ticks"); record["completed_clock"]=state["clock"]
	state["room_reentries"].append(record); state["active_room_reentry"]={}
	if String(work.get("post_reentry_posture","")).is_empty(): state["protective_postures"].erase(work["room"])
	else: state["protective_postures"][work["room"]]=work["post_reentry_posture"]
	return {"accepted":true,"status":"committed","reentry":record}

func request_primary_command_restoration(state: Dictionary, finding_id: String, displaced_actor: Dictionary, primary_actor: Dictionary, rationale: String) -> Dictionary:
	if not state.get("active_command_restoration",{}).is_empty() or rationale.strip_edges().is_empty(): return {"accepted":false,"reason":"primary command restoration identity or rationale invalid"}
	var finding: Dictionary={}; var reentry: Dictionary={}; var displaced_command: Dictionary={}
	for candidate in state.get("hazard_findings",[]):
		if candidate.get("finding_id","")==finding_id: finding=candidate; break
	for candidate in state.get("room_reentries",[]):
		if candidate.get("finding_id","")==finding_id: reentry=candidate; break
	for candidate in state.get("displaced_commands",[]):
		if candidate.get("finding_id","")==finding_id: displaced_command=candidate; break
	for candidate in state.get("command_restorations",[]):
		if candidate.get("finding_id","")==finding_id: return {"accepted":false,"reason":"primary command already restored"}
	var policy: Dictionary=_hazard_rule_for(state,finding.get("classification","")).get("remediation",{}).get("inspection",{}).get("reentry",{}).get("command_restoration",{})
	if finding.is_empty() or reentry.is_empty() or displaced_command.is_empty() or policy.is_empty() or state.get("protective_postures",{}).has(finding.get("room","")): return {"accepted":false,"reason":"primary command restoration prerequisites incomplete"}
	if displaced_actor.get("person_id","")!=displaced_command.get("actor_person_id","") or displaced_actor.get("job","")!=policy.get("displaced_job","") or displaced_actor.get("current_room","")!=policy.get("displaced_station","") or String(primary_actor.get("person_id","")).is_empty() or primary_actor.get("person_id","")==displaced_actor.get("person_id","") or primary_actor.get("job","")!=policy.get("primary_job","") or primary_actor.get("current_room","")!=policy.get("primary_station",""): return {"accepted":false,"reason":"primary command restoration participants invalid"}
	state["active_command_restoration"]={"restoration_id":finding_id+":command-restoration","finding_id":finding_id,"reentry_id":reentry["reentry_id"],"displaced_command_id":displaced_command["command_id"],"action":policy["action"],"displaced_actor_person_id":displaced_actor["person_id"],"displaced_job":policy["displaced_job"],"displaced_station":policy["displaced_station"],"primary_actor_person_id":primary_actor["person_id"],"primary_job":policy["primary_job"],"primary_station":policy["primary_station"],"duration_ticks":policy["duration_ticks"],"remaining_ticks":policy["duration_ticks"],"rationale":rationale,"started_clock":state["clock"]}
	return {"accepted":true,"status":"active","restoration_id":state["active_command_restoration"]["restoration_id"]}

func resume_primary_command_restoration(state: Dictionary, finding_id: String, actor_locations: Dictionary) -> Dictionary:
	var work: Dictionary=state.get("active_command_restoration",{})
	if work.is_empty() or work.get("finding_id","")!=finding_id or not work.get("suspended",false) or work.get("suspension_reason","")!="restart_reconciliation": return {"accepted":false,"reason":"primary command restoration is not suspended for restart reconciliation"}
	if actor_locations.get(work["displaced_actor_person_id"],"")!=work["displaced_station"] or actor_locations.get(work["primary_actor_person_id"],"")!=work["primary_station"]: return {"accepted":false,"reason":"command restoration participants not reconciled at stations"}
	work["suspended"]=false; work["suspension_reason"]=""; state["active_command_restoration"]=work
	return {"accepted":true,"remaining_ticks":work["remaining_ticks"]}

func tick_primary_command_restoration(state: Dictionary, actor_locations: Dictionary) -> Dictionary:
	var work: Dictionary=state.get("active_command_restoration",{})
	if work.is_empty(): return {"accepted":false,"reason":"no active primary command restoration"}
	if work.get("suspended",false): return {"accepted":false,"reason":"primary command restoration requires explicit resume"}
	if actor_locations.get(work["displaced_actor_person_id"],"")!=work["displaced_station"] or actor_locations.get(work["primary_actor_person_id"],"")!=work["primary_station"]: return {"accepted":false,"reason":"command restoration participants left stations"}
	work["remaining_ticks"]=int(work["remaining_ticks"])-1
	if work["remaining_ticks"]>0: state["active_command_restoration"]=work; return {"accepted":true,"status":"working","remaining_ticks":work["remaining_ticks"]}
	var record: Dictionary=work.duplicate(true); record.erase("remaining_ticks"); record["completed_clock"]=state["clock"]
	state["command_restorations"].append(record); state["active_command_restoration"]={}
	return {"accepted":true,"status":"restored","restoration":record}


func authorize_hazard_remediation(state: Dictionary, finding_id: String, rationale: String, actor: Dictionary) -> Dictionary:
	var finding: Dictionary={}; var displaced_command: Dictionary={}
	for candidate in state.get("hazard_findings",[]):
		if candidate.get("finding_id","")==finding_id: finding=candidate; break
	var policy: Dictionary=_hazard_rule_for(state,finding.get("classification","")).get("remediation",{}).get("authorization",{})
	for candidate in state.get("displaced_commands",[]):
		if candidate.get("finding_id","")==finding_id: displaced_command=candidate; break
	if finding.is_empty() or finding.get("status","")!="commanded" or policy.is_empty() or String(rationale).strip_edges().is_empty(): return {"accepted":false,"reason":"hazard remediation authorization unavailable"}
	if policy.get("required_displaced_command",false) and (displaced_command.is_empty() or displaced_command.get("actor_person_id","")!=actor.get("person_id", "")): return {"accepted":false,"reason":"remediation authority is not active displaced command"}
	if actor.get("job","")!=policy.get("actor_job","") or actor.get("current_room","")!=policy.get("station",""): return {"accepted":false,"reason":"remediation authority not at alternate command station"}
	for existing in state.get("remediation_authorizations",[]):
		if existing.get("finding_id","")==finding_id: return {"accepted":false,"reason":"hazard remediation already authorized"}
	var record: Dictionary={"authorization_id":finding_id+":remediation_authorization","finding_id":finding_id,"command_id":displaced_command.get("command_id",""),"action":policy["action"],"actor_person_id":actor["person_id"],"actor_job":policy["actor_job"],"station":policy["station"],"rationale":rationale,"authorized_clock":state["clock"]}
	state["remediation_authorizations"].append(record)
	return {"accepted":true,"status":"authorized","authorization_id":record["authorization_id"]}

func request_hazard_remediation(state: Dictionary, finding_id: String, remediation_actor: Dictionary, verification_actor: Dictionary) -> Dictionary:
	if not state.get("active_hazard_work", {}).is_empty(): return {"accepted": false, "reason": "hazard work already active"}
	var finding_index := -1
	for index in state.get("hazard_findings", []).size():
		if state["hazard_findings"][index].get("finding_id", "") == finding_id: finding_index = index; break
	if finding_index < 0 or state["hazard_findings"][finding_index].get("status", "") != "commanded": return {"accepted": false, "reason": "commanded hazard finding not found"}
	var finding: Dictionary = state["hazard_findings"][finding_index]
	var rule: Dictionary = _hazard_rule_for(state, finding.get("classification", ""))
	var policy: Dictionary = rule.get("remediation", {})
	if policy.is_empty(): return {"accepted": false, "reason": "hazard has no executable remediation policy"}
	if not policy.get("authorization",{}).is_empty():
		var authorized: bool=false
		for authorization in state.get("remediation_authorizations",[]):
			if authorization.get("finding_id","")==finding_id: authorized=true; break
		if not authorized: return {"accepted":false,"reason":"hazard remediation lacks displaced-command authorization"}
	if String(remediation_actor.get("person_id", "")).is_empty() or not (remediation_actor.get("roles", []) as Array).has(policy.get("actor_job", "")) or remediation_actor.get("current_room", "") != policy.get("station", ""): return {"accepted": false, "reason": "remediation lacks named technical authority at station"}
	if String(verification_actor.get("person_id", "")).is_empty() or verification_actor.get("person_id", "") == remediation_actor.get("person_id", "") or not (verification_actor.get("roles", []) as Array).has(policy.get("verification_job", "")) or verification_actor.get("current_room", "") != policy.get("verification_station", ""): return {"accepted": false, "reason": "remediation lacks independent verifier at station"}
	state["active_hazard_work"] = {"work_id":finding_id + ":remediation","finding_id":finding_id,"phase":"remediation","actor_person_id":remediation_actor["person_id"],"actor_job":policy["actor_job"],"station":policy["station"],"verification_person_id":verification_actor["person_id"],"verification_job":policy["verification_job"],"verification_station":policy["verification_station"],"remaining_ticks":policy["duration_ticks"],"remediation_duration_ticks":policy["duration_ticks"],"verification_duration_ticks":policy["verification_duration_ticks"],"clear_readings":policy["clear_readings"].duplicate(true),"closure_scope":policy.get("closure_scope","technical_hazard_clearance"),"verification_samples":[],"started_clock":state["clock"],"handoffs":[]}
	return {"accepted": true, "work_id": state["active_hazard_work"]["work_id"], "remaining_ticks": state["active_hazard_work"]["remaining_ticks"]}


func tick_hazard_work(state: Dictionary, actor_locations: Dictionary, readings_by_room: Dictionary) -> Dictionary:
	var work: Dictionary = state.get("active_hazard_work", {})
	if work.is_empty(): return {"accepted": false, "reason": "no active hazard work"}
	if work.get("suspended", false): return {"accepted": false, "reason": "hazard work requires explicit resume"}
	var actor_id: String = work["actor_person_id"] if work["phase"] == "remediation" else work["verification_person_id"]
	var station: String = work["station"] if work["phase"] == "remediation" else work["verification_station"]
	if actor_locations.get(actor_id, "") != station: return {"accepted": false, "reason": "hazard worker not at required station"}
	if work["phase"] == "verification":
		var readings: Dictionary = readings_by_room.get(station, {})
		for reading_name in work["clear_readings"]:
			if not readings.has(reading_name) or readings[reading_name] != false: return {"accepted": false, "reason": "hazard verification lacks clear reading:" + String(reading_name)}
		var retained_readings: Dictionary = {}
		for reading_name in work["clear_readings"]: retained_readings[reading_name] = readings[reading_name]
		work["verification_samples"].append({"sequence":work["verification_samples"].size()+1,"station":station,"verifier_person_id":actor_id,"readings":retained_readings,"clock":state["clock"]})
	work["remaining_ticks"] = int(work["remaining_ticks"]) - 1
	if work["remaining_ticks"] > 0: state["active_hazard_work"] = work; return {"accepted": true, "status": "working", "remaining_ticks": work["remaining_ticks"]}
	if work["phase"] == "remediation":
		work["phase"] = "verification"; work["remaining_ticks"] = work["verification_duration_ticks"]; work["remediation_completed_clock"] = state["clock"]; state["active_hazard_work"] = work
		for index in state["hazard_findings"].size():
			if state["hazard_findings"][index].get("finding_id", "") == work["finding_id"]: state["hazard_findings"][index]["status"] = "verification_pending"; break
		return {"accepted": true, "status": "verification_pending", "remaining_ticks": work["remaining_ticks"]}
	var closure_id: String = work["finding_id"] + ":closure"
	var closure: Dictionary = {"closure_id":closure_id,"finding_id":work["finding_id"],"occurrence_id":state["occurrence_id"],"work_id":work["work_id"],"remediation_actor_person_id":work["actor_person_id"],"remediation_actor_job":work["actor_job"],"remediation_station":work["station"],"verification_actor_person_id":work["verification_person_id"],"verification_actor_job":work["verification_job"],"verification_station":work["verification_station"],"clear_readings":work["clear_readings"].duplicate(true),"closure_scope":work.get("closure_scope","technical_hazard_clearance"),"verification_samples":work.get("verification_samples",[]).duplicate(true),"handoffs":work.get("handoffs", []).duplicate(true),"closed_clock":state["clock"]}
	state["hazard_closures"].append(closure)
	for index in state["hazard_findings"].size():
		if state["hazard_findings"][index].get("finding_id", "") == work["finding_id"]: state["hazard_findings"][index]["status"] = "closed"; state["hazard_findings"][index]["closure_id"] = closure_id; break
	state["active_hazard_work"] = {}
	return {"accepted": true, "status": "closed", "closure_id": closure_id}


func decide_hazard(state: Dictionary, finding_id: String, decision: String, rationale: String, actor: Dictionary) -> Dictionary:
	var policy: Dictionary = state.get("obligation", {}).get("escalation", {})
	if String(actor.get("person_id", "")).is_empty() or not (actor.get("roles", []) as Array).has(policy.get("actor_job", "")) or actor.get("current_room", "") != policy.get("station", ""): return {"accepted": false, "reason": "hazard decision lacks named command authority"}
	var finding_index := -1
	for index in state.get("hazard_findings", []).size():
		if state["hazard_findings"][index].get("finding_id", "") == finding_id: finding_index = index; break
	if finding_index < 0: return {"accepted": false, "reason": "hazard finding does not exist"}
	var finding: Dictionary = state["hazard_findings"][finding_index]
	if finding.get("status", "") != "unresolved": return {"accepted": false, "reason": "hazard finding already commanded"}
	if decision != finding.get("recommended_decision", "") or rationale.strip_edges().is_empty(): return {"accepted": false, "reason": "hazard disposition must match recommendation and include rationale"}
	var decision_id: String = finding_id + ":decision"
	var event: Dictionary = {"decision_id":decision_id,"finding_id":finding_id,"occurrence_id":state["occurrence_id"],"observation_id":finding["observation_id"],"decision":decision,"rationale":rationale,"actor_person_id":actor["person_id"],"actor_job":policy["actor_job"],"station":policy["station"],"clock":state["clock"]}
	state["hazard_decisions"].append(event); finding["status"] = "commanded"; finding["decision_id"] = decision_id; state["hazard_findings"][finding_index] = finding
	if decision == "archive_safe_hold": state["protective_postures"]["archive_stack"] = "safe_hold"
	elif decision == "compute_safe_shutdown": state["protective_postures"]["compute_core"] = "safe_shutdown"
	elif decision == "evacuate_affected_rooms": state["protective_postures"][finding["room"]] = "evacuate"
	return {"accepted": true, "decision_id": decision_id, "finding_id": finding_id, "decision": decision}


func decide_escalation(state: Dictionary, round_number: int, decision: String, rationale: String, actor: Dictionary) -> Dictionary:
	var policy: Dictionary = state.get("obligation", {}).get("escalation", {})
	if String(actor.get("person_id", "")).is_empty() or not (actor.get("roles", []) as Array).has(policy.get("actor_job", "")) or actor.get("current_room", "") != policy.get("station", ""):
		return {"accepted": false, "reason": "escalation decision lacks named command authority"}
	if decision not in policy.get("decisions", []) or rationale.strip_edges().is_empty(): return {"accepted": false, "reason": "escalation decision or rationale is invalid"}
	var escalation_index := -1
	for index in state.get("escalations", []).size():
		var candidate: Dictionary = state["escalations"][index]
		if int(candidate.get("round_number", 0)) == round_number:
			if candidate.get("consumed", false): return {"accepted": false, "reason": "escalation decision already consumed"}
			escalation_index = index; break
	if escalation_index < 0: return {"accepted": false, "reason": "escalation does not exist"}
	var event: Dictionary = {"occurrence_id":state["occurrence_id"],"round_number":round_number,"decision":decision,"rationale":rationale,"actor_person_id":actor["person_id"],"actor_job":policy["actor_job"],"station":policy["station"],"clock":state["clock"]}
	state["decisions"].append(event)
	state["escalations"][escalation_index]["consumed"] = true; state["escalations"][escalation_index]["decision_clock"] = state["clock"]
	if decision == "archive_safe_hold": state["protective_postures"]["archive_stack"] = "safe_hold"
	elif decision == "compute_safe_shutdown": state["protective_postures"]["compute_core"] = "safe_shutdown"
	elif decision == "evacuate_affected_rooms":
		for assignment in state["obligation"]["room_assignments"]: state["protective_postures"][assignment["room"]] = "evacuate"
	return {"accepted": true, "decision": decision, "actor_person_id": actor["person_id"], "round_number": round_number}


func release_protective_posture(state: Dictionary, room_id: String, rationale: String, monitoring_phase: String, authority: Dictionary, concurrence: Dictionary) -> Dictionary:
	if not state.get("protective_postures", {}).has(room_id): return {"accepted": false, "reason": "protective posture is not active"}
	if state.get("active", false) or monitoring_phase != "normal": return {"accepted": false, "reason": "environmental monitoring has not been reconstituted"}
	var release_policy: Dictionary = state.get("obligation", {}).get("escalation", {}).get("release", {})
	if String(authority.get("person_id", "")).is_empty() or authority.get("job_id", "") != release_policy.get("authority_job", "") or authority.get("current_room", "") != release_policy.get("authority_station", ""): return {"accepted": false, "reason": "release lacks named command authority"}
	if String(concurrence.get("person_id", "")).is_empty() or concurrence.get("person_id", "") == authority.get("person_id", "") or concurrence.get("job_id", "") != release_policy.get("concurrence_job", "") or concurrence.get("current_room", "") != release_policy.get("concurrence_station", ""): return {"accepted": false, "reason": "release lacks independent records concurrence"}
	if rationale.strip_edges().is_empty(): return {"accepted": false, "reason": "release rationale is required"}
	var source_decision: Dictionary = {}
	for decision_event in state.get("decisions", []):
		if (room_id == "archive_stack" and decision_event.get("decision", "") == "archive_safe_hold") or (room_id == "compute_core" and decision_event.get("decision", "") == "compute_safe_shutdown"): source_decision = decision_event
	if source_decision.is_empty(): return {"accepted": false, "reason": "protective posture lacks source decision"}
	var evidence_round: Dictionary = {}
	for completed in state.get("completed_rounds", []):
		if int(completed.get("completed_clock", 0)) > int(source_decision.get("clock", 0)): evidence_round = completed
	if evidence_round.is_empty(): return {"accepted": false, "reason": "no post-decision completed observation round"}
	if not state.get("active_release", {}).is_empty(): return {"accepted": false, "reason": "protective release work already active"}
	state["active_release"] = {"occurrence_id":state["occurrence_id"],"room":room_id,"prior_posture":state["protective_postures"][room_id],"source_round_number":source_decision["round_number"],"evidence_round_number":evidence_round["round_number"],"authority_person_id":authority["person_id"],"authority_station":release_policy["authority_station"],"concurrence_person_id":concurrence["person_id"],"concurrence_station":release_policy["concurrence_station"],"rationale":rationale,"remaining_ticks":int(release_policy["duration_ticks"]),"duration_ticks":int(release_policy["duration_ticks"]),"handoffs":[]}
	return {"accepted": true, "status": "release_work_started", "room": room_id, "remaining_ticks": state["active_release"]["remaining_ticks"]}


func begin_reentry_shift_handoff(state: Dictionary, turnover_receipt: Dictionary) -> Dictionary:
	if state.get("active_room_reentry",{}).is_empty(): return {"accepted":true,"receipts":[]}
	var work: Dictionary=state["active_room_reentry"]; var receipts: Array[Dictionary]=[]
	for participant in ["authority","concurrence"]:
		var job_id: String=work[participant+"_job"]; var current_id: String=work[participant+"_person_id"]; var staffing_handoff: Dictionary={}
		for candidate in turnover_receipt.get("handoffs",[]):
			if candidate.get("job_id","")==job_id: staffing_handoff=candidate; break
		if staffing_handoff.is_empty() or current_id not in staffing_handoff.get("outgoing",[]) or staffing_handoff.get("incoming",[]).is_empty(): return {"accepted":false,"reason":"turnover lacks qualified incoming re-entry "+participant}
		var incoming: Array=staffing_handoff["incoming"].duplicate(); incoming.sort()
		if incoming[0]==current_id: return {"accepted":false,"reason":"re-entry handoff requires distinct incoming actor"}
		receipts.append({"turnover_id":turnover_receipt["turnover_id"],"participant":participant,"job_id":job_id,"outgoing_person_id":current_id,"incoming_person_id":incoming[0],"remaining_ticks":work["remaining_ticks"]})
	return {"accepted":true,"receipts":receipts}

func complete_reentry_shift_handoff(state: Dictionary, receipts: Array, agent_state: Dictionary) -> Dictionary:
	if receipts.is_empty(): return {"accepted":true,"handoffs":[]}
	var work: Dictionary=state.get("active_room_reentry",{})
	if work.is_empty() or receipts.size()!=2: return {"accepted":false,"reason":"re-entry handoff set is incomplete"}
	var participants: Dictionary={}; var completed: Array[Dictionary]=[]
	for receipt in receipts:
		var participant: String=receipt.get("participant",""); var incoming_id: String=receipt.get("incoming_person_id",""); var incoming: Dictionary=agent_state.get("agents",{}).get(incoming_id,{})
		if participant not in ["authority","concurrence"] or participants.has(participant) or work.get(participant+"_person_id","")!=receipt.get("outgoing_person_id","") or incoming.get("job_id","")!=receipt.get("job_id","") or int(work.get("remaining_ticks",-1))!=int(receipt.get("remaining_ticks",-2)): return {"accepted":false,"reason":"re-entry handoff receipt no longer matches work"}
		participants[participant]=true; work[participant+"_person_id"]=incoming_id
		var event: Dictionary=receipt.duplicate(true); event["sequence"]=work.get("handoffs",[]).size(); work["handoffs"].append(event); completed.append(event)
	if work["authority_person_id"]==work["concurrence_person_id"]: return {"accepted":false,"reason":"re-entry handoff lost separation of duties"}
	work["suspended"]=true; work["suspension_reason"]="shift_handoff_reconciliation"; state["active_room_reentry"]=work
	return {"accepted":true,"handoffs":completed,"remaining_ticks":work["remaining_ticks"]}


func begin_hazard_shift_handoff(state: Dictionary, turnover_receipt: Dictionary) -> Dictionary:
	if state.get("active_hazard_work", {}).is_empty(): return {"accepted": true, "receipts": []}
	var work: Dictionary = state["active_hazard_work"]
	var participants: Array = [{"participant":"technical","job_id":work["actor_job"],"person_field":"actor_person_id"},{"participant":"verification","job_id":work["verification_job"],"person_field":"verification_person_id"}]
	var receipts: Array[Dictionary] = []
	for participant in participants:
		var staffing_handoff: Dictionary = {}
		for candidate in turnover_receipt.get("handoffs", []):
			if candidate.get("job_id", "") == participant["job_id"]: staffing_handoff = candidate; break
		var current_id: String = work[participant["person_field"]]
		if staffing_handoff.is_empty() or current_id not in staffing_handoff.get("outgoing", []) or staffing_handoff.get("incoming", []).is_empty(): return {"accepted": false, "reason": "turnover lacks qualified incoming hazard " + String(participant["participant"])}
		var incoming: Array = staffing_handoff["incoming"].duplicate(); incoming.sort()
		if incoming[0] == current_id: return {"accepted": false, "reason": "hazard handoff requires distinct incoming actor"}
		receipts.append({"turnover_id":turnover_receipt["turnover_id"],"participant":participant["participant"],"job_id":participant["job_id"],"outgoing_person_id":current_id,"incoming_person_id":incoming[0],"phase":work["phase"],"remaining_ticks":work["remaining_ticks"]})
	return {"accepted": true, "receipts": receipts}


func complete_hazard_shift_handoff(state: Dictionary, receipts: Array, agent_state: Dictionary) -> Dictionary:
	if receipts.is_empty(): return {"accepted": true, "handoffs": []}
	if receipts.size() != 2 or state.get("active_hazard_work", {}).is_empty(): return {"accepted": false, "reason": "hazard work handoff set is incomplete"}
	var work: Dictionary = state["active_hazard_work"]
	var completed: Array[Dictionary] = []
	var participants: Dictionary = {}
	for receipt in receipts:
		var participant: String = receipt.get("participant", "")
		var person_field: String = "actor_person_id" if participant == "technical" else "verification_person_id"
		var incoming: Dictionary = agent_state.get("agents", {}).get(receipt.get("incoming_person_id", ""), {})
		if participant not in ["technical", "verification"] or participants.has(participant) or work.get(person_field, "") != receipt.get("outgoing_person_id", "") or incoming.get("job_id", "") != receipt.get("job_id", "") or work.get("phase", "") != receipt.get("phase", "") or int(work.get("remaining_ticks", -1)) != int(receipt.get("remaining_ticks", -2)): return {"accepted": false, "reason": "hazard handoff receipt no longer matches work"}
		participants[participant] = true; work[person_field] = receipt["incoming_person_id"]
		var event: Dictionary = receipt.duplicate(true); event["sequence"] = work.get("handoffs", []).size(); work["handoffs"].append(event); completed.append(event)
	if participants.size() != 2 or work["actor_person_id"] == work["verification_person_id"]: return {"accepted": false, "reason": "hazard handoff lost separation of duties"}
	work["suspended"] = true; work["suspension_reason"] = "shift_handoff_reconciliation"; state["active_hazard_work"] = work
	return {"accepted": true, "handoffs": completed, "remaining_ticks": work["remaining_ticks"]}


func begin_release_shift_handoff(state: Dictionary, turnover_receipt: Dictionary) -> Dictionary:
	if state.get("active_release", {}).is_empty(): return {"accepted": true, "receipts": []}
	var work: Dictionary = state["active_release"]
	var policy: Dictionary = state.get("obligation", {}).get("escalation", {}).get("release", {})
	var receipts: Array[Dictionary] = []
	for participant in ["authority", "concurrence"]:
		var job_id: String = policy[participant + "_job"]
		var current_id: String = work[participant + "_person_id"]
		var staffing_handoff: Dictionary = {}
		for candidate in turnover_receipt.get("handoffs", []):
			if candidate.get("job_id", "") == job_id: staffing_handoff = candidate; break
		if staffing_handoff.is_empty() or current_id not in staffing_handoff.get("outgoing", []) or staffing_handoff.get("incoming", []).is_empty(): return {"accepted": false, "reason": "turnover lacks qualified incoming release " + participant}
		var incoming: Array = staffing_handoff["incoming"].duplicate(); incoming.sort()
		if incoming[0] == current_id: return {"accepted": false, "reason": "release handoff requires distinct incoming actor"}
		receipts.append({"turnover_id":turnover_receipt["turnover_id"],"participant":participant,"job_id":job_id,"outgoing_person_id":current_id,"incoming_person_id":incoming[0],"remaining_ticks":work["remaining_ticks"]})
	return {"accepted": true, "receipts": receipts}


func complete_release_shift_handoff(state: Dictionary, receipts: Array, agent_state: Dictionary) -> Dictionary:
	if receipts.is_empty(): return {"accepted": true, "handoffs": []}
	var work: Dictionary = state.get("active_release", {})
	if work.is_empty(): return {"accepted": false, "reason": "release work disappeared during turnover"}
	var completed: Array[Dictionary] = []
	for receipt in receipts:
		var participant: String = receipt["participant"]
		var incoming_id: String = receipt["incoming_person_id"]
		var incoming: Dictionary = agent_state.get("agents", {}).get(incoming_id, {})
		if work.get(participant + "_person_id", "") != receipt.get("outgoing_person_id", "") or incoming.get("job_id", "") != receipt.get("job_id", "") or int(work.get("remaining_ticks", -1)) != int(receipt.get("remaining_ticks", -2)): return {"accepted": false, "reason": "release handoff receipt no longer matches work"}
		work[participant + "_person_id"] = incoming_id
		var event: Dictionary = receipt.duplicate(true); event["sequence"] = work.get("handoffs", []).size(); work["handoffs"].append(event); completed.append(event)
	work["suspended"] = true; work["suspension_reason"] = "shift_handoff_reconciliation"; state["active_release"] = work
	return {"accepted": true, "handoffs": completed, "remaining_ticks": work["remaining_ticks"]}


func tick_protective_release(state: Dictionary, actor_locations: Dictionary) -> Dictionary:
	if state.get("active_release", {}).is_empty(): return {"accepted": false, "reason": "protective release work is not active"}
	var work: Dictionary = state["active_release"]
	if work.get("suspended", false): return {"accepted": false, "reason": "protective release requires explicit resume"}
	if actor_locations.get(work["authority_person_id"], "") != work["authority_station"]: return {"accepted": false, "reason": "release authority left command station"}
	if actor_locations.get(work["concurrence_person_id"], "") != work["concurrence_station"]: return {"accepted": false, "reason": "release concurrence left records station"}
	work["remaining_ticks"] = int(work["remaining_ticks"]) - 1
	if int(work["remaining_ticks"]) > 0: state["active_release"] = work; return {"accepted": true, "status": "working", "remaining_ticks": work["remaining_ticks"]}
	var release_event: Dictionary = work.duplicate(true); release_event.erase("remaining_ticks"); release_event["clock"] = state["clock"]
	state["releases"].append(release_event); state["protective_postures"].erase(work["room"]); state["active_release"] = {}
	return {"accepted": true, "status": "committed", "room": work["room"], "release_number": state["releases"].size()}


func tick_waiting(state: Dictionary) -> Dictionary:
	if not state.get("active", false): return {"accepted": false, "reason": "observation_authority_inactive"}
	if state.get("active_round", {}).is_empty(): return {"accepted": false, "reason": "observation_round_inactive"}
	if state["active_round"].get("suspended", false): return {"accepted": false, "reason": "observation round requires explicit resume"}
	state["clock"] = int(state.get("clock", 0)) + 1
	_record_overdue_if_needed(state)
	return {"accepted": true, "status": "observer_unavailable", "overdue": state["active_round"].get("overdue", false)}


func _reentry_handoffs_valid(record: Dictionary) -> bool:
	var handoffs: Array=record.get("handoffs",[])
	if handoffs.is_empty(): return true
	if handoffs.size()!=2: return false
	var participants: Dictionary={}; var turnover_id: String=""
	for index in handoffs.size():
		var handoff: Dictionary=handoffs[index]; var participant: String=handoff.get("participant","")
		if participant not in ["authority","concurrence"] or participants.has(participant) or int(handoff.get("sequence",-1))!=index or String(handoff.get("turnover_id","")).is_empty() or (not turnover_id.is_empty() and turnover_id!=handoff["turnover_id"]) or handoff.get("job_id","")!=record.get(participant+"_job","") or handoff.get("incoming_person_id","")!=record.get(participant+"_person_id","") or String(handoff.get("outgoing_person_id","")).is_empty() or handoff.get("outgoing_person_id","")==handoff.get("incoming_person_id","") or int(handoff.get("remaining_ticks",0))<1 or int(handoff.get("remaining_ticks",0))>int(record.get("duration_ticks",0)): return false
		turnover_id=handoff["turnover_id"]; participants[participant]=true
	return participants.size()==2


func _hazard_verifier_ids(record: Dictionary) -> Array:
	var ids: Array = [record.get("verification_person_id", record.get("verification_actor_person_id", ""))]
	for handoff in record.get("handoffs", []):
		if handoff.get("participant", "") == "verification_actor":
			for field in ["outgoing_person_id", "incoming_person_id"]:
				if not ids.has(handoff.get(field, "")): ids.append(handoff.get(field, ""))
	return ids


func _verification_samples_valid(samples: Array, expected_count: int, policy: Dictionary, verifier_person_ids: Array) -> bool:
	if samples.size() != expected_count: return false
	for index in samples.size():
		var sample: Dictionary = samples[index]
		if int(sample.get("sequence", 0)) != index + 1 or sample.get("station", "") != policy.get("verification_station", "") or sample.get("verifier_person_id", "") not in verifier_person_ids: return false
		var readings: Dictionary = sample.get("readings", {})
		if readings.size() != policy.get("clear_readings", []).size(): return false
		for reading_name in policy.get("clear_readings", []):
			if not readings.has(reading_name) or readings[reading_name] != false: return false
	return true


func _hazard_rule_for(state: Dictionary, classification: String) -> Dictionary:
	for rule in state.get("obligation", {}).get("hazard_rules", []):
		if rule.get("classification", "") == classification: return rule
	return {}


func _classify_hazards(state: Dictionary, observation: Dictionary) -> void:
	for rule in state.get("obligation", {}).get("hazard_rules", []):
		if rule.get("room", "") != observation.get("room", "") or not bool(observation.get("readings", {}).get(rule.get("reading", ""), false)): continue
		var finding_id: String = observation["observation_id"] + ":hazard:" + rule["classification"]
		var duplicate := false
		for existing in state.get("hazard_findings", []):
			if existing.get("finding_id", "") == finding_id: duplicate = true; break
		if duplicate: continue
		state["hazard_findings"].append({"finding_id":finding_id,"occurrence_id":state["occurrence_id"],"observation_id":observation["observation_id"],"round_number":observation["round_number"],"room":observation["room"],"reading":rule["reading"],"classification":rule["classification"],"recommended_decision":rule["recommended_decision"],"recorded_clock":observation["recorded_clock"],"status":"unresolved"})


func _record_overdue_if_needed(state: Dictionary) -> void:
	if state.get("active_round", {}).is_empty(): return
	var round_state: Dictionary = state["active_round"]
	var max_round_ticks: int = int(state.get("obligation", {}).get("max_round_ticks", 0))
	if max_round_ticks < 1 or round_state.get("overdue", false) or int(state["clock"]) - int(round_state["started_clock"]) <= max_round_ticks: return
	var policy: Dictionary = state["obligation"].get("escalation", {})
	var event: Dictionary = {"occurrence_id":state["occurrence_id"],"round_number":round_state["round_number"],"clock":state["clock"],"action":policy.get("action",""),"station":policy.get("station",""),"actor_job":policy.get("actor_job",""),"reason":"manual_observation_round_overdue"}
	state["escalations"].append(event); round_state["overdue"] = true; round_state["escalation_clock"] = state["clock"]; state["active_round"] = round_state


func _start_round(state: Dictionary) -> void:
	state["round_counter"] = int(state["round_counter"]) + 1
	var bound: Array = []
	for assignment in state["obligation"]["room_assignments"]:
		var item: Dictionary = assignment.duplicate(true); item["actor_person_id"] = state["actors_by_job"][item["actor_job"]]; bound.append(item)
	state["active_round"] = {"round_number": state["round_counter"], "started_clock": state["clock"], "completed_clock": 0, "assignments": bound, "room_index": 0, "remaining_ticks": int(state["obligation"]["duration_ticks_per_room"]), "observation_ids": []}

func _validate_obligation(obligation: Dictionary, actors_by_job: Dictionary, require_named_actors: bool = true) -> Array[String]:
	var errors: Array[String] = []
	if obligation.get("kind", "") != "manual_observation_round": errors.append("invalid_observation_obligation")
	if int(obligation.get("interval_ticks", 0)) < 1 or int(obligation.get("duration_ticks_per_room", 0)) < 1: errors.append("invalid_observation_timing")
	var maximum_round_ticks: int = int(obligation.get("max_round_ticks", 0))
	var escalation: Dictionary = obligation.get("escalation", {})
	if maximum_round_ticks < int(obligation.get("duration_ticks_per_room", 0)) * obligation.get("room_assignments", []).size(): errors.append("invalid_observation_deadline")
	if escalation.get("action", "") != "review_protective_safe_hold" or escalation.get("decisions", []) != ["archive_safe_hold", "compute_safe_shutdown", "evacuate_affected_rooms"] or String(escalation.get("station", "")).is_empty() or String(escalation.get("actor_job", "")).is_empty(): errors.append("invalid_observation_escalation")
	var release_policy: Dictionary = escalation.get("release", {})
	if release_policy.get("action", "") != "release_protective_posture" or release_policy.get("required_evidence", "") != "monitoring_normal_and_post_decision_round" or int(release_policy.get("duration_ticks", 0)) < 1 or String(release_policy.get("authority_job", "")).is_empty() or release_policy.get("authority_job", "") == release_policy.get("concurrence_job", "") or String(release_policy.get("authority_station", "")).is_empty() or String(release_policy.get("concurrence_station", "")).is_empty(): errors.append("invalid_observation_release_policy")
	var hazard_pairs: Dictionary = {}
	var hazard_classifications: Dictionary = {}
	for hazard_rule in obligation.get("hazard_rules", []):
		var hazard_pair: String = String(hazard_rule.get("room", "")) + ":" + String(hazard_rule.get("reading", ""))
		var classification: String = hazard_rule.get("classification", "")
		if hazard_rule.get("room", "") not in ["archive_stack", "compute_core", "security_control"] or hazard_rule.get("reading", "") not in ["water_intrusion", "smoke_or_local_alarm"] or classification.is_empty() or hazard_pairs.has(hazard_pair) or hazard_classifications.has(classification) or hazard_rule.get("recommended_decision", "") not in escalation.get("decisions", []): errors.append("invalid environmental hazard rule")
		var reactivation: Dictionary = hazard_rule.get("remediation", {}).get("reactivation", {})
		if classification.ends_with("fire_or_local_alarm") and not hazard_rule.get("remediation", {}).is_empty() and hazard_rule.get("remediation", {}).get("closure_scope", "") != "local_alarm_controls_only": errors.append("alarm stabilization overclaims room clearance")
		if not reactivation.is_empty() and (reactivation.get("action", "") != "reactivate_compute_after_hazard" or String(reactivation.get("authority_job", "")).is_empty() or String(reactivation.get("concurrence_job", "")).is_empty() or reactivation.get("authority_job", "") == reactivation.get("concurrence_job", "") or String(reactivation.get("authority_station", "")).is_empty() or String(reactivation.get("concurrence_station", "")).is_empty() or int(reactivation.get("duration_ticks", 0)) < 1): errors.append("invalid compute hazard reactivation policy")
		var evacuation: Dictionary = hazard_rule.get("evacuation", {})
		if not evacuation.is_empty() and (hazard_rule.get("recommended_decision", "") != "evacuate_affected_rooms" or String(evacuation.get("destination", "")).is_empty() or String(evacuation.get("accountability_job", "")).is_empty() or String(evacuation.get("accountability_station", "")).is_empty()): errors.append("invalid environmental evacuation policy")
		hazard_pairs[hazard_pair] = true; hazard_classifications[classification] = true
	if hazard_pairs.size() != 6: errors.append("environmental hazard rules do not cover protected rooms")
	if obligation.get("observations", []) != REQUIRED_READINGS: errors.append("invalid_observation_schema")
	var assignments: Array = obligation.get("room_assignments", [])
	if assignments.is_empty(): errors.append("missing_room_assignments")
	for assignment in assignments:
		if String(assignment.get("room", "")).is_empty() or String(assignment.get("actor_job", "")).is_empty(): errors.append("invalid_room_assignment")
		elif require_named_actors and String(actors_by_job.get(assignment["actor_job"], "")).is_empty(): errors.append("missing_named_observer:" + String(assignment["actor_job"]))
	return errors
