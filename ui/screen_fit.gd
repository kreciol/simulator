class_name ScreenFit
extends RefCounted
## How the screens fit a phone (issue #87): whether the screen is held in portrait, how
## many CSS pixels one canvas unit takes (the project stretches 1280×720 with `expand`),
## the display's safe area in canvas units (a notch, rounded corners) and the smallest
## size a finger can press. Pure functions over sizes, so tests run them at every
## size of the screen-size matrix; the `*_now` helpers read the platform.

## Remembers each button's own minimum size before a touch target enlarges it.
const BASE_SIZE_META: StringName = &"touch_base_min_size"


## Whether a screen of `size` is held upright: the game is played in landscape only.
static func is_portrait(size: Vector2) -> bool:
	return size.y > size.x


## CSS pixels per canvas unit when a window of `window_px` device pixels at
## `pixel_ratio` device pixels per CSS pixel shows `visible_size` canvas units.
static func css_scale(window_px: Vector2, pixel_ratio: float, visible_size: Vector2) -> float:
	if window_px.x <= 0.0 or visible_size.x <= 0.0 or pixel_ratio <= 0.0:
		return 1.0
	return window_px.x / pixel_ratio / visible_size.x


## The same for `viewport`'s window now.
static func css_scale_now(viewport: Viewport) -> float:
	return css_scale(Vector2(DisplayServer.window_get_size()), DisplayServer.screen_get_scale(),
			viewport.get_visible_rect().size)


## Canvas units a button side needs to be `config.min_touch_target_px` CSS pixels at
## `scale` CSS pixels per unit.
static func min_target(config: TouchConfig, scale: float) -> float:
	return config.min_touch_target_px / maxf(scale, 0.0001)


## The part of a `visible_size` canvas inside the display's safe area: `window` and
## `safe_area` in screen pixels. The whole canvas when the platform reports no safe
## area or one that does not cut into the window.
static func safe_rect(visible_size: Vector2, window: Rect2, safe_area: Rect2) -> Rect2:
	var full: Rect2 = Rect2(Vector2.ZERO, visible_size)
	if not window.has_area() or not safe_area.has_area():
		return full
	var inside: Rect2 = window.intersection(safe_area)
	if not inside.has_area():
		return full
	var units_per_px: Vector2 = visible_size / window.size
	return Rect2((inside.position - window.position) * units_per_px, inside.size * units_per_px)


## The same for `viewport`'s window now.
static func safe_rect_now(viewport: Viewport) -> Rect2:
	var window: Rect2 = Rect2(Vector2(DisplayServer.window_get_position()), Vector2(DisplayServer.window_get_size()))
	return safe_rect(viewport.get_visible_rect().size, window, Rect2(DisplayServer.get_display_safe_area()))


## Whether the player plays by touch: a touch device, or touch buttons shown this run.
static func touch_device() -> bool:
	return DisplayServer.is_touchscreen_available() or TouchControls.run_shown


## Grows every button under `root` to at least `min_side` canvas units each way; 0
## puts them back to their own minimum size.
static func fit_buttons(root: Node, min_side: float) -> void:
	for node: Node in root.find_children("*", "BaseButton", true, false):
		var button: Control = node as Control
		if not button.has_meta(BASE_SIZE_META):
			button.set_meta(BASE_SIZE_META, button.custom_minimum_size)
		var base: Vector2 = button.get_meta(BASE_SIZE_META)
		button.custom_minimum_size = base.max(Vector2(min_side, min_side))
