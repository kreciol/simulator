extends GdUnitTestSuite
## Shared turn signal blink phase (issue #8: HUD arrows blink with the dashboard lamps).

const HZ: float = 1.5

var _car: VehicleState


func before_test() -> void:
	_car = VehicleState.new()


func test_dark_without_a_signal() -> void:
	assert_bool(SignalBlink.is_lit(_car, 0.0, HZ)).is_false()
	assert_bool(SignalBlink.is_lit(_car, 0.2, HZ)).is_false()


func test_lit_first_half_of_each_period_from_switch_on() -> void:
	_car.signal_dir = VehicleState.Dir.LEFT
	_car.signal_on_since_s = 10.0
	var period: float = 1.0 / HZ
	assert_bool(SignalBlink.is_lit(_car, 10.0, HZ)).is_true()
	assert_bool(SignalBlink.is_lit(_car, 10.0 + period * 0.25, HZ)).is_true()
	assert_bool(SignalBlink.is_lit(_car, 10.0 + period * 0.75, HZ)).is_false()
	assert_bool(SignalBlink.is_lit(_car, 10.0 + period * 1.25, HZ)).is_true()
	_car.signal_dir = VehicleState.Dir.RIGHT
	assert_bool(SignalBlink.is_lit(_car, 10.0 + period * 1.75, HZ)).is_false()
