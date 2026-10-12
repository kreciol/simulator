extends GdUnitTestSuite
## Session history file (issue #40 acceptance criteria, spec Phase 9 step 1, Edge Cases):
## round-trip, cap, bests, corrupt and future-version files, storage unavailable.

const DIR: String = "user://test_history_store"
const PATH: String = DIR + "/history.json"
const LIMIT: int = 5

var _store: HistoryStore


func before_test() -> void:
	_clear_dir()
	DirAccess.make_dir_recursive_absolute(DIR)
	_store = _new_store()


func after_test() -> void:
	_clear_dir()


func _clear_dir() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		return
	for file_name: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file_name))
	DirAccess.remove_absolute(DIR)


func _new_store() -> HistoryStore:
	var store: HistoryStore = HistoryStore.new(PATH, LIMIT)
	store.userfs_persistent = true
	store.load_history()
	return store


func _record(id: String, score: float, status: StringName = SessionRecord.STATUS_COMPLETED,
		mode: StringName = SessionRecord.MODE_LEARN, level: int = 2) -> SessionRecord:
	var record: SessionRecord = SessionRecord.new()
	record.id = id
	record.started_at = "2026-10-12T10:00:00"
	record.app_version = "0.1.0"
	record.mode = mode
	record.road_profile = &"motorway"
	record.difficulty = level
	record.seed_value = 1234567
	record.duration_s = 90.0
	record.status = status
	record.score_total = score
	record.score_by_category = {&"gap": -3.5, &"lane": 12.25, &"signal": -1.0, &"speed": 0.0}
	record.lane_changes = 4
	record.lane_changes_signaled = 3
	record.time_left_lane_unjustified_s = 2.5
	record.time_gap_below_min_s = 1.75
	record.min_gap_ratio = 0.625
	record.exam_passed = true if mode == SessionRecord.MODE_EXAM else null
	return record


func _write_file(text: String) -> void:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _read_file() -> String:
	return FileAccess.get_file_as_string(PATH)


func _saved_ids(store: HistoryStore) -> Array[String]:
	var ids: Array[String] = []
	for entry: Dictionary in store.sessions:
		ids.append(str(entry["id"]))
	return ids


func test_a_saved_record_round_trips_with_schema_version_1() -> void:
	var record: SessionRecord = _record("a", 42.5, SessionRecord.STATUS_COMPLETED, SessionRecord.MODE_EXAM)
	assert_bool(_store.save_record(record)).is_true()

	var file: Dictionary = JSON.parse_string(_read_file()) as Dictionary
	assert_int(int(file["schema_version"])).is_equal(1)
	assert_int(int((file["sessions"] as Array)[0]["schema_version"])).is_equal(1)

	var reloaded: HistoryStore = _new_store()
	assert_int(reloaded.sessions.size()).is_equal(1)
	var read_back: SessionRecord = SessionRecord.from_dict(reloaded.last_session())
	assert_dict(read_back.to_dict()).is_equal(record.to_dict())
	assert_that(read_back.difficulty).is_equal(2)
	assert_that(read_back.seed_value).is_equal(1234567)


func test_a_learn_record_keeps_a_null_exam_verdict() -> void:
	_store.save_record(_record("a", 10.0))
	var read_back: SessionRecord = SessionRecord.from_dict(_new_store().last_session())
	assert_that(read_back.exam_passed).is_null()


func test_a_missing_file_is_an_empty_history_that_can_be_saved_to() -> void:
	assert_int(_store.sessions.size()).is_equal(0)
	assert_bool(_store.can_save()).is_true()
	assert_int(_store.notice).is_equal(HistoryStore.Notice.NONE)
	assert_bool(FileAccess.file_exists(PATH)).is_false()


func test_more_than_the_cap_drops_the_oldest() -> void:
	for i: int in LIMIT + 2:
		_store.save_record(_record("s%d" % i, float(i)))
	assert_array(_saved_ids(_store)).contains_exactly(["s2", "s3", "s4", "s5", "s6"])
	assert_array(_saved_ids(_new_store())).contains_exactly(["s2", "s3", "s4", "s5", "s6"])


func test_the_default_cap_is_200() -> void:
	var config: PersistenceConfig = load("res://config/persistence.tres") as PersistenceConfig
	assert_int(config.history_limit).is_equal(200)
	assert_str(config.history_path).is_equal("user://history.json")


func test_a_new_best_for_a_combination_is_saved() -> void:
	_store.save_record(_record("first", 30.0))
	_store.save_record(_record("better", 55.0))
	assert_str(str(_store.best_for(SessionRecord.MODE_LEARN, &"motorway", 2)["id"])).is_equal("better")
	assert_str(str(_new_store().best_for(SessionRecord.MODE_LEARN, &"motorway", 2)["id"])).is_equal("better")


func test_a_worse_or_equal_result_leaves_the_best_unchanged() -> void:
	_store.save_record(_record("best", 55.0))
	_store.save_record(_record("worse", 20.0))
	_store.save_record(_record("tie", 55.0))
	assert_str(str(_new_store().best_for(SessionRecord.MODE_LEARN, &"motorway", 2)["id"])).is_equal("best")


func test_bests_are_kept_per_mode_profile_and_level() -> void:
	_store.save_record(_record("learn2", 50.0))
	_store.save_record(_record("exam2", 10.0, SessionRecord.STATUS_COMPLETED, SessionRecord.MODE_EXAM))
	_store.save_record(_record("learn3", 5.0, SessionRecord.STATUS_COMPLETED, SessionRecord.MODE_LEARN, 3))
	assert_str(str(_store.best_for(SessionRecord.MODE_LEARN, &"motorway", 2)["id"])).is_equal("learn2")
	assert_str(str(_store.best_for(SessionRecord.MODE_EXAM, &"motorway", 2)["id"])).is_equal("exam2")
	assert_str(str(_store.best_for(SessionRecord.MODE_LEARN, &"motorway", 3)["id"])).is_equal("learn3")
	assert_dict(_store.best_for(SessionRecord.MODE_LEARN, &"expressway", 2)).is_empty()
	assert_str(_store.best[HistoryStore.combination_key(SessionRecord.MODE_EXAM, &"motorway", 2)]).is_equal("exam2")


func test_an_aborted_session_never_sets_a_best() -> void:
	_store.save_record(_record("crash", 80.0, SessionRecord.STATUS_ABORTED_COLLISION))
	assert_dict(_store.best_for(SessionRecord.MODE_LEARN, &"motorway", 2)).is_empty()
	_store.save_record(_record("done", 10.0))
	assert_str(str(_store.best_for(SessionRecord.MODE_LEARN, &"motorway", 2)["id"])).is_equal("done")


func test_a_best_dropped_by_the_cap_is_replaced_by_the_best_remaining_session() -> void:
	_store.save_record(_record("old_best", 99.0))
	for i: int in LIMIT:
		_store.save_record(_record("s%d" % i, float(i)))
	assert_array(_saved_ids(_store)).not_contains(["old_best"])
	assert_str(str(_store.best_for(SessionRecord.MODE_LEARN, &"motorway", 2)["id"])).is_equal("s4")


func test_a_corrupt_file_is_renamed_and_a_fresh_one_started() -> void:
	_write_file("{ this is not json")
	var store: HistoryStore = _new_store()

	assert_int(store.notice).is_equal(HistoryStore.Notice.CORRUPT_RECOVERED)
	assert_int(store.sessions.size()).is_equal(0)
	assert_bool(store.can_save()).is_true()
	assert_str(store.corrupt_backup_path.get_file()).starts_with("history.corrupt-").ends_with(".json")
	assert_str(FileAccess.get_file_as_string(store.corrupt_backup_path)).is_equal("{ this is not json")
	var fresh: Dictionary = JSON.parse_string(_read_file()) as Dictionary
	assert_int(int(fresh["schema_version"])).is_equal(1)
	assert_array(fresh["sessions"] as Array).is_empty()

	assert_bool(store.save_record(_record("a", 1.0))).is_true()
	var reloaded: HistoryStore = _new_store()
	assert_int(reloaded.notice).is_equal(HistoryStore.Notice.NONE)
	assert_array(_saved_ids(reloaded)).contains_exactly(["a"])


func test_a_wrongly_shaped_file_counts_as_corrupt(text: String, test_parameters: Array = [
		["[1, 2, 3]"],
		["{\"sessions\": [], \"best\": {}}"],
		["{\"schema_version\": 0, \"sessions\": [], \"best\": {}}"],
		["{\"schema_version\": \"1\", \"sessions\": [], \"best\": {}}"],
		["{\"schema_version\": 1, \"sessions\": {}, \"best\": {}}"],
		["{\"schema_version\": 1, \"sessions\": [7], \"best\": {}}"],
		["{\"schema_version\": 1, \"sessions\": []}"],
		[""],
	]) -> void:
	_write_file(text)
	var store: HistoryStore = _new_store()
	assert_int(store.notice).is_equal(HistoryStore.Notice.CORRUPT_RECOVERED)
	assert_bool(store.can_save()).is_true()
	assert_bool(FileAccess.file_exists(store.corrupt_backup_path)).is_true()


func test_two_corrupt_files_in_the_same_second_keep_both_backups() -> void:
	_write_file("first broken")
	var first: String = _new_store().corrupt_backup_path
	_write_file("second broken")
	var second: String = _new_store().corrupt_backup_path
	assert_str(second).is_not_equal(first)
	assert_str(FileAccess.get_file_as_string(first)).is_equal("first broken")
	assert_str(FileAccess.get_file_as_string(second)).is_equal("second broken")


func test_a_newer_schema_version_is_read_only_and_never_overwritten() -> void:
	var future: String = JSON.stringify({
		"schema_version": 2,
		"sessions": [{"id": "future", "score_total": 12.0, "mode": "learn"}],
		"best": {},
		"something_new": true,
	})
	_write_file(future)
	var store: HistoryStore = _new_store()

	assert_bool(store.read_only).is_true()
	assert_int(store.file_version).is_equal(2)
	assert_int(store.notice).is_equal(HistoryStore.Notice.NONE)
	assert_array(_saved_ids(store)).contains_exactly(["future"])
	assert_bool(store.can_save()).is_false()
	assert_bool(store.save_record(_record("a", 1.0))).is_false()
	assert_str(_read_file()).is_equal(future)


func test_unavailable_storage_disables_saving() -> void:
	var store: HistoryStore = HistoryStore.new(PATH, LIMIT)
	store.userfs_persistent = false
	store.load_history()
	assert_bool(store.storage_available).is_false()
	assert_bool(store.can_save()).is_false()
	assert_bool(store.save_record(_record("a", 1.0))).is_false()
	assert_bool(FileAccess.file_exists(PATH)).is_false()


func test_an_unwritable_location_disables_saving() -> void:
	# A file where the history's directory should be: nothing can be created inside it.
	_write_file("not a directory")
	var store: HistoryStore = HistoryStore.new(PATH.path_join("history.json"), LIMIT)
	store.userfs_persistent = true
	store.load_history()
	assert_bool(store.storage_available).is_false()
	assert_bool(store.save_record(_record("a", 1.0))).is_false()


func test_a_corrupt_file_on_unavailable_storage_is_moved_aside_but_nothing_is_written() -> void:
	_write_file("broken")
	var store: HistoryStore = HistoryStore.new(PATH, LIMIT)
	store.userfs_persistent = false
	store.load_history()
	assert_int(store.notice).is_equal(HistoryStore.Notice.CORRUPT_RECOVERED)
	assert_bool(store.can_save()).is_false()
	assert_bool(FileAccess.file_exists(PATH)).is_false()
