# A 3-lane motorway road profile (Autostrada, 3 pasy)

Refs #96 · Parent: [MVP spec](2026-10-11-highway-driving-simulator-mvp.md) (Data Model: `RoadProfile`; Phase 2 simulation, Phase 3 road, Phase 4 traffic, Phase 6 calibration)

## 📝 TLDR
Learner drivers can practise only on 2-lane roads today: the motorway and the expressway both have 2 lanes per direction, although requirements §4.1 allow a motorway with "2 [PARAM], opcjonalnie 3" lanes. Proposed: a third road profile, *Autostrada (3 pasy)* (`motorway_3lane`, 140 km/h, 3 lanes), offered in the new-session setup and as `?profile=motorway_3lane`. The code is already lane-count generic, so the change is one config resource, one launcher entry and one string, plus tests that pin the 3-lane behaviour down; the existing profiles stay unchanged.

## 📝 Problem Statement
Polish motorways are often three lanes wide per direction, and that is where "keep as far right as possible" is hardest: a learner in the middle lane must still move right when the right lane is free. The product owner asked for a 3-lane road (issue #96, scope confirmed 2026-10-22). Players who want to practise it have no road for it today.

## 📝 Proposed Solution
A new data-only `RoadProfile`, added to the launcher's profile list. Everything that depends on the lane count already reads `RoadProfile.lane_count`:

- `LaneIndex` sizes its per-lane lists from it, and `RoadProfile.is_lane_on_road` bounds the road.
- `Spawner` targets `density_per_km_per_lane × window_km × lane_count` and places each vehicle on the rightmost safe lane.
- `RoadLayout` loops over the lanes for the asphalt, the dashed lane lines and the edge lines, and places the median and the opposite carriageway from `carriageway_width()`.
- The scoring rules (K2, N1, N2), the AI (MOBIL) and the ideal-driver bot are lane-relative (`lane - 1`, `lane + 1`, `lane == 0`).
- `PassDetector` scans `player.lane ± 1`, mirrors hang on the player rig, and the blind-spot zones (`ViewConfig.blind_spot_*_m`) are longitudinal and relative to the lane beside the player.

So the work is config plus verification.

Alternatives rejected (owner's decisions, 2026-10-22, issue #96 *Out of scope*):
- **Make the existing motorway 3 lanes.** That would change every existing result's meaning and the calibrated pass marks. A separate profile keeps history comparable.
- **A random 2/3 lane count per session.** Results would stop being comparable within one mode × profile × level, which history and bests are keyed by.
- **A 3-lane expressway, lane drops or merges, a 3-lane tutorial, touch-control changes.** These are not asked for and each would add its own surface.

## 📝 Architecture
- **`config/road_profiles/motorway_3lane.tres`** (new): `id = &"motorway_3lane"`, `display_name_key = "ROAD_MOTORWAY_3LANE"`, `speed_limit_kmh = 140.0`, `lane_count = 3`, `lane_width_m = 3.75`, `shoulder_width_m = 3.0`. Every value is written in the `.tres`, per the [PARAM] rule.
- **`config/dev_launcher.tres`**: the profile is appended to `profiles`, and `default_profile` stays `&"motorway"`. `ui/start_screen.gd` builds the setup's profile buttons from that list, and `DevLauncher.resolve` validates `profile=` against it. This gives one path for the menu and the URL, so neither needs code changes.
- **`i18n/strings.csv`**: `ROAD_MOTORWAY_3LANE,Autostrada (3 pasy)`.
- **Persistence**: none. `SessionRecord.road_profile` already stores the profile id, and history, bests and the previous-result comparison are keyed by mode × profile × level, so the new road counts separately. `schema_version` stays.
- **Exam calibration**: `exam_calibration_test` adds the profile to `PROFILE_PATHS`. `ExamCalibration.pass_score` takes 60% of the bot's **lowest** score across profiles, so a new profile can only lower a level's pass mark, never raise it.

Takeaway: no production script in `core/`, `game/` or `ui/` changes (only tests and `ScoringTestHelper`). A 3-lane road is a data change the existing primitives already support.

## 📝 UI/UX
The setup's *Droga* row shows three option buttons: *Autostrada*, *Droga ekspresowa*, *Autostrada (3 pasy)*. The new one is appended last, so the existing two keep their place and focus order. The row grows from 2 to 3 buttons (`OPTION_BUTTON_SIZE` 250 px, separation 12 px): 774 px, narrower than the existing 4-button *Poziom* row (1036 px) in the 1280×720 canvas-items base. The page therefore keeps its width and height on desktop and at 667×315 on a phone, and touch targets keep their size. In the drive, the road shows a third lane on the left, with a second dashed line. The HUD shows the 140 km/h limit as on the motorway. There are no new hint texts and no new icons.

No mockups: this repository has no test-environment descriptor for browser capture, and the only screen change is one more button of an existing kind.

## 📝 Edge Cases & Failure Scenarios
- **Middle lane, right lane free.** K2 applies, because the lane to the right is free. From lane 2, K2 also applies when lane 1 is free, even if lane 0 is busy. One lane right at a time is what "keep as far right as possible" asks for (see *Resolved assumptions*, Q1).
- **Overtaking from lane 2 a car on lane 1.** `LaneQuery.is_overtaking` looks at the lane to the right of the player, so this is overtaking and there is no K2.
- **N2 on lane 1 or 2.** N2 rewards only lane 0, the rightmost lane.
- **Leaving the road.** A lane change left from lane 2 (to 3) or right from lane 0 (to −1) ends off-road through the existing `is_lane_on_road` check. In learn mode that starts a respawn, and in the exam it ends the session.
- **Traffic volume.** Density is per lane, so traffic on the 3-lane road is 1.5× the 2-lane motorway's at the same level. The spawner still places every vehicle on the rightmost safe lane and skips a spawn when none is safe. Lane 2 fills through AI overtakes.
- **Respawn.** `Respawn` searches the right lane (lane 0), as on 2 lanes.
- **An unknown `profile=` value.** It falls back to `motorway`, as today.

## 📝 Risks & Impact Review
Low blast radius: one additive resource, one list entry, one string, and no save-format change. Rollback is removing the list entry, after which saved records with `road_profile = motorway_3lane` just show under that id in history. Two budgets are at stake:
- **Exam pass marks.** Re-measured with the new profile included, they stay 71 / 59 / 33 / 31 for levels 1–4. On 3 lanes the bot scores 126 / 104.8 / 65 / 75, between the motorway (119 / 98.6 / 55 / 51.3) and the expressway (134.5 / 130.6 / 82.9 / 73) except on level 4, where it is highest. The motorway stays the minimum.
- **FPS (60 target / 30 min on an integrated GPU).** The densest level brings 1.5× the vehicles in the window, each also drawn in up to three mirrors. The issue asks for a `perf=1` level-4 measurement on the reference machine (README *Performance*), which cannot run headless in CI. The implementation PR records it or flags it as pending for QA.

## 📋 Phasing
One phase — independently shippable, a single PR.

## 📋 Implementation Plan

### Phase 1 — The 3-lane motorway profile
1. **Profile, launcher, string.** Add `config/road_profiles/motorway_3lane.tres`, append it to `profiles` in `config/dev_launcher.tres` (`default_profile` unchanged), and add `ROAD_MOTORWAY_3LANE` to `i18n/strings.csv`. Tests: `road_profile_test` loads all three profiles with their lane counts and checks lane 2 on, lane 3 off the 3-lane road; `requirements_params_test` and `difficulty_level_test` include the profile; `dev_launcher_test` finds the profile, keeps the default `motorway` and resolves `?profile=motorway_3lane`; `start_screen_test` offers three profiles, with the label *Autostrada (3 pasy)*.
2. **Lane-relative logic on 3 lanes.** Let `ScoringTestHelper` take a road profile. Tests:
   - `keep_right_rule_test`: K2 in the middle lane with the right lane free, K2 in lane 2 with lane 1 free, no K2 with a car beside on the right, and no K2 overtaking a lane-1 car from lane 2.
   - `reward_rules_test`: N2 on lane 0 only.
   - `traffic_sim_lane_change_test`: off-road left of lane 2 and right of lane 0, and both changes from the middle lane staying on the road.
   - `road_layout_test`: 3 lanes, 2 dashed lines, the right side unchanged, and the median and opposite carriageway moved by one lane.
3. **Traffic and history.** Tests:
   - `traffic_session_test` and `traffic_soak_test` run levels 1–4 on the profile.
   - A new `traffic_session_test` case asserts traffic on all three lanes, overtakes 1→2, returns 2→1 and 1→0, and no collisions.
   - `ai_traffic_test` adds a seeded 3-lane run.
   - `history_store_test` keeps a separate best for `motorway_3lane`.
4. **Calibration and docs.** Add the profile to `exam_calibration_test`'s `PROFILE_PATHS` and re-measure `exam_pass_score` per `docs/agents/scoring.md`. The test fails on any drift, so a changed value is written to `config/difficulty_levels/`. Measured for this spec, the marks are unchanged (see *Risks*), so step 1 leaves the gate green: the calibration test reads its own `PROFILE_PATHS`, not the launcher list. Add `motorway_3lane` to the README's `profile` parameter row. Record the `perf=1` level-4 measurement in the PR, or list it in the PR's QA checklist together with a 667×315 screenshot of the setup.

## Resolved assumptions (autonomous defaults)

| # | Question | Default applied | Rationale |
|---|---|---|---|
| Q1 | On 3 lanes, should K2 ask for one lane right whenever the next lane right is free, including from lane 2 to lane 1? | **Yes**: K2 keeps its lane-relative definition (`lane - 1` free). | This matches "keep as far right as possible" (§8.2), the issue names it as the intended rule, and it needs no code change. A "two lanes right" rule would be a new contract. |
| Q2 | Should exam pass marks become per profile? | **No**: one `exam_pass_score` per level, shared by every profile. | Measured: the bot scores between or above the existing profiles on 3 lanes, so the shared minimum-based mark is unchanged and no schema change is needed. Revisit only if a later calibration diverges. |
| Q3 | Button label and position? | ***Autostrada (3 pasy)***, appended after *Droga ekspresowa*. | The label comes from the issue (marked as possibly changing). Appending keeps the existing buttons' place and focus order. The label is one CSV line to change. |
