extends GdUnitTestSuite
## Player-facing text comes from translation files, Polish first (AGENTS.md, spec
## Architecture: Localisation).


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
		[&"SAVE_DONE", "Wynik zapisany w tej przeglądarce."],
		[&"SAVE_UNAVAILABLE", "Tym razem wyniku nie zapisaliśmy: pamięć przeglądarki jest niedostępna (np. w trybie prywatnym). Możesz dalej ćwiczyć, tylko historia się nie zapisze."],
		[&"SAVE_READ_ONLY", "Twoja historia pochodzi z nowszej wersji gry, więc nie dopisujemy do niej wyników, żeby jej nie uszkodzić."],
		[&"HISTORY_CORRUPT_RECOVERED", "Zapisana historia była uszkodzona. Zachowaliśmy jej kopię i zaczęliśmy nową."],
		]) -> void:
	assert_str(TranslationServer.translate(key)).is_equal(polish)
