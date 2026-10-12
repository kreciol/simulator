extends GdUnitTestSuite
## Player-facing text comes from translation files, Polish first (AGENTS.md, spec
## Architecture: Localisation).


func test_polish_is_the_fallback_locale() -> void:
	assert_str(ProjectSettings.get_setting("internationalization/locale/fallback")).is_equal("pl")


func test_hud_strings_are_translated_to_polish(key: StringName, polish: String, test_parameters: Array = [
		[&"HUD_SPEED_UNIT", "km/h"],
		[&"SESSION_ENDED", "Koniec sesji"],
		[&"TOAST_LOW_FPS", "Gra działa wolno na tym komputerze. Spróbuj niskiej jakości grafiki (quality=low)."],
		]) -> void:
	assert_str(TranslationServer.translate(key)).is_equal(polish)
