# Backlogs

## .ai/specs/2026-10-11-highway-driving-simulator-mvp.md
Backlog source: .ai/specs/2026-10-11-highway-driving-simulator-mvp.md
Last filed: 2026-10-11

Phases 1–4 filed as E01–E04; Phases 5–11 parked in E05 (re-run `om-backlog .ai/specs/2026-10-11-highway-driving-simulator-mvp.md` to file them).

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
| E05 | #14 | Later (parked) | — | — | no |
