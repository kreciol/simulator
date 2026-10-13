class_name HistoryScreen
extends Control
## The history screen (requirements §13, spec Phase 9 step 2, UI/UX: History): the
## recent sessions, the best per mode × road profile × level and a simple score trend,
## always with a notice that the results live only in this browser. With nothing saved
## it shows the empty state; when the browser's storage is unavailable it says so
## instead (sessions still playable, nothing saved); a history from a newer version or
## a recovered corrupt one gets its notice too. Only reads the `HistoryStore`.
## Opened by the dev launcher's `screen=history` until the Phase 10 menus exist.
## Placeholder styling until the UI theme lands (Phase 10).

const MARGIN: int = 32
const SEPARATION: int = 12
const COLUMN_SEPARATION: int = 36
const OUTLINE_SIZE: int = 6
const TITLE_FONT_SIZE: int = 44
const HEADING_FONT_SIZE: int = 26
const TEXT_FONT_SIZE: int = 18
const ROW_FONT_SIZE: int = 16
## Widths of the recent list and of the bests and trend beside it: together they fit
## the 1280×720 minimum window. A row too long for its column wraps.
const RECENT_WIDTH: float = 720.0
const SIDE_WIDTH: float = ScoreTrendChart.SIZE.x
## Wrap width of the notices above the lists.
const NOTICE_WIDTH: float = 1100.0
const BACKGROUND: Color = Color(0.08, 0.1, 0.13)
const NOTICE_COLOR: Color = Color(1.0, 0.82, 0.4)

## Translation key of each saved session's mode.
const MODE_KEYS: Dictionary[String, StringName] = {
	"learn": &"MODE_LEARN",
	"exam": &"MODE_EXAM",
}
const STATUS_KEYS: Dictionary[String, StringName] = {
	"completed": &"HISTORY_STATUS_COMPLETED",
	"aborted_collision": &"HISTORY_STATUS_COLLISION",
	"aborted_offroad": &"HISTORY_STATUS_OFFROAD",
}
const EXAM_PASSED: StringName = &"HISTORY_EXAM_PASSED"
const EXAM_FAILED: StringName = &"HISTORY_EXAM_FAILED"

## Shows `SaveManager`'s history once in the tree (the scene sets it); tests call
## `show_history` themselves.
@export var show_saved_on_ready: bool = false
## Road profiles' display names; without it a profile shows its id.
@export var launcher_config: DevLauncherConfig

var title_label: Label
var local_notice_label: Label
## Storage unavailable, read-only or recovered history; hidden when there is none.
var status_label: Label
var empty_label: Label
## The lists and the trend; hidden when nothing is saved.
var content: HBoxContainer
var recent_rows: VBoxContainer
var best_rows: VBoxContainer
var no_bests_label: Label
var trend_heading: Label
var trend_chart: ScoreTrendChart
var trend_caption_label: Label
var recent_count: int = 10
var trend_count: int = 20


func _init() -> void:
	name = "HistoryScreen"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background: ColorRect = ColorRect.new()
	background.name = "Background"
	background.color = BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margins: MarginContainer = MarginContainer.new()
	margins.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "top", "right", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, MARGIN)
	scroll.add_child(margins)
	var page: VBoxContainer = VBoxContainer.new()
	page.name = "Page"
	page.add_theme_constant_override("separation", SEPARATION)
	margins.add_child(page)

	title_label = _label("Title", TITLE_FONT_SIZE)
	title_label.text = tr(&"HISTORY_TITLE")
	page.add_child(title_label)
	local_notice_label = _wrapped("LocalNotice", TEXT_FONT_SIZE)
	local_notice_label.text = tr(&"HISTORY_LOCAL_NOTICE")
	page.add_child(local_notice_label)
	status_label = _wrapped("Status", TEXT_FONT_SIZE)
	status_label.add_theme_color_override("font_color", NOTICE_COLOR)
	status_label.visible = false
	page.add_child(status_label)
	empty_label = _wrapped("Empty", HEADING_FONT_SIZE)
	empty_label.text = tr(&"HISTORY_EMPTY")
	empty_label.visible = false
	page.add_child(empty_label)

	content = HBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", COLUMN_SEPARATION)
	content.visible = false
	page.add_child(content)
	var recent_column: VBoxContainer = _column("Recent", &"HISTORY_RECENT")
	recent_column.custom_minimum_size = Vector2(RECENT_WIDTH, 0.0)
	content.add_child(recent_column)
	recent_rows = _rows("Rows")
	recent_column.add_child(recent_rows)
	var side_column: VBoxContainer = _column("Bests", &"HISTORY_BESTS")
	content.add_child(side_column)
	best_rows = _rows("Rows")
	side_column.add_child(best_rows)
	no_bests_label = _row_label("NoBests", SIDE_WIDTH)
	no_bests_label.text = tr(&"HISTORY_NO_BESTS")
	side_column.add_child(no_bests_label)
	trend_heading = _label_with_key("TrendHeading", HEADING_FONT_SIZE, &"HISTORY_TREND")
	side_column.add_child(trend_heading)
	trend_chart = ScoreTrendChart.new()
	side_column.add_child(trend_chart)
	trend_caption_label = _row_label("TrendCaption", SIDE_WIDTH)
	side_column.add_child(trend_caption_label)


func _ready() -> void:
	if not show_saved_on_ready:
		return
	recent_count = SaveManager.config.history_recent_count
	trend_count = SaveManager.config.history_trend_count
	show_history(SaveManager.store)


func show_history(history: HistoryStore) -> void:
	var notice: StringName = status_key(history)
	status_label.text = tr(notice) if notice != &"" else ""
	status_label.visible = notice != &""
	var has_sessions: bool = not history.sessions.is_empty()
	# Unavailable storage says why there is nothing, rather than inviting a first drive
	# that would not be kept either.
	empty_label.visible = not has_sessions and notice != &"HISTORY_UNAVAILABLE"
	content.visible = has_sessions
	if not has_sessions:
		return

	var recent_texts: Array[String] = []
	for entry: Dictionary in history.recent(recent_count):
		recent_texts.append(row_text(entry))
	_fill(recent_rows, recent_texts, RECENT_WIDTH)
	var best_texts: Array[String] = []
	for entry: Dictionary in history.bests():
		best_texts.append(best_text(entry))
	_fill(best_rows, best_texts, SIDE_WIDTH)
	no_bests_label.visible = best_texts.is_empty()
	var scores: Array[float] = history.trend_scores(trend_count)
	trend_chart.scores = scores
	# Nothing to plot when the trend count is configured to 0.
	trend_heading.visible = not scores.is_empty()
	trend_chart.visible = not scores.is_empty()
	trend_caption_label.visible = not scores.is_empty()
	if scores.is_empty():
		return
	trend_caption_label.text = tr(&"HISTORY_TREND_CAPTION").format({
		"count": scores.size(),
		"min": floori(scores.min()),
		"max": floori(scores.max()),
		"last": floori(scores.back()),
	})


## The notice above the lists: a history from a newer version (or one that could not
## be set aside) first, then unavailable storage, then a corrupt history that was set
## aside; none when all is well.
static func status_key(history: HistoryStore) -> StringName:
	if history.read_only:
		return &"HISTORY_READ_ONLY"
	if not history.storage_available:
		return &"HISTORY_UNAVAILABLE"
	if history.notice == HistoryStore.Notice.CORRUPT_RECOVERED:
		return &"HISTORY_CORRUPT_RECOVERED"
	return &""


## One recent session: when, which combination, its points and how it ended.
func row_text(entry: Dictionary) -> String:
	return tr(&"HISTORY_ROW").format({
		"date": format_date(str(entry.get("started_at", "")), _time_zone_bias_min()),
		"combination": combination_text(entry),
		"points": floori(float(entry.get("score_total", 0.0))),
		"status": tr(status_of(entry)),
	})


## The best session of a combination: the combination and its points.
func best_text(entry: Dictionary) -> String:
	return tr(&"HISTORY_BEST_ROW").format({
		"combination": combination_text(entry),
		"points": floori(float(entry.get("score_total", 0.0))),
	})


## Mode, road profile and level in words, e.g. "Nauka · Autostrada · poziom 2".
func combination_text(entry: Dictionary) -> String:
	var mode: String = str(entry.get("mode", ""))
	var profile: String = str(entry.get("road_profile", ""))
	var profile_name: String = profile
	if launcher_config != null:
		var found: RoadProfile = launcher_config.find_profile(StringName(profile))
		if found != null:
			profile_name = tr(found.display_name_key)
	return tr(&"HISTORY_COMBINATION").format({
		"mode": tr(MODE_KEYS[mode]) if MODE_KEYS.has(mode) else mode,
		"profile": profile_name,
		"level": int(entry.get("difficulty", 0)),
	})


## How a saved session ended; a completed exam says whether it was passed.
static func status_of(entry: Dictionary) -> StringName:
	var status: String = str(entry.get("status", ""))
	var passed: Variant = entry.get("exam_passed")
	if status == String(SessionRecord.STATUS_COMPLETED) and passed is bool:
		return EXAM_PASSED if passed else EXAM_FAILED
	return STATUS_KEYS.get(status, &"HISTORY_STATUS_COMPLETED")


## `started_at` (ISO-8601, UTC) as local "dd.mm.yyyy hh:mm", `bias_min` minutes ahead
## of UTC; a dash when it is missing or unreadable. The bias is today's, so a session
## from the other side of a daylight-saving change shows an hour off: the record keeps
## no offset of its own.
static func format_date(started_at: String, bias_min: int) -> String:
	if not started_at.contains("T"):
		return "—"
	var utc: int = Time.get_unix_time_from_datetime_string(started_at.trim_suffix("Z"))
	if utc <= 0:
		return "—"
	var local: Dictionary = Time.get_datetime_dict_from_unix_time(utc + bias_min * 60)
	return "%02d.%02d.%04d %02d:%02d" % [local.day, local.month, local.year, local.hour, local.minute]


func _time_zone_bias_min() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0))


func _fill(rows: VBoxContainer, texts: Array[String], width: float) -> void:
	for child: Node in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	for text: String in texts:
		var row: Label = _row_label("Row", width)
		row.text = text
		rows.add_child(row)


## A line of a list, wrapping at `width`.
func _row_label(node_name: String, width: float) -> Label:
	var label: Label = _label(node_name, ROW_FONT_SIZE)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width, 0.0)
	return label


func _column(node_name: String, heading_key: StringName) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.name = node_name
	column.add_theme_constant_override("separation", SEPARATION)
	column.add_child(_label_with_key("Heading", HEADING_FONT_SIZE, heading_key))
	return column


func _rows(node_name: String) -> VBoxContainer:
	var rows: VBoxContainer = VBoxContainer.new()
	rows.name = node_name
	rows.add_theme_constant_override("separation", 4)
	return rows


func _label_with_key(node_name: String, font_size: int, key: StringName) -> Label:
	var label: Label = _label(node_name, font_size)
	label.text = tr(key)
	return label


func _wrapped(node_name: String, font_size: int) -> Label:
	var label: Label = _label(node_name, font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(NOTICE_WIDTH, 0.0)
	return label


func _label(node_name: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	return label
