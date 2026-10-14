class_name HintEngine
extends RefCounted
## Learn-mode coaching while driving (requirements §11.2, spec Phase 8 step 1). Reads
## the sim and its `ScoringSystem` after every scored step and never changes either;
## picks translation keys with live numbers (`FeedbackLine`), never text, so every hint
## is gender-neutral Polish from i18n/strings.csv (Q3). The exam has no engine at all.
##
## - Preventive hints, before or while a penalty runs: K2 grace started ("the right
##   lane is free, go back right"), the gap closing in on the legal minimum, the gap
##   below it with the numbers, and the speed above the limit while S1 is on.
## - Event messages, after the fact: when a player lane change completes on the road,
##   its K3 event decides between confirming the signal and naming the missing, late
##   or wrong one.
## Rate limits (`FeedbackConfig`): a type is not shown again within `hint_cooldown_s`
## of its last showing, nor while it is still on screen; at most
## `hint_max_on_screen` hints are shown, and a new one replaces the oldest only once
## that has been up for `hint_min_display_s` — otherwise it waits, its cooldown
## unspent; each stays `hint_duration_s`. Within a step the lane-change message comes
## first (it waits for room rather than being dropped), then K2, the gap and speeding.
## All times are sim time, so a pause or a respawn freezes them.

## Emitted when a hint goes on screen.
signal hint_shown(hint: Hint)

## What `_show` did with a hint.
enum Shown { SHOWN, RATE_LIMITED, NO_ROOM }

const KEEP_RIGHT: StringName = &"HINT_KEEP_RIGHT"
const GAP_TOO_SMALL: StringName = &"HINT_GAP_TOO_SMALL"
const GAP_CLOSING: StringName = &"HINT_GAP_CLOSING"
const SPEEDING: StringName = &"HINT_SPEEDING"
const SIGNAL_OK: StringName = &"HINT_SIGNAL_OK"
## The message for each K3 outcome but OK, by the lane change's direction.
const SIGNAL_MESSAGES: Dictionary[StringName, Dictionary] = {
	SignalRule.TYPE_NONE: {VehicleState.Dir.LEFT: &"HINT_SIGNAL_NONE_LEFT", VehicleState.Dir.RIGHT: &"HINT_SIGNAL_NONE_RIGHT"},
	SignalRule.TYPE_LATE: {VehicleState.Dir.LEFT: &"HINT_SIGNAL_LATE_LEFT", VehicleState.Dir.RIGHT: &"HINT_SIGNAL_LATE_RIGHT"},
	SignalRule.TYPE_WRONG: {VehicleState.Dir.LEFT: &"HINT_SIGNAL_WRONG_LEFT", VehicleState.Dir.RIGHT: &"HINT_SIGNAL_WRONG_RIGHT"},
}

const TYPE_KEEP_RIGHT: StringName = &"keep_right"
const TYPE_GAP_TOO_SMALL: StringName = &"gap_too_small"
const TYPE_GAP_CLOSING: StringName = &"gap_closing"
const TYPE_SPEEDING: StringName = &"speeding"
## Float drift in a minimum gap derived from a speed in m/s (a whole km/h may convert
## back to a hair above it).
const MIN_GAP_EPSILON_M: float = 1e-6

var sim: TrafficSim
var scoring: ScoringSystem
var config: FeedbackConfig
## On screen now, oldest first.
var hints: Array[Hint] = []

## When each type was last shown, sim time.
var _last_shown_s: Dictionary[StringName, float] = {}
## The K3 event of the player's lane change in progress, until it completes.
var _signal_event: ScoreEvent
## Set when the player's lane change completed during the last sim step.
var _lane_change_completed: bool = false
## The message of the last completed lane change while it waits for room on screen.
var _pending_message: Hint


func _init(observed_sim: TrafficSim, observed_scoring: ScoringSystem, feedback_config: FeedbackConfig) -> void:
	sim = observed_sim
	scoring = observed_scoring
	config = feedback_config
	sim.lane_change_finished.connect(_on_lane_change_finished)


## Call after `scoring.observe(dt)` with the events it returned. Drops expired hints,
## then shows what this step calls for.
func observe(events: Array[ScoreEvent]) -> void:
	var now_s: float = sim.time_s
	for i: int in range(hints.size() - 1, -1, -1):
		if hints[i].expires_at_s <= now_s:
			hints.remove_at(i)
	for event: ScoreEvent in events:
		if event.category == SignalRule.CATEGORY:
			_signal_event = event
			# A new lane change makes the previous one's waiting message stale.
			_pending_message = null
	var player: VehicleState = sim.player
	var on_road: bool = player != null and not player.off_road
	if _lane_change_completed:
		_lane_change_completed = false
		# A change that left the road is followed by a respawn, not a signal message.
		_pending_message = _signal_message() if on_road else null
		_signal_event = null
	if not on_road:
		return
	if _pending_message != null and _show(_pending_message) != Shown.NO_ROOM:
		_pending_message = null
	_show_preventive(player)


## Takes every hint off the screen and forgets the lane change in progress, after the
## player was put back on the road (learn-mode respawn). Cooldowns keep running.
func clear() -> void:
	hints.clear()
	_signal_event = null
	_lane_change_completed = false
	_pending_message = null


## Seconds as Polish text: a decimal comma, and no ",0" on whole numbers.
static func seconds_text(seconds: float) -> String:
	var tenths: int = roundi(seconds * 10.0)
	if tenths % 10 == 0:
		return str(floori(tenths / 10.0))
	return "%d,%d" % [floori(tenths / 10.0), tenths % 10]


## Each hint is built only when `admission` lets its type on screen, so a held-back
## type allocates nothing in a step.
func _show_preventive(player: VehicleState) -> void:
	if scoring.keep_right_rule.applies(player) and admission(TYPE_KEEP_RIGHT) == Shown.SHOWN:
		# From the first moment of the K2 grace, so it comes before any penalty.
		_show(_hint(TYPE_KEEP_RIGHT, FeedbackLine.create(KEEP_RIGHT)))
	var speed_kmh: float = ScoringSystem.speed_kmh(player)
	var min_gap_m: float = LaneQuery.min_gap(speed_kmh)
	var gap_m: float = LaneQuery.gap_to_leader(player, sim.lanes)
	if scoring.gap_rule.gap_ratio(player) < 1.0:
		if admission(TYPE_GAP_TOO_SMALL) == Shown.SHOWN:
			# Rounded up, as half the shown speed; the epsilon absorbs km/h conversion drift.
			var shown_min_gap: int = ceili(min_gap_m - MIN_GAP_EPSILON_M)
			_show(_hint(TYPE_GAP_TOO_SMALL, FeedbackLine.create(GAP_TOO_SMALL, {
				"speed": roundi(speed_kmh),
				"min_gap": shown_min_gap,
				# Below the minimum as shown, so a gap just short of it never reads as equal.
				"gap": mini(floori(gap_m), shown_min_gap - 1),
			})))
	elif _gap_closing(player, gap_m, min_gap_m) and admission(TYPE_GAP_CLOSING) == Shown.SHOWN:
		_show(_hint(TYPE_GAP_CLOSING, FeedbackLine.create(GAP_CLOSING, {
			"speed": roundi(speed_kmh),
			"min_gap": roundi(min_gap_m),
			"gap": roundi(gap_m),
		})))
	var limit_kmh: float = sim.road.speed_limit_kmh
	# Above the limit as shown, so the speed never reads as equal to it; before S1's
	# tolerance runs out.
	if scoring.config.speed_rule_enabled and roundi(speed_kmh) > roundi(limit_kmh) \
			and admission(TYPE_SPEEDING) == Shown.SHOWN:
		_show(_hint(TYPE_SPEEDING, FeedbackLine.create(SPEEDING, {
			"limit": roundi(limit_kmh),
			"speed": roundi(speed_kmh),
		})))


## The gap is at or above the legal minimum but within `hint_gap_warning_factor` of
## it, and shrinking: the leader is slower. Not while overtaking, as K1.
func _gap_closing(player: VehicleState, gap_m: float, min_gap_m: float) -> bool:
	if min_gap_m <= 0.0 or gap_m >= min_gap_m * config.hint_gap_warning_factor:
		return false
	var leader: VehicleState = LaneQuery.leader_in_lane(sim.lanes, player.lane, player.s, player)
	if leader == null or leader.speed_mps >= player.speed_mps:
		return false
	return not LaneQuery.is_overtaking(player, sim.lanes, scoring.config.overtake_look_ahead_m)


## The message confirming a correct signal or naming what was wrong with it, for the
## lane change that just completed; null without its K3 event.
func _signal_message() -> Hint:
	var event: ScoreEvent = _signal_event
	if event == null:
		return null
	if event.type == SignalRule.TYPE_OK:
		return _hint(event.type, FeedbackLine.create(SIGNAL_OK), true)
	var by_dir: Dictionary = SIGNAL_MESSAGES.get(event.type, {})
	var dir: VehicleState.Dir = VehicleState.Dir.LEFT \
			if event.context.get("lane_to", 0) > event.context.get("lane_from", 0) else VehicleState.Dir.RIGHT
	if not by_dir.has(dir):
		return null
	return _hint(event.type, FeedbackLine.create(by_dir[dir], {"seconds": seconds_text(sim.config.signal_min_on_s)}))


static func _hint(type: StringName, line: FeedbackLine, positive: bool = false) -> Hint:
	var hint: Hint = Hint.new()
	hint.type = type
	hint.line = line
	hint.positive = positive
	return hint


## What `_show` would do with a hint of `type` now, without building one or changing
## anything: rate-limited, no room (the screen is full and its oldest hint has not been
## up `hint_min_display_s` yet, which also keeps a hint from being replaced in the step
## that showed it), or SHOWN when it may go on screen.
func admission(type: StringName) -> Shown:
	var now_s: float = sim.time_s
	if now_s - _last_shown_s.get(type, -INF) < config.hint_cooldown_s:
		return Shown.RATE_LIMITED
	for shown: Hint in hints:
		if shown.type == type:
			return Shown.RATE_LIMITED
	if config.hint_max_on_screen <= 0:
		return Shown.NO_ROOM
	if hints.size() >= config.hint_max_on_screen:
		var held_s: float = now_s - hints[0].shown_at_s
		# Even a minimum of 0 never replaces a hint in the step that showed it.
		if held_s <= 0.0 or held_s < config.hint_min_display_s - LaneQuery.TIME_EPSILON:
			return Shown.NO_ROOM
	return Shown.SHOWN


## Puts `hint` on screen unless `admission` holds it back, replacing the oldest when
## the screen is full.
func _show(hint: Hint) -> Shown:
	var admitted: Shown = admission(hint.type)
	if admitted != Shown.SHOWN:
		return admitted
	var now_s: float = sim.time_s
	while hints.size() >= config.hint_max_on_screen:
		hints.pop_front()
	hint.shown_at_s = now_s
	hint.expires_at_s = now_s + config.hint_duration_s
	hints.append(hint)
	_last_shown_s[hint.type] = now_s
	hint_shown.emit(hint)
	return Shown.SHOWN


## Runs inside `TrafficSim.step`; the message waits for `observe`, which also has the
## change's K3 event when it started in the same step.
func _on_lane_change_finished(vehicle_id: int, _lane: int) -> void:
	if sim.player != null and vehicle_id == sim.player.id:
		_lane_change_completed = true
