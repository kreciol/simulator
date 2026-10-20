# MVP acceptance evidence — requirements §16

Issue #47 (E12-S01), spec Phase 11 step 1 and exit criteria. Recorded 2026-10-20 against `main` at `7f3b206`, the build deployed to GitHub Pages (https://kreciol.github.io/simulator/), plus the tests added in PR #82.

Every criterion has a test that asserts it headlessly, a recorded manual check on the deployed build, or both. Test paths are relative to `tests/`; the whole suite runs in CI on every PR (`README.md` *Run the tests*).

**Manual checks** were run on the reference laptop from `README.md` *Performance measurement* (Intel Iris Xe, Windows 11 Pro 26200), in Chrome 155 driven by `agent-browser` in a headed window (WebGL renderer `ANGLE (Intel, Intel(R) Iris(R) Xe Graphics … Direct3D11)`). Screenshots are on the `qa-evidence-pr-82` branch:

- [start screen after the first load](https://raw.githubusercontent.com/kreciol/simulator/qa-evidence-pr-82/pr-82/deployed-start.png)
- [driving, learn mode, level 4, 20 s in](https://raw.githubusercontent.com/kreciol/simulator/qa-evidence-pr-82/pr-82/drive-20s.png)
- [end of a learn session: summary](https://raw.githubusercontent.com/kreciol/simulator/qa-evidence-pr-82/pr-82/deployed-high-end.png)
- [history after reloading the page](https://raw.githubusercontent.com/kreciol/simulator/qa-evidence-pr-82/pr-82/deployed-history-after-reload.png)

## §16 criteria

### Road and world

| # | Criterion | Evidence | Status |
|---|---|---|---|
| W1 | The motorway profile sets 140 km/h and its lane count; the expressway sets 120 km/h | `config/road_profile_test.gd::test_profile_loads_from_tres`; `ui/hud_test.gd::test_limit_is_the_road_profiles`; `ui/hud_test.gd::test_expressway_from_the_url_shows_a_120_limit`; `game/session/session_manager_test.gd::test_start_uses_the_launch_options_profile_and_seed` | ✅ tested |
| W2 | The road renders without gaps for the whole session; no visible segment popping | `game/world/road_view_test.gd::test_driving_10_km_keeps_the_road_continuous`; `game/world/road_view_test.gd::test_segments_appear_only_beyond_the_covered_distance_ahead`; `core/sim/traffic_session_test.gd::test_session_traffic` (traffic appears only out of view). Manual: two full 90 s sessions at level 4 on Pages ran to the summary without a break in the road | ✅ tested; the "no popping" look is for the playtests (#48) to confirm with people |
| W3 | The opposite carriageway is visible and separated | `game/world/road_layout_test.gd::test_opposite_carriageway_is_mirrored_beyond_a_median_barrier`; **new** `game/main_scene_test.gd::test_the_opposite_carriageway_is_in_the_cockpit_view`. Manual: the driving screenshot shows it left of the median | ✅ tested + manual |

### Player

| # | Criterion | Evidence | Status |
|---|---|---|---|
| G1 | Cockpit view; 3 mirrors show the traffic behind | `game/main_scene_test.gd::test_scene_shows_road_and_cockpit_camera`; `game/mirrors/mirrors_view_test.gd::test_three_mirrors_share_the_main_world`; `game/mirrors/mirrors_view_test.gd::test_car_behind_in_the_left_lane_shows_on_the_left`; `game/main_quality_mirrors_test.gd::test_mirrors_follow_the_player_through_a_lane_change`. Manual: the driving screenshot shows the cockpit and three mirrors with cars behind | ✅ tested + manual |
| G2 | W/S change speed smoothly; the speed is on the HUD | `game/main_scene_test.gd::test_holding_w_accelerates_smoothly_and_moves_the_road`; `ui/hud_test.gd::test_speed_is_shown_in_kmh`; `core/sim/traffic_sim_longitudinal_test.gd::test_accelerating_raises_speed_by_configured_rate` | ✅ tested |
| G3 | A/D run an animated lane change; a change past the outer lane leaves the road | `game/main_scene_test.gd::test_a_changes_lane_with_animation_and_moves_the_camera_left`; `core/sim/traffic_sim_lane_change_test.gd::test_lateral_position_follows_progress_and_lane_updates_on_completion`; `core/sim/traffic_sim_lane_change_test.gd::test_change_beyond_outermost_lane_ends_off_road` | ✅ tested |
| G4 | Q/E toggle the signal, shown on the HUD; it switches off after the manoeuvre | `game/main_scene_test.gd::test_q_and_e_toggle_the_signal`; `ui/hud_test.gd::test_signal_arrow_blinks_on_its_side_only`; `core/sim/traffic_sim_lane_change_test.gd::test_signal_records_on_since_and_switches_off_after_change` | ✅ tested |

### AI

| # | Criterion | Evidence | Status |
|---|---|---|---|
| A1 | Vehicles drive at different speeds, overtake slower ones and return to the right lane | `core/ai/ai_lane_change_test.gd::test_fast_car_overtakes_a_slow_truck_and_returns_right_signalling`; `core/ai/ai_lane_change_test.gd::test_model_driver_returns_right_on_a_free_road`; `core/sim/spawner_test.gd::test_spawned_traffic_follows_the_level` | ✅ tested |
| A2 | AI vehicles signal their lane changes | `core/ai/ai_lane_change_test.gd::test_fast_car_overtakes_a_slow_truck_and_returns_right_signalling`; `core/ai/ai_traffic_test.gd::test_seeded_mixed_traffic_never_collides` (no late signals); `game/traffic/vehicle_view_test.gd::test_ai_indicators_blink_before_the_lane_change_starts` | ✅ tested |
| A3 | AI vehicles cause no collisions themselves and never appear in a collision with the player | `core/sim/traffic_soak_test.gd::test_ten_minutes_of_traffic_without_collisions`; `core/sim/traffic_session_test.gd::test_session_traffic` (spawn clearance from the player); `core/ai/ai_lane_change_test.gd::test_no_lane_change_into_a_vehicle_alongside`; **new** `core/sim/traffic_session_test.gd::test_ai_never_runs_into_a_player_that_holds_its_speed` (levels 1–4, right and left lane) | ✅ tested |
| A4 | A higher level gives noticeably more vehicles | `config/difficulty_level_test.gd::test_higher_levels_are_denser_with_wider_speed_spread_and_lower_discipline`; **new** `core/sim/traffic_session_test.gd::test_higher_levels_bring_noticeably_more_traffic` (measured: each level ≥ 1.2× the one below, level 4 ≥ 2× level 1) | ✅ tested |

### Scoring

| # | Criterion | Evidence | Status |
|---|---|---|---|
| O1 | At 140 km/h a 50 m gap is charged K1; a 75 m gap is not | `core/scoring/gap_rule_test.gd::test_at_140_kmh_a_50_m_gap_is_penalised`; `core/scoring/gap_rule_test.gd::test_at_140_kmh_a_75_m_gap_is_not_penalised` | ✅ tested |
| O2 | K1 at 20 m is larger than at 50 m at the same speed | `core/scoring/gap_rule_test.gd::test_a_20_m_gap_costs_more_than_50_m_at_the_same_speed` | ✅ tested |
| O3 | K1 is not charged while overtaking | `core/scoring/gap_rule_test.gd::test_no_k1_while_overtaking` | ✅ tested |
| O4 | Staying in the left lane with the right one free: a hint during the grace period, a penalty only after it | `core/feedback/hint_engine_test.gd::test_keep_right_hint_shows_as_the_grace_starts_before_any_penalty`; `core/scoring/keep_right_rule_test.gd::test_no_penalty_inside_the_grace_period`; `core/scoring/keep_right_rule_test.gd::test_penalty_accrues_per_second_after_the_grace_period` | ✅ tested |
| O5 | A lane change without a signal is charged K3; with a signal on ≥ 1 s in a justified situation it earns N1 | `core/scoring/signal_rule_test.gd::test_no_signal_costs_the_full_penalty_once`; `core/scoring/signal_rule_test.gd::test_a_signal_held_for_the_minimum_costs_nothing`; `core/scoring/lane_change_rule_test.gd::test_a_signalled_overtake_and_return_are_each_rewarded_once`; **new** `core/scoring/lane_change_rule_test.gd::test_a_signal_held_for_exactly_the_minimum_earns_the_reward` | ✅ tested |
| O6 | Repeated pointless lane changes do not raise the score | `core/scoring/lane_change_rule_test.gd::test_repeated_pointless_lane_changes_do_not_raise_the_score`; `core/scoring/lane_change_rule_test.gd::test_an_aimless_change_left_and_back_earns_nothing` | ✅ tested |
| O7 | Driving in the right lane with a legal gap keeps raising the score | `core/scoring/reward_rules_test.gd::test_right_lane_driving_with_a_legal_gap_raises_the_score_steadily` | ✅ tested |

### Modes and session

| # | Criterion | Evidence | Status |
|---|---|---|---|
| T1 | The session ends by itself after 90 s | `game/session/session_manager_test.gd::test_session_ends_after_ninety_seconds_of_simulated_time`; `ui/hud_test.gd::test_time_left_counts_down_from_the_session_length`. Manual: every Pages session ended on its own at 0:00 | ✅ tested + manual |
| T2 | Learn mode: live hints and messages; after a collision the player is put back on the road and drives on | `ui/hud_test.gd::test_learn_shows_hints_with_an_icon_and_text`; `game/session/session_manager_test.gd::test_learn_mode_names_a_missing_signal_after_the_lane_change`; `game/main_scene_test.gd::test_hitting_a_car_in_learn_mode_charges_k4_fades_and_drives_on`; `game/session/session_manager_test.gd::test_a_learn_respawn_puts_the_player_on_a_free_right_lane_at_the_respawn_speed`. Manual: a learn session on Pages with one collision ran on to the summary ("Liczba kolizji z innym pojazdem: 1") | ✅ tested + manual |
| T3 | Exam mode: no hints; a collision or leaving the road ends the session and names the cause | `game/session/session_manager_test.gd::test_exam_has_no_hints_for_the_same_events`; `ui/hud_test.gd::test_exam_collision_names_the_cause`; `ui/hud_test.gd::test_exam_leaving_the_road_names_the_cause`; `game/session/session_manager_test.gd::test_exam_leaving_the_road_ends_the_session_as_aborted_offroad` | ✅ tested |
| T4 | Both modes end with a summary: score, categories and a verbal description | `game/session/session_manager_test.gd::test_a_completed_scored_session_ends_with_its_record_and_summary`; `ui/hud_test.gd::test_scored_exam_collision_shows_failed_with_the_cause`; `ui/summary_panel_test.gd::test_shows_four_categories_each_with_an_icon_and_text`; `core/feedback/summary_generator_test.gd::test_description_has_two_to_four_sentences`. Manual: the end-of-session screenshot | ✅ tested + manual |

### Saving

| # | Criterion | Evidence | Status |
|---|---|---|---|
| Z1 | The session result is saved and shown in the history after a page reload | `game/main_scene_test.gd::test_a_finished_session_is_saved_and_survives_a_reload`; `ui/history_screen_test.gd::test_the_scene_shows_the_saved_history`; `persistence/history_store_test.gd::test_a_saved_record_round_trips_with_schema_version_1`. Manual: after two sessions on Pages, a fresh page load with `?screen=history` listed both (IndexedDB) | ✅ tested + manual |
| Z2 | The best for each mode × profile × level is updated | `persistence/history_store_test.gd::test_a_new_best_for_a_combination_is_saved`; `persistence/history_store_test.gd::test_bests_are_kept_per_mode_profile_and_level`; `persistence/history_store_test.gd::test_a_worse_or_equal_result_leaves_the_best_unchanged`; `persistence/history_store_test.gd::test_an_aborted_session_never_sets_a_best` | ✅ tested |

### Platform

| # | Criterion | Evidence | Status |
|---|---|---|---|
| P1 | The web export runs on static hosting with no extra headers | `export_presets_test.gd::test_web_preset_is_single_threaded`; `project_settings_test.gd::test_renderer_is_compatibility`. Manual: GitHub Pages serves the build with no `Cross-Origin-*` headers (`curl -I`), and it loads and plays | ✅ tested + manual |
| P2 | ≥ 30 FPS on an integrated-GPU laptop at level 4 | Manual: the Phase 5 method on Pages, below | ✅ manual |

## Exit criteria beyond §16

### Build size — ≤ 50 MB

A local `Web` export of `7f3b206` (Godot 4.7.2, `godot --headless --export-release "Web"`), the same command CI runs:

| File | Size |
|---|---|
| `index.wasm` | 39.5 MB |
| `index.pck` | 0.30 MB |
| `index.js` | 0.28 MB |
| the rest (HTML, icons, audio worklets) | 0.05 MB |
| **Total** | **40.1 MB** (10.5 MB gzipped) |

✅ Under the 50 MB budget. CI prints the same numbers on every PR (`Report build size` in `.github/workflows/ci.yml`).

### First load — ≤ 10 s on 50 Mb/s

GitHub Pages serves every file gzip-encoded; the transfer is 10.55 MB in all, 10.25 MB of it the engine (`index.wasm`).

- **Measured:** a cold load of the Pages build in Chrome reached the start screen 8.3 s after navigation. The connection used delivered `index.wasm` in 4.25 s, about 19 Mb/s, well below 50 Mb/s.
- **At 50 Mb/s:** `index.wasm` takes 10.25 MB × 8 / 50 Mb/s ≈ 1.6 s, so the same load would take about 8.3 − 4.25 + 1.6 ≈ **5.7 s**.
- A rate-limited download of each file at 6.25 MB/s (`curl --limit-rate`) took 3.8 s for `index.wasm`, latency included.

✅ Under 10 s even on the slower connection measured.

### FPS — the Phase 5 method on the final build

`?perf=1&level=4&profile=motorway&seed=1&quality=…` on Pages, in the setup described at the top. The table is also in `README.md` *Results*.

| Preset | avg FPS | p5 FPS | Frames (60 s) |
|---|---|---|---|
| `low` | 59.7 | 60.0 | 3596 |
| `high` | 52.6 | 42.0 | 3168 |

✅ The criterion (on `low`: avg ≥ 30, p5 ≥ 25) holds at the 60 Hz vsync cap.

Three deviations from the README method:

- Chrome 155, not 154.
- A 1889 × 1381 window instead of full screen.
- No driving input.

`high` has dropped from 60 FPS since PR #57, but stays well above 30 FPS.

### [PARAM]s live in config only

**New** `config/requirements_params_test.gd`:

- `test_every_requirements_param_is_written_in_its_tres`: every numeric [PARAM] the requirements name is set in its `.tres`, not left to a script default.
- `test_every_level_sets_its_own_params`: the same for each difficulty level.
- `test_every_listed_param_is_a_resource_property`: each [PARAM] in the list is a real property of its resource.

So retuning a [PARAM] changes only a config file. This PR retunes nothing: tuning from play with target users belongs to the playtests (#48), and the exam pass marks (Q9) are re-measured by `core/scoring/exam_calibration_test.gd` whenever weights or traffic change.

## Still open

- **Playtests with 3–5 target users** (E12-T01, #48): out of scope here. The things only people can judge go there:
  - whether segments pop,
  - whether the scoring balance feels fair,
  - whether the [PARAM]s need retuning.
