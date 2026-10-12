class_name SummaryPanel
extends VBoxContainer
## The body of the end-of-session summary (requirements §11.3, spec UI/UX: Summary):
## the total, the four categories each with an icon and text, the 2–4 sentence
## description and one tip. The status and the cause above it stay in the HUD's end
## notice. Only reads the `Summary`; translates its lines (Polish first).

const SEPARATION: int = 14
const OUTLINE_SIZE: int = 8
const TOTAL_FONT_SIZE: int = 44
const CATEGORY_FONT_SIZE: int = 26
const TEXT_FONT_SIZE: int = 24
## Wrap width of the description and the tip; fits the 1280 px minimum window.
const TEXT_WIDTH: float = 900.0
const RATING_KEYS: Dictionary[Summary.Rating, StringName] = {
	Summary.Rating.GOOD: &"SUMMARY_RATING_GOOD",
	Summary.Rating.IMPROVE: &"SUMMARY_RATING_IMPROVE",
}

var total_label: Label
## One icon and one label per category, in `SessionRecord.SCORED_CATEGORIES` order.
var category_icons: Array[SummaryIcon] = []
var category_labels: Array[Label] = []
var description_label: Label
var tip_label: Label


func _init() -> void:
	name = "Summary"
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", SEPARATION)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	total_label = _label("Total", TOTAL_FONT_SIZE)
	add_child(total_label)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.name = "Categories"
	rows.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(rows)
	for category: StringName in SessionRecord.SCORED_CATEGORIES:
		var row: HBoxContainer = HBoxContainer.new()
		row.name = String(category).capitalize()
		row.add_theme_constant_override("separation", SEPARATION)
		rows.add_child(row)
		var icon: SummaryIcon = SummaryIcon.new()
		row.add_child(icon)
		category_icons.append(icon)
		var label: Label = _label("Text", CATEGORY_FONT_SIZE)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(label)
		category_labels.append(label)
	description_label = _wrapped_label("Description")
	add_child(description_label)
	tip_label = _wrapped_label("Tip")
	add_child(tip_label)


func show_summary(summary: Summary) -> void:
	total_label.text = tr(&"SUMMARY_TOTAL").format({"points": roundi(summary.score_total)})
	for i: int in summary.categories.size():
		var result: Summary.CategoryResult = summary.categories[i]
		category_icons[i].rating = result.rating
		category_labels[i].text = tr(&"SUMMARY_CATEGORY_ROW").format({
			"category": tr(SummaryGenerator.CATEGORY_NAMES[result.category]),
			"points": roundi(result.points),
			"rating": tr(RATING_KEYS[result.rating]),
		})
	var sentences: PackedStringArray = []
	for line: FeedbackLine in summary.sentences:
		sentences.append(text_of(line))
	description_label.text = " ".join(sentences)
	tip_label.text = tr(&"SUMMARY_TIP").format({"tip": text_of(summary.tip)})


func text_of(line: FeedbackLine) -> String:
	return tr(line.key).format(line.args)


func _label(node_name: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	return label


func _wrapped_label(node_name: String) -> Label:
	var label: Label = _label(node_name, TEXT_FONT_SIZE)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(TEXT_WIDTH, 0.0)
	return label
