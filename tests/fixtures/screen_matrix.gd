class_name ScreenMatrix
extends RefCounted
## The screen-size matrix of issue #87, shared by every phone-layout test: landscape
## sizes in CSS pixels as the browser reports them, and the canvas each one shows (the
## project stretches 1280×720 with `expand`).

const BASE: Vector2 = Vector2(1280.0, 720.0)
## iPhone SE; iPhone 14; Pixel / Galaxy; iPhone Pro Max.
const PHONES: Array[Vector2] = [Vector2(667.0, 375.0), Vector2(844.0, 390.0), Vector2(915.0, 412.0),
		Vector2(932.0, 430.0)]
## iPad; iPad Air; an Android tablet.
const TABLETS: Array[Vector2] = [Vector2(1024.0, 768.0), Vector2(1180.0, 820.0), Vector2(1280.0, 800.0)]
## Desktop regression sizes, no touch.
const DESKTOPS: Array[Vector2] = [Vector2(1280.0, 720.0), Vector2(1920.0, 1080.0)]
## Height the browser's address and tool bars take from a phone's screen.
const BROWSER_BARS_PX: float = 60.0


## Every touch size: the phones, the tablets and each phone with the browser bars shown.
static func touch_sizes() -> Array[Vector2]:
	var sizes: Array[Vector2] = []
	sizes.append_array(PHONES)
	sizes.append_array(TABLETS)
	sizes.append_array(phones_with_bars())
	return sizes


static func phones_with_bars() -> Array[Vector2]:
	var sizes: Array[Vector2] = []
	for phone: Vector2 in PHONES:
		sizes.append(phone - Vector2(0.0, BROWSER_BARS_PX))
	return sizes


## CSS pixels per canvas unit on a screen of `css` pixels.
static func css_scale(css: Vector2) -> float:
	return minf(css.x / BASE.x, css.y / BASE.y)


## The canvas a screen of `css` pixels shows.
static func canvas_size(css: Vector2) -> Vector2:
	return (css / css_scale(css)).floor()


## Readable name of a size for failure messages.
static func describe(css: Vector2) -> String:
	return "%dx%d" % [roundi(css.x), roundi(css.y)]
