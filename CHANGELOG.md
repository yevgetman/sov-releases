# Changelog

## v0.6.1 — 2026-05-25

Task routing UX polish — fixes five issues surfaced by a real session
running the smart router against a complex generative task.

- **AgentTool compact-line rendering**: `AgentTool` calls now render as
  `Dispatched <agent> → <status>` in the theme's primary color (light blue)
  instead of a raw JSON dump in brand-purple.
- **Left margin**: 2-space indent on all compact tool lines and delegator
  event lines, setting tool output apart from assistant text.
- **Vertical spacing**: blank line before and after delegator event groups
  so the routing progress reads as a visual unit.
- **Lane timeouts**: moderate-task 2min→5min, frontier-task 2min→10min,
  delegator 2min→10min. Prevents premature timeout on complex generative
  tasks. cheap-task stays at 2min.
- **Empty-output detection**: AgentTool now marks status=error when the
  subagent reports "completed" but produced no output — prevents misleading
  success indicators.

## v0.6.0 — 2026-05-25

Phase 21 M2: release pipeline now runs in GitHub Actions. Tagging
`vX.Y.Z` and pushing the tag is the new release ceremony; the local
`bun run release v0.x.y` flow remains operational as a fallback.

- No runtime behavior changes; this is a release-engineering cut.
- New `.github/workflows/release.yml` in `sovereign-ai-harness` drives compile + upload via tag-push.
- `scripts/release.ts` refactored into thin orchestrator over `scripts/release-shared.ts` + `scripts/release-build-target.ts` + `scripts/release-upload.ts`.
- Idempotent upload step: re-running against an already-published tag is a no-op success.

## v0.2.1 — 2026-05-22

Cosmetic + correctness fixes surfaced by the v0.2.0 release smoke:

- Splash card now shows the actual harness version (e.g. `(0.2.1)`) instead of a hardcoded `(0.1.0)`. Wired via new `--harness-version` flag from `tuiLauncher` to `sov-tui`.
- MCP client identifier sent to MCP servers now tracks the actual harness version instead of a hardcoded `0.1.0`.
- No new features. `sov upgrade` from v0.2.0 picks this up automatically.

## v0.2.0 — 2026-05-22

First public binary release. Phase 21 M1.

- `sov` CLI (TypeScript runtime, Bun-compiled, ~80 MB)
- `sov-tui` (Go, Bubble Tea, ~10 MB)
- Default agent bundle (skills + agents + prompts)
- Platforms: darwin-arm64, darwin-x64, linux-x64
- One-line installer at `install.sh`
- `sov upgrade` re-runs the installer in binary mode
