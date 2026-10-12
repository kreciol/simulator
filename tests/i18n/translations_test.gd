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
		[&"RESPAWN_COLLISION", "Kolizja z innym pojazdem"],
		[&"RESPAWN_OFFROAD", "Zjechanie z drogi"],
		[&"RESPAWN_BACK_ON_ROAD", "Wracasz na prawy pas. Czas sesji biegnie dalej."],
		]) -> void:
	assert_str(TranslationServer.translate(key)).is_equal(polish)
