extends GdUnitTestSuite
## The history screen lists recent sessions, the best per mode × profile × level and a
## score trend, with its empty and storage-unavailable states and the data-is-local
## notice (requirements §13, issue #41 acceptance criteria).

const DIR: String = "user://test_history_screen"
const PATH: String = DIR + "/history.json"
const STARTED_AT: String = "2026-10-12T10:05:00Z"

var _screen: HistoryScreen
var _store: HistoryStore


func before_test() -> void:
	_clear_dir()
	DirAccess.make_dir_recursive_absolute(DIR)
	_store = HistoryStore.new(PATH, 50)
	_store.userfs_persistent = true
	_store.load_history()
	_screen = auto_free(HistoryScreen.new()) as HistoryScreen
	_screen.launcher_config = load("res://config/dev_launcher.tres") as DevLauncherConfig
	_screen.recent_count = 3
	_screen.trend_count = 4
	add_child(_screen)


func after_test() -> void:
	_clear_dir()


func _clear_dir() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		return
	for file_name: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file_name))
	DirAccess.remove_absolute(DIR)


func _save(id: String, score: float, status: StringName = SessionRecord.STATUS_COMPLETED,
		mode: StringName = SessionRecord.MODE_LEARN, level: int = 2,
		profile: StringName = &"motorway") -> void:
	var record: SessionRecord = SessionRecord.new()
	record.id = id
	record.started_at = STARTED_AT
	record.mode = mode
	record.road_profile = profile
	record.difficulty = level
	record.status = status
	record.score_total = score
	if mode == SessionRecord.MODE_EXAM:
		record.exam_passed = status == SessionRecord.STATUS_COMPLETED and score >= 50.0
	_store.save_record(record)


## The date as this machine's time zone shows it.
func _date() -> String:
	return HistoryScreen.format_date(STARTED_AT, _screen._time_zone_bias_min())


func _texts(rows: VBoxContainer) -> Array[String]:
	var texts: Array[String] = []
	for row: Node in rows.get_children():
		texts.append((row as Label).text)
	return texts


func test_the_data_is_local_notice_is_always_shown() -> void:
	_screen.show_history(_store)
	assert_str(_screen.local_notice_label.text).is_equal(
			"Wyniki są zapisane tylko w tej przeglądarce na tym urządzeniu. Wyczyszczenie danych przeglądarki je usunie.")
	assert_bool(_screen.local_notice_label.is_visible_in_tree()).is_true()
	_save("a", 10.0)
	_screen.show_history(_store)
	assert_bool(_screen.local_notice_label.is_visible_in_tree()).is_true()


func test_no_saved_sessions_shows_the_empty_state() -> void:
	_screen.show_history(_store)
	assert_bool(_screen.empty_label.is_visible_in_tree()).is_true()
	assert_str(_screen.empty_label.text).starts_with("Brak zapisanych przejazdów")
	assert_bool(_screen.content.visible).is_false()
	assert_bool(_screen.status_label.visible).is_false()


func test_storage_unavailable_shows_its_state_instead_of_the_empty_one() -> void:
	_store.userfs_persistent = false
	_store.load_history()
	_screen.show_history(_store)
	assert_bool(_screen.status_label.is_visible_in_tree()).is_true()
	assert_str(_screen.status_label.text).starts_with("Pamięć przeglądarki jest niedostępna")
	assert_bool(_screen.empty_label.visible).is_false()
	assert_bool(_screen.local_notice_label.is_visible_in_tree()).is_true()


func test_a_newer_history_is_shown_read_only_with_its_notice() -> void:
	_save("a", 10.0)
	_store.read_only = true
	_screen.show_history(_store)
	assert_str(_screen.status_label.text).starts_with("Historia pochodzi z nowszej wersji gry")
	assert_bool(_screen.content.visible).is_true()


func test_status_key_of_each_storage_state() -> void:
	assert_str(HistoryScreen.status_key(_store)).is_equal("")
	_store.notice = HistoryStore.Notice.CORRUPT_RECOVERED
	assert_str(HistoryScreen.status_key(_store)).is_equal("HISTORY_CORRUPT_RECOVERED")
	_store.storage_available = false
	assert_str(HistoryScreen.status_key(_store)).is_equal("HISTORY_UNAVAILABLE")
	_store.read_only = true
	assert_str(HistoryScreen.status_key(_store)).is_equal("HISTORY_READ_ONLY")


func test_lists_the_recent_sessions_newest_first() -> void:
	_save("s1", 12.0)
	_save("s2", 30.6, SessionRecord.STATUS_ABORTED_COLLISION)
	_save("s3", 55.0, SessionRecord.STATUS_COMPLETED, SessionRecord.MODE_EXAM, 3, &"expressway")
	_save("s4", 41.0, SessionRecord.STATUS_ABORTED_OFFROAD)
	_screen.show_history(_store)
	assert_bool(_screen.content.is_visible_in_tree()).is_true()
	assert_bool(_screen.empty_label.visible).is_false()
	assert_array(_texts(_screen.recent_rows)).contains_exactly([
		"%s · Nauka · Autostrada · poziom 2 — 41 pkt · przerwany — zjazd z drogi" % _date(),
		"%s · Egzamin · Droga ekspresowa · poziom 3 — 55 pkt · egzamin zaliczony" % _date(),
		"%s · Nauka · Autostrada · poziom 2 — 30 pkt · przerwany — kolizja" % _date(),
	])


func test_lists_the_best_per_combination() -> void:
	_save("learn2", 40.0)
	_save("learn2_better", 48.0)
	_save("learn2_crash", 90.0, SessionRecord.STATUS_ABORTED_COLLISION)
	_save("exam3", 20.0, SessionRecord.STATUS_COMPLETED, SessionRecord.MODE_EXAM, 3)
	_screen.show_history(_store)
	assert_array(_texts(_screen.best_rows)).contains_exactly([
		"Egzamin · Autostrada · poziom 3: 20 pkt",
		"Nauka · Autostrada · poziom 2: 48 pkt",
	])
	assert_bool(_screen.no_bests_label.visible).is_false()


func test_only_aborted_sessions_explain_why_there_is_no_best() -> void:
	_save("crash", 30.0, SessionRecord.STATUS_ABORTED_COLLISION)
	_screen.show_history(_store)
	assert_array(_texts(_screen.best_rows)).is_empty()
	assert_bool(_screen.no_bests_label.is_visible_in_tree()).is_true()
	assert_str(_screen.no_bests_label.text).is_equal("Rekord ustanawia dopiero ukończony przejazd.")


func test_the_trend_plots_the_latest_scores_and_says_them_in_text() -> void:
	for score: float in [5.0, 20.0, 12.5, 33.0, 28.9]:
		_save("s%s" % score, score)
	_screen.show_history(_store)
	assert_array(_screen.trend_chart.scores).contains_exactly([20.0, 12.5, 33.0, 28.9])
	assert_bool(_screen.trend_chart.is_visible_in_tree()).is_true()
	assert_str(_screen.trend_caption_label.text).is_equal(
			"Ostatnie wyniki (4): najniższy 12 pkt, najwyższy 33 pkt, ostatni 28 pkt.")


func test_showing_again_replaces_the_rows() -> void:
	_save("a", 10.0)
	_screen.show_history(_store)
	_save("b", 20.0)
	_screen.show_history(_store)
	assert_int(_texts(_screen.recent_rows).size()).is_equal(2)


func test_trend_points_rise_with_the_score() -> void:
	var chart_size: Vector2 = Vector2(224.0, 124.0)
	assert_array(Array(ScoreTrendChart.points_for([10.0, 30.0, 20.0], chart_size))).contains_exactly(
			[Vector2(12.0, 112.0), Vector2(112.0, 12.0), Vector2(212.0, 62.0)])
	assert_array(Array(ScoreTrendChart.points_for([7.0], chart_size))).contains_exactly([Vector2(112.0, 62.0)])
	assert_array(Array(ScoreTrendChart.points_for([], chart_size))).is_empty()


func test_format_date_is_local_day_month_year_and_time(started_at: String, bias_min: int, shown: String,
		test_parameters: Array = [
			["2026-10-12T10:05:00Z", 0, "12.10.2026 10:05"],
			["2026-10-12T23:30:00Z", 120, "13.10.2026 01:30"],
			["", 60, "—"],
		]) -> void:
	assert_str(HistoryScreen.format_date(started_at, bias_min)).is_equal(shown)


func test_exam_status_says_passed_or_failed() -> void:
	assert_str(HistoryScreen.status_of({"status": "completed", "exam_passed": false})).is_equal("HISTORY_EXAM_FAILED")
	assert_str(HistoryScreen.status_of({"status": "completed", "exam_passed": true})).is_equal("HISTORY_EXAM_PASSED")
	assert_str(HistoryScreen.status_of({"status": "aborted_collision", "exam_passed": false})).is_equal("HISTORY_STATUS_COLLISION")
	assert_str(HistoryScreen.status_of({"status": "completed", "exam_passed": null})).is_equal("HISTORY_STATUS_COMPLETED")


func test_every_history_text_is_translated() -> void:
	var keys: Array[StringName] = [&"HISTORY_TITLE", &"HISTORY_LOCAL_NOTICE", &"HISTORY_EMPTY",
			&"HISTORY_UNAVAILABLE", &"HISTORY_READ_ONLY", &"HISTORY_CORRUPT_RECOVERED", &"HISTORY_RECENT",
			&"HISTORY_BESTS", &"HISTORY_NO_BESTS", &"HISTORY_TREND", &"HISTORY_TREND_CAPTION", &"HISTORY_ROW",
			&"HISTORY_BEST_ROW", &"HISTORY_COMBINATION", HistoryScreen.EXAM_PASSED, HistoryScreen.EXAM_FAILED]
	keys.append_array(HistoryScreen.MODE_KEYS.values())
	keys.append_array(HistoryScreen.STATUS_KEYS.values())
	for profile: RoadProfile in _screen.launcher_config.profiles:
		keys.append(StringName(profile.display_name_key))
	for key: StringName in keys:
		assert_str(TranslationServer.translate(key)).override_failure_message(String(key)).is_not_equal(String(key))


func test_the_scene_shows_the_saved_history() -> void:
	var scene: HistoryScreen = auto_free((load("res://ui/history_screen.tscn") as PackedScene).instantiate()) as HistoryScreen
	assert_bool(scene.show_saved_on_ready).is_true()
	assert_object(scene.launcher_config).is_not_null()
