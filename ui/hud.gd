class_name Hud
extends CanvasLayer
## Driving HUD (requirements §5.3): speed, the road's limit, blinking signal arrows and
## the session time left, plus the 3-2-1 countdown and the plain end-of-session screen
## (placeholder until the Phase 7/8 summary), and a timed, non-blocking notice (the
## low-FPS suggestion). Only reads session state. Placeholder styling until the UI
## theme lands (Phase 10).

const MARGIN: float = 24.0
const OUTLINE_SIZE: int = 8
const SPEED_FONT_SIZE: int = 56
const UNIT_FONT_SIZE: int = 22
const LIMIT_FONT_SIZE: int = 30
const TIME_FONT_SIZE: int = 40
const COUNTDOWN_FONT_SIZE: int = 160
const NOTICE_FONT_SIZE: int = 64
const TOAST_FONT_SIZE: int = 26
## The notice sits under the time left.
const TOAST_TOP: float = 2.0 * MARGIN + 1.5 * TIME_FONT_SIZE
const TOAST_BACKDROP: Color = Color(0.0, 0.0, 0.0, 0.6)
const TOAST_PADDING: int = 12
## Round limit sign: white disc with a red ring, as on Polish B-33 signs.
const LIMIT_SIGN_SIZE: float = 76.0
const LIMIT_RING_WIDTH: int = 9
const ARROW_SIZE: Vector2 = Vector2(44.0, 36.0)
const ARROW_GAP: float = 120.0
## Arrows stay faintly visible when off, so the player knows where to look.
const ARROW_OFF: Color = Color(1.0, 1.0, 1.0, 0.2)
const ARROW_ON: Color = Color(0.2, 1.0, 0.3)
## Dims the frozen scene behind the end-of-session notice.
const ENDED_BACKDROP: Color = Color(0.0, 0.0, 0.0, 0.55)
## Absorbs float drift so a whole second left never reads as the next one up.
const TIME_EPSILON: float = 1e-6

var view: ViewConfig
var speed_label: Label
var unit_label: Label
var limit_label: Label
var time_label: Label
var signal_left: Polygon2D
var signal_right: Polygon2D
var countdown_label: Label
var ended_screen: ColorRect
var ended_label: Label
var toast: PanelContainer
var toast_label: Label

## Time the notice stays on screen; it hides at 0.
var _toast_left_s: float = 0.0


func setup(view_config: ViewConfig) -> void:
	view = view_config
	var root: Control = Control.new()
	root.name = "Root"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var dashboard: HBoxContainer = HBoxContainer.new()
	dashboard.name = "Dashboard"
	dashboard.add_theme_constant_override("separation", int(MARGIN))
	dashboard.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(dashboard)
	dashboard.add_child(_limit_sign())
	var speedometer: VBoxContainer = VBoxContainer.new()
	speedometer.name = "Speedometer"
	speedometer.add_theme_constant_override("separation", 0)
	dashboard.add_child(speedometer)
	speed_label = _label("Speed", SPEED_FONT_SIZE)
	speedometer.add_child(speed_label)
	unit_label = _label("Unit", UNIT_FONT_SIZE)
	unit_label.text = tr(&"HUD_SPEED_UNIT")
	speedometer.add_child(unit_label)
	dashboard.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, int(MARGIN))
	dashboard.grow_vertical = Control.GROW_DIRECTION_BEGIN

	time_label = _label("TimeLeft", TIME_FONT_SIZE)
	root.add_child(time_label)
	time_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, int(MARGIN))
	time_label.grow_horizontal = Control.GROW_DIRECTION_BOTH

	var signals: Control = Control.new()
	signals.name = "Signals"
	signals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	signals.custom_minimum_size = Vector2(ARROW_GAP + 2.0 * ARROW_SIZE.x, ARROW_SIZE.y)
	root.add_child(signals)
	signals.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, int(MARGIN))
	signals.grow_horizontal = Control.GROW_DIRECTION_BOTH
	signals.grow_vertical = Control.GROW_DIRECTION_BEGIN
	signal_left = _arrow("SignalLeft", VehicleState.Dir.LEFT, 0.0)
	signals.add_child(signal_left)
	signal_right = _arrow("SignalRight", VehicleState.Dir.RIGHT, ARROW_SIZE.x + ARROW_GAP)
	signals.add_child(signal_right)

	countdown_label = _centered_label("Countdown", COUNTDOWN_FONT_SIZE)
	root.add_child(countdown_label)
	ended_screen = ColorRect.new()
	ended_screen.name = "EndedScreen"
	ended_screen.color = ENDED_BACKDROP
	ended_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ended_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	ended_screen.visible = false
	root.add_child(ended_screen)
	ended_label = _centered_label("Ended", NOTICE_FONT_SIZE)
	ended_label.text = tr(&"SESSION_ENDED")
	ended_screen.add_child(ended_label)

	toast = _toast()
	root.add_child(toast)
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, int(TOAST_TOP))
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH


func _process(delta: float) -> void:
	if _toast_left_s <= 0.0:
		return
	_toast_left_s -= delta
	if _toast_left_s <= 0.0:
		toast.visible = false


## Shows `text` for `duration_s` over the drive; it never takes input or pauses play.
func show_toast(text: String, duration_s: float) -> void:
	toast_label.text = text
	toast.visible = true
	_toast_left_s = duration_s


func update(session: SessionManager) -> void:
	var sim: TrafficSim = session.sim
	var player: VehicleState = session.player
	speed_label.text = str(roundi(player.speed_mps * TrafficSim.KMH_PER_MPS))
	limit_label.text = str(roundi(sim.road.speed_limit_kmh))
	time_label.text = format_time(session.time_left_s())

	var lit: bool = SignalBlink.is_lit(player, sim.time_s, view.signal_blink_hz)
	signal_left.color = ARROW_ON if lit and player.signal_dir == VehicleState.Dir.LEFT else ARROW_OFF
	signal_right.color = ARROW_ON if lit and player.signal_dir == VehicleState.Dir.RIGHT else ARROW_OFF

	countdown_label.visible = session.state == SessionManager.State.INTRO
	if countdown_label.visible:
		countdown_label.text = str(maxi(1, ceili(session.countdown_left_s() - TIME_EPSILON)))
	ended_screen.visible = session.state == SessionManager.State.ENDED
	ended_label.visible = ended_screen.visible


## `m:ss`, rounding up so the display reads 0:00 only once the time is up.
static func format_time(seconds: float) -> String:
	var whole: int = maxi(0, ceili(seconds - TIME_EPSILON))
	return "%d:%02d" % [floori(whole / 60.0), whole % 60]


func _label(node_name: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	return label


func _centered_label(node_name: String, font_size: int) -> Label:
	var label: Label = _label(node_name, font_size)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.visible = false
	return label


func _toast() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Toast"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = TOAST_BACKDROP
	style.set_content_margin_all(TOAST_PADDING)
	style.set_corner_radius_all(TOAST_PADDING)
	panel.add_theme_stylebox_override("panel", style)
	toast_label = _label("ToastText", TOAST_FONT_SIZE)
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(toast_label)
	panel.visible = false
	return panel


func _limit_sign() -> PanelContainer:
	var plate: PanelContainer = PanelContainer.new()
	plate.name = "LimitSign"
	plate.custom_minimum_size = Vector2(LIMIT_SIGN_SIZE, LIMIT_SIGN_SIZE)
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.border_color = Color(0.8, 0.05, 0.05)
	style.set_border_width_all(LIMIT_RING_WIDTH)
	style.set_corner_radius_all(int(LIMIT_SIGN_SIZE / 2.0))
	plate.add_theme_stylebox_override("panel", style)
	limit_label = Label.new()
	limit_label.name = "Limit"
	limit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	limit_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	limit_label.add_theme_font_size_override("font_size", LIMIT_FONT_SIZE)
	limit_label.add_theme_color_override("font_color", Color.BLACK)
	plate.add_child(limit_label)
	return plate


## Triangle pointing towards `dir`, `x` from the left of the arrow row.
func _arrow(node_name: String, dir: VehicleState.Dir, x: float) -> Polygon2D:
	var arrow: Polygon2D = Polygon2D.new()
	arrow.name = node_name
	arrow.position = Vector2(x, 0.0)
	var tip_x: float = 0.0 if dir == VehicleState.Dir.LEFT else ARROW_SIZE.x
	var base_x: float = ARROW_SIZE.x - tip_x
	arrow.polygon = PackedVector2Array([
		Vector2(tip_x, ARROW_SIZE.y / 2.0), Vector2(base_x, 0.0), Vector2(base_x, ARROW_SIZE.y)])
	arrow.color = ARROW_OFF
	return arrow
