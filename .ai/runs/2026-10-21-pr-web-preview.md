# Execution plan — web preview of every `needs-qa` PR

Source doc: .ai/specs/2026-10-21-pr-web-preview.md (spec PR #92)
Issue: #91

## Goal

CI publishes the web build of every same-repo `needs-qa` PR to `https://kreciol.github.io/simulator/pr/<n>/<sha7>/` and links it from one bot comment; Pages moves to deploy from the `gh-pages` branch, where `main` owns the root.

## Scope

- New `.github/scripts/publish-gh-pages.sh`, `.github/scripts/preview-comment.sh` and their test `.github/scripts/test-publish-gh-pages.sh`.
- `.github/workflows/ci.yml` (artifact upload, `publish-main`, `publish-preview`, script test step; `deploy-pages` removed) and new `.github/workflows/pr-preview.yml`.
- Docs: `README.md` (CI section), `SDLC.md` (QA section), `docs/agents/project-setup.md`.

## Non-goals

Game code, the export settings, previews for forks or PRs without `needs-qa`, external hosts, wiring the preview into the QA skills.

## Implementation Plan

Phases and steps follow the spec's Implementation Plan one to one.

## Risks

- The workflows can only be exercised on GitHub; before merge, evidence is the `gh-pages` tree and the PR comment. Preview URLs 404 until the owner switches the Pages source (manual step in the PR body).
- The `github-pages` environment allows only `main` today; the branch-based deploy needs `gh-pages` added — confirmed on the first `pages-build-deployment` run.

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: gh-pages as the site

- [x] 1.1 Publish script with main/preview/remove modes and its local test — 19da1be
- [x] 1.2 Run the script test in CI's test job — b6d0877
- [x] 1.3 Upload web-build on every event; replace deploy-pages with publish-main — b6d0877
- [x] 1.4 README and project-setup docs for the gh-pages site — bbe388b

### Phase 2: previews

- [ ] 2.1 publish-preview job in CI with the sticky comment
- [ ] 2.2 pr-preview.yml for labeled and closed
- [ ] 2.3 SDLC QA section and project-setup preview rules
- [ ] 2.4 PR description with the owner's manual step and pre-merge evidence
