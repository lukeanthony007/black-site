class_name FacilitySceneJournalRuntime
extends RefCounted
## Append-only, checksummed scene checkpoint records with an atomically advanced head.

const JOURNAL_VERSION := "facility-scene-journal/v1"
const HEAD_FILE := "head.json"


func commit_checkpoint(directory: String, checkpoint: Dictionary) -> Dictionary:
	var epoch := int(checkpoint.get("epoch", 0))
	if epoch < 1 or checkpoint.get("version", "") != "generated-facility-scene/v1":
		return _denied("journal checkpoint identity is invalid")
	var absolute_dir := _absolute(directory)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if mkdir_error != OK and mkdir_error != ERR_ALREADY_EXISTS:
		return _denied("journal directory could not be created")
	var current: Dictionary = load_committed(directory)
	if current.get("accepted", false) and epoch <= int(current["epoch"]):
		return _denied("journal checkpoint epoch is stale or replayed")
	if not current.get("accepted", false) and not current.get("empty", false):
		return _denied("journal committed authority is unreadable: %s" % current.get("reason", "unknown"))
	var checkpoint_text := JSON.stringify(checkpoint)
	var checksum := _sha256(checkpoint_text)
	var record_name := _record_name(epoch)
	var record := {
		"journal_version": JOURNAL_VERSION,
		"epoch": epoch,
		"checkpoint_json": checkpoint_text,
		"checksum": checksum,
	}
	var record_result := _write_atomic(absolute_dir.path_join(record_name), JSON.stringify(record))
	if not record_result.get("accepted", false):
		return record_result
	var head := {
		"journal_version": JOURNAL_VERSION,
		"epoch": epoch,
		"record": record_name,
		"checksum": checksum,
	}
	var head_result := _write_atomic(absolute_dir.path_join(HEAD_FILE), JSON.stringify(head))
	if not head_result.get("accepted", false):
		return _denied("journal epoch record is durable but head did not advance")
	return {"accepted": true, "epoch": epoch, "record": record_name, "checksum": checksum}


func load_committed(directory: String, requested_epoch: int = -1) -> Dictionary:
	var absolute_dir := _absolute(directory)
	if not DirAccess.dir_exists_absolute(absolute_dir):
		return {"accepted": false, "empty": true, "reason": "journal is empty"}
	var head_path := absolute_dir.path_join(HEAD_FILE)
	if FileAccess.file_exists(head_path):
		var head_result := _read_json_dictionary(head_path)
		if not head_result.get("accepted", false):
			return _denied("committed head is malformed")
		var head: Dictionary = head_result["value"]
		var epoch := int(head.get("epoch", 0))
		var expected_name := _record_name(epoch)
		if head.get("journal_version", "") != JOURNAL_VERSION or head.get("record", "") != expected_name or String(head.get("checksum", "")).is_empty():
			return _denied("committed head identity is invalid")
		if requested_epoch >= 0 and requested_epoch != epoch:
			return _denied("requested journal epoch is not the committed head")
		var record_result := _load_record(absolute_dir.path_join(expected_name), epoch, head["checksum"])
		if not record_result.get("accepted", false):
			return _denied("committed head record is invalid: %s" % record_result.get("reason", "unknown"))
		return record_result
	var newest: Dictionary = {}
	var files: PackedStringArray = DirAccess.get_files_at(absolute_dir)
	for file_name in files:
		if not file_name.begins_with("epoch-") or not file_name.ends_with(".json"):
			continue
		var record_result := _load_record(absolute_dir.path_join(file_name))
		if record_result.get("accepted", false) and (newest.is_empty() or int(record_result["epoch"]) > int(newest["epoch"])):
			newest = record_result
	if newest.is_empty():
		return {"accepted": false, "empty": true, "reason": "journal has no complete epoch record"}
	if requested_epoch >= 0 and requested_epoch != int(newest["epoch"]):
		return _denied("requested journal epoch is not the newest complete epoch")
	return newest


func clear_journal(directory: String) -> Dictionary:
	var absolute_dir := _absolute(directory)
	if not DirAccess.dir_exists_absolute(absolute_dir):
		return {"accepted": true, "already_empty": true}
	for file_name in DirAccess.get_files_at(absolute_dir):
		DirAccess.remove_absolute(absolute_dir.path_join(file_name))
	var error := DirAccess.remove_absolute(absolute_dir)
	return {"accepted": error == OK, "already_empty": false, "error": error}


func _load_record(path: String, expected_epoch: int = -1, expected_checksum: String = "") -> Dictionary:
	var parsed := _read_json_dictionary(path)
	if not parsed.get("accepted", false):
		return _denied("epoch record is malformed")
	var record: Dictionary = parsed["value"]
	var epoch := int(record.get("epoch", 0))
	if record.get("journal_version", "") != JOURNAL_VERSION or epoch < 1 or not record.get("checkpoint_json", null) is String:
		return _denied("epoch record identity is invalid")
	if expected_epoch >= 0 and epoch != expected_epoch:
		return _denied("epoch record does not match head")
	var checkpoint_text: String = record["checkpoint_json"]
	var checkpoint_json := JSON.new()
	if checkpoint_json.parse(checkpoint_text) != OK:
		return _denied("epoch checkpoint JSON is malformed")
	var checkpoint: Variant = checkpoint_json.data
	if not checkpoint is Dictionary or int(checkpoint.get("epoch", 0)) != epoch:
		return _denied("epoch record/checkpoint mismatch")
	var actual_checksum := _sha256(checkpoint_text)
	if record.get("checksum", "") != actual_checksum:
		return _denied("epoch record checksum mismatch")
	if not expected_checksum.is_empty() and actual_checksum != expected_checksum:
		return _denied("epoch record checksum does not match head")
	return {
		"accepted": true,
		"epoch": epoch,
		"checkpoint": (checkpoint as Dictionary).duplicate(true),
		"checksum": actual_checksum,
	}


func _read_json_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _denied("file cannot be read")
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return _denied("file contains malformed JSON")
	var parsed: Variant = json.data
	if not parsed is Dictionary:
		return _denied("file is not a JSON dictionary")
	return {"accepted": true, "value": parsed}


func _write_atomic(path: String, text: String) -> Dictionary:
	var temp_path := "%s.tmp" % path
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return _denied("journal temporary file cannot be opened")
	file.store_string(text)
	file.flush()
	file.close()
	if FileAccess.file_exists(path):
		var remove_error := DirAccess.remove_absolute(path)
		if remove_error != OK:
			DirAccess.remove_absolute(temp_path)
			return _denied("journal prior file cannot be retired")
	var rename_error := DirAccess.rename_absolute(temp_path, path)
	if rename_error != OK:
		DirAccess.remove_absolute(temp_path)
		return _denied("journal temporary file cannot be committed")
	return {"accepted": true}


func _sha256(text: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(text.to_utf8_buffer())
	return context.finish().hex_encode()


func _record_name(epoch: int) -> String:
	return "epoch-%020d.json" % epoch


func _absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path) if path.begins_with("user://") or path.begins_with("res://") else path


func _denied(reason: String) -> Dictionary:
	return {"accepted": false, "reason": reason}
