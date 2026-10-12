class_name HintList
extends VBoxContainer
## The learn-mode hint area (requirements §11.2, spec UI/UX: Learn HUD): one row per
## hint on screen, oldest first, each an icon — a tick for a confirmation, a warning
## triangle otherwise (`SummaryIcon`), so meaning never rests on colour alone — and its
## translated text. Rows are built once, as many as `FeedbackConfig.hint_max_on_screen`,
## and reused. Only reads the hints.

const SEPARATION: int = 8
const OUTLINE_SIZE: int = 6
const FONT_SIZE: int = 24
## Wrap width of a hint's text; the longest hint takes two lines.
const TEXT_WIDTH: float = 620.0
const BACKDROP: Color = Color(0.0, 0.0, 0.0, 0.6)
const PADDING: int = 10

var rows: Array[PanelContainer] = []
var icons: Array[SummaryIcon] = []
var labels: Array[Label] = []

## The hints the rows show, so they are refilled only when that changes.
var _shown: Array[Hint] = []


func _init() -> void:
	name = "Hints"
	add_theme_constant_override("separation", SEPARATION)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Builds `count` rows, all hidden.
func setup(count: int) -> void:
	for i: int in count:
		var row: PanelContainer = PanelContainer.new()
		row.name = "Hint%d" % i
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		row.visible = false
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = BACKDROP
		style.set_content_margin_all(PADDING)
		style.set_corner_radius_all(PADDING)
		row.add_theme_stylebox_override("panel", style)
		add_child(row)
		var content: HBoxContainer = HBoxContainer.new()
		content.add_theme_constant_override("separation", SEPARATION)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(content)
		var icon: SummaryIcon = SummaryIcon.new()
		content.add_child(icon)
		var label: Label = Label.new()
		label.name = "Text"
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(TEXT_WIDTH, 0.0)
		label.add_theme_font_size_override("font_size", FONT_SIZE)
		label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		content.add_child(label)
		rows.append(row)
		icons.append(icon)
		labels.append(label)


## Shows `hints`, oldest first; rows beyond them are hidden.
func show_hints(hints: Array[Hint]) -> void:
	if hints == _shown:
		return
	_shown = hints.duplicate()
	for i: int in rows.size():
		var hint: Hint = hints[i] if i < hints.size() else null
		rows[i].visible = hint != null
		if hint == null:
			continue
		icons[i].rating = Summary.Rating.GOOD if hint.positive else Summary.Rating.IMPROVE
		labels[i].text = tr(hint.line.key).format(hint.line.args)
