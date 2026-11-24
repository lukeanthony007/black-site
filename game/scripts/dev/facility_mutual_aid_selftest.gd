extends Node
var fails := 0
func _ready() -> void:
	var cli: PackedStringArray=OS.get_cmdline_user_args()
	if cli.has("--external-journal-post-revoke"):
		var post=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(post)
		for _frame in 4: await get_tree().process_frame
		var post_loaded: Dictionary=post.recover_scene_journal("/tmp/blacksite_external_journal")
		var replay: Array[Dictionary]=post.mutual_aid_runtime.revoke_closed_occurrences(post.mutual_aid_state,[])
		_check(post_loaded.get("accepted",false) and post.infrastructure_runtime.service_phase(post.infrastructure_state,"cooling")=="normal" and post.mutual_aid_state["cases"]["mutual-aid-1"]["phase"]=="revoked" and not post.mutual_aid_runtime.active_capacity(post.mutual_aid_state,"infrastructure:cooling:1").get("accepted",true) and replay.is_empty(),"post-revocation restart resurrected external authority")
		print("EXTERNAL_JOURNAL_POST_REVOKE_OK" if fails==0 else "EXTERNAL_JOURNAL_POST_REVOKE_FAILED"); get_tree().quit(0 if fails==0 else 1); return
	if cli.has("--external-journal-read"):
		var reader=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(reader)
		for _frame in 4: await get_tree().process_frame
		var loaded: Dictionary=reader.recover_scene_journal("/tmp/blacksite_external_journal")
		var history: Array=reader.infrastructure_state.get("history",[])
		_check(loaded.get("accepted",false) and reader.infrastructure_runtime.service_phase(reader.infrastructure_state,"cooling")=="controlled_shutdown" and reader.operations_queue_state["entries"]["live-external-entry"]["status"]=="resolved" and reader.procedure_work_state["tasks"]["procedure-task-1"]["status"]=="committed" and reader.mutual_aid_state["capacity_reservations"].is_empty() and reader.mutual_aid_state["cases"]["mutual-aid-1"]["phase"]=="admitted" and history[-1].get("actor_person_id","")=="external-command-9", "separate-process external journal recovery lost authority")
		if cli.has("--external-journal-close"):
			for panel_id in ["cooling:isolate_for_repair","cooling:begin_repair","cooling:record_repair","cooling:functional_test","cooling:verify_reconstitution"]:
				var step: Dictionary=_run_panel_to_commit(reader,panel_id); _check(step.get("accepted",false),"post-restart cooling continuation failed at %s: %s" % [panel_id,step.get("reason","")])
			var revoked: Array[Dictionary]=reader.mutual_aid_runtime.revoke_closed_occurrences(reader.mutual_aid_state,[])
			_check(reader.infrastructure_runtime.service_phase(reader.infrastructure_state,"cooling")=="normal" and revoked.size()==1 and reader.mutual_aid_state["cases"]["mutual-aid-1"]["phase"]=="revoked","restored occurrence did not revoke retained credential")
			var recommit: Dictionary=reader.commit_scene_journal("/tmp/blacksite_external_journal"); _check(recommit.get("accepted",false),"revocation epoch journal commit failed")
			print("EXTERNAL_JOURNAL_CLOSER_OK" if fails==0 else "EXTERNAL_JOURNAL_CLOSER_FAILED"); get_tree().quit(0 if fails==0 else 1); return
		print("EXTERNAL_JOURNAL_READER_OK" if fails==0 else "EXTERNAL_JOURNAL_READER_FAILED"); get_tree().quit(0 if fails==0 else 1); return
	var graph = load("res://scripts/facility/facility_operation_graph.gd").new(); graph.configure_cyber_archives(7319)
	var route_router=load("res://scripts/facility/facility_route_router.gd").new(); var route_plan: Dictionary=route_router.route(graph,load("res://scripts/facility/facility_layout_solver.gd").new().solve(graph))
	var runtime = load("res://scripts/facility/facility_mutual_aid_runtime.gd").new()
	var escort_to_staging: Array=route_router.ordinary_room_path(route_plan,"security_control","screened_entry"); var responder_to_plant: Array=route_router.ordinary_room_path(route_plan,"screened_entry","plant"); var escort_to_plant: Array=runtime.compose_escort_route_via_staging(escort_to_staging,responder_to_plant)
	var state: Dictionary = runtime.start_state()
	var requested: Dictionary = runtime.request(state, "infrastructure:cooling:1", "facilities_engineer", "plant", "external-tech-7", graph.mutual_aid_policy)
	_check(requested.get("accepted", false), "request rejected"); var id: String = requested["case_id"]
	_check(not runtime.advance(state, id, "authorize", {"actor_id":"duty-1", "job":"duty_officer", "room":"cyber_ops"}).get("accepted", true), "authorization skipped arrival and screening")
	_check(runtime.advance(state,id,"record_arrival",{"responder_id":"external-tech-7","room":"screened_entry"})["accepted"], "arrival rejected")
	_check(not runtime.advance(state,id,"record_screening",{"actor_id":"guard-1","job":"security_officer","room":"archive_stack"}).get("accepted",true), "remote screening accepted")
	_check(runtime.advance(state,id,"record_screening",{"actor_id":"guard-1","job":"security_officer","room":"screened_entry"})["accepted"], "screening rejected")
	_check(runtime.advance(state,id,"authorize",{"actor_id":"duty-1","job":"duty_officer","room":"cyber_ops"})["accepted"], "authorization rejected")
	_check(not runtime.advance(state,id,"issue_credential",{"credential_id":"temp-1","mode":"incident_scoped_temporary","occurrence_id":"wrong","destination":"plant"}).get("accepted",true), "cross-occurrence credential accepted")
	_check(runtime.advance(state,id,"issue_credential",{"credential_id":"temp-1","mode":"incident_scoped_temporary","occurrence_id":"infrastructure:cooling:1","destination":"plant"})["accepted"], "credential rejected")
	_check(runtime.advance(state,id,"assign_escort",{"actor_id":"guard-1","job":"security_officer","room":"security_control"})["accepted"], "escort rejected")
	_check(not runtime.advance(state,id,"record_escorted_arrival",{"responder_id":"external-tech-7","escort_id":"guard-1","responder_room":"plant","escort_room":"corridor","responder_route":responder_to_plant,"escort_route":escort_to_plant}).get("accepted",true), "unescorted destination admitted")
	_check(escort_to_plant.size()>=2 and escort_to_plant[0]=="security_control" and escort_to_plant[-1]=="plant" and "screened_entry" in escort_to_plant, "escort route skipped staging pickup")
	var began_travel: Dictionary=runtime.advance(state,id,"record_escorted_arrival",{"responder_id":"external-tech-7","escort_id":"guard-1","responder_room":"plant","escort_room":"plant","responder_route":responder_to_plant,"escort_route":escort_to_plant})
	_check(began_travel.get("accepted",false) and began_travel.get("phase","")=="escorted" and state["cases"][id]["phase"]=="escorted" and state.get("admissions",{}).has(id), "escorted travel begin rejected")
	_check(not runtime.active_capacity(state,"infrastructure:cooling:1").get("accepted",true), "capacity projected during escorted travel")
	var mid_travel_tick: Dictionary=runtime.tick_escorted_travel(state,id)
	_check(mid_travel_tick.get("accepted",false) and mid_travel_tick.get("phase","")=="escorted" and state.get("admissions",{}).has(id) and state["cases"][id]["phase"]=="escorted", "escorted travel completed before destination ticks")
	var recovered_mid: Dictionary=runtime.prepare_recovered_state(state)
	_check(recovered_mid.get("accepted",false) and recovered_mid["state"].get("admissions",{}).get(id,{}).get("suspended",false), "mid-travel recovery did not suspend admissions")
	_check(not runtime.tick_escorted_travel(recovered_mid["state"],id).get("accepted",true), "suspended escorted travel auto-advanced")
	_check(runtime.resume_escorted_travel(recovered_mid["state"],id,"external-tech-7","guard-1").get("accepted",false), "escorted travel resume rejected")
	_check(runtime.complete_escorted_travel(recovered_mid["state"],id).get("phase","")=="admitted" and recovered_mid["state"]["cases"][id]["phase"]=="admitted" and not recovered_mid["state"].get("admissions",{}).has(id) and recovered_mid["state"].get("escort_routes",{}).has(id), "resumed escorted travel did not admit")
	var admitted_travel: Dictionary=runtime.complete_escorted_travel(state,id)
	_check(admitted_travel.get("accepted",false) and admitted_travel.get("phase","")=="admitted" and state["cases"][id]["phase"]=="admitted" and not state.get("admissions",{}).has(id) and state.get("escort_routes",{}).has(id), "escorted admission travel rejected")
	_check(runtime.validate_state(state)["accepted"] and runtime.validate_route_provenance(state,route_plan).get("accepted",false), "valid routed state rejected")
	var forged_route: Dictionary=state.duplicate(true); forged_route["escort_routes"][id]["responder_route"]=["screened_entry","archive_stack"]
	_check(not runtime.validate_route_provenance(forged_route,route_plan).get("accepted",true),"unknown or non-personnel escort edge accepted")
	var forged_location: Dictionary=state.duplicate(true); forged_location["temporary_locations"]["external-tech-7"]="screened_entry"
	_check(not runtime.validate_state(forged_location).get("accepted",true),"admitted responder location forgery accepted")
	var capacity: Dictionary = runtime.active_capacity(state, "infrastructure:cooling:1")
	_check(capacity.get("accepted", false) and capacity["response_job"] == "facilities_engineer" and capacity["destination"] == "plant", "admitted responder did not project narrow temporary capacity")
	_check(not runtime.active_capacity(state, "infrastructure:power:1").get("accepted", true), "capacity leaked to another occurrence")
	var queue_runtime = load("res://scripts/facility/facility_operations_queue_runtime.gd").new(); var queue_state: Dictionary = queue_runtime.start_queue()
	var candidate: Dictionary = {"entry_id":"external-entry", "panel_id":"p:external", "domain":"infrastructure", "action":"repair", "actor_job":"facilities_engineer", "station":"plant", "base_priority":20, "deadline_ticks":3, "retry_backoff_ticks":2, "max_wait_ticks":9, "abandonment_action":"mobilize_qualified_relief"}
	var candidates: Array[Dictionary] = [candidate]; queue_runtime.advance(queue_state, candidates)
	var work_runtime = load("res://scripts/facility/facility_procedure_work_runtime.gd").new(); var work_state: Dictionary = work_runtime.start_scheduler()
	var external_definition: Dictionary = {"panel_id":"p:external","service":"cooling","action":"repair","actor_job":"facilities_engineer","station":"plant","duration_ticks":2,"required_services":[]}
	var external_dispatch: Dictionary = queue_runtime.admit_external_work_dispatch(queue_state, work_runtime, work_state, runtime, state, "external-entry", external_definition, "infrastructure:cooling:1")
	_check(external_dispatch.get("accepted", false) and work_state["tasks"][external_dispatch["task_id"]]["control_mode"] == "temporary_mutual_aid", "external procedure task admission failed")
	_check(external_dispatch.get("accepted", false) and queue_state["entries"]["external-entry"]["actor_person_id"] == "external-tech-7" and state["capacity_reservations"].has("external-entry"), "atomic external dispatch did not bind both owners")
	var admitted_live_state: Dictionary = state.duplicate(true); runtime.release_capacity(admitted_live_state, "external-entry")
	var completion_work: Dictionary = work_state.duplicate(true)
	var first_tick: Dictionary = work_runtime.tick_external_work(completion_work, external_dispatch["task_id"], runtime, state); var second_tick: Dictionary = work_runtime.tick_external_work(completion_work, external_dispatch["task_id"], runtime, state)
	_check(first_tick.get("accepted", false) and not first_tick.get("completed", true) and first_tick["remaining_ticks"] == 1 and second_tick.get("completed", false) and completion_work["completion_receipts"].has(second_tick["receipt"]["receipt_id"]), "external nonzero work did not produce completion receipt")
	var completion_queue: Dictionary=queue_state.duplicate(true); var completion_mutual: Dictionary=state.duplicate(true)
	_check(not queue_runtime.finalize_external_semantic_commit(completion_queue,work_runtime,completion_work, runtime,completion_mutual,"external-entry",second_tick["receipt"],{}).get("accepted",true) and completion_queue["entries"]["external-entry"]["status"]=="dispatched", "semantic rejection consumed external completion")
	var semantic_result: Dictionary={"accepted":true,"task_id":second_tick["receipt"]["task_id"],"receipt_id":second_tick["receipt"]["receipt_id"],"panel_id":second_tick["receipt"]["panel_id"],"actor_person_id":second_tick["receipt"]["actor_person_id"],"occurrence_id":"infrastructure:cooling:1","service":"cooling","action":"repair","station":"plant"}
	var forged_semantic: Dictionary=semantic_result.duplicate(true); forged_semantic["occurrence_id"]="infrastructure:power:1"
	_check(not queue_runtime.finalize_external_semantic_commit(completion_queue,work_runtime,completion_work,runtime,completion_mutual,"external-entry",second_tick["receipt"],forged_semantic).get("accepted",true), "cross-occurrence semantic evidence consumed external completion")
	var finalized: Dictionary=queue_runtime.finalize_external_semantic_commit(completion_queue,work_runtime,completion_work,runtime,completion_mutual,"external-entry",second_tick["receipt"],semantic_result)
	_check(finalized.get("accepted",false) and completion_queue["entries"]["external-entry"]["status"]=="resolved" and completion_work["tasks"][external_dispatch["task_id"]]["status"]=="committed" and completion_mutual["capacity_reservations"].is_empty() and completion_mutual["cases"][id]["phase"]=="admitted", "accepted semantic commit did not close external work")
	var revoked_capacity: Dictionary = state.duplicate(true); runtime.revoke_closed_occurrences(revoked_capacity, [])
	_check(not work_runtime.tick_external_work(work_state.duplicate(true), external_dispatch["task_id"], runtime, revoked_capacity).get("accepted", true), "external work ticked after credential revocation")
	var closure_queue: Dictionary = queue_state.duplicate(true); var closure_work: Dictionary = work_state.duplicate(true); var closure_mutual: Dictionary = state.duplicate(true)
	var closure: Dictionary = queue_runtime.revoke_external_dispatch_for_closed_occurrence(closure_queue, work_runtime, closure_work, runtime, closure_mutual, "external-entry", "infrastructure:cooling:1")
	_check(closure.get("accepted", false) and closure_queue["entries"]["external-entry"]["status"] == "terminal_failed" and closure_work["tasks"][external_dispatch["task_id"]]["status"] == "superseded" and closure_work["active_panel_tasks"].is_empty() and closure_mutual["capacity_reservations"].is_empty() and closure_mutual["cases"][id]["phase"] == "revoked", "incident closure did not atomically terminate external work")
	runtime.release_capacity(state, "external-entry")
	var wrong_state: Dictionary = queue_runtime.start_queue(); var wrong: Dictionary = candidate.duplicate(true); wrong["entry_id"] = "wrong-entry"; wrong["actor_job"] = "security_officer"; var wrong_candidates: Array[Dictionary] = [wrong]; queue_runtime.advance(wrong_state, wrong_candidates)
	var wrong_work_state: Dictionary = work_runtime.start_scheduler()
	_check(not queue_runtime.admit_external_work_dispatch(wrong_state, work_runtime, wrong_work_state, runtime, state, "wrong-entry", external_definition, "infrastructure:cooling:1").get("accepted", true) and wrong_state["entries"]["wrong-entry"]["status"] == "waiting" and wrong_state["reservations"]["actors"].is_empty() and wrong_work_state["tasks"].is_empty() and wrong_work_state["active_panel_tasks"].is_empty(), "failed external capacity admission did not roll back queue and work")
	_check(not runtime.reserve_capacity(state, "infrastructure:cooling:1", "entry-1", "security_officer", "plant", "task-1").get("accepted", true), "temporary capacity reserved for wrong job")
	_check(runtime.reserve_capacity(state, "infrastructure:cooling:1", "entry-1", "facilities_engineer", "plant", "task-1").get("accepted", false), "exact temporary capacity reservation failed")
	_check(not runtime.reserve_capacity(state, "infrastructure:cooling:1", "entry-2", "facilities_engineer", "plant", "task-2").get("accepted", true), "one responder was reserved twice")
	_check(runtime.release_capacity(state, "entry-1").get("accepted", false), "temporary capacity release failed")
	_check(runtime.reserve_capacity(state, "infrastructure:cooling:1", "entry-2", "facilities_engineer", "plant", "task-2").get("accepted", false), "released responder could not be reserved again")
	_check(runtime.revoke_closed_occurrences(state, ["infrastructure:cooling:1"]).is_empty(), "active occurrence revoked capacity")
	var closed: Array[Dictionary] = runtime.revoke_closed_occurrences(state, [])
	_check(closed.size() == 1 and closed[0]["credential_id"] == "temp-1" and state["capacity_reservations"].is_empty(), "closed occurrence did not atomically revoke credential capacity")
	_check(not runtime.active_capacity(state, "infrastructure:cooling:1").get("accepted", true), "revoked responder retained capacity")
	_check(not runtime.revoke(state,id,"infrastructure:cooling:1").get("accepted",true), "revocation replay accepted")
	var live_facility = load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(live_facility)
	for _frame in 4: await get_tree().process_frame
	live_facility.set_service_available("cooling", false)
	var live_definition: Dictionary = live_facility.procedure_panel_definitions["cooling:enter_controlled_shutdown"]
	var live_admission: Dictionary = runtime.start_state(); var live_request: Dictionary = runtime.request(live_admission,"infrastructure:cooling:1",live_definition["actor_job"],live_definition["station"],"external-command-9",graph.mutual_aid_policy); var live_case: String=live_request["case_id"]
	runtime.advance(live_admission,live_case,"record_arrival",{"responder_id":"external-command-9","room":"screened_entry"}); runtime.advance(live_admission,live_case,"record_screening",{"actor_id":"guard-1","job":"security_officer","room":"screened_entry"}); runtime.advance(live_admission,live_case,"authorize",{"actor_id":"duty-1","job":"duty_officer","room":"cyber_ops"}); runtime.advance(live_admission,live_case,"issue_credential",{"credential_id":"temp-live","mode":"incident_scoped_temporary","occurrence_id":"infrastructure:cooling:1","destination":live_definition["station"]}); runtime.advance(live_admission,live_case,"assign_escort",{"actor_id":"guard-1","job":"security_officer","room":"security_control"}); var live_responder_route: Array=route_router.ordinary_room_path(live_facility.generated_route_plan,"screened_entry",live_definition["station"]); var live_escort_route: Array=runtime.compose_escort_route_via_staging(route_router.ordinary_room_path(live_facility.generated_route_plan,"security_control","screened_entry"),live_responder_route); runtime.advance(live_admission,live_case,"record_escorted_arrival",{"responder_id":"external-command-9","escort_id":"guard-1","responder_room":live_definition["station"],"escort_room":live_definition["station"],"responder_route":live_responder_route,"escort_route":live_escort_route}); runtime.complete_escorted_travel(live_admission,live_case)
	live_facility.mutual_aid_state = live_admission
	live_facility._sync_mutual_aid_locations()
	var expected_external_room: String = String(live_facility.mutual_aid_state.get("temporary_locations", {}).get("external-command-9", ""))
	var external_marker_found := false
	var external_marker_room := ""
	if live_facility.staffing_group != null:
		for child in live_facility.staffing_group.get_children():
			var is_external_marker: bool = child.name == "MutualAid_external-command-9" or (child.has_meta("temporary_mutual_aid") and bool(child.get_meta("temporary_mutual_aid")) and String(child.get_meta("person_id", "")) == "external-command-9")
			if not is_external_marker:
				continue
			external_marker_found = true
			external_marker_room = String(child.get_meta("current_room", ""))
			break
	_check(not live_facility.staff_agent_state.get("agents", {}).has("external-command-9"), "external mutual-aid responder entered staff agents")
	_check(external_marker_found and expected_external_room != "" and external_marker_room == expected_external_room, "admitted external mutual-aid marker missing or wrong current_room")
	if live_facility.staff_agent_state.get("agents", {}).has("guard-1"):
		_check(String(live_facility.staff_agent_state["agents"]["guard-1"].get("current_room", "")) == String(live_facility.mutual_aid_state.get("temporary_locations", {}).get("guard-1", "")), "bound escort agent room did not track temporary_locations")
	var live_candidate: Dictionary={"entry_id":"live-external-entry","panel_id":live_definition["panel_id"],"domain":"infrastructure","action":live_definition["action"],"actor_job":live_definition["actor_job"],"station":live_definition["station"],"base_priority":20,"deadline_ticks":3,"retry_backoff_ticks":2,"max_wait_ticks":9,"abandonment_action":"mobilize_qualified_relief"}
	var live_candidates: Array[Dictionary]=[live_candidate]; live_facility.operations_queue_runtime.advance(live_facility.operations_queue_state,live_candidates)
	var live_dispatch: Dictionary=live_facility.operations_queue_runtime.admit_external_work_dispatch(live_facility.operations_queue_state,live_facility.procedure_work_runtime,live_facility.procedure_work_state,live_facility.mutual_aid_runtime,live_facility.mutual_aid_state,"live-external-entry",live_definition,"infrastructure:cooling:1")
	var live_before_work: Dictionary=live_facility.procedure_work_state.duplicate(true); var live_before_queue: Dictionary=live_facility.operations_queue_state.duplicate(true); var live_before_mutual: Dictionary=live_facility.mutual_aid_state.duplicate(true)
	live_facility.operations_queue_state["entries"]["live-external-entry"]["task_id"]="forged-late-task"
	var rejected_live_tick: Dictionary=live_facility.tick_procedure_work()
	_check(rejected_live_tick.get("commits",[]).is_empty() and not rejected_live_tick.get("failures",[]).is_empty() and live_facility.infrastructure_runtime.service_phase(live_facility.infrastructure_state,"cooling")=="safe_hold" and live_facility.operations_queue_state["entries"]["live-external-entry"]["status"]=="dispatched", "late external finalization rejection did not roll back source authority")
	live_facility.procedure_work_state=live_before_work; live_facility.operations_queue_state=live_before_queue; live_facility.mutual_aid_state=live_before_mutual
	var live_tick: Dictionary=live_facility.tick_procedure_work()
	_check(live_dispatch.get("accepted",false) and not live_tick.get("commits",[]).is_empty() and live_tick["commits"][0].get("actor_person_id","")=="external-command-9" and live_facility.infrastructure_runtime.service_phase(live_facility.infrastructure_state,"cooling")=="controlled_shutdown" and live_facility.operations_queue_state["entries"]["live-external-entry"]["status"]=="resolved", "public live tick did not execute external cooling procedure")
	if cli.has("--external-journal-write"):
		var journaled: Dictionary=live_facility.commit_scene_journal("/tmp/blacksite_external_journal"); _check(journaled.get("accepted",false),"external response journal commit failed")
		print("EXTERNAL_JOURNAL_WRITER_OK" if fails==0 else "EXTERNAL_JOURNAL_WRITER_FAILED"); get_tree().quit(0 if fails==0 else 1); return
	var live_checkpoint: Dictionary=live_facility.export_scene_checkpoint(); if not live_checkpoint.get("accepted",false): print("LIVE_CHECKPOINT_REJECT ",live_checkpoint)
	_check(live_checkpoint.get("accepted",false),"resolved external response checkpoint export failed")
	var live_recovered=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(live_recovered)
	for _frame in 4: await get_tree().process_frame
	var forged_route_checkpoint: Dictionary=live_checkpoint.duplicate(true); forged_route_checkpoint["owners"]["mutual_aid"]["state"]["escort_routes"][live_case]["responder_route"]=["screened_entry","archive_stack"]
	var forged_route_recovery: Dictionary=live_recovered.recover_scene_checkpoint(forged_route_checkpoint)
	_check(not forged_route_recovery.get("accepted",true) and live_recovered.infrastructure_runtime.service_phase(live_recovered.infrastructure_state,"cooling")=="normal" and live_recovered.mutual_aid_state["cases"].is_empty(),"forged generated escort route mutated recovered authority")
	var live_recovery: Dictionary=live_recovered.recover_scene_checkpoint(live_checkpoint)
	var recovered_history: Array=live_recovered.infrastructure_state.get("history",[])
	_check(live_recovery.get("accepted",false) and live_recovered.infrastructure_runtime.service_phase(live_recovered.infrastructure_state,"cooling")=="controlled_shutdown" and live_recovered.operations_queue_state["entries"]["live-external-entry"]["status"]=="resolved" and live_recovered.procedure_work_state["tasks"][live_dispatch["task_id"]]["status"]=="committed" and live_recovered.mutual_aid_state["capacity_reservations"].is_empty() and live_recovered.mutual_aid_state["cases"][live_case]["phase"]=="admitted" and recovered_history[-1].get("actor_person_id","")=="external-command-9", "resolved external response did not recover across all owners")
	var facility = load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(facility)
	for _frame in 4: await get_tree().process_frame
	facility.mutual_aid_state = state.duplicate(true)
	var checkpoint: Dictionary = facility.export_scene_checkpoint()
	_check(checkpoint.get("accepted", false), "mutual-aid owner checkpoint export failed")
	var recovered = load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(recovered)
	for _frame in 4: await get_tree().process_frame
	_check(recovered.recover_scene_checkpoint(checkpoint).get("accepted", false), "mutual-aid owner checkpoint recovery failed")
	_check(recovered.mutual_aid_state["cases"][id]["phase"] == "revoked", "recovered mutual-aid lifecycle lost revocation")
	var orphan: Dictionary = checkpoint.duplicate(true); orphan["epoch"] = int(checkpoint["epoch"]) + 1
	for owner in orphan["owners"].values(): owner["epoch"] = orphan["epoch"]
	orphan["owners"]["mutual_aid"]["state"]["cases"][id]["phase"] = "admitted"
	orphan["owners"]["mutual_aid"]["state"]["capacity_reservations"]["ghost-entry"] = {"queue_entry_id":"ghost-entry","task_id":"ghost-task","case_id":id,"occurrence_id":"infrastructure:cooling:1","responder_id":"external-tech-7","response_job":"facilities_engineer","destination":"plant","credential_id":"temp-1"}
	_check(not recovered.recover_scene_checkpoint(orphan).get("accepted", true), "orphan mutual-aid reservation without queue dispatch was accepted")
	var forged: Dictionary = checkpoint.duplicate(true); forged["epoch"] = int(checkpoint["epoch"]) + 1
	for owner in forged["owners"].values(): owner["epoch"] = forged["epoch"]
	forged["owners"]["mutual_aid"]["state"]["cases"][id]["phase"] = "admitted"; forged["owners"]["mutual_aid"]["state"]["cases"][id]["credential_id"] = ""
	_check(not recovered.recover_scene_checkpoint(forged).get("accepted", true), "forged admitted responder without credential replaced live state")
	_check(recovered.mutual_aid_state["cases"][id]["phase"] == "revoked", "forgery rejection mutated live mutual-aid authority")
	print("=== facility_mutual_aid_selftest done fails=%d ===" % fails); get_tree().quit(0 if fails == 0 else 1)
func _run_panel_to_commit(facility: Node, panel_id: String) -> Dictionary:
	var definition: Dictionary=facility.procedure_panel_definitions.get(panel_id,{})
	if definition.is_empty(): return {"accepted":false,"reason":"panel missing"}
	var requested: Dictionary=facility.call("_request_procedure_work",definition,"journal_continuation")
	if not requested.get("accepted",false): return requested
	for _tick in 96:
		var result: Dictionary=facility.tick_procedure_work()
		if not result.get("commits",[]).is_empty(): return result["commits"][-1]
	return {"accepted":false,"reason":"panel work did not commit"}

func _check(v: bool, m: String) -> void:
	if not v: fails += 1; push_error("FAIL: %s" % m)
