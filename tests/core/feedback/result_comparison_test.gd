extends GdUnitTestSuite
## The summary compares a finished session with the previous result and the best of its
## mode × profile × level (requirements §11.3, issue #41).


func _record(score: float, status: StringName = SessionRecord.STATUS_COMPLETED) -> SessionRecord:
	var record: SessionRecord = SessionRecord.new()
	record.mode = SessionRecord.MODE_LEARN
	record.road_profile = &"motorway"
	record.difficulty = 2
	record.status = status
	record.score_total = score
	return record


func _saved(score: float, status: StringName = SessionRecord.STATUS_COMPLETED) -> Dictionary:
	return _record(score, status).to_dict()


func _shown(lines: Array[FeedbackLine]) -> Array[String]:
	var texts: Array[String] = []
	for line: FeedbackLine in lines:
		texts.append(TranslationServer.translate(line.key).format(line.args))
	return texts


func test_a_first_result_says_so_and_nothing_else() -> void:
	var lines: Array[FeedbackLine] = ResultComparison.compare(_record(40.0), {}, {})
	assert_array(_shown(lines)).contains_exactly([
		"To pierwszy zapisany przejazd w tym trybie, na tej drodze i tym poziomie ruchu."])


func test_a_better_result_than_the_previous_shows_the_gain_and_a_new_best() -> void:
	var lines: Array[FeedbackLine] = ResultComparison.compare(_record(72.8), _saved(55.0), _saved(60.0))
	assert_array(_shown(lines)).contains_exactly([
		"Poprzednio: 55 pkt — tym razem o 17 pkt więcej.",
		"Nowy rekord w tej kombinacji — dotychczasowy wynosił 60 pkt.",
	])


func test_a_worse_result_shows_the_drop_and_the_best_to_beat() -> void:
	var lines: Array[FeedbackLine] = ResultComparison.compare(_record(30.0), _saved(55.0), _saved(80.0))
	assert_array(_shown(lines)).contains_exactly([
		"Poprzednio: 55 pkt — tym razem o 25 pkt mniej.",
		"Rekord w tej kombinacji: 80 pkt.",
	])


func test_the_same_points_as_before_reads_as_the_same() -> void:
	var lines: Array[FeedbackLine] = ResultComparison.compare(_record(55.9), _saved(55.2), _saved(70.0))
	assert_str(_shown(lines)[0]).is_equal("Poprzednio: 55 pkt — tym razem tyle samo.")


func test_equalling_the_best_is_not_a_new_best() -> void:
	var lines: Array[FeedbackLine] = ResultComparison.compare(_record(60.0), _saved(40.0), _saved(60.0))
	assert_str(_shown(lines)[1]).is_equal("Rekord w tej kombinacji: 60 pkt.")


func test_an_aborted_session_never_claims_a_best() -> void:
	var crash: StringName = SessionRecord.STATUS_ABORTED_COLLISION
	var above_best: Array[FeedbackLine] = ResultComparison.compare(_record(90.0, crash), _saved(55.0), _saved(60.0))
	assert_str(_shown(above_best)[1]).is_equal("Rekord w tej kombinacji: 60 pkt.")
	var no_best_yet: Array[FeedbackLine] = ResultComparison.compare(_record(90.0, crash), _saved(10.0, crash), {})
	assert_array(_shown(no_best_yet)).contains_exactly(["Poprzednio: 10 pkt — tym razem o 80 pkt więcej."])


func test_the_first_completed_session_after_aborted_ones_is_the_first_best() -> void:
	var lines: Array[FeedbackLine] = ResultComparison.compare(
			_record(20.0), _saved(35.0, SessionRecord.STATUS_ABORTED_OFFROAD), {})
	assert_array(_shown(lines)).contains_exactly([
		"Poprzednio: 35 pkt — tym razem o 15 pkt mniej.",
		"To pierwszy ukończony przejazd w tej kombinacji i od razu rekord.",
	])


func test_every_comparison_text_is_translated() -> void:
	for key: StringName in ResultComparison.KEYS:
		assert_str(TranslationServer.translate(key)).override_failure_message(String(key)).is_not_equal(String(key))
