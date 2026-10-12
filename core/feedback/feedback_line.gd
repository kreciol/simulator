class_name FeedbackLine
extends RefCounted
## One player-facing sentence as a translation key and its format arguments, e.g.
## `SUMMARY_IMPROVE_GAP` with `{"seconds": 6}`. Core picks the words; the UI
## translates them with `tr(key).format(args)` (Polish first, i18n/strings.csv).

var key: StringName
var args: Dictionary


static func create(line_key: StringName, line_args: Dictionary = {}) -> FeedbackLine:
	var line: FeedbackLine = FeedbackLine.new()
	line.key = line_key
	line.args = line_args
	return line
