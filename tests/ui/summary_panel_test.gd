extends GdUnitTestSuite
## The summary screen shows the total, four categories with an icon and text, the
## description and one tip, in Polish (requirements §11.3, spec UI/UX: Summary;
## issue #38).

var _panel: SummaryPanel


func before_test() -> void:
	_panel = auto_free(SummaryPanel.new()) as SummaryPanel
	add_child(_panel)


## gap 24 (lost 6), lane 30, signal -10 (one unsignalled change), speed 0.
func _summary() -> Summary:
	var event_log: EventLog = EventLog.new()
	event_log.add_instant(1.0, RightLaneRule.TYPE, RightLaneRule.CATEGORY, 30.0)
	event_log.add_instant(2.0, GapKeptRule.TYPE_FOLLOWING, GapKeptRule.CATEGORY, 30.0)
	event_log.add_instant(3.0, GapRule.TYPE, GapRule.CATEGORY, -6.0)
	event_log.add_instant(4.0, SignalRule.TYPE_OK, SignalRule.CATEGORY, 0.0)
	event_log.add_instant(5.0, SignalRule.TYPE_NONE, SignalRule.CATEGORY, -10.0)
	var builder: SessionRecordBuilder = SessionRecordBuilder.new(load("res://config/scoring.tres") as ScoringConfig)
	var record: SessionRecord = builder.build(event_log)
	record.time_gap_below_min_s = 3.0
	return SummaryGenerator.new(load("res://config/feedback.tres") as FeedbackConfig).generate(event_log, record)


func test_shows_the_total() -> void:
	_panel.show_summary(_summary())
	assert_str(_panel.total_label.text).is_equal("Wynik: 44 pkt")


func test_shows_four_categories_each_with_an_icon_and_text() -> void:
	_panel.show_summary(_summary())
	assert_int(_panel.category_icons.size()).is_equal(4)
	var texts: Array[String] = []
	for label: Label in _panel.category_labels:
		texts.append(label.text)
	assert_array(texts).is_equal([
		"Odstęp: 24 pkt — do poprawy",
		"Pas: 30 pkt — dobrze",
		"Kierunkowskaz: -10 pkt — do poprawy",
		"Prędkość: 0 pkt — dobrze",
	])
	var ratings: Array = _panel.category_icons.map(func(icon: SummaryIcon) -> Summary.Rating: return icon.rating)
	assert_array(ratings).is_equal([Summary.Rating.IMPROVE, Summary.Rating.GOOD,
			Summary.Rating.IMPROVE, Summary.Rating.GOOD])
	for icon: SummaryIcon in _panel.category_icons:
		assert_bool(icon.is_visible_in_tree()).is_true()


func test_shows_the_description_and_the_tip_in_polish() -> void:
	_panel.show_summary(_summary())
	assert_str(_panel.description_label.text).is_equal(
			"Najlepiej wyszło trzymanie się prawego pasa. "
			+ "Zmiany pasa bez właściwego kierunkowskazu włączonego zawczasu: 1 z 2 — inni kierowcy powinni znać zamiar przed manewrem. "
			+ "Przez 3 s odstęp był mniejszy niż wymagane minimum, czyli połowa prędkości w km/h wyrażona w metrach.")
	assert_str(_panel.tip_label.text).is_equal(
			"Wskazówka na następny raz\nNajpierw kierunkowskaz i lusterko, a zmiana pasa dopiero po chwili.")


func test_a_category_not_judged_says_so() -> void:
	var summary: Summary = _summary()
	summary.categories[3].rating = Summary.Rating.NOT_JUDGED
	_panel.show_summary(summary)
	assert_str(_panel.category_labels[3].text).is_equal("Prędkość: 0 pkt — bez oceny")
	assert_int(_panel.category_icons[3].rating).is_equal(Summary.Rating.NOT_JUDGED)
