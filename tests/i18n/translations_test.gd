extends GdUnitTestSuite
## Player-facing text comes from translation files, Polish first (AGENTS.md, spec
## Architecture: Localisation).

## Gendered Polish verb forms at the end of a word: past tense in the first or second
## person (-łem, -łam, -łeś, -łaś) and their conditional (-łbym, -łabym, -łbyś, -łabyś).
## Letter classes rather than \w and \b, which only know ASCII letters.
const GENDERED_FORM: String = "\\p{L}(łem|łam|łeś|łaś|łbym|łabym|łbyś|łabyś)(?!\\p{L})"


func test_polish_is_the_fallback_locale() -> void:
	assert_str(ProjectSettings.get_setting("internationalization/locale/fallback")).is_equal("pl")


func test_hud_strings_are_translated_to_polish(key: StringName, polish: String, test_parameters: Array = [
		[&"HUD_SPEED_UNIT", "km/h"],
		[&"SESSION_ENDED", "Koniec sesji"],
		[&"SESSION_PAUSED", "Pauza"],
		[&"SESSION_PAUSED_HINT", "Naciśnij Esc lub P, aby jechać dalej"],
		[&"EXAM_FAILED", "Egzamin niezaliczony"],
		[&"END_CAUSE_COLLISION", "Przyczyna: kolizja z innym pojazdem"],
		[&"END_CAUSE_OFFROAD", "Przyczyna: zjechanie z drogi"],
		]) -> void:
	assert_str(TranslationServer.translate(key)).is_equal(polish)


## Every key the summary generator and the summary screen can show.
func _summary_keys() -> Array[StringName]:
	var keys: Array[StringName] = [
		SummaryGenerator.STATUS_COMPLETED, SummaryGenerator.STATUS_ABORTED,
		SummaryGenerator.STATUS_EXAM_PASSED, SummaryGenerator.STATUS_EXAM_FAILED,
		SummaryGenerator.ALL_GOOD, SummaryGenerator.TIP_GENERAL,
		&"SUMMARY_TOTAL", &"SUMMARY_CATEGORY_ROW", &"SUMMARY_RATING_GOOD",
		&"SUMMARY_RATING_IMPROVE", &"SUMMARY_TIP",
	]
	for table: Dictionary in [SummaryGenerator.CAUSES, SummaryGenerator.ABORT_SENTENCES,
			SummaryGenerator.ABORT_TIPS, SummaryGenerator.CATEGORY_NAMES, SummaryGenerator.STRENGTHS,
			SummaryGenerator.IMPROVEMENTS, SummaryGenerator.TIPS]:
		for key: StringName in table.values():
			keys.append(key)
	return keys


func test_every_summary_text_is_translated_to_polish() -> void:
	var untranslated: Array[StringName] = []
	for key: StringName in _summary_keys():
		if TranslationServer.translate(key) == String(key):
			untranslated.append(key)
	assert_array(untranslated).is_empty()


func test_summary_sentences_are_one_sentence_each() -> void:
	# The description counts sentences by line (2–4, requirements §11.3).
	for table: Dictionary in [SummaryGenerator.ABORT_SENTENCES, SummaryGenerator.STRENGTHS,
			SummaryGenerator.IMPROVEMENTS]:
		for key: StringName in table.values():
			var text: String = TranslationServer.translate(key)
			assert_str(text).override_failure_message("%s: %s" % [key, text]).ends_with(".")
			assert_int(text.count(". ")).override_failure_message("%s: %s" % [key, text]).is_zero()


func test_the_gendered_form_lint_catches_the_superseded_example() -> void:
	# The §11.3 example sentence, superseded by Q3 (gender-neutral texts).
	var regex: RegEx = RegEx.create_from_string(GENDERED_FORM)
	assert_object(regex.search("Jechałeś pewnie i dobrze trzymałeś odstęp.")).is_not_null()
	assert_object(regex.search("Zostałaś na lewym pasie.")).is_not_null()
	assert_object(regex.search("Odstęp był utrzymany. Wróć na prawy pas.")).is_null()


func test_no_polish_string_uses_a_gendered_verb_form() -> void:
	# Q3: impersonal, imperative or noun forms everywhere, no gender setting.
	var regex: RegEx = RegEx.create_from_string(GENDERED_FORM)
	var file: FileAccess = FileAccess.open("res://i18n/strings.csv", FileAccess.READ)
	var header: PackedStringArray = file.get_csv_line()
	var polish: int = header.find("pl")
	assert_int(polish).is_greater(0)
	var offenders: Array[String] = []
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() <= polish:
			continue
		for found: RegExMatch in regex.search_all(row[polish]):
			offenders.append("%s: %s" % [row[0], found.get_string()])
	assert_array(offenders).is_empty()
