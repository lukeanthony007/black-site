extends Node
var fails:=0
func _ready()->void:
	var cli: PackedStringArray=OS.get_cmdline_user_args()
	if cli.has("--utility-recovery-read"):
		var utility_reader=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(utility_reader)
		for _urr in 4: await get_tree().process_frame
		var utility_loaded: Dictionary=utility_reader.recover_scene_journal("/tmp/blacksite_utility_recovery_journal"); var terminal_actions: Dictionary={"cooling":{},"communications":{},"access_control":{},"environmental_monitoring":{}}
		for utility_task in utility_reader.procedure_work_state["tasks"].values():
			var utility_service: String=utility_task.get("service","")
			if terminal_actions.has(utility_service) and utility_task.get("status","")=="committed": terminal_actions[utility_service][utility_task.get("action","")]=true
		var expected_terminal: Array[String]=["isolate_for_repair","begin_repair","record_repair","functional_test","verify_reconstitution"]
		_check(utility_loaded.get("accepted",false) and utility_reader.infrastructure_runtime.service_phase(utility_reader.infrastructure_state,"cooling")=="normal" and utility_reader.infrastructure_runtime.service_phase(utility_reader.infrastructure_state,"communications")=="normal" and utility_reader.infrastructure_runtime.service_phase(utility_reader.infrastructure_state,"access_control")=="normal" and utility_reader.infrastructure_runtime.service_phase(utility_reader.infrastructure_state,"environmental_monitoring")=="normal" and utility_reader.control_network_state.get("posture","")=="isolated" and expected_terminal.all(func(action): return terminal_actions["cooling"].has(action) and terminal_actions["communications"].has(action) and terminal_actions["access_control"].has(action) and terminal_actions["environmental_monitoring"].has(action)),"utility recovery reader lost terminal facility-control authority")
		_check(not utility_reader.environmental_observation_state.get("active",true) and utility_reader.environmental_observation_state.get("observations",[]).size()==3,"utility reader lost closed environmental observation evidence")
		print("UTILITY_RECOVERY_JOURNAL_READER_OK" if fails==0 else "UTILITY_RECOVERY_JOURNAL_READER_FAILED"); get_tree().quit(0 if fails==0 else 1); return
	if cli.has("--utility-recovery-write"):
		var utility_writer=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(utility_writer)
		for _urw in 4: await get_tree().process_frame
		_check(utility_writer.declare_control_network_compromise("control-network:utility-journal:1","utility-control-owner").get("accepted",false),"utility writer control isolation rejected")
		var utility_panel_sets: Dictionary={
			"cooling":["cooling:enter_controlled_shutdown@security_control","cooling:isolate_for_repair@plant","cooling:begin_repair@plant","cooling:record_repair@plant","cooling:functional_test@plant","cooling:verify_reconstitution@security_control"],
			"communications":["communications:isolate_external_links@security_control","communications:isolate_for_repair@compute_core","communications:begin_repair@compute_core","communications:record_repair@compute_core","communications:functional_test@compute_core","communications:verify_reconstitution@security_control"],
			"access_control":["access_control:enforce_guarded_entry@security_control","access_control:isolate_for_repair@security_control","access_control:begin_repair@security_control","access_control:record_repair@security_control","access_control:functional_test@security_control","access_control:verify_reconstitution@security_control"],
			"environmental_monitoring":["environmental_monitoring:establish_manual_sensor_rounds@security_control","environmental_monitoring:isolate_for_repair@plant","environmental_monitoring:begin_repair@plant","environmental_monitoring:record_repair@plant","environmental_monitoring:functional_test@plant","environmental_monitoring:verify_reconstitution@security_control"],
		}
		for utility_service in utility_panel_sets:
			_check(utility_writer.set_service_available(utility_service,false).get("accepted",false),"utility writer failure rejected: "+utility_service)
			if utility_service == "environmental_monitoring":
				for _observation_tick in 24:
					if utility_writer.environmental_observation_state.get("active_round", {}).is_empty(): break
					var active_round: Dictionary = utility_writer.environmental_observation_state["active_round"]
					var observation_room: String = active_round["assignments"][active_round["room_index"]]["room"]
					utility_writer.tick_environmental_observation_rounds({observation_room:{"temperature":20.0,"relative_humidity":42.0,"water_intrusion":false,"smoke_or_local_alarm":false}})
				_check(utility_writer.environmental_observation_state.get("completed_rounds", []).size()==1,"utility writer did not complete environmental observation round")
			for utility_panel in utility_panel_sets[utility_service]: _check(_run_named_panel(utility_writer,utility_panel).get("status","")=="committed","utility writer work failed: "+utility_panel)
			if utility_service == "environmental_monitoring":
				_check(not utility_writer.environmental_observation_state.get("active",true) and utility_writer.environmental_observation_state.get("observations",[]).size()==3,"monitoring reconstitution did not close round authority while retaining evidence")
		var utility_commit: Dictionary=utility_writer.commit_scene_journal("/tmp/blacksite_utility_recovery_journal"); _check(utility_commit.get("accepted",false),"utility recovery journal commit rejected")
		print("UTILITY_RECOVERY_JOURNAL_WRITER_OK" if fails==0 else "UTILITY_RECOVERY_JOURNAL_WRITER_FAILED"); get_tree().quit(0 if fails==0 else 1); return
	if cli.has("--control-power-restored-read"):
		var final_reader=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(final_reader)
		for _pfr in 4: await get_tree().process_frame
		var final_loaded: Dictionary=final_reader.recover_scene_journal("/tmp/blacksite_control_power_interruption_journal"); var committed_control:=false; var committed_power_actions: Dictionary={}
		for final_task in final_reader.procedure_work_state["tasks"].values():
			if final_task.get("action","")=="control_network_reconstitute" and final_task.get("status","")=="committed": committed_control=true
			if final_task.get("service","")=="power" and final_task.get("status","")=="committed": committed_power_actions[final_task.get("action","")]=true
		_check(final_loaded.get("accepted",false) and final_reader.infrastructure_runtime.service_phase(final_reader.infrastructure_state,"power")=="normal" and final_reader.control_network_state.get("posture","")=="normal" and committed_control and ["shed_noncritical_load","isolate_for_repair","begin_repair","record_repair","functional_test","verify_reconstitution"].all(func(action): return committed_power_actions.has(action)),"terminal reader lost complete power/control recovery chain")
		print("CONTROL_POWER_RESTORED_FINAL_READER_OK" if fails==0 else "CONTROL_POWER_RESTORED_FINAL_READER_FAILED"); get_tree().quit(0 if fails==0 else 1); return
	if cli.has("--control-power-interruption-read"):
		var power_reader=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(power_reader)
		for _pir in 4: await get_tree().process_frame
		var power_loaded: Dictionary=power_reader.recover_scene_journal("/tmp/blacksite_control_power_interruption_journal")
		var interrupted_control: Dictionary={}; var committed_shed:=false; var committed_isolation:=false
		for power_task in power_reader.procedure_work_state["tasks"].values():
			if power_task.get("action","")=="control_network_reconstitute": interrupted_control=power_task
			if power_task.get("service","")=="power" and power_task.get("action","")=="shed_noncritical_load" and power_task.get("status","")=="committed": committed_shed=true
			if power_task.get("service","")=="power" and power_task.get("action","")=="isolate_for_repair" and power_task.get("status","")=="committed" and power_task.get("control_mode","")=="hardwired_local_isolation": committed_isolation=true
		_check(power_loaded.get("accepted",false) and power_reader.infrastructure_runtime.service_phase(power_reader.infrastructure_state,"power")=="repair_pending" and interrupted_control.get("status","")=="interrupted" and interrupted_control.get("remaining_ticks",0)==1 and interrupted_control.get("interruptions",[])[-1].get("reason","")=="required_service_unavailable:power" and committed_shed and committed_isolation and power_reader.control_network_state.get("posture","")=="isolated","separate reader lost degraded power/control causal chain")
		var interrupted_before_resume: Dictionary=interrupted_control.duplicate(true); var denied_resume: Dictionary=power_reader.resume_procedure_work(interrupted_control.get("task_id",""))
		_check(not denied_resume.get("accepted",true) and denied_resume.get("reason","")=="required_service_unavailable:power" and power_reader.procedure_work_state["tasks"][interrupted_control["task_id"]]==interrupted_before_resume and power_reader.control_network_state.get("posture","")=="isolated","restart allowed control reconstitution before physical power restoration")
		var began_repair: Dictionary=_run_named_panel(power_reader,"power:begin_repair@plant"); _check(began_repair.get("status","")=="committed" and power_reader.infrastructure_runtime.service_phase(power_reader.infrastructure_state,"power")=="repair_pending","local repair authorization failed after restart")
		var recorded_repair: Dictionary=_run_named_panel(power_reader,"power:record_repair@plant"); _check(recorded_repair.get("status","")=="committed" and power_reader.infrastructure_runtime.service_phase(power_reader.infrastructure_state,"power")=="testing","local repair work did not reach testing")
		var tested_power: Dictionary=_run_named_panel(power_reader,"power:functional_test@plant"); _check(tested_power.get("status","")=="committed" and power_reader.infrastructure_runtime.service_phase(power_reader.infrastructure_state,"power")=="reconstitution_pending","local power functional test did not reach independent verification")
		var verified_power: Dictionary=_run_named_panel(power_reader,"power:verify_reconstitution@security_control"); _check(verified_power.get("status","")=="committed" and power_reader.infrastructure_runtime.service_phase(power_reader.infrastructure_state,"power")=="normal","independent hardwired power verification did not restore power")
		_check(power_reader.resume_procedure_work(interrupted_control["task_id"]).get("accepted",false),"restored power did not permit explicit control reconstitution resume"); power_reader.tick_procedure_work()
		_check(power_reader.procedure_work_state["tasks"][interrupted_control["task_id"]].get("status","")=="committed" and power_reader.control_network_state.get("posture","")=="normal","resumed control reconstitution did not commit after power restoration")
		var restored_commit: Dictionary=power_reader.commit_scene_journal("/tmp/blacksite_control_power_interruption_journal"); _check(restored_commit.get("accepted",false),"restored power/control epoch commit rejected")
		print("CONTROL_POWER_RESTORER_OK" if fails==0 else "CONTROL_POWER_RESTORER_FAILED")
		print("CONTROL_POWER_INTERRUPTION_JOURNAL_READER_OK" if fails==0 else "CONTROL_POWER_INTERRUPTION_JOURNAL_READER_FAILED"); get_tree().quit(0 if fails==0 else 1); return
	if cli.has("--control-recurrence-read"):
		var recurrence_reader=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(recurrence_reader)
		for _crr in 4: await get_tree().process_frame
		var recurrence_loaded: Dictionary=recurrence_reader.recover_scene_journal("/tmp/blacksite_control_recurrence_journal")
		var recurrence_history: Array=recurrence_reader.control_network_state.get("history",[])
		_check(recurrence_loaded.get("accepted",false) and recurrence_reader.control_network_state.get("posture","")=="normal" and recurrence_history.size()==6 and recurrence_history[3].get("occurrence_id","")=="control-network:generated:2" and recurrence_history[5].get("occurrence_id","")=="control-network:generated:2" and recurrence_reader.control_network_state["functional_test"].get("occurrence_id","")=="control-network:generated:2" and recurrence_reader.infrastructure_runtime.service_phase(recurrence_reader.infrastructure_state,"cooling")=="safe_hold","separate reader did not recover two isolated control lifecycles")
		print("CONTROL_RECURRENCE_JOURNAL_READER_OK" if fails==0 else "CONTROL_RECURRENCE_JOURNAL_READER_FAILED"); get_tree().quit(0 if fails==0 else 1); return
	if cli.has("--control-reconstitution-read"):
		var rc_reader=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(rc_reader)
		for _rr in 4: await get_tree().process_frame
		var rc_loaded: Dictionary=rc_reader.recover_scene_journal("/tmp/blacksite_control_reconstitution_journal")
		var rc_task_id: String=""
		for candidate in rc_reader.procedure_work_state["tasks"]:
			if rc_reader.procedure_work_state["tasks"][candidate].get("action","")=="control_network_reconstitute": rc_task_id=candidate
		_check(rc_loaded.get("accepted",false) and not rc_task_id.is_empty() and rc_reader.procedure_work_state["tasks"][rc_task_id].get("remaining_ticks",0)==1 and rc_reader.control_network_state.get("posture","")=="isolated","separate reader lost mid-reconstitution authority")
		_check(rc_reader.resume_procedure_work(rc_task_id).get("accepted",false),"separate reader could not resume reconstitution")
		rc_reader.tick_procedure_work(); _check(rc_reader.control_network_state.get("posture","")=="normal" and rc_reader.infrastructure_runtime.service_phase(rc_reader.infrastructure_state,"cooling")=="safe_hold" and rc_reader.procedure_work_state["tasks"][rc_task_id].get("status","")=="committed","separate reader did not finish exact reconstitution work")
		print("CONTROL_RECONSTITUTION_JOURNAL_READER_OK" if fails==0 else "CONTROL_RECONSTITUTION_JOURNAL_READER_FAILED"); get_tree().quit(0 if fails==0 else 1); return
	if cli.has("--control-work-read"):
		var work_reader=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(work_reader)
		for _wr in 4: await get_tree().process_frame
		var loaded_work: Dictionary=work_reader.recover_scene_journal("/tmp/blacksite_control_work_journal")
		var task_ids: Array=work_reader.procedure_work_state["tasks"].keys(); task_ids.sort(); var task_id: String=task_ids[0] if not task_ids.is_empty() else ""
		_check(loaded_work.get("accepted",false) and not task_id.is_empty() and work_reader.procedure_work_state["tasks"][task_id].get("remaining_ticks",0)==1 and work_reader.control_network_state["functional_test"].is_empty(),"separate reader lost mid-test work")
		_check(work_reader.resume_procedure_work(task_id).get("accepted",false),"separate reader could not explicitly resume test")
		work_reader.tick_procedure_work(); _check(not work_reader.control_network_state["functional_test"].is_empty() and work_reader.procedure_work_state["tasks"][task_id].get("status","")=="committed","separate reader did not finish exact remaining work")
		print("CONTROL_WORK_JOURNAL_READER_OK" if fails==0 else "CONTROL_WORK_JOURNAL_READER_FAILED"); get_tree().quit(0 if fails==0 else 1); return
	if cli.has("--control-journal-read"):
		var reader=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(reader)
		for _r in 4: await get_tree().process_frame
		var loaded: Dictionary=reader.recover_scene_journal("/tmp/blacksite_control_network_journal")
		_check(loaded.get("accepted",false) and reader.control_network_state.get("posture","")=="isolated" and reader.infrastructure_runtime.service_phase(reader.infrastructure_state,"cooling")=="safe_hold","separate process lost isolated control network or physical phase")
		print("CONTROL_NETWORK_JOURNAL_READER_OK" if fails==0 else "CONTROL_NETWORK_JOURNAL_READER_FAILED"); get_tree().quit(0 if fails==0 else 1); return
	var facility=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(facility)
	for _i in 4: await get_tree().process_frame
	facility.set_service_available("cooling",false)
	var before_phase: String=facility.infrastructure_runtime.service_phase(facility.infrastructure_state,"cooling")
	var result: Dictionary=facility.declare_control_network_compromise("control-network:generated:1","ids-7")
	var primary: Node=_panel(facility,"cooling:enter_controlled_shutdown")
	var hardwired: Node=_panel(facility,"cooling:enter_controlled_shutdown@security_control")
	_check(result.get("accepted",false),"generated compromise rejected")
	_check(facility.control_status_board.text.contains("CONTROL isolated") and facility.control_status_board.text.contains("control-network:generated:1"),"control board omitted isolated control-network occurrence")
	_check(primary != null and not primary.get_meta("available",true),"remote primary panel remained available")
	_check(hardwired != null and hardwired.get_meta("available",false),"hardwired panel became unavailable")
	_check(before_phase==facility.infrastructure_runtime.service_phase(facility.infrastructure_state,"cooling"),"control isolation fabricated physical cooling failure")
	if cli.has("--control-journal-write"):
		var committed: Dictionary=facility.commit_scene_journal("/tmp/blacksite_control_network_journal")
		_check(committed.get("accepted",false),"control-network journal commit rejected")
		print("CONTROL_NETWORK_JOURNAL_WRITER_OK" if fails==0 else "CONTROL_NETWORK_JOURNAL_WRITER_FAILED"); get_tree().quit(0 if fails==0 else 1); return
	var checkpoint: Dictionary=facility.export_scene_checkpoint(); _check(checkpoint.has("owners"),"control checkpoint export failed after service expansion: %s" % checkpoint); if not checkpoint.has("owners"): get_tree().quit(1); return
	var recovered=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(recovered)
	for _j in 4: await get_tree().process_frame
	var forged_checkpoint: Dictionary=checkpoint.duplicate(true); forged_checkpoint["owners"]["control_network"]["state"]["active_incident"]["occurrence_id"]="control-network:forged"
	var forged_result: Dictionary=recovered.recover_scene_checkpoint(forged_checkpoint)
	_check(not forged_result.get("accepted",true) and recovered.control_network_state.get("posture","")=="normal" and recovered.infrastructure_runtime.service_phase(recovered.infrastructure_state,"cooling")=="normal" and recovered.last_recovered_scene_epoch==0,"forged control-network history mutated live or epoch authority")
	var recovery: Dictionary=recovered.recover_scene_checkpoint(checkpoint)
	_check(recovery.get("accepted",false) and recovered.control_network_state.get("posture","")=="isolated" and recovered.infrastructure_runtime.service_phase(recovered.infrastructure_state,"cooling")==before_phase,"control isolation did not survive composite recovery")
	var tester: String=recovered.staffing_state["assignments"]["day"]["cyber_analyst"][0]; var approver: String=recovered.staffing_state["assignments"]["day"]["duty_officer"][0]
	recovered.staff_agent_state["agents"][tester]["current_room"]="security_control"; recovered.staff_agent_state["agents"][tester]["route"]=[]; recovered.staff_agent_state["agents"][tester]["status"]="at_post"; recovered.staff_agent_state["agents"][approver]["current_room"]="security_control"; recovered.staff_agent_state["agents"][approver]["route"]=[]; recovered.staff_agent_state["agents"][approver]["status"]="at_post"
	var analysts: Array=recovered.staffing_state["assignments"]["day"]["cyber_analyst"]; _check(analysts.size()>1,"exact-actor rollback proof needs two analysts")
	var alternate_tester: String=analysts[1]; recovered.staff_agent_state["agents"][alternate_tester]["current_room"]="security_control"; recovered.staff_agent_state["agents"][alternate_tester]["route"]=[]; recovered.staff_agent_state["agents"][alternate_tester]["status"]="at_post"
	var work_before_wrong: Dictionary=recovered.procedure_work_state.duplicate(true); var agents_before_wrong: Dictionary=recovered.staff_agent_state.duplicate(true)
	var wrong_actor: Dictionary=recovered.start_control_network_functional_test("control-network:generated:1",alternate_tester)
	_check(not wrong_actor.get("accepted",true) and recovered.procedure_work_state==work_before_wrong and recovered.staff_agent_state==agents_before_wrong,"wrong exact actor denial left orphan work or agent mutation")
	_check(not recovered.record_control_network_functional_test("control-network:generated:1","sensor-operator-1").get("accepted",true),"incident owner self-tested control network")
	var started_test: Dictionary=recovered.start_control_network_functional_test("control-network:generated:1",tester)
	_check(started_test.get("accepted",false) and recovered.procedure_work_state["tasks"][started_test.get("task_id","")].get("remaining_ticks",0)==2 and recovered.control_network_state["functional_test"].is_empty(),"functional test was not admitted as two-tick work")
	recovered.staff_agent_state["agents"][tester]["current_room"]="cyber_ops"; recovered.staff_agent_state["agents"][tester]["route"]=[]
	recovered.tick_procedure_work()
	var interrupted_task: Dictionary=recovered.procedure_work_state["tasks"][started_test["task_id"]]
	_check(interrupted_task.get("status","")=="interrupted" and interrupted_task.get("remaining_ticks",0)==2 and interrupted_task.get("interruptions",[])[-1].get("reason","")=="actor_left_station" and recovered.control_network_state["functional_test"].is_empty(),"tester departure advanced work or created semantic evidence")
	var interrupted_checkpoint: Dictionary=recovered.export_scene_checkpoint(); var interruption_resumed=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(interruption_resumed)
	for _ir in 4: await get_tree().process_frame
	var interruption_recovery: Dictionary=interruption_resumed.recover_scene_checkpoint(interrupted_checkpoint); var recovered_interrupted_task: Dictionary=interruption_resumed.procedure_work_state["tasks"].get(started_test["task_id"],{})
	_check(interruption_recovery.get("accepted",false) and recovered_interrupted_task.get("status","")=="interrupted" and recovered_interrupted_task.get("remaining_ticks",0)==2 and recovered_interrupted_task.get("interruptions",[])[-1].get("reason","")=="actor_left_station" and interruption_resumed.control_network_state["functional_test"].is_empty(),"restart lost test interruption blocker or duration")
	interruption_resumed.staff_agent_state["agents"][tester]["current_room"]="security_control"; interruption_resumed.staff_agent_state["agents"][tester]["route"]=[]; interruption_resumed.staff_agent_state["agents"][tester]["status"]="at_post"
	_check(interruption_resumed.resume_procedure_work(started_test["task_id"]).get("accepted",false),"returned tester could not explicitly resume interrupted work")
	recovered=interruption_resumed; recovered.tick_procedure_work(); _check(recovered.control_network_state["functional_test"].is_empty(),"functional test committed after one resumed tick")
	if cli.has("--control-work-write"):
		var work_committed: Dictionary=recovered.commit_scene_journal("/tmp/blacksite_control_work_journal")
		_check(work_committed.get("accepted",false),"mid-test journal commit rejected")
		print("CONTROL_WORK_JOURNAL_WRITER_OK" if fails==0 else "CONTROL_WORK_JOURNAL_WRITER_FAILED"); get_tree().quit(0 if fails==0 else 1); return
	var mid_checkpoint: Dictionary=recovered.export_scene_checkpoint(); var resumed=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(resumed)
	for _m in 4: await get_tree().process_frame
	var mid_recovery: Dictionary=resumed.recover_scene_checkpoint(mid_checkpoint)
	_check(mid_recovery.get("accepted",false) and resumed.procedure_work_state["tasks"].get(started_test.get("task_id",""),{}).get("remaining_ticks",0)==1 and resumed.control_network_state["functional_test"].is_empty(),"mid-test checkpoint did not preserve one remaining tick")
	_check(resumed.resume_procedure_work(started_test["task_id"]).get("accepted",false),"recovered functional test did not require and accept explicit resume")
	resumed.tick_procedure_work(); _check(resumed.control_network_state["functional_test"].get("actor_id","")==tester,"recovered functional-test work did not commit evidence")
	recovered=resumed
	_check(not recovered.reconstitute_control_network("control-network:generated:1",tester).get("accepted",true),"tester self-approved reconstitution")
	var staffing_before_wrong_duty: Dictionary=recovered.staffing_state.duplicate(true); var agents_before_wrong_duty_fixture: Dictionary=recovered.staff_agent_state.duplicate(true)
	var other_duty: String=""
	for person_id in recovered.staffing_state["staff"]:
		if recovered.staffing_state["staff"][person_id].get("job_id","")=="duty_officer" and person_id!=approver: other_duty=person_id; break
	_check(not other_duty.is_empty(),"wrong-duty rollback proof needs another duty officer")
	recovered.staffing_state["assignments"]["day"]["duty_officer"].append(other_duty); recovered.staffing_state["assignments"]["day"]["duty_officer"].sort()
	recovered.staff_agent_state["agents"][other_duty]=recovered.staff_agent_state["agents"][approver].duplicate(true); recovered.staff_agent_state["agents"][other_duty]["person_id"]=other_duty
	var work_before_wrong_duty: Dictionary=recovered.procedure_work_state.duplicate(true); var agents_before_wrong_duty: Dictionary=recovered.staff_agent_state.duplicate(true)
	var wrong_duty: Dictionary=recovered.start_control_network_reconstitution("control-network:generated:1",other_duty)
	_check(not wrong_duty.get("accepted",true) and recovered.procedure_work_state==work_before_wrong_duty and recovered.staff_agent_state==agents_before_wrong_duty,"wrong duty-officer denial left orphan work or agent mutation")
	recovered.staffing_state=staffing_before_wrong_duty; recovered.staff_agent_state=agents_before_wrong_duty_fixture
	var started_reconstitution: Dictionary=recovered.start_control_network_reconstitution("control-network:generated:1",approver)
	_check(started_reconstitution.get("accepted",false) and recovered.procedure_work_state["tasks"][started_reconstitution.get("task_id","")].get("remaining_ticks",0)==2,"reconstitution was not admitted as two-tick work")
	var infrastructure_before_power: Dictionary=recovered.infrastructure_state.duplicate(true); var mission_before_power: Dictionary=recovered.mission_state.duplicate(true)
	_check(recovered.set_service_available("power",false).get("accepted",false),"power support failure declaration rejected")
	var local_power_isolation: Node=_panel(recovered,"power:isolate_for_repair@plant")
	_check(recovered.procedure_panel_definitions.has("power:isolate_for_repair@plant") and local_power_isolation!=null,"isolated control network had no local physical power-isolation procedure")
	for recovery_panel_id in ["power:begin_repair@plant","power:record_repair@plant","power:functional_test@plant"]:
		_check(recovered.procedure_panel_definitions.has(recovery_panel_id) and recovered.procedure_panel_definitions[recovery_panel_id].get("control_mode","")!="primary_control" and recovered.procedure_panel_definitions[recovery_panel_id].get("equipment","")=="local_power_isolation_control","isolated control network had no local power recovery mechanism: "+recovery_panel_id)
	for security_actor in recovered.staffing_state["assignments"]["day"]["security_officer"]:
		recovered.staff_agent_state["agents"][security_actor]["current_room"]="security_control"; recovered.staff_agent_state["agents"][security_actor]["route"]=[]; recovered.staff_agent_state["agents"][security_actor]["status"]="at_post"
	var shed_panel_id: String="power:shed_noncritical_load@security_control"; var shed_panel: Node=_panel(recovered,shed_panel_id)
	_check(shed_panel!=null and shed_panel.get_meta("available",false),"hardwired power load-shed control unavailable during isolation")
	var shed_work: Dictionary=recovered._request_procedure_work(recovered.procedure_panel_definitions[shed_panel_id],"control-support-loss-proof"); _check(shed_work.get("accepted",false),"hardwired power load-shed work rejected")
	recovered.tick_procedure_work(); _check(recovered.infrastructure_runtime.service_phase(recovered.infrastructure_state,"power")=="load_shed","hardwired load-shed work did not commit physical power phase")
	for facilities_actor in recovered.staffing_state["assignments"]["day"]["facilities_engineer"]:
		recovered.staff_agent_state["agents"][facilities_actor]["current_room"]="plant"; recovered.staff_agent_state["agents"][facilities_actor]["route"]=[]; recovered.staff_agent_state["agents"][facilities_actor]["status"]="at_post"
	recovered._refresh_procedure_panels(); _check(local_power_isolation.get_meta("available",false),"local plant isolation control unavailable in load-shed phase")
	var isolate_work: Dictionary=recovered._request_procedure_work(recovered.procedure_panel_definitions["power:isolate_for_repair@plant"],"control-support-loss-proof"); _check(isolate_work.get("accepted",false),"local physical power-isolation work rejected")
	recovered.tick_procedure_work(); recovered.tick_procedure_work(); _check(recovered.infrastructure_runtime.service_phase(recovered.infrastructure_state,"power")=="repair_pending","local physical isolation work did not reach repair-pending phase")
	var power_interrupted_task: Dictionary=recovered.procedure_work_state["tasks"][started_reconstitution["task_id"]]
	_check(power_interrupted_task.get("status","")=="interrupted" and power_interrupted_task.get("remaining_ticks",0)==1 and power_interrupted_task.get("interruptions",[])[-1].get("reason","")=="required_service_unavailable:power" and recovered.control_network_state.get("posture","")=="isolated","power loss advanced or reconstituted control work")
	var power_checkpoint: Dictionary=recovered.export_scene_checkpoint(); var power_resumed=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(power_resumed)
	for _pr in 4: await get_tree().process_frame
	var power_recovery: Dictionary=power_resumed.recover_scene_checkpoint(power_checkpoint); var recovered_power_task: Dictionary=power_resumed.procedure_work_state["tasks"].get(started_reconstitution["task_id"],{})
	_check(power_recovery.get("accepted",false) and recovered_power_task.get("status","")=="interrupted" and recovered_power_task.get("remaining_ticks",0)==1 and recovered_power_task.get("interruptions",[])[-1].get("reason","")=="required_service_unavailable:power" and not power_resumed.infrastructure_state["services"]["power"] and power_resumed.control_network_state.get("posture","")=="isolated","restart lost power blocker or reconstitution duration")
	if cli.has("--control-power-interruption-write"):
		var power_commit: Dictionary=power_resumed.commit_scene_journal("/tmp/blacksite_control_power_interruption_journal"); _check(power_commit.get("accepted",false),"degraded power/control journal commit rejected")
		print("CONTROL_POWER_INTERRUPTION_JOURNAL_WRITER_OK" if fails==0 else "CONTROL_POWER_INTERRUPTION_JOURNAL_WRITER_FAILED"); get_tree().quit(0 if fails==0 else 1); return
	power_resumed.infrastructure_state=infrastructure_before_power; power_resumed.mission_state=mission_before_power; power_resumed._refresh_procedure_panels(); power_resumed._apply_service_snapshot(); power_resumed._refresh_control_status_board()
	_check(power_resumed.resume_procedure_work(started_reconstitution["task_id"]).get("accepted",false),"reconstitution did not require restored power and explicit resume")
	recovered=power_resumed
	if cli.has("--control-reconstitution-write"):
		var rc_committed: Dictionary=recovered.commit_scene_journal("/tmp/blacksite_control_reconstitution_journal")
		_check(rc_committed.get("accepted",false),"mid-reconstitution journal commit rejected")
		print("CONTROL_RECONSTITUTION_JOURNAL_WRITER_OK" if fails==0 else "CONTROL_RECONSTITUTION_JOURNAL_WRITER_FAILED"); get_tree().quit(0 if fails==0 else 1); return
	var reconstitution_checkpoint: Dictionary=recovered.export_scene_checkpoint(); var reconstitution_resumed=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(reconstitution_resumed)
	for _rc in 4: await get_tree().process_frame
	var forged_work_checkpoint: Dictionary=reconstitution_checkpoint.duplicate(true); forged_work_checkpoint["owners"]["procedure_work"]["snapshot"]["state"]["tasks"][started_reconstitution["task_id"]]["initiator"]="control-network:forged"
	var forged_work_result: Dictionary=reconstitution_resumed.recover_scene_checkpoint(forged_work_checkpoint)
	_check(not forged_work_result.get("accepted",true) and reconstitution_resumed.last_recovered_scene_epoch==0 and reconstitution_resumed.control_network_state.get("posture","")=="normal","cross-occurrence control task replaced live checkpoint authority")
	var reconstitution_recovery: Dictionary=reconstitution_resumed.recover_scene_checkpoint(reconstitution_checkpoint)
	_check(reconstitution_recovery.get("accepted",false) and reconstitution_resumed.procedure_work_state["tasks"].get(started_reconstitution.get("task_id",""),{}).get("remaining_ticks",0)==1 and reconstitution_resumed.control_network_state.get("posture","")=="isolated","mid-reconstitution checkpoint changed work or posture")
	_check(reconstitution_resumed.resume_procedure_work(started_reconstitution["task_id"]).get("accepted",false),"recovered reconstitution did not explicitly resume")
	reconstitution_resumed.tick_procedure_work(); recovered=reconstitution_resumed
	_check(recovered.control_network_state.get("posture","")=="normal" and recovered.infrastructure_runtime.service_phase(recovered.infrastructure_state,"cooling")==before_phase,"completed named reconstitution did not restore automation without changing physical cooling")
	var terminal_checkpoint: Dictionary=recovered.export_scene_checkpoint()
	var forged_terminal_test: Dictionary=terminal_checkpoint.duplicate(true); forged_terminal_test["owners"]["procedure_work"]["snapshot"]["state"]["tasks"][started_test["task_id"]]["actor_person_id"]=alternate_tester
	var terminal_test_target=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(terminal_test_target)
	for _tt in 4: await get_tree().process_frame
	var terminal_test_result: Dictionary=terminal_test_target.recover_scene_checkpoint(forged_terminal_test); _check(not terminal_test_result.get("accepted",true) and terminal_test_target.last_recovered_scene_epoch==0,"forged committed functional-test actor replaced live authority")
	var forged_terminal_reconstitution: Dictionary=terminal_checkpoint.duplicate(true); forged_terminal_reconstitution["owners"]["procedure_work"]["snapshot"]["state"]["tasks"][started_reconstitution["task_id"]]["actor_person_id"]=other_duty
	var terminal_reconstitution_target=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(terminal_reconstitution_target)
	for _tr in 4: await get_tree().process_frame
	var terminal_reconstitution_result: Dictionary=terminal_reconstitution_target.recover_scene_checkpoint(forged_terminal_reconstitution); _check(not terminal_reconstitution_result.get("accepted",true) and terminal_reconstitution_target.last_recovered_scene_epoch==0,"forged committed reconstitution actor replaced live authority")
	if cli.has("--control-recurrence-write"):
		_check(recovered.declare_control_network_compromise("control-network:generated:2","sensor-operator-2").get("accepted",false),"second generated compromise rejected")
		var second_test: Dictionary=recovered.start_control_network_functional_test("control-network:generated:2",tester); _check(second_test.get("accepted",false),"second timed functional test rejected")
		recovered.tick_procedure_work(); recovered.tick_procedure_work()
		var second_reconstitution: Dictionary=recovered.start_control_network_reconstitution("control-network:generated:2",approver); _check(second_reconstitution.get("accepted",false),"second timed reconstitution rejected")
		recovered.tick_procedure_work(); recovered.tick_procedure_work()
		var recurrence_commit: Dictionary=recovered.commit_scene_journal("/tmp/blacksite_control_recurrence_journal"); _check(recurrence_commit.get("accepted",false) and recovered.control_network_state["history"].size()==6,"second lifecycle journal commit rejected")
		print("CONTROL_RECURRENCE_JOURNAL_WRITER_OK" if fails==0 else "CONTROL_RECURRENCE_JOURNAL_WRITER_FAILED"); get_tree().quit(0 if fails==0 else 1); return
	var cooling_facility=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(cooling_facility)
	for _cf in 4: await get_tree().process_frame
	_check(cooling_facility.set_service_available("cooling",false).get("accepted",false),"cooling failure declaration rejected")
	_check(cooling_facility.declare_control_network_compromise("control-network:cooling-proof:1","cooling-control-owner").get("accepted",false),"cooling proof control isolation rejected")
	var cooling_actions: Array[String]=["cooling:enter_controlled_shutdown@security_control","cooling:isolate_for_repair@plant","cooling:begin_repair@plant","cooling:record_repair@plant","cooling:functional_test@plant","cooling:verify_reconstitution@security_control"]
	for cooling_panel_id in cooling_actions:
		var cooling_task: Dictionary=_run_named_panel(cooling_facility,cooling_panel_id); _check(cooling_task.get("status","")=="committed","cooling degraded recovery work failed: "+cooling_panel_id)
	_check(cooling_facility.infrastructure_runtime.service_phase(cooling_facility.infrastructure_state,"cooling")=="normal" and cooling_facility.control_network_state.get("posture","")=="isolated","cooling recovery changed control-network authority or failed to restore cooling")
	print("COOLING_LOCAL_RECOVERY_EXECUTED_OK" if fails==0 else "COOLING_LOCAL_RECOVERY_EXECUTED_FAILED")
	var communications_facility=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(communications_facility)
	for _cmf in 4: await get_tree().process_frame
	_check(communications_facility.set_service_available("communications",false).get("accepted",false),"communications failure declaration rejected")
	_check(communications_facility.declare_control_network_compromise("control-network:communications-proof:1","communications-control-owner").get("accepted",false),"communications proof control isolation rejected")
	var communications_actions: Array[String]=["communications:isolate_external_links@security_control","communications:isolate_for_repair@compute_core","communications:begin_repair@compute_core","communications:record_repair@compute_core","communications:functional_test@compute_core","communications:verify_reconstitution@security_control"]
	for communications_panel_id in communications_actions:
		var communications_task: Dictionary=_run_named_panel(communications_facility,communications_panel_id); _check(communications_task.get("status","")=="committed","communications degraded recovery work failed: "+communications_panel_id)
	_check(communications_facility.infrastructure_runtime.service_phase(communications_facility.infrastructure_state,"communications")=="normal" and communications_facility.control_network_state.get("posture","")=="isolated","communications recovery changed control-network authority")
	print("COMMUNICATIONS_LOCAL_RECOVERY_EXECUTED_OK")
	var access_facility=load("res://scenes/dev_generated_facility.tscn").instantiate(); add_child(access_facility); await get_tree().process_frame
	_check(access_facility.set_service_available("access_control",false).get("accepted",false),"access-control failure declaration rejected")
	_check(access_facility.declare_control_network_compromise("control-access-recovery-owner","access-control-automation-untrusted").get("accepted",false),"access-control recovery did not isolate automation")
	for access_panel_id in ["access_control:enforce_guarded_entry@security_control","access_control:isolate_for_repair@security_control","access_control:begin_repair@security_control","access_control:record_repair@security_control","access_control:functional_test@security_control","access_control:verify_reconstitution@security_control"]:
		var access_task: Dictionary=_run_named_panel(access_facility,access_panel_id); _check(access_task.get("status","")=="committed","access-control recovery work failed: "+access_panel_id)
	_check(access_facility.infrastructure_runtime.service_phase(access_facility.infrastructure_state,"access_control")=="normal" and access_facility.control_network_state.get("posture","")=="isolated","access-control restoration changed automation authority or failed")
	print("ACCESS_CONTROL_LOCAL_RECOVERY_EXECUTED_OK" if fails==0 else "ACCESS_CONTROL_LOCAL_RECOVERY_EXECUTED_FAILED")
	print("=== generated_facility_control_network_selftest done fails=%d ==="%fails); get_tree().quit(0 if fails==0 else 1)
func _run_named_panel(facility, panel_id: String) -> Dictionary:
	if not facility.procedure_panel_definitions.has(panel_id): return {"accepted":false,"reason":"unknown_panel"}
	var definition: Dictionary=facility.procedure_panel_definitions[panel_id]
	var panel: Node=_panel(facility,panel_id)
	if panel==null or not panel.get_meta("available",false): return {"accepted":false,"reason":"panel_unavailable"}
	var role: String=definition["actor_job"]; var station: String=definition["station"]
	for actor in facility.staffing_state["assignments"]["day"].get(role,[]):
		facility.staff_agent_state["agents"][actor]["current_room"]=station; facility.staff_agent_state["agents"][actor]["route"]=[]; facility.staff_agent_state["agents"][actor]["status"]="at_post"
	facility._refresh_procedure_panels()
	var requested: Dictionary=facility._request_procedure_work(definition,"power-restoration-proof")
	if not requested.get("accepted",false): return requested
	for _tick in int(definition["duration_ticks"]): facility.tick_procedure_work()
	return facility.procedure_work_state["tasks"].get(requested.get("task_id",""),{})


func _panel(facility,id:String)->Node:
	for p in facility.procedure_panels.get_children():
		if p.get_meta("panel_id","")==id:return p
	return null
func _check(v:bool,m:String)->void:
	if not v:fails+=1;push_error("FAIL: %s"%m)
