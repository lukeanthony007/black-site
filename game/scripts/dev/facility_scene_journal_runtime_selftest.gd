extends Node
## Pure durable-journal contract: commit ordering, torn records, checksum, stale rollback.

const JOURNAL_DIR := "user://facility_scene_journal_runtime_selftest"
var _fails := 0


func _ready() -> void:
	print("=== facility_scene_journal_runtime_selftest ===")
	var script: Script = load("res://scripts/facility/facility_scene_journal_runtime.gd")
	if script == null or not script.can_instantiate():
		_fail("scene journal runtime unavailable")
		_finish()
		return
	var journal: RefCounted = script.new()
	journal.clear_journal(JOURNAL_DIR)
	var first := _checkpoint(1, "one")
	var second := _checkpoint(2, "two")
	_check(journal.commit_checkpoint(JOURNAL_DIR, first).get("accepted", false), "epoch one did not commit")
	_check(journal.commit_checkpoint(JOURNAL_DIR, second).get("accepted", false), "epoch two did not commit")
	var latest: Dictionary = journal.load_committed(JOURNAL_DIR)
	_check(latest.get("accepted", false) and latest.get("epoch", 0) == 2 and latest["checkpoint"]["probe"] == "two", "journal did not load committed head")
	_check(not journal.load_committed(JOURNAL_DIR, 1).get("accepted", true), "journal admitted stale rollback below committed head")
	var absolute_dir := ProjectSettings.globalize_path(JOURNAL_DIR)
	var torn := FileAccess.open(absolute_dir.path_join("epoch-00000000000000000003.json"), FileAccess.WRITE)
	_check(torn != null, "could not create torn-record fixture")
	if torn != null:
		torn.store_string("{\"journal_version\":")
		torn.flush()
		torn.close()
	var after_torn: Dictionary = journal.load_committed(JOURNAL_DIR)
	_check(after_torn.get("accepted", false) and after_torn.get("epoch", 0) == 2, "unheaded torn newer record displaced committed head")
	DirAccess.remove_absolute(absolute_dir.path_join("head.json"))
	var scanned: Dictionary = journal.load_committed(JOURNAL_DIR)
	_check(scanned.get("accepted", false) and scanned.get("epoch", 0) == 2, "headless scan did not select newest complete epoch")
	var recommit: Dictionary = journal.commit_checkpoint(JOURNAL_DIR, _checkpoint(3, "three"))
	_check(recommit.get("accepted", false), "epoch three did not re-establish head")
	var record_path: String = absolute_dir.path_join("epoch-00000000000000000003.json")
	var corrupt := FileAccess.open(record_path, FileAccess.WRITE)
	_check(corrupt != null, "could not create committed-corruption fixture")
	if corrupt != null:
		corrupt.store_string(JSON.stringify({"journal_version": "facility-scene-journal/v1", "epoch": 3, "checkpoint": _checkpoint(3, "tampered"), "checksum": "forged"}))
		corrupt.flush()
		corrupt.close()
	var committed_corrupt: Dictionary = journal.load_committed(JOURNAL_DIR)
	_check(not committed_corrupt.get("accepted", true) and committed_corrupt.get("reason", "").contains("committed head"), "corrupt committed head silently rolled back")
	journal.clear_journal(JOURNAL_DIR)
	if _fails == 0:
		_ok("journal distinguishes torn uncommitted records from corrupt committed authority")
	_finish()


func _checkpoint(epoch: int, probe: String) -> Dictionary:
	return {
		"accepted": true,
		"version": "generated-facility-scene/v1",
		"epoch": epoch,
		"facility_seed": 7319,
		"graph_fingerprint": "fixture",
		"owners": {},
		"probe": probe,
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _ok(message: String) -> void:
	print("OK: %s" % message)


func _fail(message: String) -> void:
	_fails += 1
	push_error("FAIL: %s" % message)


func _finish() -> void:
	print("=== facility_scene_journal_runtime_selftest done fails=%d ===" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
