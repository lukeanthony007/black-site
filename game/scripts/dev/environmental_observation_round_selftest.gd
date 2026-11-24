extends Node
var fails:=0
func _ready()->void:
	var cli: Array = OS.get_cmdline_user_args()
	if cli.has("--environmental-hazard-write"):
		var hazard_writer=await _prepare_mid_hazard_facility()
		var hazard_committed: Dictionary=hazard_writer.commit_scene_journal("/tmp/blacksite_environmental_hazard")
		_check(hazard_committed.get("accepted",false) and hazard_writer.environmental_observation_state.get("active_hazard_work",{}).get("remaining_ticks",-1)==1,"mid-hazard writer failed")
		print("ENVIRONMENTAL_HAZARD_WRITER_OK" if fails==0 else "ENVIRONMENTAL_HAZARD_WRITER_FAILED"); get_tree().quit(0 if fails==0 else 1); return
	if cli.has("--environmental-hazard-read"):
		var hazard_reader=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(hazard_reader); await get_tree().process_frame
		var hazard_loaded: Dictionary=hazard_reader.recover_scene_journal("/tmp/blacksite_environmental_hazard")
		var hazard_work: Dictionary=hazard_reader.environmental_observation_state.get("active_hazard_work",{}).duplicate(true)
		var hazard_denied: Dictionary=hazard_reader.tick_environmental_hazard_work({})
		var hazard_resumed: Dictionary=hazard_reader.resume_environmental_hazard_work(hazard_work.get("finding_id",""))
		var hazard_remediated: Dictionary=hazard_reader.tick_environmental_hazard_work({})
		var clear_archive: Dictionary={"archive_stack":{"water_intrusion":false,"smoke_or_local_alarm":false}}
		var hazard_verified_1: Dictionary=hazard_reader.tick_environmental_hazard_work(clear_archive)
		var hazard_verified_2: Dictionary=hazard_reader.tick_environmental_hazard_work(clear_archive)
		_check(hazard_loaded.get("accepted",false) and hazard_work.get("suspended",false) and hazard_work.get("remaining_ticks",-1)==1 and not hazard_denied.get("accepted",true) and hazard_resumed.get("accepted",false) and hazard_remediated.get("status","")=="verification_pending" and hazard_verified_1.get("status","")=="working" and hazard_verified_2.get("status","")=="closed" and hazard_reader.environmental_observation_state.get("hazard_closures",[]).size()==1 and hazard_reader.environmental_observation_state.get("protective_postures",{}).get("archive_stack","")=="safe_hold","mid-hazard reader lost suspension, exact work, closure, or protective hold")
		print("ENVIRONMENTAL_HAZARD_READER_OK" if fails==0 else "ENVIRONMENTAL_HAZARD_READER_FAILED"); get_tree().quit(0 if fails==0 else 1); return
	if cli.has("--environmental-release-write"):
		var release_writer=await _prepare_mid_release_facility()
		var release_committed: Dictionary=release_writer.commit_scene_journal("/tmp/blacksite_environmental_release")
		_check(release_committed.get("accepted",false) and release_writer.environmental_observation_state.get("active_release",{}).get("remaining_ticks",-1)==1,"mid-release writer failed")
		print("ENVIRONMENTAL_RELEASE_WRITER_OK" if fails==0 else "ENVIRONMENTAL_RELEASE_WRITER_FAILED"); get_tree().quit(0 if fails==0 else 1); return
	if cli.has("--environmental-release-read"):
		var release_reader=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(release_reader); await get_tree().process_frame
		var release_loaded: Dictionary=release_reader.recover_scene_journal("/tmp/blacksite_environmental_release")
		var release_before: int=release_reader.environmental_observation_state.get("active_release",{}).get("remaining_ticks",-1)
		var release_denied: Dictionary=release_reader.tick_environmental_protective_release()
		var release_resumed: Dictionary=release_reader.resume_environmental_protective_release("archive_stack")
		var release_completed: Dictionary=release_reader.tick_environmental_protective_release()
		_check(release_loaded.get("accepted",false) and release_before==1 and not release_denied.get("accepted",true) and release_reader.environmental_observation_state.get("releases",[]).size()==1 and release_resumed.get("accepted",false) and release_completed.get("status","")=="committed" and release_reader.mission_state.get("room_protective_postures",{}).is_empty(),"mid-release reader lost freeze/resume/commit semantics")
		print("ENVIRONMENTAL_RELEASE_READER_OK" if fails==0 else "ENVIRONMENTAL_RELEASE_READER_FAILED"); get_tree().quit(0 if fails==0 else 1); return
	if cli.has("--environmental-midround-write"):
		var writer=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(writer); await get_tree().process_frame
		var opened: Dictionary=writer.set_service_available("environmental_monitoring",false)
		var archive_readings: Dictionary={"temperature":18.0,"relative_humidity":42.0,"water_intrusion":false,"smoke_or_local_alarm":false}
		for _writer_tick in 16:
			writer.tick_environmental_observation_rounds({"archive_stack":archive_readings})
			if writer.environmental_observation_state["active_round"]["room_index"]==0 and writer.environmental_observation_state["active_round"]["remaining_ticks"]==1: break
		var committed: Dictionary=writer.commit_scene_journal("/tmp/blacksite_environmental_midround")
		_check(opened.get("accepted",false) and committed.get("accepted",false) and writer.environmental_observation_state["active_round"]["remaining_ticks"]==1,"midround writer failed")
		print("ENVIRONMENTAL_MIDROUND_WRITER_OK" if fails==0 else "ENVIRONMENTAL_MIDROUND_WRITER_FAILED"); get_tree().quit(0 if fails==0 else 1); return
	if cli.has("--environmental-midround-read"):
		var reader=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(reader); await get_tree().process_frame
		var loaded: Dictionary=reader.recover_scene_journal("/tmp/blacksite_environmental_midround")
		var before: int=reader.environmental_observation_state.get("active_round",{}).get("remaining_ticks",-1)
		var archive_readings: Dictionary={"temperature":18.0,"relative_humidity":42.0,"water_intrusion":false,"smoke_or_local_alarm":false}
		var denied: Dictionary=reader.tick_environmental_observation_rounds({"archive_stack":archive_readings})
		var after_denial: int=reader.environmental_observation_state.get("active_round",{}).get("remaining_ticks",-1)
		var occurrence_id: String=reader.environmental_observation_state.get("occurrence_id","")
		var resumed: Dictionary=reader.resume_environmental_observation_round(occurrence_id)
		var completed: Dictionary=reader.tick_environmental_observation_rounds({"archive_stack":archive_readings})
		_check(loaded.get("accepted",false) and before==1 and after_denial==before and not denied.get("accepted",true) and reader.environmental_observation_state["observations"].size()==1 and resumed.get("accepted",false) and completed.get("status","")=="room_recorded","midround reader lost freeze/resume semantics")
		print("ENVIRONMENTAL_MIDROUND_READER_OK" if fails==0 else "ENVIRONMENTAL_MIDROUND_READER_FAILED"); get_tree().quit(0 if fails==0 else 1); return
	var graph=load("res://scripts/facility/facility_operation_graph.gd").new(); graph.configure_cyber_archives(7319)
	var runtime=load("res://scripts/facility/environmental_observation_round_runtime.gd").new()
	var obligation: Dictionary=graph.service_continuity_profiles["environmental_monitoring"]["degraded_obligations"][0]
	var state: Dictionary=runtime.new_state()
	var actors: Dictionary={"archive_custodian":"archive-round-1","systems_administrator":"systems-round-1","security_officer":"security-round-1"}
	var opened: Dictionary=runtime.activate(state,"environmental-monitoring:1",obligation,actors)
	_check(opened.get("accepted",false),"manual observation authority did not activate")
	var blocked: Dictionary=runtime.tick(state,{"archive-round-1":"archive_processing"},{})
	_check(not blocked.get("accepted",true) and blocked.get("reason","")=="observer_not_at_room:archive_stack" and state["active_round"]["remaining_ticks"]==2,"round advanced without exact observer presence")
	var overdue_obligation: Dictionary=obligation.duplicate(true); overdue_obligation["max_round_ticks"]=6; overdue_obligation["escalation"]={"action":"review_protective_safe_hold","station":"security_control","actor_job":"duty_officer","decisions":["archive_safe_hold","compute_safe_shutdown","evacuate_affected_rooms"],"release":{"action":"release_protective_posture","authority_job":"duty_officer","authority_station":"security_control","concurrence_job":"archive_custodian","concurrence_station":"archive_processing","required_evidence":"monitoring_normal_and_post_decision_round","duration_ticks":2}}
	var overdue_state: Dictionary=runtime.new_state(); runtime.activate(overdue_state,"environmental-monitoring:overdue",overdue_obligation,actors)
	for _overdue_tick in 8: runtime.tick(overdue_state,{"archive-round-1":"archive_processing"},{})
	_check(overdue_state.get("escalations",[]).size()==1 and overdue_state["escalations"][0].get("action","")=="review_protective_safe_hold" and overdue_state["active_round"]["remaining_ticks"]==2,"overdue manual round did not emit one non-fabricated protective escalation")
	runtime.tick(overdue_state,{"archive-round-1":"archive_processing"},{})
	_check(overdue_state.get("escalations",[]).size()==1,"overdue manual round emitted duplicate escalations")
	var before_denied_decision: Dictionary=overdue_state.duplicate(true)
	var denied_decision: Dictionary=runtime.decide_escalation(overdue_state,1,"archive_safe_hold","archive conditions cannot be verified",{"person_id":"security-round-1","roles":["security_officer"],"current_room":"security_control"})
	_check(not denied_decision.get("accepted",true) and overdue_state==before_denied_decision,"unauthorized escalation decision mutated observation authority")
	var accepted_decision: Dictionary=runtime.decide_escalation(overdue_state,1,"archive_safe_hold","archive conditions cannot be verified",{"person_id":"duty-round-1","roles":["duty_officer"],"current_room":"security_control"})
	_check(accepted_decision.get("accepted",false) and overdue_state.get("decisions",[]).size()==1 and overdue_state.get("protective_postures",{}).get("archive_stack","")=="safe_hold" and overdue_state["active_round"]["remaining_ticks"]==2,"authorized escalation decision failed to project archive safe hold")
	_check(not runtime.decide_escalation(overdue_state,1,"compute_safe_shutdown","replay",{"person_id":"duty-round-1","roles":["duty_officer"],"current_room":"security_control"}).get("accepted",true),"escalation decision replay was accepted")
	var hazard_state: Dictionary=runtime.new_state(); runtime.activate(hazard_state,"environmental-monitoring:hazard",obligation,actors)
	var archive_water: Dictionary={"temperature":18.0,"relative_humidity":42.0,"water_intrusion":true,"smoke_or_local_alarm":false}
	runtime.tick(hazard_state,{"archive-round-1":"archive_stack"},{"archive_stack":archive_water}); runtime.tick(hazard_state,{"archive-round-1":"archive_stack"},{"archive_stack":archive_water})
	_check(hazard_state.get("hazard_findings",[]).size()==1 and hazard_state["hazard_findings"][0].get("classification","")=="archive_water_intrusion" and hazard_state["hazard_findings"][0].get("recommended_decision","")=="archive_safe_hold" and hazard_state.get("protective_postures",{}).is_empty(),"archive water observation was not classified or bypassed command authority")
	var hazard_presence: Dictionary={"archive-round-1":"archive_stack","systems-round-1":"compute_core","security-round-1":"security_control"}
	var hazard_normal_readings: Dictionary={"temperature":20.0,"relative_humidity":40.0,"water_intrusion":false,"smoke_or_local_alarm":false}
	for _finish_hazard_round in 4:
		var hazard_room: String=hazard_state["active_round"]["assignments"][hazard_state["active_round"]["room_index"]]["room"]
		runtime.tick(hazard_state,hazard_presence,{hazard_room:hazard_normal_readings})
	_check(runtime.close(hazard_state,"environmental-monitoring:hazard").get("reason","")=="unresolved_environmental_hazard" and hazard_state.get("active",false),"unresolved hazard did not hold observation authority open")
	var omitted_hazard_state: Dictionary=hazard_state.duplicate(true); omitted_hazard_state["hazard_findings"]=[]
	_check(not runtime.validate_state(omitted_hazard_state,obligation).is_empty(),"state validation admitted hazardous observation with omitted finding")
	var hazard_before_wrong_decision: Dictionary=hazard_state.duplicate(true)
	var wrong_hazard_decision: Dictionary=runtime.decide_hazard(hazard_state,hazard_state["hazard_findings"][0]["finding_id"],"compute_safe_shutdown","wrong protected domain",{"person_id":"duty-round-1","roles":["duty_officer"],"current_room":"security_control"})
	_check(not wrong_hazard_decision.get("accepted",true) and hazard_state==hazard_before_wrong_decision,"hazard command accepted non-recommended disposition or mutated evidence")
	var commanded_hazard: Dictionary=runtime.decide_hazard(hazard_state,hazard_state["hazard_findings"][0]["finding_id"],"archive_safe_hold","water observed in archive stack",{"person_id":"duty-round-1","roles":["duty_officer"],"current_room":"security_control"})
	_check(commanded_hazard.get("accepted",false) and hazard_state["hazard_findings"][0].get("status","")=="commanded" and hazard_state.get("hazard_decisions",[]).size()==1 and hazard_state.get("protective_postures",{}).get("archive_stack","")=="safe_hold","named duty authority did not command classified archive hazard")
	var remediation_requested: Dictionary=runtime.request_hazard_remediation(hazard_state,hazard_state["hazard_findings"][0]["finding_id"],{"person_id":"facility-round-1","roles":["facilities_engineer"],"current_room":"plant"},{"person_id":"archive-verify-1","roles":["archive_custodian"],"current_room":"archive_stack"})
	_check(remediation_requested.get("accepted",false) and hazard_state.get("active_hazard_work",{}).get("phase","")=="remediation" and hazard_state["active_hazard_work"].get("remaining_ticks",0)==2,"archive water remediation work did not start with named facilities authority")
	var remediation_before_wrong_room: Dictionary=hazard_state["active_hazard_work"].duplicate(true)
	var wrong_room_remediation: Dictionary=runtime.tick_hazard_work(hazard_state,{"facility-round-1":"security_control"},{})
	_check(not wrong_room_remediation.get("accepted",true) and hazard_state["active_hazard_work"]==remediation_before_wrong_room,"archive water remediation advanced without exact facilities station presence")
	var first_remediation_tick: Dictionary=runtime.tick_hazard_work(hazard_state,{"facility-round-1":"plant"},{})
	var second_remediation_tick: Dictionary=runtime.tick_hazard_work(hazard_state,{"facility-round-1":"plant"},{})
	_check(first_remediation_tick.get("status","")=="working" and second_remediation_tick.get("status","")=="verification_pending" and hazard_state.get("active_hazard_work",{}).get("phase","")=="verification" and hazard_state["active_hazard_work"].get("remaining_ticks",0)==2,"archive water remediation did not preserve separated verification work")
	var dry_verification: Dictionary={"water_intrusion":false,"smoke_or_local_alarm":false}
	var first_verification_tick: Dictionary=runtime.tick_hazard_work(hazard_state,{"archive-verify-1":"archive_stack"},{"archive_stack":dry_verification})
	var second_verification_tick: Dictionary=runtime.tick_hazard_work(hazard_state,{"archive-verify-1":"archive_stack"},{"archive_stack":dry_verification})
	_check(first_verification_tick.get("status","")=="working" and second_verification_tick.get("status","")=="closed" and hazard_state["hazard_findings"][0].get("status","")=="closed" and hazard_state.get("hazard_closures",[]).size()==1 and hazard_state.get("protective_postures",{}).get("archive_stack","")=="safe_hold","independent dry-room verification did not close finding while retaining command hold")
	_check(runtime.validate_state(hazard_state,obligation).is_empty(),"valid closed archive water finding failed state validation")
	var omitted_closure_state: Dictionary=hazard_state.duplicate(true); omitted_closure_state["hazard_closures"]=[]
	_check(not runtime.validate_state(omitted_closure_state,obligation).is_empty(),"checkpoint validation admitted closed hazard without closure evidence")
	_check(not runtime.decide_hazard(hazard_state,hazard_state["hazard_findings"][0]["finding_id"],"archive_safe_hold","replay",{"person_id":"duty-round-1","roles":["duty_officer"],"current_room":"security_control"}).get("accepted",true),"hazard decision replay was accepted")
	var presence: Dictionary={"archive-round-1":"archive_stack","systems-round-1":"compute_core","security-round-1":"security_control"}
	var readings: Dictionary={
		"archive_stack":{"temperature":18.0,"relative_humidity":42.0,"water_intrusion":false,"smoke_or_local_alarm":false},
		"compute_core":{"temperature":21.0,"relative_humidity":39.0,"water_intrusion":false,"smoke_or_local_alarm":false},
		"security_control":{"temperature":20.0,"relative_humidity":41.0,"water_intrusion":false,"smoke_or_local_alarm":false},
	}
	for _tick in 6: runtime.tick(state,presence,readings)
	_check(state["active_round"].is_empty() and state["completed_rounds"].size()==1 and state["observations"].size()==3,"timed round did not produce one record per protected room")
	_check(state["observations"][0].get("actor_person_id","")=="archive-round-1" and state["observations"][0].get("readings",{}).has("water_intrusion"),"observation lost named actor or hazard reading")
	_check(runtime.validate_state(state,obligation).is_empty(),"completed observation authority failed validation")
	var closed: Dictionary=runtime.close(state,"environmental-monitoring:1")
	_check(closed.get("accepted",false) and not state["active"] and state["observations"].size()==3,"restoration did not close rounds while retaining observations")
	var forged: Dictionary=state.duplicate(true); forged["observations"][0]["readings"].erase("water_intrusion")
	_check(not runtime.validate_state(forged,obligation).is_empty(),"observation authority admitted a record without water-intrusion evidence")
	var facility=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(facility); await get_tree().process_frame
	var failure: Dictionary=facility.set_service_available("environmental_monitoring",false)
	_check(failure.get("accepted",false) and facility.environmental_observation_state.get("active",false),"generated monitoring failure did not activate observation authority")
	var early_gate: Dictionary=facility.environmental_observation_restoration_gate(failure.get("failure_id",""))
	_check(not early_gate.get("accepted",true) and early_gate.get("reason","")=="manual observation round incomplete","monitoring restoration admitted before one complete manual round")
	for _scene_tick in 20:
		if not facility.environmental_observation_state.get("active_round",{}).is_empty():
			var assignment: Dictionary=facility.environmental_observation_state["active_round"]["assignments"][facility.environmental_observation_state["active_round"]["room_index"]]
			var scene_room: String=assignment["room"]
			facility.tick_environmental_observation_rounds({scene_room: readings[scene_room]})
		if facility.environmental_observation_state.get("completed_rounds",[]).size()==1: break
	_check(facility.environmental_observation_state.get("completed_rounds",[]).size()==1 and facility.environmental_observation_state.get("observations",[]).size()==3,"generated scene did not dispatch and complete manual observation round")
	_check(facility.environmental_observation_restoration_gate(failure.get("failure_id","")).get("accepted",false),"completed manual round did not release monitoring restoration gate")
	for scene_observation in facility.environmental_observation_state.get("observations",[]):
		_check(not String(scene_observation.get("actor_person_id","")).is_empty(),"generated observation lost named active-watch actor")
	var hazard_facility=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(hazard_facility); await get_tree().process_frame
	var hazard_failure: Dictionary=hazard_facility.set_service_available("environmental_monitoring",false)
	for _generated_hazard_tick in 20:
		var generated_hazard_round: Dictionary=hazard_facility.environmental_observation_state.get("active_round",{})
		if not generated_hazard_round.is_empty():
			var generated_hazard_room: String=generated_hazard_round["assignments"][generated_hazard_round["room_index"]]["room"]
			var generated_hazard_reading: Dictionary=readings[generated_hazard_room].duplicate(true)
			if generated_hazard_room=="archive_stack": generated_hazard_reading["water_intrusion"]=true
			hazard_facility.tick_environmental_observation_rounds({generated_hazard_room:generated_hazard_reading})
		if hazard_facility.environmental_observation_state.get("completed_rounds",[]).size()==1: break
	var generated_finding: Dictionary=hazard_facility.environmental_observation_state.get("hazard_findings",[])[0]
	var hazard_gate: Dictionary=hazard_facility.environmental_observation_restoration_gate(hazard_failure.get("failure_id",""))
	var hazard_authority: Dictionary={}
	for _hazard_authority_tick in 20:
		hazard_authority=hazard_facility.dispatch_environmental_hazard_authority(generated_finding["finding_id"])
		if hazard_authority.get("status","")=="ready": break
	var generated_hazard_decision: Dictionary=hazard_facility.decide_environmental_hazard(generated_finding["finding_id"],"archive_safe_hold","water observed in archive stack",hazard_authority.get("actor_person_id",""))
	_check(not hazard_gate.get("accepted",true) and generated_hazard_decision.get("accepted",false) and hazard_facility.environmental_observation_state.get("protective_postures",{}).get("archive_stack","")=="safe_hold" and hazard_facility.mission_state.get("room_protective_postures",{}).get("archive_stack","")=="safe_hold","generated hazard did not block restoration or project named command disposition")
	var generated_remediation: Dictionary={}
	for _hazard_remediation_dispatch_tick in 24:
		generated_remediation=hazard_facility.dispatch_environmental_hazard_remediation(generated_finding["finding_id"])
		if generated_remediation.get("status","")=="active": break
	var generated_remediation_tick_1: Dictionary=hazard_facility.tick_environmental_hazard_work({})
	var mid_remediation_checkpoint: Dictionary=hazard_facility.export_scene_checkpoint()
	var mid_remediation_reader=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(mid_remediation_reader); await get_tree().process_frame
	var mid_remediation_recovery: Dictionary=mid_remediation_reader.recover_scene_checkpoint(mid_remediation_checkpoint)
	_check(mid_remediation_recovery.get("accepted",false) and mid_remediation_reader.environmental_observation_state.get("active_hazard_work",{}).get("suspended",false) and mid_remediation_reader.environmental_observation_state["active_hazard_work"].get("remaining_ticks",-1)==1,"mid-remediation checkpoint did not recover suspended with exact remaining work")
	var premature_remediation_tick: Dictionary=mid_remediation_reader.tick_environmental_hazard_work({})
	var remediation_resume: Dictionary=mid_remediation_reader.resume_environmental_hazard_work(generated_finding["finding_id"])
	var generated_remediation_tick_2: Dictionary=mid_remediation_reader.tick_environmental_hazard_work({})
	var generated_verification_tick_1: Dictionary=mid_remediation_reader.tick_environmental_hazard_work({"archive_stack":dry_verification})
	var generated_verification_tick_2: Dictionary=mid_remediation_reader.tick_environmental_hazard_work({"archive_stack":dry_verification})
	_check(generated_remediation.get("status","")=="active" and generated_remediation_tick_1.get("status","")=="working" and mid_remediation_recovery.get("accepted",false) and mid_remediation_reader.environmental_observation_state.get("hazard_closures",[]).size()==1 and not premature_remediation_tick.get("accepted",true) and remediation_resume.get("accepted",false) and generated_remediation_tick_2.get("status","")=="verification_pending" and generated_verification_tick_1.get("status","")=="working" and generated_verification_tick_2.get("status","")=="closed" and mid_remediation_reader.environmental_observation_state["hazard_findings"][0].get("status","")=="closed" and mid_remediation_reader.environmental_observation_state.get("protective_postures",{}).get("archive_stack","")=="safe_hold","generated archive water remediation did not suspend on restart, reconcile exact actors, close evidence, and retain safe hold")
	var overdue_facility=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(overdue_facility); await get_tree().process_frame
	overdue_facility.set_service_available("environmental_monitoring",false)
	for _generated_overdue_tick in 32:
		overdue_facility.tick_environmental_observation_rounds({})
		if overdue_facility.environmental_observation_state.get("escalations",[]).size()==1: break
	_check(overdue_facility.environmental_observation_state.get("escalations",[]).size()==1,"generated scene did not escalate overdue observation coverage")
	var authority_ready: Dictionary={}
	for _authority_tick in 20:
		authority_ready=overdue_facility.dispatch_environmental_escalation_authority(1)
		if authority_ready.get("status","")=="ready": break
	var generated_decision: Dictionary=overdue_facility.decide_environmental_escalation(1,"archive_safe_hold","archive conditions cannot be verified",authority_ready.get("actor_person_id",""))
	_check(authority_ready.get("status","")=="ready" and generated_decision.get("accepted",false) and overdue_facility.environmental_observation_state.get("protective_postures",{}).get("archive_stack","")=="safe_hold","generated named duty authority failed to establish archive safe hold")
	var all_roles: Array=overdue_facility.operation_graph.jobs.keys()
	for custody_room in ["material_screening","archive_accession","quarantine"]: _check(overdue_facility.transfer_material(custody_room,all_roles).get("accepted",false),"custody setup failed before archive safe hold boundary")
	_check(overdue_facility.custody_runtime.clear_quarantine(overdue_facility.custody_state,{"roles":["accession_technician"]}).get("accepted",false),"custody quarantine setup did not clear")
	_check(overdue_facility.transfer_material("archive_processing",all_roles).get("accepted",false),"custody processing setup failed before archive safe hold boundary")
	var custody_before_hold_attempt: Dictionary=overdue_facility.custody_state.duplicate(true)
	var held_transfer: Dictionary=overdue_facility.transfer_material("archive_stack",all_roles)
	_check(not held_transfer.get("accepted",true) and held_transfer.get("reason","")=="destination under environmental protective posture: safe_hold" and overdue_facility.custody_state==custody_before_hold_attempt,"archive safe hold admitted or mutated custody transfer")
	var mission_prefix: Dictionary=overdue_facility.advance_mission(6)
	var mission_before_hold_attempt: Dictionary=overdue_facility.mission_state.duplicate(true)
	var held_mission: Dictionary=overdue_facility.advance_mission(1)
	_check(mission_prefix.get("status","")=="running" and held_mission.get("status","")=="blocked" and held_mission.get("blocked_posture","")=="safe_hold" and not overdue_facility.mission_state.get("artifacts",{}).has("preserved_record") and overdue_facility.mission_state.get("next_step_index",-1)==mission_before_hold_attempt.get("next_step_index",-2),"archive safe hold admitted preservation work or fabricated its output")
	var decision_checkpoint: Dictionary=overdue_facility.export_scene_checkpoint()
	var decision_reader=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(decision_reader); await get_tree().process_frame
	_check(decision_reader.recover_scene_checkpoint(decision_checkpoint).get("accepted",false) and decision_reader.environmental_observation_state.get("decisions",[]).size()==1 and decision_reader.environmental_observation_state.get("protective_postures",{}).get("archive_stack","")=="safe_hold","checkpoint recovery lost command decision or protective posture")
	var forged_decision_checkpoint: Dictionary=decision_checkpoint.duplicate(true); forged_decision_checkpoint["owners"]["environmental_observations"]["state"]["decisions"][0]["rationale"]=""
	var forged_decision_reader=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(forged_decision_reader); await get_tree().process_frame
	_check(not forged_decision_reader.recover_scene_checkpoint(forged_decision_checkpoint).get("accepted",false) and forged_decision_reader.environmental_observation_state.get("decisions",[]).is_empty(),"checkpoint admitted command decision without rationale")
	var split_posture_checkpoint: Dictionary=decision_checkpoint.duplicate(true); split_posture_checkpoint["owners"]["mission"]["state"]["room_protective_postures"]={}
	var split_posture_reader=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(split_posture_reader); await get_tree().process_frame
	_check(not split_posture_reader.recover_scene_checkpoint(split_posture_checkpoint).get("accepted",false) and split_posture_reader.environmental_observation_state.get("decisions",[]).is_empty(),"checkpoint admitted environmental decision without matching mission enforcement")
	for _release_observation_tick in 24:
		if not overdue_facility.environmental_observation_state.get("active_round",{}).is_empty():
			var release_assignment: Dictionary=overdue_facility.environmental_observation_state["active_round"]["assignments"][overdue_facility.environmental_observation_state["active_round"]["room_index"]]
			overdue_facility.tick_environmental_observation_rounds({release_assignment["room"]:readings[release_assignment["room"]]})
		if overdue_facility.environmental_observation_state.get("completed_rounds",[]).size()==1: break
	for recovery_panel in ["environmental_monitoring:establish_manual_sensor_rounds@security_control","environmental_monitoring:isolate_for_repair@plant","environmental_monitoring:begin_repair@plant","environmental_monitoring:record_repair@plant","environmental_monitoring:functional_test@plant","environmental_monitoring:verify_reconstitution@security_control"]:
		_check(_execute_generated_panel(overdue_facility,recovery_panel).get("status","")=="committed","environmental recovery panel failed before hold release: "+recovery_panel)
	_check(overdue_facility.infrastructure_runtime.service_phase(overdue_facility.infrastructure_state,"environmental_monitoring")=="normal" and overdue_facility.environmental_observation_state.get("protective_postures",{}).get("archive_stack","")=="safe_hold","monitoring restoration silently erased archive safe hold")
	var release_ready: Dictionary={}
	for _release_authority_tick in 24:
		release_ready=overdue_facility.dispatch_environmental_release_authorities("archive_stack")
		if release_ready.get("status","")=="ready": break
	var release_requested: Dictionary=overdue_facility.release_environmental_protective_posture("archive_stack","post-repair observation round complete",release_ready.get("authority_person_id",""),release_ready.get("concurrence_person_id",""))
	_check(release_requested.get("accepted",false) and release_requested.get("status","")=="release_work_started" and overdue_facility.environmental_observation_state.get("protective_postures",{}).get("archive_stack","")=="safe_hold","release request bypassed timed work or failed admission")
	var concurrence_id: String=release_ready.get("concurrence_person_id","")
	_check(overdue_facility.staff_agent_runtime.dispatch(overdue_facility.operation_graph,overdue_facility.staff_agent_state,concurrence_id,"archive_accession").get("accepted",false),"could not route concurrence actor away for interruption proof")
	for _leave_tick in 32:
		overdue_facility.staff_agent_runtime.tick(overdue_facility.staff_agent_state)
		if overdue_facility.staff_agent_runtime.is_at_room(overdue_facility.staff_agent_state,concurrence_id,"archive_accession"): break
	var release_remaining_before_denial: int=overdue_facility.environmental_observation_state.get("active_release",{}).get("remaining_ticks",-1)
	var interrupted_release: Dictionary=overdue_facility.tick_environmental_protective_release()
	_check(not interrupted_release.get("accepted",true) and overdue_facility.environmental_observation_state.get("active_release",{}).get("remaining_ticks",-2)==release_remaining_before_denial and overdue_facility.environmental_observation_state.get("protective_postures",{}).get("archive_stack","")=="safe_hold","release work advanced without continuous two-person presence")
	for _return_tick in 24:
		release_ready=overdue_facility.dispatch_environmental_release_authorities("archive_stack")
		if release_ready.get("status","")=="ready": break
	var first_release_tick: Dictionary=overdue_facility.tick_environmental_protective_release()
	var mid_release_checkpoint: Dictionary=overdue_facility.export_scene_checkpoint()
	var mid_release_reader=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(mid_release_reader); await get_tree().process_frame
	_check(mid_release_reader.recover_scene_checkpoint(mid_release_checkpoint).get("accepted",false) and mid_release_reader.environmental_observation_state.get("active_release",{}).get("suspended",false) and mid_release_reader.environmental_observation_state.get("active_release",{}).get("remaining_ticks",-1)==1,"mid-release checkpoint did not recover suspended with exact remaining work")
	var premature_release_tick: Dictionary=mid_release_reader.tick_environmental_protective_release()
	_check(not premature_release_tick.get("accepted",true) and mid_release_reader.environmental_observation_state.get("active_release",{}).get("remaining_ticks",-1)==1 and mid_release_reader.environmental_observation_state.get("protective_postures",{}).get("archive_stack","")=="safe_hold","recovered release work auto-resumed or erased hold")
	var resumed_release: Dictionary=mid_release_reader.resume_environmental_protective_release("archive_stack")
	var second_release_tick: Dictionary=mid_release_reader.tick_environmental_protective_release()
	_check(first_release_tick.get("status","")=="working" and resumed_release.get("accepted",false) and second_release_tick.get("status","")=="committed" and mid_release_reader.environmental_observation_state.get("protective_postures",{}).get("archive_stack","").is_empty(),"explicitly resumed two-person archive hold release failed")
	var released_facility=mid_release_reader
	_check(released_facility.transfer_material("archive_stack",all_roles).get("accepted",false) and released_facility.advance_mission(1).get("status","") in ["running","completed"] and released_facility.mission_state.get("artifacts",{}).has("preserved_record"),"released archive hold did not reopen custody and exact blocked mission work")
	_check(not released_facility.release_environmental_protective_posture("archive_stack","replay",release_ready.get("authority_person_id",""),release_ready.get("concurrence_person_id","")).get("accepted",true),"archive hold release replay was accepted")
	var release_checkpoint: Dictionary=released_facility.export_scene_checkpoint()
	var release_reader=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(release_reader); await get_tree().process_frame
	_check(release_reader.recover_scene_checkpoint(release_checkpoint).get("accepted",false) and release_reader.environmental_observation_state.get("releases",[]).size()==1 and release_reader.mission_state.get("room_protective_postures",{}).is_empty(),"checkpoint recovery lost archive hold release or retained stale mission block")
	var forged_release_checkpoint: Dictionary=release_checkpoint.duplicate(true); forged_release_checkpoint["owners"]["environmental_observations"]["state"]["releases"][0]["evidence_round_number"]=999
	var forged_release_reader=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(forged_release_reader); await get_tree().process_frame
	_check(not forged_release_reader.recover_scene_checkpoint(forged_release_checkpoint).get("accepted",false),"checkpoint admitted hold release without matching completed-round evidence")
	var observation_checkpoint: Dictionary=facility.export_scene_checkpoint()
	_check(observation_checkpoint.get("owners",{}).has("environmental_observations"),"composite checkpoint omitted environmental observation owner")
	var recovered_facility=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(recovered_facility); await get_tree().process_frame
	var forged_checkpoint: Dictionary=observation_checkpoint.duplicate(true)
	forged_checkpoint["owners"]["environmental_observations"]["state"]["observations"][0]["readings"].erase("water_intrusion")
	var forged_recovery: Dictionary=recovered_facility.recover_scene_checkpoint(forged_checkpoint)
	_check(not forged_recovery.get("accepted",false) and recovered_facility.environmental_observation_state.get("observations",[]).is_empty(),"corrupt observation checkpoint replaced live authority")
	var observation_recovery: Dictionary=recovered_facility.recover_scene_checkpoint(observation_checkpoint)
	_check(observation_recovery.get("accepted",false) and recovered_facility.environmental_observation_state.get("observations",[]).size()==3 and recovered_facility.environmental_observation_state.get("active",false),"fresh scene recovery lost active environmental observation evidence")
	var midpoint_facility=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(midpoint_facility); await get_tree().process_frame
	var midpoint_failure: Dictionary=midpoint_facility.set_service_available("environmental_monitoring",false)
	for _midpoint_tick in 16:
		var midpoint_round: Dictionary=midpoint_facility.environmental_observation_state["active_round"]
		var midpoint_room: String=midpoint_round["assignments"][midpoint_round["room_index"]]["room"]
		midpoint_facility.tick_environmental_observation_rounds({midpoint_room:readings[midpoint_room]})
		if midpoint_facility.environmental_observation_state["active_round"]["room_index"]==0 and midpoint_facility.environmental_observation_state["active_round"]["remaining_ticks"]==1: break
	var midpoint_checkpoint: Dictionary=midpoint_facility.export_scene_checkpoint()
	var midpoint_reader=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(midpoint_reader); await get_tree().process_frame
	_check(midpoint_reader.recover_scene_checkpoint(midpoint_checkpoint).get("accepted",false),"mid-room checkpoint recovery rejected")
	var recovered_remaining: int=midpoint_reader.environmental_observation_state["active_round"]["remaining_ticks"]
	var premature_tick: Dictionary=midpoint_reader.tick_environmental_observation_rounds({"archive_stack":readings["archive_stack"]})
	_check(not premature_tick.get("accepted",true) and premature_tick.get("reason","")=="observation round requires explicit resume" and midpoint_reader.environmental_observation_state["active_round"]["remaining_ticks"]==recovered_remaining,"recovered observation work auto-resumed or lost remaining duration")
	_check(midpoint_reader.resume_environmental_observation_round(midpoint_failure.get("failure_id","")).get("accepted",false),"explicit observation resume rejected at recovered room")
	_check(midpoint_reader.tick_environmental_observation_rounds({"archive_stack":readings["archive_stack"]}).get("status","")=="room_recorded","resumed observation did not finish exact remaining work")
	var handoff_facility=await _prepare_mid_release_facility()
	var handoff_before: Dictionary=handoff_facility.environmental_observation_state["active_release"].duplicate(true)
	var release_turnover: Dictionary=handoff_facility.turnover_shift("swing")
	var handoff_after: Dictionary=handoff_facility.environmental_observation_state.get("active_release",{})
	_check(release_turnover.get("accepted",false) and handoff_after.get("remaining_ticks",-1)==handoff_before.get("remaining_ticks",-2) and handoff_after.get("authority_person_id","")!=handoff_before.get("authority_person_id","") and handoff_after.get("concurrence_person_id","")!=handoff_before.get("concurrence_person_id","") and handoff_after.get("suspended",false) and handoff_after.get("handoffs",[]).size()==2,"shift turnover did not hand unfinished release to distinct incoming authorities without progress")
	var handoff_checkpoint: Dictionary=handoff_facility.export_scene_checkpoint()
	var handoff_reader=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(handoff_reader); await get_tree().process_frame
	_check(handoff_reader.recover_scene_checkpoint(handoff_checkpoint).get("accepted",false) and handoff_reader.environmental_observation_state.get("active_release",{}).get("handoffs",[]).size()==2 and handoff_reader.environmental_observation_state.get("active_release",{}).get("remaining_ticks",-1)==handoff_before.get("remaining_ticks",-2),"checkpoint recovery lost two-person release handoff provenance")
	var forged_handoff_checkpoint: Dictionary=handoff_checkpoint.duplicate(true); forged_handoff_checkpoint["owners"]["environmental_observations"]["state"]["active_release"]["handoffs"][0]["turnover_id"]=""
	var forged_handoff_reader=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(forged_handoff_reader); await get_tree().process_frame
	_check(not forged_handoff_reader.recover_scene_checkpoint(forged_handoff_checkpoint).get("accepted",false) and forged_handoff_reader.environmental_observation_state.get("active_release",{}).is_empty(),"checkpoint admitted release handoff without turnover provenance")
	handoff_facility=handoff_reader
	var handoff_ready: Dictionary={}
	for _handoff_route_tick in 24:
		handoff_ready=handoff_facility.dispatch_environmental_release_authorities("archive_stack")
		if handoff_ready.get("status","")=="ready": break
	_check(handoff_facility.resume_environmental_protective_release("archive_stack").get("accepted",false) and handoff_facility.tick_environmental_protective_release().get("status","")=="committed","incoming release authorities could not resume exact remaining work")
	var adverse_facility=await _prepare_mid_release_facility()
	for missing_job in ["duty_officer","archive_custodian"]:
		var prior_unavailable: Dictionary=adverse_facility.staffing_state["unavailable"].duplicate(true)
		for unavailable_id in adverse_facility.staffing_runtime.all_staff_ids_for_job(adverse_facility.staffing_state,missing_job): adverse_facility.staffing_state["unavailable"][unavailable_id]=true
		var adverse_release_before: Dictionary=adverse_facility.environmental_observation_state["active_release"].duplicate(true)
		var adverse_mission_before: Dictionary=adverse_facility.mission_state.duplicate(true)
		var adverse_custody_before: Dictionary=adverse_facility.custody_state.duplicate(true)
		var adverse_turnover: Dictionary=adverse_facility.turnover_shift("swing")
		_check(not adverse_turnover.get("accepted",true) and adverse_facility.staffing_state.get("active_shift","")=="day" and adverse_facility.staffing_state.get("pending_turnover",{}).is_empty() and adverse_facility.environmental_observation_state.get("active_release",{})==adverse_release_before and adverse_facility.mission_state==adverse_mission_before and adverse_facility.custody_state==adverse_custody_before,"missing incoming "+missing_job+" did not cancel turnover without authority drift")
		adverse_facility.staffing_state["unavailable"]=prior_unavailable
	var hazard_turnover_facility=await _prepare_mid_hazard_facility()
	var hazard_work_before_turnover: Dictionary=hazard_turnover_facility.environmental_observation_state.get("active_hazard_work",{}).duplicate(true)
	var hazard_turnover: Dictionary=hazard_turnover_facility.turnover_shift("swing")
	var hazard_work_after_turnover: Dictionary=hazard_turnover_facility.environmental_observation_state.get("active_hazard_work",{})
	_check(hazard_turnover.get("accepted",false) and hazard_turnover_facility.staffing_state.get("active_shift","")=="swing" and hazard_work_after_turnover.get("actor_person_id","")!=hazard_work_before_turnover.get("actor_person_id","") and hazard_work_after_turnover.get("verification_person_id","")!=hazard_work_before_turnover.get("verification_person_id","") and hazard_work_after_turnover.get("remaining_ticks",-1)==hazard_work_before_turnover.get("remaining_ticks",-2) and hazard_work_after_turnover.get("handoffs",[]).size()==2 and hazard_work_after_turnover.get("suspended",false) and hazard_work_after_turnover.get("suspension_reason","")=="shift_handoff_reconciliation" and hazard_turnover_facility.environmental_observation_state.get("protective_postures",{}).get("archive_stack","")=="safe_hold","active archive remediation did not transfer both named authorities across shift without advancing work or clearing hold")
	var incoming_hazard_ready: Dictionary={}
	for _incoming_hazard_route_tick in 24:
		incoming_hazard_ready=hazard_turnover_facility.dispatch_environmental_hazard_remediation(hazard_work_after_turnover["finding_id"])
		if incoming_hazard_ready.get("status","")=="ready": break
	var incoming_hazard_resume: Dictionary=hazard_turnover_facility.resume_environmental_hazard_work(hazard_work_after_turnover["finding_id"])
	var incoming_remediation_completed: Dictionary=hazard_turnover_facility.tick_environmental_hazard_work({})
	var incoming_verification_tick_1: Dictionary=hazard_turnover_facility.tick_environmental_hazard_work({"archive_stack":dry_verification})
	var incoming_verification_tick_2: Dictionary=hazard_turnover_facility.tick_environmental_hazard_work({"archive_stack":dry_verification})
	var turnover_closures: Array=hazard_turnover_facility.environmental_observation_state.get("hazard_closures",[])
	var turnover_closure: Dictionary={} if turnover_closures.is_empty() else turnover_closures[0]
	var turnover_closure_checkpoint: Dictionary=hazard_turnover_facility.export_scene_checkpoint()
	var turnover_closure_reader=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(turnover_closure_reader); await get_tree().process_frame
	var turnover_closure_recovery: Dictionary=turnover_closure_reader.recover_scene_checkpoint(turnover_closure_checkpoint)
	_check(incoming_hazard_ready.get("status","")=="ready" and incoming_hazard_resume.get("accepted",false) and incoming_remediation_completed.get("status","")=="verification_pending" and incoming_verification_tick_1.get("status","")=="working" and incoming_verification_tick_2.get("status","")=="closed" and turnover_closure.get("handoffs",[]).size()==2 and turnover_closure.get("remediation_actor_person_id","")==hazard_work_after_turnover.get("actor_person_id","") and turnover_closure.get("verification_actor_person_id","")==hazard_work_after_turnover.get("verification_person_id","") and turnover_closure_recovery.get("accepted",false) and turnover_closure_reader.environmental_observation_state.get("hazard_closures",[])[0].get("handoffs",[]).size()==2 and turnover_closure_reader.environmental_observation_state.get("protective_postures",{}).get("archive_stack","")=="safe_hold","incoming hazard watch did not route, reconcile, finish exact work, and retain handoff provenance through closure recovery")
	var compute_hazard_facility=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(compute_hazard_facility); await get_tree().process_frame
	compute_hazard_facility.set_service_available("environmental_monitoring",false)
	var compute_hazard_readings: Dictionary=readings.duplicate(true); compute_hazard_readings["compute_core"]["water_intrusion"]=true
	for _compute_observation_tick in 24:
		var compute_round: Dictionary=compute_hazard_facility.environmental_observation_state.get("active_round",{})
		if not compute_round.is_empty():
			var compute_assignment: Dictionary=compute_round["assignments"][compute_round["room_index"]]
			compute_hazard_facility.tick_environmental_observation_rounds({compute_assignment["room"]:compute_hazard_readings[compute_assignment["room"]]})
		if compute_hazard_facility.environmental_observation_state.get("completed_rounds",[]).size()==1: break
	var compute_finding: Dictionary=compute_hazard_facility.environmental_observation_state.get("hazard_findings",[])[0]
	var compute_authority: Dictionary={}
	for _compute_authority_tick in 24:
		compute_authority=compute_hazard_facility.dispatch_environmental_hazard_authority(compute_finding["finding_id"])
		if compute_authority.get("status","")=="ready": break
	var compute_decision: Dictionary=compute_hazard_facility.decide_environmental_hazard(compute_finding["finding_id"],"compute_safe_shutdown","water observed in compute core",compute_authority.get("actor_person_id",""))
	var compute_mission_prefix: Dictionary=compute_hazard_facility.advance_mission(7)
	var compute_mission_before_block: Dictionary=compute_hazard_facility.mission_state.duplicate(true)
	var compute_mission_blocked: Dictionary=compute_hazard_facility.advance_mission(1)
	var compute_remediation: Dictionary={}
	for _compute_remediation_dispatch_tick in 24:
		compute_remediation=compute_hazard_facility.dispatch_environmental_hazard_remediation(compute_finding["finding_id"])
		if compute_remediation.get("status","")=="active": break
	var compute_remediation_tick_1: Dictionary=compute_hazard_facility.tick_environmental_hazard_work({})
	var compute_remediation_tick_2: Dictionary=compute_hazard_facility.tick_environmental_hazard_work({})
	var clear_compute: Dictionary={"compute_core":dry_verification}
	var compute_verification_tick_1: Dictionary=compute_hazard_facility.tick_environmental_hazard_work(clear_compute)
	var compute_verification_tick_2: Dictionary=compute_hazard_facility.tick_environmental_hazard_work(clear_compute)
	var compute_closures: Array=compute_hazard_facility.environmental_observation_state.get("hazard_closures",[])
	var compute_closure: Dictionary={} if compute_closures.is_empty() else compute_closures[0]
	_check(compute_finding.get("classification","")=="compute_water_intrusion" and compute_decision.get("accepted",false) and compute_hazard_facility.environmental_observation_state.get("protective_postures",{}).get("compute_core","")=="safe_shutdown" and compute_mission_prefix.get("status","")=="running" and compute_mission_blocked.get("status","")=="blocked" and compute_mission_blocked.get("blocked_posture","")=="safe_shutdown" and compute_hazard_facility.mission_state.get("next_step_index",-1)==compute_mission_before_block.get("next_step_index",-2) and not compute_hazard_facility.mission_state.get("artifacts",{}).has("restored_baseline") and compute_remediation.get("status","")=="active" and compute_remediation_tick_1.get("status","")=="working" and compute_remediation_tick_2.get("status","")=="verification_pending" and compute_verification_tick_1.get("status","")=="working" and compute_verification_tick_2.get("status","")=="closed" and compute_closure.get("verification_actor_job","")=="systems_administrator" and compute_hazard_facility.environmental_observation_state.get("protective_postures",{}).get("compute_core","")=="safe_shutdown","compute water intrusion did not shut down workload, run separated remediation, close finding, and retain controlled shutdown")
	var compute_reactivation_ready: Dictionary={}
	for _compute_reactivation_route_tick in 24:
		compute_reactivation_ready=compute_hazard_facility.dispatch_environmental_compute_reactivation(compute_finding["finding_id"])
		if compute_reactivation_ready.get("status","")=="ready": break
	var premature_compute_reactivation: Dictionary=compute_hazard_facility.reactivate_environmental_compute(compute_finding["finding_id"],"restart after verified dry condition",compute_reactivation_ready.get("authority_person_id",""),compute_reactivation_ready.get("concurrence_person_id",""))
	for panel_id in ["environmental_monitoring:establish_manual_sensor_rounds@security_control","environmental_monitoring:isolate_for_repair@plant","environmental_monitoring:begin_repair@plant","environmental_monitoring:record_repair@plant","environmental_monitoring:functional_test@plant","environmental_monitoring:verify_reconstitution@security_control"]: _execute_generated_panel(compute_hazard_facility,panel_id)
	var started_compute_reactivation: Dictionary=compute_hazard_facility.reactivate_environmental_compute(compute_finding["finding_id"],"restart after verified dry condition",compute_reactivation_ready.get("authority_person_id",""),compute_reactivation_ready.get("concurrence_person_id",""))
	var compute_reactivation_tick_1: Dictionary=compute_hazard_facility.tick_environmental_compute_reactivation()
	var compute_posture_during_reactivation: String=compute_hazard_facility.environmental_observation_state.get("protective_postures",{}).get("compute_core","")
	var mid_compute_reactivation_checkpoint: Dictionary=compute_hazard_facility.export_scene_checkpoint()
	var mid_compute_reactivation_reader=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(mid_compute_reactivation_reader); await get_tree().process_frame
	var mid_compute_reactivation_recovery: Dictionary=mid_compute_reactivation_reader.recover_scene_checkpoint(mid_compute_reactivation_checkpoint)
	var mid_compute_reactivation_suspended: bool=mid_compute_reactivation_reader.environmental_observation_state.get("active_compute_reactivation",{}).get("suspended",false)
	var mid_compute_reactivation_remaining: int=mid_compute_reactivation_reader.environmental_observation_state.get("active_compute_reactivation",{}).get("remaining_ticks",0)
	var mid_compute_reactivation_events_empty: bool=mid_compute_reactivation_reader.environmental_observation_state.get("compute_reactivations",[]).is_empty()
	var denied_compute_reactivation_tick: Dictionary=mid_compute_reactivation_reader.tick_environmental_compute_reactivation()
	var resumed_compute_reactivation_work: Dictionary=mid_compute_reactivation_reader.resume_environmental_compute_reactivation(compute_finding["finding_id"])
	var compute_reactivation_tick_2: Dictionary=mid_compute_reactivation_reader.tick_environmental_compute_reactivation()
	var resumed_compute_mission: Dictionary=mid_compute_reactivation_reader.advance_mission(1)
	_check(not premature_compute_reactivation.get("accepted",true) and compute_hazard_facility.infrastructure_state["service_states"]["environmental_monitoring"].get("phase","")=="normal" and started_compute_reactivation.get("accepted",false) and started_compute_reactivation.get("remaining_ticks",0)==2 and compute_reactivation_tick_1.get("status","")=="working" and compute_posture_during_reactivation=="safe_shutdown" and mid_compute_reactivation_recovery.get("accepted",false) and mid_compute_reactivation_events_empty and mid_compute_reactivation_suspended and mid_compute_reactivation_remaining==1 and not denied_compute_reactivation_tick.get("accepted",true) and resumed_compute_reactivation_work.get("accepted",false) and compute_reactivation_tick_2.get("status","")=="committed" and mid_compute_reactivation_reader.environmental_observation_state.get("protective_postures",{}).get("compute_core","").is_empty() and resumed_compute_mission.get("status","") in ["running","completed"] and mid_compute_reactivation_reader.mission_state.get("artifacts",{}).has("restored_baseline"),"compute reactivation bypassed monitoring restoration, auto-resumed after restart, cleared shutdown early, or failed exact workload")
	var compute_reactivation_checkpoint: Dictionary=mid_compute_reactivation_reader.export_scene_checkpoint()
	var compute_reactivation_reader=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(compute_reactivation_reader); await get_tree().process_frame
	var recovered_compute_reactivation: Dictionary=compute_reactivation_reader.recover_scene_checkpoint(compute_reactivation_checkpoint)
	var forged_compute_reactivation_checkpoint: Dictionary={}
	if compute_reactivation_checkpoint.has("owners"):
		forged_compute_reactivation_checkpoint=compute_reactivation_checkpoint.duplicate(true); forged_compute_reactivation_checkpoint["owners"]["environmental_observations"]["state"]["compute_reactivations"][0]["rationale"]=""
	var forged_compute_reactivation_reader=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(forged_compute_reactivation_reader); await get_tree().process_frame
	_check(recovered_compute_reactivation.get("accepted",false) and compute_reactivation_reader.environmental_observation_state.get("compute_reactivations",[]).size()==1 and compute_reactivation_reader.environmental_observation_state.get("protective_postures",{}).get("compute_core","").is_empty() and not forged_compute_reactivation_reader.recover_scene_checkpoint(forged_compute_reactivation_checkpoint).get("accepted",false) and forged_compute_reactivation_reader.environmental_observation_state.get("compute_reactivations",[]).is_empty(),"compute reactivation checkpoint lost terminal authority or admitted missing rationale")
	var archive_fire_facility=await _prepare_archive_fire_facility()
	var archive_fire_finding: Dictionary=archive_fire_facility.environmental_observation_state["hazard_findings"][0]
	var archive_evacuation_started: Dictionary=archive_fire_facility.dispatch_environmental_room_evacuation(archive_fire_finding["finding_id"])
	var archive_evacuation_roster: Array=archive_fire_facility.environmental_observation_state.get("active_room_evacuation",{}).get("roster",[]).duplicate(true)
	var evacuation_route_was_physical: bool=not archive_evacuation_roster.is_empty() and not (archive_fire_facility.staff_agent_state["agents"][archive_evacuation_roster[0]["person_id"]].get("route",[]) as Array).is_empty() and archive_fire_facility.staff_agent_state["agents"][archive_evacuation_roster[0]["person_id"]].get("destination","")=="emergency_exit"
	var archive_evacuation_progress: Dictionary={}
	for _evacuation_tick in 24:
		archive_evacuation_progress=archive_fire_facility.tick_environmental_room_evacuation()
		if archive_evacuation_progress.get("status","")=="accounted": break
	var archive_evacuation_record: Dictionary={} if archive_fire_facility.environmental_observation_state.get("room_evacuations",[]).is_empty() else archive_fire_facility.environmental_observation_state["room_evacuations"][0]
	var all_archive_occupants_at_egress:=true
	for roster_entry in archive_evacuation_roster:
		if archive_fire_facility.staff_agent_state["agents"][roster_entry["person_id"]].get("current_room","")!="emergency_exit": all_archive_occupants_at_egress=false
	var reentry_candidate: String=archive_fire_facility.get_meta("reentry_candidate","")
	var reentry_location_before: String=archive_fire_facility.staff_agent_state["agents"][reentry_candidate]["current_room"]
	var denied_archive_reentry: Dictionary=archive_fire_facility.staff_agent_runtime.dispatch(archive_fire_facility.operation_graph,archive_fire_facility.staff_agent_state,reentry_candidate,"archive_stack")
	var fire_stabilization: Dictionary={}
	for _fire_stabilization_dispatch_tick in 24:
		fire_stabilization=archive_fire_facility.dispatch_environmental_hazard_remediation(archive_fire_finding["finding_id"])
		if fire_stabilization.get("status","")=="active": break
	var fire_stabilization_tick_1: Dictionary=archive_fire_facility.tick_environmental_hazard_work({})
	var fire_stabilization_tick_2: Dictionary=archive_fire_facility.tick_environmental_hazard_work({})
	var clear_alarm: Dictionary={"security_control":{"water_intrusion":false,"smoke_or_local_alarm":false}}
	var fire_verification_tick_1: Dictionary=archive_fire_facility.tick_environmental_hazard_work(clear_alarm)
	var fire_verification_tick_2: Dictionary=archive_fire_facility.tick_environmental_hazard_work(clear_alarm)
	var denied_archive_reentry_after_stabilization: Dictionary=archive_fire_facility.staff_agent_runtime.dispatch(archive_fire_facility.operation_graph,archive_fire_facility.staff_agent_state,reentry_candidate,"archive_stack")
	var fire_closure: Dictionary={} if archive_fire_facility.environmental_observation_state.get("hazard_closures",[]).is_empty() else archive_fire_facility.environmental_observation_state["hazard_closures"][0]
	var fire_verification_samples: Array=fire_closure.get("verification_samples",[])
	var fire_samples_exact:=fire_verification_samples.size()==2
	for sample in fire_verification_samples:
		if sample.get("station","")!="security_control" or sample.get("readings",{})!={"water_intrusion":false,"smoke_or_local_alarm":false}: fire_samples_exact=false
	var inspection_case_result: Dictionary=archive_fire_facility.mutual_aid_runtime.request(archive_fire_facility.mutual_aid_state,archive_fire_finding["finding_id"],"fire_scene_inspector","archive_stack","external-fire-inspector-1",archive_fire_facility.operation_graph.mutual_aid_policy)
	var inspection_case_id: String=inspection_case_result.get("case_id","")
	var route_runtime=load("res://scripts/facility/facility_route_router.gd").new()
	var responder_inspection_route: Array=route_runtime.ordinary_room_path(archive_fire_facility.generated_route_plan,"screened_entry","archive_stack")
	var escort_to_staging: Array=route_runtime.ordinary_room_path(archive_fire_facility.generated_route_plan,"security_control","screened_entry")
	var escort_inspection_route: Array=archive_fire_facility.mutual_aid_runtime.compose_escort_route_via_staging(escort_to_staging,responder_inspection_route)
	archive_fire_facility.mutual_aid_runtime.advance(archive_fire_facility.mutual_aid_state,inspection_case_id,"record_arrival",{"responder_id":"external-fire-inspector-1","room":"screened_entry"})
	archive_fire_facility.mutual_aid_runtime.advance(archive_fire_facility.mutual_aid_state,inspection_case_id,"record_screening",{"actor_id":"fire-screening-officer","job":"security_officer","room":"screened_entry"})
	archive_fire_facility.mutual_aid_runtime.advance(archive_fire_facility.mutual_aid_state,inspection_case_id,"authorize",{"actor_id":"fire-duty-authority","job":"duty_officer","room":"cyber_ops"})
	archive_fire_facility.mutual_aid_runtime.advance(archive_fire_facility.mutual_aid_state,inspection_case_id,"issue_credential",{"credential_id":"fire-inspection-credential-1","mode":"incident_scoped_temporary","occurrence_id":archive_fire_finding["finding_id"],"destination":"archive_stack"})
	archive_fire_facility.mutual_aid_runtime.advance(archive_fire_facility.mutual_aid_state,inspection_case_id,"assign_escort",{"actor_id":"fire-escort-officer","job":"security_officer","room":"security_control"})
	var began_inspector: Dictionary=archive_fire_facility.mutual_aid_runtime.advance(archive_fire_facility.mutual_aid_state,inspection_case_id,"record_escorted_arrival",{"responder_id":"external-fire-inspector-1","escort_id":"fire-escort-officer","responder_room":"archive_stack","escort_room":"archive_stack","responder_route":responder_inspection_route,"escort_route":escort_inspection_route})
	var admitted_inspector: Dictionary=archive_fire_facility.mutual_aid_runtime.complete_escorted_travel(archive_fire_facility.mutual_aid_state,inspection_case_id)
	var fire_inspection_started: Dictionary=archive_fire_facility.begin_environmental_fire_inspection(archive_fire_finding["finding_id"],fire_closure["closure_id"],"physical scene inspection after alarm stabilization")
	var physical_clearance: Dictionary={"no_active_fire":true,"atmosphere_safe_for_entry":true,"structural_access_safe":true}
	var fire_inspection_tick_1: Dictionary=archive_fire_facility.tick_environmental_fire_inspection(physical_clearance)
	var fire_inspection_tick_2: Dictionary=archive_fire_facility.tick_environmental_fire_inspection(physical_clearance)
	var fire_inspection_record: Dictionary={} if archive_fire_facility.environmental_observation_state.get("fire_inspections",[]).is_empty() else archive_fire_facility.environmental_observation_state["fire_inspections"][0]
	var denied_archive_reentry_after_inspection: Dictionary=archive_fire_facility.staff_agent_runtime.dispatch(archive_fire_facility.operation_graph,archive_fire_facility.staff_agent_state,reentry_candidate,"archive_stack")
	var reentry_started: Dictionary=archive_fire_facility.begin_environmental_room_reentry(archive_fire_finding["finding_id"],fire_inspection_record["inspection_id"],"restore archive access after physical clearance")
	var reentry_tick_1: Dictionary=archive_fire_facility.tick_environmental_room_reentry()
	var posture_after_first_reentry_tick: String=archive_fire_facility.environmental_observation_state.get("protective_postures",{}).get("archive_stack","")
	var mid_reentry_checkpoint: Dictionary=archive_fire_facility.export_scene_checkpoint()
	var recovered_reentry_facility=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(recovered_reentry_facility); await get_tree().process_frame
	var recovered_mid_reentry: Dictionary=recovered_reentry_facility.recover_scene_checkpoint(mid_reentry_checkpoint)
	var automatic_reentry_after_restart: Dictionary=recovered_reentry_facility.tick_environmental_room_reentry()
	var reentry_turnover: Dictionary=recovered_reentry_facility.turnover_shift("swing")
	var handed_reentry: Dictionary=recovered_reentry_facility.environmental_observation_state.get("active_room_reentry",{}).duplicate(true)
	for participant in ["authority","concurrence"]:
		var incoming_id: String=handed_reentry[participant+"_person_id"]; var station: String=handed_reentry[participant+"_station"]
		if not recovered_reentry_facility.staff_agent_runtime.is_at_room(recovered_reentry_facility.staff_agent_state,incoming_id,station): recovered_reentry_facility.staff_agent_runtime.dispatch(recovered_reentry_facility.operation_graph,recovered_reentry_facility.staff_agent_state,incoming_id,station)
	for _route_tick in 8:
		if recovered_reentry_facility.staff_agent_runtime.is_at_room(recovered_reentry_facility.staff_agent_state,handed_reentry["authority_person_id"],handed_reentry["authority_station"]) and recovered_reentry_facility.staff_agent_runtime.is_at_room(recovered_reentry_facility.staff_agent_state,handed_reentry["concurrence_person_id"],handed_reentry["concurrence_station"]): break
		recovered_reentry_facility.staff_agent_runtime.tick(recovered_reentry_facility.staff_agent_state)
	var resumed_reentry: Dictionary=recovered_reentry_facility.resume_environmental_room_reentry(archive_fire_finding["finding_id"])
	var recovered_reentry_commit: Dictionary=recovered_reentry_facility.tick_environmental_room_reentry()
	var reentry_tick_2: Dictionary=archive_fire_facility.tick_environmental_room_reentry()
	var admitted_archive_return: Dictionary=archive_fire_facility.staff_agent_runtime.dispatch(archive_fire_facility.operation_graph,archive_fire_facility.staff_agent_state,reentry_candidate,"archive_stack")
	var reentry_record: Dictionary={} if archive_fire_facility.environmental_observation_state.get("room_reentries",[]).is_empty() else archive_fire_facility.environmental_observation_state["room_reentries"][0]
	_check(archive_fire_finding.get("classification","")=="archive_fire_or_local_alarm" and archive_evacuation_started.get("accepted",false) and not archive_evacuation_roster.is_empty() and evacuation_route_was_physical and archive_evacuation_progress.get("status","")=="accounted" and archive_evacuation_record.get("roster",[])==archive_evacuation_roster and all_archive_occupants_at_egress and not denied_archive_reentry.get("accepted",true) and fire_stabilization.get("status","")=="active" and fire_stabilization_tick_1.get("status","")=="working" and fire_stabilization_tick_2.get("status","")=="verification_pending" and fire_verification_tick_1.get("status","")=="working" and fire_verification_tick_2.get("status","")=="closed" and fire_closure.get("verification_actor_job","")=="security_officer" and fire_closure.get("closure_scope","")=="local_alarm_controls_only" and fire_samples_exact and began_inspector.get("phase","")=="escorted" and admitted_inspector.get("phase","")=="admitted" and fire_inspection_started.get("status","")=="active" and fire_inspection_tick_1.get("status","")=="working" and fire_inspection_tick_2.get("status","")=="inspected" and fire_inspection_record.get("clearance_scope","")=="limited_inspection_clearance" and fire_inspection_record.get("responder_id","")=="external-fire-inspector-1" and not denied_archive_reentry_after_inspection.get("accepted",true) and reentry_started.get("status","")=="active" and reentry_tick_1.get("status","")=="working" and posture_after_first_reentry_tick=="evacuate" and mid_reentry_checkpoint.get("accepted",false) and recovered_mid_reentry.get("accepted",false) and recovered_reentry_facility.environmental_observation_state.get("room_reentries",[]).size()==1 and recovered_reentry_facility.environmental_observation_state["room_reentries"][0].get("handoffs",[]).size()==2 and not automatic_reentry_after_restart.get("accepted",true) and reentry_turnover.get("accepted",false) and handed_reentry.get("suspension_reason","")=="shift_handoff_reconciliation" and handed_reentry.get("handoffs",[]).size()==2 and handed_reentry.get("authority_person_id","")!=reentry_record.get("authority_person_id","") and handed_reentry.get("concurrence_person_id","")!=reentry_record.get("concurrence_person_id","") and resumed_reentry.get("remaining_ticks",0)==1 and recovered_reentry_commit.get("status","")=="committed" and recovered_reentry_facility.mutual_aid_state["cases"][inspection_case_id]["phase"]=="revoked" and reentry_tick_2.get("status","")=="committed" and not archive_fire_facility.environmental_observation_state.get("protective_postures",{}).has("archive_stack") and reentry_record.get("inspection_id","")==fire_inspection_record.get("inspection_id","") and reentry_record.get("authority_person_id","")!=reentry_record.get("concurrence_person_id","") and archive_fire_facility.mutual_aid_state["cases"][inspection_case_id]["phase"]=="revoked" and admitted_archive_return.get("accepted",false),"archive alarm stabilization did not separate technical work, immutable security verification, narrow closure, and continued re-entry prohibition")
	var fire_checkpoint: Dictionary=archive_fire_facility.export_scene_checkpoint()
	var forged_fire_checkpoint: Dictionary=fire_checkpoint.duplicate(true)
	if forged_fire_checkpoint.has("owners"): forged_fire_checkpoint["owners"]["environmental_observations"]["state"]["hazard_closures"][0]["verification_samples"].pop_back()
	var forged_fire_reader=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(forged_fire_reader); await get_tree().process_frame
	var forged_fire_result: Dictionary=forged_fire_reader.recover_scene_checkpoint(forged_fire_checkpoint)
	var valid_fire_recovery: Dictionary=forged_fire_reader.recover_scene_checkpoint(fire_checkpoint)
	_check(fire_checkpoint.get("accepted",false) and not forged_fire_result.get("accepted",true) and valid_fire_recovery.get("accepted",false) and forged_fire_reader.environmental_observation_state.get("room_reentries",[]).size()==1 and not forged_fire_reader.environmental_observation_state.get("protective_postures",{}).has("archive_stack") and not forged_fire_reader.staff_agent_state.get("room_entry_blocks",{}).has("archive_stack") and forged_fire_reader.mutual_aid_state["cases"][inspection_case_id]["phase"]=="revoked","checkpoint admitted incomplete alarm evidence or failed to recover terminal re-entry and credential revocation")
	var security_fire_facility=await _prepare_security_control_fire_facility()
	var security_fire_finding: Dictionary={}
	for candidate in security_fire_facility.environmental_observation_state.get("hazard_findings",[]):
		if candidate.get("classification","")=="security_control_fire_or_local_alarm": security_fire_finding=candidate; break
	var security_evacuation: Dictionary={}
	for _security_evac_tick in 32:
		if security_fire_facility.environmental_observation_state.get("active_room_evacuation",{}).is_empty(): security_evacuation=security_fire_facility.dispatch_environmental_room_evacuation(security_fire_finding.get("finding_id",""))
		else: security_evacuation=security_fire_facility.tick_environmental_room_evacuation()
		if security_evacuation.get("status","")=="accounted": break
	var security_evacuation_record: Dictionary={} if security_fire_facility.environmental_observation_state.get("room_evacuations",[]).is_empty() else security_fire_facility.environmental_observation_state["room_evacuations"][-1]
	var all_security_occupants_at_exit: bool=not security_evacuation_record.get("roster",[]).is_empty()
	var security_occupant_ids: Array=[]
	for occupant_record in security_evacuation_record.get("roster",[]):
		var occupant: String=occupant_record.get("person_id",""); security_occupant_ids.append(occupant)
		if not security_fire_facility.staff_agent_runtime.is_at_room(security_fire_facility.staff_agent_state,occupant,"emergency_exit"): all_security_occupants_at_exit=false
	var security_backup_id: String=security_fire_facility.get_meta("security_accountability_backup","")
	var evacuated_duty_id: String=""
	for occupant_record in security_evacuation_record.get("roster",[]):
		if occupant_record.get("job","")=="duty_officer": evacuated_duty_id=occupant_record.get("person_id",""); break
	var rejected_evacuated_command: Dictionary=security_fire_facility.establish_environmental_displaced_command(security_fire_finding.get("finding_id",""),"assume alternate incident command after control-room evacuation",evacuated_duty_id)
	var displaced_command_ready: Dictionary={}
	for _displaced_command_route_tick in 16:
		displaced_command_ready=security_fire_facility.dispatch_environmental_displaced_command(security_fire_finding.get("finding_id",""))
		if displaced_command_ready.get("status","")=="ready": break
	var displaced_command: Dictionary=security_fire_facility.establish_environmental_displaced_command(security_fire_finding.get("finding_id",""),"assume alternate incident command after control-room evacuation",displaced_command_ready.get("actor_person_id",""))
	var displaced_command_record: Dictionary={} if security_fire_facility.environmental_observation_state.get("displaced_commands",[]).is_empty() else security_fire_facility.environmental_observation_state["displaced_commands"][-1]
	var displaced_command_checkpoint: Dictionary=security_fire_facility.export_scene_checkpoint()
	var forged_displaced_command_checkpoint: Dictionary=displaced_command_checkpoint.duplicate(true)
	forged_displaced_command_checkpoint["owners"]["environmental_observations"]["state"]["displaced_commands"][-1]["actor_person_id"]=evacuated_duty_id
	var displaced_command_reader=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(displaced_command_reader); await get_tree().process_frame
	var rejected_forged_displaced_command: Dictionary=displaced_command_reader.recover_scene_checkpoint(forged_displaced_command_checkpoint)
	var recovered_displaced_command: Dictionary=displaced_command_reader.recover_scene_checkpoint(displaced_command_checkpoint)
	var premature_security_stabilization: Dictionary=security_fire_facility.dispatch_environmental_hazard_remediation(security_fire_finding.get("finding_id",""))
	var security_stabilization_authorization: Dictionary=security_fire_facility.authorize_environmental_hazard_remediation(security_fire_finding.get("finding_id",""),"authorize local alarm-control stabilization from displaced command",displaced_command_record.get("actor_person_id",""))
	var security_stabilization_ready: Dictionary={}
	for _security_stabilization_route_tick in 24:
		security_stabilization_ready=security_fire_facility.dispatch_environmental_hazard_remediation(security_fire_finding.get("finding_id",""))
		if security_stabilization_ready.get("status","")=="active" or security_stabilization_ready.get("status","")=="ready": break
	var security_stabilization_tick_1: Dictionary=security_fire_facility.tick_environmental_hazard_work({})
	var security_stabilization_tick_2: Dictionary=security_fire_facility.tick_environmental_hazard_work({})
	var security_clear_readings: Dictionary={"staff_control":{"water_intrusion":false,"smoke_or_local_alarm":false}}
	var security_verification_tick_1: Dictionary=security_fire_facility.tick_environmental_hazard_work(security_clear_readings)
	var security_verification_tick_2: Dictionary=security_fire_facility.tick_environmental_hazard_work(security_clear_readings)
	var security_stabilization_closure: Dictionary={} if security_fire_facility.environmental_observation_state.get("hazard_closures",[]).is_empty() else security_fire_facility.environmental_observation_state["hazard_closures"][-1]
	var security_inspection_case: Dictionary=security_fire_facility.request_environmental_fire_inspector(security_fire_finding.get("finding_id",""),"external-security-control-inspector-1")
	var security_inspection_case_id: String=security_inspection_case.get("case_id","")
	var security_route_runtime=load("res://scripts/facility/facility_route_router.gd").new()
	var security_responder_route: Array=security_route_runtime.ordinary_room_path(security_fire_facility.generated_route_plan,"screened_entry","security_control")
	var security_escort_to_staging: Array=security_route_runtime.ordinary_room_path(security_fire_facility.generated_route_plan,"staff_control","screened_entry")
	var security_escort_route: Array=security_fire_facility.mutual_aid_runtime.compose_escort_route_via_staging(security_escort_to_staging,security_responder_route)
	security_fire_facility.mutual_aid_runtime.advance(security_fire_facility.mutual_aid_state,security_inspection_case_id,"record_arrival",{"responder_id":"external-security-control-inspector-1","room":"screened_entry"})
	security_fire_facility.mutual_aid_runtime.advance(security_fire_facility.mutual_aid_state,security_inspection_case_id,"record_screening",{"actor_id":"security-fire-screening-officer","job":"security_officer","room":"screened_entry"})
	var security_inspection_authorized: Dictionary=security_fire_facility.mutual_aid_runtime.advance(security_fire_facility.mutual_aid_state,security_inspection_case_id,"authorize",{"actor_id":displaced_command_record["actor_person_id"],"job":"duty_officer","room":"staff_control"})
	security_fire_facility.mutual_aid_runtime.advance(security_fire_facility.mutual_aid_state,security_inspection_case_id,"issue_credential",{"credential_id":"security-control-inspection-credential-1","mode":"incident_scoped_temporary","occurrence_id":security_fire_finding["finding_id"],"destination":"security_control"})
	security_fire_facility.mutual_aid_runtime.advance(security_fire_facility.mutual_aid_state,security_inspection_case_id,"assign_escort",{"actor_id":security_backup_id,"job":"security_officer","room":"staff_control"})
	var security_inspector_began: Dictionary=security_fire_facility.mutual_aid_runtime.advance(security_fire_facility.mutual_aid_state,security_inspection_case_id,"record_escorted_arrival",{"responder_id":"external-security-control-inspector-1","escort_id":security_backup_id,"responder_room":"security_control","escort_room":"security_control","responder_route":security_responder_route,"escort_route":security_escort_route})
	var security_inspector_admitted: Dictionary=security_fire_facility.mutual_aid_runtime.complete_escorted_travel(security_fire_facility.mutual_aid_state,security_inspection_case_id)
	var security_inspection_started: Dictionary=security_fire_facility.begin_environmental_fire_inspection(security_fire_finding["finding_id"],security_stabilization_closure["closure_id"],"physical command-room inspection under displaced authority")
	var security_physical_clearance: Dictionary={"no_active_fire":true,"atmosphere_safe_for_entry":true,"structural_access_safe":true}
	var security_inspection_tick_1: Dictionary=security_fire_facility.tick_environmental_fire_inspection(security_physical_clearance)
	var security_inspection_tick_2: Dictionary=security_fire_facility.tick_environmental_fire_inspection(security_physical_clearance)
	var security_inspection_record: Dictionary={} if security_fire_facility.environmental_observation_state.get("fire_inspections",[]).is_empty() else security_fire_facility.environmental_observation_state["fire_inspections"][-1]
	var security_inspection_checkpoint: Dictionary=security_fire_facility.export_scene_checkpoint()
	var security_inspection_reader=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(security_inspection_reader); await get_tree().process_frame
	var recovered_security_inspection: Dictionary=security_inspection_reader.recover_scene_checkpoint(security_inspection_checkpoint)
	var forged_security_inspection_checkpoint: Dictionary=security_inspection_checkpoint.duplicate(true)
	forged_security_inspection_checkpoint["owners"]["environmental_observations"]["state"]["fire_inspections"][-1]["authority_person_id"]=evacuated_duty_id
	var forged_security_inspection_reader=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(forged_security_inspection_reader); await get_tree().process_frame
	var rejected_forged_security_inspection: Dictionary=forged_security_inspection_reader.recover_scene_checkpoint(forged_security_inspection_checkpoint)
	var displaced_command_backup_id: String=security_fire_facility.get_meta("displaced_command_backup","")
	var security_demobilization_started: Dictionary=security_fire_facility.begin_environmental_fire_inspector_demobilization(security_fire_finding["finding_id"])
	var security_demobilization_first_tick: Dictionary=security_fire_facility.tick_environmental_fire_inspector_demobilization(security_inspection_case_id)
	var security_demobilization_before_turnover: Dictionary=security_fire_facility.mutual_aid_state.duplicate(true)
	var security_escort_holdover_turnover: Dictionary=security_fire_facility.turnover_shift_with_external_escort_holdover("swing",security_inspection_case_id)

	var security_demobilization_turnover_preserved: bool=security_fire_facility.staffing_state.get("active_shift","")=="swing" and security_fire_facility.mutual_aid_state==security_demobilization_before_turnover and security_fire_facility.staffing_state.get("incident_holdovers",{}).has(security_backup_id)
	var security_demobilization_checkpoint: Dictionary=security_fire_facility.export_scene_checkpoint()

	var forged_security_demobilization_checkpoint: Dictionary=security_demobilization_checkpoint.duplicate(true)
	forged_security_demobilization_checkpoint["owners"]["mutual_aid"]["state"]["temporary_locations"]["external-security-control-inspector-1"]="security_control"
	var forged_security_demobilization_reader=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(forged_security_demobilization_reader); await get_tree().process_frame
	var rejected_forged_security_demobilization: Dictionary=forged_security_demobilization_reader.recover_scene_checkpoint(forged_security_demobilization_checkpoint)
	var security_demobilization_reader=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(security_demobilization_reader); await get_tree().process_frame
	var recovered_security_demobilization: Dictionary=security_demobilization_reader.recover_scene_checkpoint(security_demobilization_checkpoint)
	var automatic_security_demobilization: Dictionary=security_demobilization_reader.tick_environmental_fire_inspector_demobilization(security_inspection_case_id)
	var resumed_security_demobilization: Dictionary=security_demobilization_reader.resume_environmental_fire_inspector_demobilization(security_inspection_case_id,"external-security-control-inspector-1",security_backup_id)
	var security_demobilization_result: Dictionary={}
	for _demobilization_tick in 24:
		security_demobilization_result=security_demobilization_reader.tick_environmental_fire_inspector_demobilization(security_inspection_case_id)
		if security_demobilization_result.get("status","")=="closed": break
	security_fire_facility=security_demobilization_reader

	var security_case_after_demobilization: Dictionary=security_fire_facility.mutual_aid_state.get("cases",{}).get(security_inspection_case_id,{})
	var stale_security_inspector_capacity: Dictionary=security_fire_facility.mutual_aid_runtime.active_capacity(security_fire_facility.mutual_aid_state,security_fire_finding["finding_id"])
	var security_posture_after_inspection: String=security_fire_facility.environmental_observation_state.get("protective_postures",{}).get("security_control","")
	var security_entry_block_after_inspection: String=security_fire_facility.staff_agent_state.get("room_entry_blocks",{}).get("security_control","")
	var security_reentry_started: Dictionary=security_fire_facility.begin_environmental_room_reentry(security_fire_finding["finding_id"],security_inspection_record["inspection_id"],"controlled return to primary command room after physical clearance")

	var security_reentry_tick_1: Dictionary=security_fire_facility.tick_environmental_room_reentry()
	var security_posture_after_reentry_tick_1: String=security_fire_facility.environmental_observation_state.get("protective_postures",{}).get("security_control","")
	var security_reentry_tick_2: Dictionary=security_fire_facility.tick_environmental_room_reentry()
	var security_escort_holdover_released: bool=security_fire_facility.staffing_state.get("incident_holdovers",{}).has(security_backup_id) and security_fire_facility.staffing_state.get("incident_holdover_log",[]).is_empty()
	var security_reentry_record: Dictionary={} if security_fire_facility.environmental_observation_state.get("room_reentries",[]).is_empty() else security_fire_facility.environmental_observation_state["room_reentries"][-1]
	var security_posture_after_reentry: String=security_fire_facility.environmental_observation_state.get("protective_postures",{}).get("security_control","")
	var security_entry_block_after_reentry: String=security_fire_facility.staff_agent_state.get("room_entry_blocks",{}).get("security_control","")
	var security_reentry_checkpoint: Dictionary=security_fire_facility.export_scene_checkpoint()

	var security_reentry_reader=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(security_reentry_reader); await get_tree().process_frame
	var recovered_security_reentry: Dictionary=security_reentry_reader.recover_scene_checkpoint(security_reentry_checkpoint)
	var forged_security_reentry_checkpoint: Dictionary=security_reentry_checkpoint.duplicate(true)
	forged_security_reentry_checkpoint["owners"]["environmental_observations"]["state"]["room_reentries"][-1]["authority_person_id"]=evacuated_duty_id
	var forged_security_reentry_reader=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(forged_security_reentry_reader); await get_tree().process_frame
	var rejected_forged_security_reentry: Dictionary=forged_security_reentry_reader.recover_scene_checkpoint(forged_security_reentry_checkpoint)

	var command_restoration_started: Dictionary={}
	for _command_restoration_route_tick in 24:
		command_restoration_started=security_fire_facility.begin_environmental_primary_command_restoration(security_fire_finding["finding_id"],"transfer incident command back to restored primary control")
		if command_restoration_started.get("status","")=="active": break
	var command_restoration_tick_1: Dictionary=security_fire_facility.tick_environmental_primary_command_restoration()
	var restorations_after_tick_1: int=security_fire_facility.environmental_observation_state.get("command_restorations",[]).size()
	var mid_command_restoration_checkpoint: Dictionary=security_fire_facility.export_scene_checkpoint()
	var mid_command_restoration_reader=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(mid_command_restoration_reader); await get_tree().process_frame
	var recovered_mid_command_restoration: Dictionary=mid_command_restoration_reader.recover_scene_checkpoint(mid_command_restoration_checkpoint)
	var automatic_command_restoration_after_restart: Dictionary=mid_command_restoration_reader.tick_environmental_primary_command_restoration()
	var resumed_command_restoration: Dictionary=mid_command_restoration_reader.resume_environmental_primary_command_restoration(security_fire_finding["finding_id"])
	var command_restoration_tick_2: Dictionary=mid_command_restoration_reader.tick_environmental_primary_command_restoration()
	var command_restoration_record: Dictionary={} if mid_command_restoration_reader.environmental_observation_state.get("command_restorations",[]).is_empty() else mid_command_restoration_reader.environmental_observation_state["command_restorations"][-1]
	var incident_holdovers_released: bool=mid_command_restoration_reader.staffing_state.get("incident_holdovers",{}).is_empty() and mid_command_restoration_reader.staffing_state.get("incident_holdover_log",[]).size()==2
	var command_restoration_checkpoint: Dictionary=mid_command_restoration_reader.export_scene_checkpoint()
	var command_restoration_reader=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(command_restoration_reader); await get_tree().process_frame
	var recovered_command_restoration: Dictionary=command_restoration_reader.recover_scene_checkpoint(command_restoration_checkpoint)
	var forged_command_restoration_checkpoint: Dictionary=command_restoration_checkpoint.duplicate(true)
	forged_command_restoration_checkpoint["owners"]["environmental_observations"]["state"]["command_restorations"][-1]["primary_station"]="staff_control"
	var forged_command_restoration_reader=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(forged_command_restoration_reader); await get_tree().process_frame
	var rejected_forged_command_restoration: Dictionary=forged_command_restoration_reader.recover_scene_checkpoint(forged_command_restoration_checkpoint)
	_check(security_evacuation.get("status","")=="accounted" and security_evacuation_record.get("source_room","")=="security_control" and security_evacuation_record.get("accountability_station","")=="staff_control" and security_evacuation_record.get("accountability_person_id","")==security_backup_id and security_backup_id not in security_occupant_ids and all_security_occupants_at_exit and security_posture_after_inspection=="evacuate" and security_entry_block_after_inspection=="environmental_evacuation" and not rejected_evacuated_command.get("accepted",true) and displaced_command_ready.get("status","")=="ready" and displaced_command.get("status","")=="established" and displaced_command_record.get("actor_person_id","")==displaced_command_backup_id and displaced_command_record.get("station","")=="staff_control" and displaced_command_record.get("actor_person_id","") not in security_occupant_ids and displaced_command_checkpoint.get("accepted",false) and not rejected_forged_displaced_command.get("accepted",true) and recovered_displaced_command.get("accepted",false) and displaced_command_reader.environmental_observation_state.get("displaced_commands",[]).size()==1 and not premature_security_stabilization.get("accepted",true) and security_stabilization_authorization.get("status","")=="authorized" and security_stabilization_ready.get("status","") in ["active","ready"] and security_stabilization_tick_1.get("status","")=="working" and security_stabilization_tick_2.get("status","")=="verification_pending" and security_verification_tick_1.get("status","")=="working" and security_verification_tick_2.get("status","")=="closed" and security_stabilization_closure.get("closure_scope","")=="local_alarm_controls_only" and security_posture_after_inspection=="evacuate" and security_inspection_case.get("accepted",false) and security_inspection_authorized.get("phase","")=="authorized" and security_inspector_began.get("phase","")=="escorted" and security_inspector_admitted.get("phase","")=="admitted" and security_inspection_started.get("status","")=="active" and security_inspection_tick_1.get("status","")=="working" and security_inspection_tick_2.get("status","")=="inspected" and security_inspection_record.get("destination","")=="security_control" and security_inspection_record.get("authority_station","")=="staff_control" and security_inspection_record.get("authority_person_id","")==displaced_command_record.get("actor_person_id","") and security_inspection_record.get("clearance_scope","")=="limited_inspection_clearance" and recovered_security_inspection.get("accepted",false) and not rejected_forged_security_inspection.get("accepted",true) and security_demobilization_started.get("status","")=="demobilizing" and security_demobilization_first_tick.get("status","")=="traveling" and security_escort_holdover_turnover.get("accepted",false) and security_escort_holdover_turnover.get("escort_person_id","")==security_backup_id and security_demobilization_turnover_preserved and not rejected_forged_security_demobilization.get("accepted",true) and recovered_security_demobilization.get("accepted",false) and not automatic_security_demobilization.get("accepted",true) and resumed_security_demobilization.get("accepted",false) and security_demobilization_result.get("status","")=="closed" and security_case_after_demobilization.get("phase","")=="closed" and security_escort_holdover_released and security_fire_facility.mutual_aid_state.get("temporary_locations",{}).get("external-security-control-inspector-1","")=="screened_entry" and security_fire_facility.mutual_aid_state.get("temporary_locations",{}).get(security_backup_id,"")=="staff_control" and not stale_security_inspector_capacity.get("accepted",true) and security_reentry_started.get("status","")=="active" and security_reentry_tick_1.get("status","")=="working" and security_posture_after_reentry_tick_1=="evacuate" and security_reentry_tick_2.get("status","")=="committed" and security_reentry_record.get("authority_person_id","")==displaced_command_record.get("actor_person_id","") and security_reentry_record.get("authority_station","")=="staff_control" and security_reentry_record.get("concurrence_station","")=="staff_control" and security_reentry_record.get("authority_person_id","")!=security_reentry_record.get("concurrence_person_id","") and security_posture_after_reentry.is_empty() and security_entry_block_after_reentry.is_empty() and recovered_security_reentry.get("accepted",false) and security_reentry_reader.environmental_observation_state.get("protective_postures",{}).get("security_control","").is_empty() and security_reentry_reader.staff_agent_state.get("room_entry_blocks",{}).get("security_control","").is_empty() and not rejected_forged_security_reentry.get("accepted",true) and command_restoration_started.get("status","")=="active" and command_restoration_tick_1.get("status","")=="working" and restorations_after_tick_1==0 and recovered_mid_command_restoration.get("accepted",false) and not automatic_command_restoration_after_restart.get("accepted",true) and resumed_command_restoration.get("accepted",false) and resumed_command_restoration.get("remaining_ticks",0)==1 and command_restoration_tick_2.get("status","")=="restored" and incident_holdovers_released and command_restoration_record.get("displaced_actor_person_id","")==displaced_command_record.get("actor_person_id","") and command_restoration_record.get("displaced_station","")=="staff_control" and command_restoration_record.get("primary_station","")=="security_control" and command_restoration_record.get("primary_actor_person_id","")!=command_restoration_record.get("displaced_actor_person_id","") and recovered_command_restoration.get("accepted",false) and command_restoration_reader.environmental_observation_state.get("command_restorations",[]).size()==1 and not rejected_forged_command_restoration.get("accepted",true),"security-control fire did not evacuate command staff under independent alternate-station accountability")
	var compute_fire_facility=await _prepare_compute_fire_facility()
	var compute_fire_finding: Dictionary={}
	for candidate in compute_fire_facility.environmental_observation_state.get("hazard_findings",[]):
		if candidate.get("classification","")=="compute_fire_or_local_alarm": compute_fire_finding=candidate; break
	var compute_evacuation: Dictionary={}
	for _compute_evac_tick in 32:
		if compute_fire_facility.environmental_observation_state.get("active_room_evacuation",{}).is_empty(): compute_evacuation=compute_fire_facility.dispatch_environmental_room_evacuation(compute_fire_finding.get("finding_id",""))
		else: compute_evacuation=compute_fire_facility.tick_environmental_room_evacuation()
		if compute_evacuation.get("status","")=="accounted": break
	var compute_roster: Array=compute_fire_facility.environmental_observation_state.get("room_evacuations",[])[0].get("roster",[]) if not compute_fire_facility.environmental_observation_state.get("room_evacuations",[]).is_empty() else []
	var compute_roster_exact:=not compute_roster.is_empty()
	for occupant in compute_roster:
		if occupant.get("job","")!="systems_administrator" or not compute_fire_facility.staff_agent_runtime.is_at_room(compute_fire_facility.staff_agent_state,occupant.get("person_id",""),"emergency_exit"): compute_roster_exact=false
	var compute_return_candidate: String=compute_roster[0].get("person_id","") if not compute_roster.is_empty() else ""
	var denied_compute_reentry: Dictionary=compute_fire_facility.staff_agent_runtime.dispatch(compute_fire_facility.operation_graph,compute_fire_facility.staff_agent_state,compute_return_candidate,"compute_core")
	var compute_fire_mission_prefix: Dictionary=compute_fire_facility.advance_mission(7)
	var compute_fire_cursor: int=int(compute_fire_facility.mission_state.get("next_step_index",-1))
	var compute_fire_workload: Dictionary=compute_fire_facility.advance_mission(1)
	_check(compute_fire_finding.get("status","")=="commanded" and compute_evacuation.get("status","")=="accounted" and compute_roster_exact and compute_fire_facility.environmental_observation_state.get("protective_postures",{})=={"compute_core":"evacuate"} and not denied_compute_reentry.get("accepted",true) and compute_fire_mission_prefix.get("status","")=="running" and compute_fire_workload.get("status","")=="blocked" and compute_fire_workload.get("blocked_posture","")=="evacuate" and int(compute_fire_facility.mission_state.get("next_step_index",-2))==compute_fire_cursor,"compute fire did not produce room-scoped systems evacuation, accountability, and continued re-entry denial")
	var compute_fire_stabilization: Dictionary={}
	for _compute_stabilization_route_tick in 24:
		compute_fire_stabilization=compute_fire_facility.dispatch_environmental_hazard_remediation(compute_fire_finding["finding_id"])
		if compute_fire_stabilization.get("status","")=="active": break
	var compute_stabilization_tick_1: Dictionary=compute_fire_facility.tick_environmental_hazard_work({})
	var compute_stabilization_tick_2: Dictionary=compute_fire_facility.tick_environmental_hazard_work({})
	var compute_fire_panel_verification_tick_1: Dictionary=compute_fire_facility.tick_environmental_hazard_work({"security_control":dry_verification})
	var compute_fire_panel_verification_tick_2: Dictionary=compute_fire_facility.tick_environmental_hazard_work({"security_control":dry_verification})
	var compute_fire_closure: Dictionary={} if compute_fire_facility.environmental_observation_state.get("hazard_closures",[]).is_empty() else compute_fire_facility.environmental_observation_state["hazard_closures"][-1]
	var compute_postclosure_workload: Dictionary=compute_fire_facility.advance_mission(1)
	_check(compute_fire_stabilization.get("status","")=="active" and compute_stabilization_tick_1.get("status","")=="working" and compute_stabilization_tick_2.get("status","")=="verification_pending" and compute_fire_panel_verification_tick_1.get("status","")=="working" and compute_fire_panel_verification_tick_2.get("status","")=="closed" and compute_fire_closure.get("closure_scope","")=="local_alarm_controls_only" and compute_fire_closure.get("verification_samples",[]).size()==2 and compute_fire_facility.environmental_observation_state.get("protective_postures",{}).get("compute_core","")=="evacuate" and compute_postclosure_workload.get("status","")=="blocked","compute alarm-control stabilization incorrectly claimed physical clearance or reopened workload")
	var compute_inspection_case_result: Dictionary=compute_fire_facility.mutual_aid_runtime.request(compute_fire_facility.mutual_aid_state,compute_fire_finding["finding_id"],"fire_scene_inspector","compute_core","external-compute-fire-inspector-1",compute_fire_facility.operation_graph.mutual_aid_policy)
	var compute_inspection_case_id: String=compute_inspection_case_result.get("case_id","")
	var compute_route_runtime=load("res://scripts/facility/facility_route_router.gd").new()
	var compute_responder_route: Array=compute_route_runtime.ordinary_room_path(compute_fire_facility.generated_route_plan,"screened_entry","compute_core")
	var compute_escort_to_staging: Array=compute_route_runtime.ordinary_room_path(compute_fire_facility.generated_route_plan,"security_control","screened_entry")
	var compute_escort_route: Array=compute_fire_facility.mutual_aid_runtime.compose_escort_route_via_staging(compute_escort_to_staging,compute_responder_route)
	compute_fire_facility.mutual_aid_runtime.advance(compute_fire_facility.mutual_aid_state,compute_inspection_case_id,"record_arrival",{"responder_id":"external-compute-fire-inspector-1","room":"screened_entry"})
	compute_fire_facility.mutual_aid_runtime.advance(compute_fire_facility.mutual_aid_state,compute_inspection_case_id,"record_screening",{"actor_id":"compute-fire-screening-officer","job":"security_officer","room":"screened_entry"})
	compute_fire_facility.mutual_aid_runtime.advance(compute_fire_facility.mutual_aid_state,compute_inspection_case_id,"authorize",{"actor_id":"compute-fire-duty-authority","job":"duty_officer","room":"cyber_ops"})
	compute_fire_facility.mutual_aid_runtime.advance(compute_fire_facility.mutual_aid_state,compute_inspection_case_id,"issue_credential",{"credential_id":"compute-fire-inspection-credential-1","mode":"incident_scoped_temporary","occurrence_id":compute_fire_finding["finding_id"],"destination":"compute_core"})
	compute_fire_facility.mutual_aid_runtime.advance(compute_fire_facility.mutual_aid_state,compute_inspection_case_id,"assign_escort",{"actor_id":"compute-fire-escort-officer","job":"security_officer","room":"security_control"})
	var began_compute_inspector: Dictionary=compute_fire_facility.mutual_aid_runtime.advance(compute_fire_facility.mutual_aid_state,compute_inspection_case_id,"record_escorted_arrival",{"responder_id":"external-compute-fire-inspector-1","escort_id":"compute-fire-escort-officer","responder_room":"compute_core","escort_room":"compute_core","responder_route":compute_responder_route,"escort_route":compute_escort_route})
	var admitted_compute_inspector: Dictionary=compute_fire_facility.mutual_aid_runtime.complete_escorted_travel(compute_fire_facility.mutual_aid_state,compute_inspection_case_id)
	var compute_inspection_started: Dictionary=compute_fire_facility.begin_environmental_fire_inspection(compute_fire_finding["finding_id"],compute_fire_closure["closure_id"],"physical compute-room inspection after panel stabilization")
	var compute_physical_clearance: Dictionary={"no_active_fire":true,"atmosphere_safe_for_entry":true,"structural_access_safe":true}
	var compute_inspection_tick_1: Dictionary=compute_fire_facility.tick_environmental_fire_inspection(compute_physical_clearance)
	var mid_compute_inspection_checkpoint: Dictionary=compute_fire_facility.export_scene_checkpoint()
	var forged_mid_compute_inspection_checkpoint: Dictionary=mid_compute_inspection_checkpoint.duplicate(true)
	forged_mid_compute_inspection_checkpoint["owners"]["environmental_observations"]["state"]["active_fire_inspection"]["samples"].pop_back()
	var forged_mid_compute_inspection_reader=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(forged_mid_compute_inspection_reader); await get_tree().process_frame
	var forged_mid_compute_inspection_recovery: Dictionary=forged_mid_compute_inspection_reader.recover_scene_checkpoint(forged_mid_compute_inspection_checkpoint)
	var recovered_compute_inspection_facility=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(recovered_compute_inspection_facility); await get_tree().process_frame
	var recovered_compute_inspection: Dictionary=recovered_compute_inspection_facility.recover_scene_checkpoint(mid_compute_inspection_checkpoint)
	var automatic_compute_inspection_after_restart: Dictionary=recovered_compute_inspection_facility.tick_environmental_fire_inspection(compute_physical_clearance)
	var resumed_compute_inspection: Dictionary=recovered_compute_inspection_facility.resume_environmental_fire_inspection(compute_fire_finding["finding_id"])
	var recovered_compute_inspection_commit: Dictionary=recovered_compute_inspection_facility.tick_environmental_fire_inspection(compute_physical_clearance)
	var compute_inspection_tick_2: Dictionary=compute_fire_facility.tick_environmental_fire_inspection(compute_physical_clearance)
	var compute_inspection_record: Dictionary={} if compute_fire_facility.environmental_observation_state.get("fire_inspections",[]).is_empty() else compute_fire_facility.environmental_observation_state["fire_inspections"][-1]
	var compute_postinspection_workload: Dictionary=compute_fire_facility.advance_mission(1)
	_check(began_compute_inspector.get("phase","")=="escorted" and admitted_compute_inspector.get("phase","")=="admitted" and compute_inspection_started.get("status","")=="active" and compute_inspection_tick_1.get("status","")=="working" and compute_inspection_tick_2.get("status","")=="inspected" and mid_compute_inspection_checkpoint.get("accepted",false) and not forged_mid_compute_inspection_recovery.get("accepted",true) and forged_mid_compute_inspection_reader.environmental_observation_state.get("active_fire_inspection",{}).is_empty() and recovered_compute_inspection.get("accepted",false) and recovered_compute_inspection_facility.environmental_observation_state.get("fire_inspections",[]).size()==1 and not automatic_compute_inspection_after_restart.get("accepted",true) and resumed_compute_inspection.get("remaining_ticks",0)==1 and recovered_compute_inspection_commit.get("status","")=="inspected" and compute_inspection_record.get("destination","")=="compute_core" and compute_inspection_record.get("clearance_scope","")=="limited_inspection_clearance" and compute_inspection_record.get("samples",[]).size()==2 and compute_fire_facility.environmental_observation_state.get("protective_postures",{}).get("compute_core","")=="evacuate" and compute_postinspection_workload.get("status","")=="blocked","compute physical inspection was not occurrence-bound, escorted, timed, or kept separate from re-entry and workload restart")
	var compute_reentry_started: Dictionary={}
	for _compute_reentry_route_tick in 24:
		compute_reentry_started=compute_fire_facility.begin_environmental_room_reentry(compute_fire_finding["finding_id"],compute_inspection_record["inspection_id"],"restore controlled compute-room access without workload restart")
		if compute_reentry_started.get("status","")=="active": break
	var compute_reentry_tick_1: Dictionary=compute_fire_facility.tick_environmental_room_reentry()
	var compute_posture_mid_reentry: String=compute_fire_facility.environmental_observation_state.get("protective_postures",{}).get("compute_core","")
	var compute_reentry_tick_2: Dictionary=compute_fire_facility.tick_environmental_room_reentry()
	var compute_reentry_record: Dictionary={} if compute_fire_facility.environmental_observation_state.get("room_reentries",[]).is_empty() else compute_fire_facility.environmental_observation_state["room_reentries"][-1]
	var compute_return_after_reentry: Dictionary=compute_fire_facility.staff_agent_runtime.dispatch(compute_fire_facility.operation_graph,compute_fire_facility.staff_agent_state,compute_reentry_record.get("concurrence_person_id",""),"compute_core")
	var compute_postreentry_workload: Dictionary=compute_fire_facility.advance_mission(1)
	_check(compute_reentry_started.get("status","")=="active" and compute_reentry_tick_1.get("status","")=="working" and compute_posture_mid_reentry=="evacuate" and compute_reentry_tick_2.get("status","")=="committed" and compute_reentry_record.get("concurrence_job","")=="systems_administrator" and compute_fire_facility.environmental_observation_state.get("protective_postures",{}).get("compute_core","")=="safe_shutdown" and not compute_fire_facility.staff_agent_state.get("room_entry_blocks",{}).has("compute_core") and compute_return_after_reentry.get("accepted",false) and compute_postreentry_workload.get("status","")=="blocked" and compute_postreentry_workload.get("blocked_posture","")=="safe_shutdown" and compute_fire_facility.mutual_aid_state["cases"][compute_inspection_case_id]["phase"]=="revoked","compute re-entry did not reopen personnel access while retaining a separate workload-safe shutdown")
	var premature_fire_reactivation: Dictionary=compute_fire_facility.reactivate_environmental_compute(compute_fire_finding["finding_id"],"restart after fire clearance",compute_reentry_record.get("authority_person_id",""),compute_reentry_record.get("concurrence_person_id",""))
	for panel_id in ["environmental_monitoring:establish_manual_sensor_rounds@security_control","environmental_monitoring:isolate_for_repair@plant","environmental_monitoring:begin_repair@plant","environmental_monitoring:record_repair@plant","environmental_monitoring:functional_test@plant","environmental_monitoring:verify_reconstitution@security_control"]: _execute_generated_panel(compute_fire_facility,panel_id)
	var compute_fire_reactivation_ready: Dictionary={}
	for _compute_fire_reactivation_route_tick in 32:
		compute_fire_reactivation_ready=compute_fire_facility.dispatch_environmental_compute_reactivation(compute_fire_finding["finding_id"])
		if compute_fire_reactivation_ready.get("status","")=="ready": break
	var compute_fire_reactivation_started: Dictionary=compute_fire_facility.reactivate_environmental_compute(compute_fire_finding["finding_id"],"restart after verified fire clearance and controlled re-entry",compute_fire_reactivation_ready.get("authority_person_id",""),compute_fire_reactivation_ready.get("concurrence_person_id",""))
	var compute_fire_reactivation_tick_1: Dictionary=compute_fire_facility.tick_environmental_compute_reactivation()
	var mid_fire_reactivation_checkpoint: Dictionary=compute_fire_facility.export_scene_checkpoint()
	var recovered_fire_reactivation_facility=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(recovered_fire_reactivation_facility); await get_tree().process_frame
	var recovered_mid_fire_reactivation: Dictionary=recovered_fire_reactivation_facility.recover_scene_checkpoint(mid_fire_reactivation_checkpoint)
	var automatic_fire_reactivation_after_restart: Dictionary=recovered_fire_reactivation_facility.tick_environmental_compute_reactivation()
	var resumed_fire_reactivation: Dictionary=recovered_fire_reactivation_facility.resume_environmental_compute_reactivation(compute_fire_finding["finding_id"])
	var recovered_fire_reactivation_commit: Dictionary=recovered_fire_reactivation_facility.tick_environmental_compute_reactivation()
	var recovered_fire_workload: Dictionary=recovered_fire_reactivation_facility.advance_mission(1)
	var compute_posture_mid_reactivation: String=compute_fire_facility.environmental_observation_state.get("protective_postures",{}).get("compute_core","")
	var compute_fire_reactivation_tick_2: Dictionary=compute_fire_facility.tick_environmental_compute_reactivation()
	var compute_resumed_workload: Dictionary=compute_fire_facility.advance_mission(1)
	_check(not premature_fire_reactivation.get("accepted",true) and compute_fire_facility.infrastructure_state.get("service_states",{}).get("environmental_monitoring",{}).get("phase","")=="normal" and compute_fire_reactivation_ready.get("status","")=="ready" and compute_fire_reactivation_started.get("status","")=="reactivation_started" and compute_fire_reactivation_tick_1.get("status","")=="working" and mid_fire_reactivation_checkpoint.get("accepted",false) and recovered_mid_fire_reactivation.get("accepted",false) and not automatic_fire_reactivation_after_restart.get("accepted",true) and resumed_fire_reactivation.get("remaining_ticks",0)==1 and recovered_fire_reactivation_commit.get("status","")=="committed" and recovered_fire_workload.get("status","") in ["running","completed"] and compute_posture_mid_reactivation=="safe_shutdown" and compute_fire_reactivation_tick_2.get("status","")=="committed" and not compute_fire_facility.environmental_observation_state.get("protective_postures",{}).has("compute_core") and compute_resumed_workload.get("status","") in ["running","completed"],"compute fire reactivation bypassed monitoring, re-entry, separated authority, timed work, or exact workload continuation")
	var compute_fire_checkpoint: Dictionary=compute_fire_facility.export_scene_checkpoint()
	var forged_compute_fire_checkpoint: Dictionary=compute_fire_checkpoint.duplicate(true)
	forged_compute_fire_checkpoint["owners"]["environmental_observations"]["state"]["hazard_closures"][-1]["verification_samples"].pop_back()
	var compute_fire_reader=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(compute_fire_reader); await get_tree().process_frame
	var forged_compute_fire_recovery: Dictionary=compute_fire_reader.recover_scene_checkpoint(forged_compute_fire_checkpoint)
	var valid_compute_fire_recovery: Dictionary=compute_fire_reader.recover_scene_checkpoint(compute_fire_checkpoint)
	_check(compute_fire_checkpoint.get("accepted",false) and not forged_compute_fire_recovery.get("accepted",true) and valid_compute_fire_recovery.get("accepted",false) and not compute_fire_reader.environmental_observation_state.get("protective_postures",{}).has("compute_core") and not compute_fire_reader.staff_agent_state.get("room_entry_blocks",{}).has("compute_core"),"compute fire recovery admitted incomplete panel evidence or lost exact-room evacuation enforcement")
	var adverse_hazard_facility=await _prepare_mid_hazard_facility()
	for missing_hazard_job in ["facilities_engineer","archive_custodian"]:
		var prior_hazard_unavailable: Dictionary=adverse_hazard_facility.staffing_state["unavailable"].duplicate(true)
		for unavailable_id in adverse_hazard_facility.staffing_runtime.all_staff_ids_for_job(adverse_hazard_facility.staffing_state,missing_hazard_job): adverse_hazard_facility.staffing_state["unavailable"][unavailable_id]=true
		var adverse_hazard_before: Dictionary=adverse_hazard_facility.environmental_observation_state.get("active_hazard_work",{}).duplicate(true)
		var adverse_hazard_mission_before: Dictionary=adverse_hazard_facility.mission_state.duplicate(true)
		var rejected_hazard_turnover: Dictionary=adverse_hazard_facility.turnover_shift("swing")
		_check(not rejected_hazard_turnover.get("accepted",true) and adverse_hazard_facility.staffing_state.get("active_shift","")=="day" and adverse_hazard_facility.staffing_state.get("pending_turnover",{}).is_empty() and adverse_hazard_facility.environmental_observation_state.get("active_hazard_work",{})==adverse_hazard_before and adverse_hazard_facility.mission_state==adverse_hazard_mission_before and adverse_hazard_facility.environmental_observation_state.get("protective_postures",{}).get("archive_stack","")=="safe_hold","missing incoming "+missing_hazard_job+" did not atomically cancel active hazard turnover")
		adverse_hazard_facility.staffing_state["unavailable"]=prior_hazard_unavailable
	print("=== environmental_observation_round_selftest done fails=%d ==="%fails); get_tree().quit(0 if fails==0 else 1)
func _prepare_security_control_fire_facility():
	var facility=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(facility); await get_tree().process_frame
	var security_staff: Array[String]=facility.staffing_runtime.active_staff_ids(facility.staffing_state,"security_officer"); security_staff.sort()
	var accountability_backup: String=security_staff[-1]
	facility.staff_agent_runtime.dispatch(facility.operation_graph,facility.staff_agent_state,accountability_backup,"staff_control")
	for _preincident_route_tick in 8:
		facility.staff_agent_runtime.tick(facility.staff_agent_state)
		if facility.staff_agent_runtime.is_at_room(facility.staff_agent_state,accountability_backup,"staff_control"): break
	facility.set_meta("security_accountability_backup",accountability_backup)
	var duty_staff: Array[String]=facility.staffing_runtime.active_staff_ids(facility.staffing_state,"duty_officer"); duty_staff.sort()
	var displaced_command_backup: String=duty_staff[-1]
	facility.staff_agent_runtime.dispatch(facility.operation_graph,facility.staff_agent_state,displaced_command_backup,"staff_control")
	for _command_route_tick in 8:
		facility.staff_agent_runtime.tick(facility.staff_agent_state)
		if facility.staff_agent_runtime.is_at_room(facility.staff_agent_state,displaced_command_backup,"staff_control"): break
	facility.set_meta("displaced_command_backup",displaced_command_backup)
	facility.set_service_available("environmental_monitoring",false)
	var readings: Dictionary={"archive_stack":{"temperature":18.0,"relative_humidity":42.0,"water_intrusion":false,"smoke_or_local_alarm":false},"compute_core":{"temperature":21.0,"relative_humidity":39.0,"water_intrusion":false,"smoke_or_local_alarm":false},"security_control":{"temperature":20.0,"relative_humidity":40.0,"water_intrusion":false,"smoke_or_local_alarm":true}}
	for _observation_tick in 24:
		var active_round: Dictionary=facility.environmental_observation_state.get("active_round",{})
		if not active_round.is_empty():
			var assignment: Dictionary=active_round["assignments"][active_round["room_index"]]
			facility.tick_environmental_observation_rounds({assignment["room"]:readings[assignment["room"]]})
		if facility.environmental_observation_state.get("completed_rounds",[]).size()==1: break
	var finding: Dictionary={}
	for candidate in facility.environmental_observation_state.get("hazard_findings",[]):
		if candidate.get("classification","")=="security_control_fire_or_local_alarm": finding=candidate; break
	var authority: Dictionary={}
	for _authority_tick in 24:
		authority=facility.dispatch_environmental_hazard_authority(finding.get("finding_id",""))
		if authority.get("status","")=="ready": break
	facility.decide_environmental_hazard(finding.get("finding_id",""),"evacuate_affected_rooms","local alarm requires security-control evacuation",authority.get("actor_person_id",""))
	return facility

func _prepare_compute_fire_facility():
	var facility=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(facility); await get_tree().process_frame
	var systems_staff: Array[String]=facility.staffing_runtime.active_staff_ids(facility.staffing_state,"systems_administrator"); systems_staff.sort()
	var reentry_concurrence: String=systems_staff[-1]
	facility.staff_agent_runtime.dispatch(facility.operation_graph,facility.staff_agent_state,reentry_concurrence,"cyber_ops")
	for _preincident_route_tick in 8:
		facility.staff_agent_runtime.tick(facility.staff_agent_state)
		if facility.staff_agent_runtime.is_at_room(facility.staff_agent_state,reentry_concurrence,"cyber_ops"): break
	facility.set_service_available("environmental_monitoring",false)
	var readings: Dictionary={"archive_stack":{"temperature":18.0,"relative_humidity":42.0,"water_intrusion":false,"smoke_or_local_alarm":false},"compute_core":{"temperature":21.0,"relative_humidity":39.0,"water_intrusion":false,"smoke_or_local_alarm":true},"security_control":{"temperature":20.0,"relative_humidity":40.0,"water_intrusion":false,"smoke_or_local_alarm":false}}
	for _observation_tick in 24:
		var active_round: Dictionary=facility.environmental_observation_state.get("active_round",{})
		if not active_round.is_empty():
			var assignment: Dictionary=active_round["assignments"][active_round["room_index"]]
			facility.tick_environmental_observation_rounds({assignment["room"]:readings[assignment["room"]]})
		if facility.environmental_observation_state.get("completed_rounds",[]).size()==1: break
	var finding: Dictionary={}
	for candidate in facility.environmental_observation_state.get("hazard_findings",[]):
		if candidate.get("classification","")=="compute_fire_or_local_alarm": finding=candidate; break
	var authority: Dictionary={}
	for _authority_tick in 24:
		authority=facility.dispatch_environmental_hazard_authority(finding.get("finding_id",""))
		if authority.get("status","")=="ready": break
	facility.decide_environmental_hazard(finding.get("finding_id",""),"evacuate_affected_rooms","local alarm requires compute-room evacuation",authority.get("actor_person_id",""))
	return facility

func _prepare_archive_fire_facility():
	var facility=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(facility); await get_tree().process_frame
	var archive_staff: Array[String]=facility.staffing_runtime.active_staff_ids(facility.staffing_state,"archive_custodian"); archive_staff.sort()
	var reentry_candidate: String=archive_staff[-1]
	facility.staff_agent_runtime.dispatch(facility.operation_graph,facility.staff_agent_state,reentry_candidate,"archive_processing")
	for _preincident_route_tick in 8:
		facility.staff_agent_runtime.tick(facility.staff_agent_state)
		if facility.staff_agent_runtime.is_at_room(facility.staff_agent_state,reentry_candidate,"archive_processing"): break
	facility.set_meta("reentry_candidate",reentry_candidate)
	facility.set_service_available("environmental_monitoring",false)
	var readings: Dictionary={"archive_stack":{"temperature":18.0,"relative_humidity":42.0,"water_intrusion":false,"smoke_or_local_alarm":true},"compute_core":{"temperature":21.0,"relative_humidity":39.0,"water_intrusion":false,"smoke_or_local_alarm":false},"security_control":{"temperature":20.0,"relative_humidity":40.0,"water_intrusion":false,"smoke_or_local_alarm":false}}
	for _observation_tick in 24:
		var active_round: Dictionary=facility.environmental_observation_state.get("active_round",{})
		if not active_round.is_empty():
			var assignment: Dictionary=active_round["assignments"][active_round["room_index"]]
			facility.tick_environmental_observation_rounds({assignment["room"]:readings[assignment["room"]]})
		if facility.environmental_observation_state.get("completed_rounds",[]).size()==1: break
	var finding: Dictionary=facility.environmental_observation_state["hazard_findings"][0]
	var authority: Dictionary={}
	for _authority_tick in 24:
		authority=facility.dispatch_environmental_hazard_authority(finding["finding_id"])
		if authority.get("status","")=="ready": break
	facility.decide_environmental_hazard(finding["finding_id"],"evacuate_affected_rooms","local alarm requires archive evacuation",authority.get("actor_person_id",""))
	return facility

func _prepare_mid_hazard_facility():
	var facility=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(facility); await get_tree().process_frame
	facility.set_service_available("environmental_monitoring",false)
	var readings: Dictionary={"archive_stack":{"temperature":18.0,"relative_humidity":42.0,"water_intrusion":true,"smoke_or_local_alarm":false},"compute_core":{"temperature":21.0,"relative_humidity":39.0,"water_intrusion":false,"smoke_or_local_alarm":false},"security_control":{"temperature":20.0,"relative_humidity":40.0,"water_intrusion":false,"smoke_or_local_alarm":false}}
	for _observation_tick in 24:
		var active_round: Dictionary=facility.environmental_observation_state.get("active_round",{})
		if not active_round.is_empty():
			var assignment: Dictionary=active_round["assignments"][active_round["room_index"]]
			facility.tick_environmental_observation_rounds({assignment["room"]:readings[assignment["room"]]})
		if facility.environmental_observation_state.get("completed_rounds",[]).size()==1: break
	var finding: Dictionary=facility.environmental_observation_state["hazard_findings"][0]
	var authority: Dictionary={}
	for _authority_tick in 24:
		authority=facility.dispatch_environmental_hazard_authority(finding["finding_id"])
		if authority.get("status","")=="ready": break
	facility.decide_environmental_hazard(finding["finding_id"],"archive_safe_hold","water observed in archive stack",authority.get("actor_person_id",""))
	for _dispatch_tick in 24:
		var remediation: Dictionary=facility.dispatch_environmental_hazard_remediation(finding["finding_id"])
		if remediation.get("status","")=="active": break
	facility.tick_environmental_hazard_work({})
	return facility

func _prepare_mid_release_facility():
	var facility=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(facility); await get_tree().process_frame
	facility.set_service_available("environmental_monitoring",false)
	for _overdue_tick in 32:
		facility.tick_environmental_observation_rounds({})
		if facility.environmental_observation_state.get("escalations",[]).size()==1: break
	var command_ready: Dictionary={}
	for _command_tick in 24:
		command_ready=facility.dispatch_environmental_escalation_authority(1)
		if command_ready.get("status","")=="ready": break
	facility.decide_environmental_escalation(1,"archive_safe_hold","archive conditions cannot be verified",command_ready.get("actor_person_id",""))
	var readings: Dictionary={"archive_stack":{"temperature":18.0,"relative_humidity":42.0,"water_intrusion":false,"smoke_or_local_alarm":false},"compute_core":{"temperature":21.0,"relative_humidity":39.0,"water_intrusion":false,"smoke_or_local_alarm":false},"security_control":{"temperature":20.0,"relative_humidity":40.0,"water_intrusion":false,"smoke_or_local_alarm":false}}
	for _observation_tick in 24:
		if not facility.environmental_observation_state.get("active_round",{}).is_empty():
			var assignment: Dictionary=facility.environmental_observation_state["active_round"]["assignments"][facility.environmental_observation_state["active_round"]["room_index"]]
			facility.tick_environmental_observation_rounds({assignment["room"]:readings[assignment["room"]]})
		if facility.environmental_observation_state.get("completed_rounds",[]).size()==1: break
	for panel_id in ["environmental_monitoring:establish_manual_sensor_rounds@security_control","environmental_monitoring:isolate_for_repair@plant","environmental_monitoring:begin_repair@plant","environmental_monitoring:record_repair@plant","environmental_monitoring:functional_test@plant","environmental_monitoring:verify_reconstitution@security_control"]: _execute_generated_panel(facility,panel_id)
	var release_ready: Dictionary={}
	for _release_tick in 24:
		release_ready=facility.dispatch_environmental_release_authorities("archive_stack")
		if release_ready.get("status","")=="ready": break
	facility.release_environmental_protective_posture("archive_stack","post-repair observation round complete",release_ready.get("authority_person_id",""),release_ready.get("concurrence_person_id",""))
	facility.tick_environmental_protective_release()
	return facility

func _execute_generated_panel(facility, panel_id: String) -> Dictionary:
	if not facility.procedure_panel_definitions.has(panel_id): return {"status":"unknown_panel"}
	var definition: Dictionary=facility.procedure_panel_definitions[panel_id]
	var candidates: Array[String]=facility.staffing_runtime.active_staff_ids(facility.staffing_state,definition["actor_job"]); candidates.sort()
	if candidates.is_empty(): return {"status":"no_actor"}
	var actor_id: String=candidates[0]
	for _route_tick in 32:
		if facility.staff_agent_runtime.is_at_room(facility.staff_agent_state,actor_id,definition["station"]): break
		var agent: Dictionary=facility.staff_agent_state["agents"][actor_id]
		if (agent.get("route",[]) as Array).is_empty():
			var dispatched: Dictionary=facility.staff_agent_runtime.dispatch(facility.operation_graph,facility.staff_agent_state,actor_id,definition["station"])
			if not dispatched.get("accepted",false): return {"status":"dispatch_rejected"}
		facility.staff_agent_runtime.tick(facility.staff_agent_state)
	facility._refresh_procedure_panels()
	var requested: Dictionary=facility._request_procedure_work(definition,actor_id)
	if not requested.get("accepted",false): return {"status":"request_rejected","reason":requested.get("reason","")}
	for _work_tick in int(definition["duration_ticks"]): facility.tick_procedure_work()
	return facility.procedure_work_state["tasks"].get(requested.get("task_id",""),{})

func _check(value:bool,message:String)->void:
	if not value: fails+=1; push_error("FAIL: "+message)
