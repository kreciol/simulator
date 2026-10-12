# Backlogs

## .ai/specs/2026-10-11-highway-driving-simulator-mvp.md
Backlog source: .ai/specs/2026-10-11-highway-driving-simulator-mvp.md
Last filed: 2026-10-12

Phases 1–4 filed as E01–E04 (2026-10-11); Phases 5–11 filed as E06–E12 (2026-10-12). E05 (parked) is closed; its id stays reserved.

| Id | Issue | Title | Epic | Depends on | Adopted |
|---|---|---|---|---|---|
| E01 | #1 | Skeleton & delivery pipeline | — | — | no |
| E01-S01 | #2 | A player can open the game on GitHub Pages, deployed automatically from main | #1 | — | no |
| E02 | #3 | Simulation core | — | — | no |
| E02-S01 | #4 | A simulated vehicle drives, signals and changes lanes per the rules | #3 | E01-S01 (#2) | no |
| E02-S02 | #5 | Lane queries, collisions and replay match the spec | #3 | E02-S01 (#4) | no |
| E03 | #6 | Drivable road | — | — | no |
| E03-S01 | #7 | A player drives in cockpit view on an endless motorway or expressway | #6 | E02-S02 (#5) | no |
| E03-S02 | #8 | A player sees speed, limit, signals and time, and the session ends after 90 s | #6 | E03-S01 (#7) | no |
| E03-S03 | #9 | A tester can start any mode, profile, level and seed from the URL | #6 | E03-S02 (#8) | no |
| E04 | #10 | Traffic | — | — | no |
| E04-S01 | #11 | AI cars keep safe gaps, overtake slower vehicles and return right, signalling | #10 | E02-S02 (#5) | no |
| E04-S02 | #12 | Traffic density follows the chosen level, spawns safely and always offers overtaking | #10 | E04-S01 (#11) | no |
| E04-S03 | #13 | A player sees varied AI vehicles with brake lights and indicators; hitting one ends the session | #10 | E04-S02 (#12), E03-S02 (#8) | no |
| E05 | #14 | Later (parked) — closed, superseded by E06–E12 | — | — | no |
| E06 | #24 | Mirrors & quality | — | — | no |
| E06-S01 | #25 | A player sees traffic behind in three mirrors and can switch quality and mirrors | #24 | E04-S03 (#13), E03-S03 (#9) | no |
| E06-S02 | #26 | The web build holds 30 FPS on level 4 on an integrated-GPU laptop, measured reproducibly | #24 | E06-S01 (#25) | no |
| E07 | #27 | Scoring | — | — | no |
| E07-S01 | #28 | Driving too close, staying left and changing lanes without a signal cost points as the rules say | #27 | — | no |
| E07-S02 | #29 | Correct lane changes, keeping right, a legal gap and staying under the limit earn points | #27 | E07-S01 (#28) | no |
| E07-S03 | #30 | Every session ends with a record of its score, categories and stats, and each level has an exam pass mark | #27 | E07-S02 (#29) | no |
| E08 | #31 | Modes & session rules | — | — | no |
| E08-S01 | #32 | In exam mode, a collision or leaving the road ends the session and names the cause | #31 | E04-S03 (#13), E03-S03 (#9), E07-S03 (#30) | no |
| E08-S02 | #33 | In learn mode, after a collision or leaving the road the player is put back on the road and drives on | #31 | E08-S01 (#32), E07-S02 (#29) | no |
| E08-S03 | #34 | A player can pause with Esc or P, and the game pauses itself when the tab loses focus | #31 | E03-S02 (#8) | no |
| E08-S04 | #35 | In learn mode the player sees a live score and blind-spot icons; exam hides them | #31 | E07-S02 (#29), E08-S01 (#32), E06-S01 (#25) | no |
| E09 | #36 | Feedback | — | — | no |
| E09-S01 | #37 | In learn mode, hints warn before a penalty and explain events with live numbers | #36 | E08-S04 (#35) | no |
| E09-S02 | #38 | After every session a summary shows the score, categories, status and a short supportive description with one tip | #36 | E07-S03 (#30), E08-S01 (#32) | no |
| E10 | #39 | Results & history | — | — | no |
| E10-S01 | #40 | Session results are saved in the browser and survive a page reload | #39 | E07-S03 (#30) | no |
| E10-S02 | #41 | A player sees history, bests per combination and a trend, and the summary compares with the previous and best result | #39 | E10-S01 (#40), E09-S02 (#38) | no |
| E11 | #42 | Menus, settings, tutorial | — | — | no |
| E11-S01 | #43 | A player starts from a start screen and picks mode, road and level, with the recommended level highlighted | #42 | E10-S02 (#41), E09-S02 (#38) | no |
| E11-S02 | #44 | A player can set quality and mirrors and preview the key bindings, and the settings are remembered | #42 | E11-S01 (#43), E06-S01 (#25) | no |
| E11-S03 | #45 | A first-time player is offered a short, skippable tutorial on an empty road | #42 | E11-S01 (#43) | no |
| E12 | #46 | Tuning & playtests | — | — | no |
| E12-S01 | #47 | The final build meets every MVP acceptance criterion with evidence | #46 | E11-S03 (#45), E06-S02 (#26) | no |
| E12-T01 | #48 | Run playtests with 3–5 target users and file the findings | #46 | E12-S01 (#47) | no |
