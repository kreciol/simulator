# Execution plan — hectometre posts

Source doc: .ai/specs/2026-10-13-hectometre-posts.md
Spec PR: #70 · Issue: #68

## Goal
White posts with a black band beside the right shoulder every `hectometre_post_spacing_m` (100 m) of road, fixed in road coordinates, pooled and recycled like `RoadView` segments, visible ahead and in the mirrors.

## Scope
- `config/view_config.gd` + `config/view_config.tres`: `hectometre_post_*` [PARAM]s and `hectometre_post_count()`.
- `game/world/road_layout.gd`: `hectometre_post_u()`.
- New `game/world/hectometre_posts_view.gd` (`HectometrePostsView`).
- `game/main.tscn` / `game/main.gd`: wiring next to `RoadView`.
- Tests in `tests/game/world/`; AGENTS.md rendering row.

## Non-goals
Hectometre numbers on the posts, posts on the median side, distance signs or gap chevrons, any hint or scoring change (K1 / N3 unchanged), anything in `core/`.

## Risks
- FPS budget: ≤ 8 posts × 2 surfaces, also rendered by the mirrors. The `perf=1` level-4 comparison needs the reference machine — recorded as pending on the PR if it cannot be run here.

## Implementation Plan

### Phase 1: Hectometre posts
1. Config and layout — `ViewConfig` params, `hectometre_post_count()`, `RoadLayout.hectometre_post_u()`, tests for the per-profile offset and the fit in the barrier gap.
2. `HectometrePostsView` — shared two-surface mesh, pool, `update(player_s)`, tests for positions, coverage, 10 km recycling, window bounds and pool edges.
3. Wire into the game — `main.tscn` / `main.gd`, a scene test, AGENTS.md row.

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: Hectometre posts

- [ ] 1.1 Config and layout
- [ ] 1.2 HectometrePostsView
- [ ] 1.3 Wire into the game
