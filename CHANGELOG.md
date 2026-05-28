# Changelog

## v0.6.11 — 2026-05-28

- **UX:** `Echo.TrailingGap` reverted 2 → 1, restoring symmetric padding
  above and below the user echo line. The v0.6.10 bump to 2 was based on
  VHS-rendered screenshots that had artificially wide letter-spacing
  (font fallback bug); once visual QA was calibrated to real Terminal.app
  density, the 2-blank within-turn gap stood out as too loose. The Q→A
  pair now reads as paired, with turn-to-turn separation remaining
  clearly larger.

## v0.6.10 — 2026-05-28

Visual QA loop iteration (all 4 changes verified against rendered PNGs
before commit).

- **UX:** `Echo.TrailingGap` bumped 1 → 2. The gap between a user
  question and the assistant's response now has the breathing room
  the conversation rhythm wanted, while still pairing cleanly visually.
- **UX:** Prompt textinput marker changed `›` → `▸`. Previously the
  prompt cursor area and the committed user echo both used similar
  right-angle-bracket glyphs, reading at a glance as "the same
  thing." The new `▸` is a filled small triangle — clearly a
  different shape from the user echo's `❯`.
- **UX:** Strong markdown (`**bold**`) now renders in
  `Brand.AccentColor` (sky-300, `#7dd3fc`) — same color as inline
  code. Pre-fix, `**56**` rendered uncolored while `Node.js` inside
  backticks rendered sky-blue, so the same conceptual emphasis
  looked visually inconsistent in the same response.

## v0.6.9 — 2026-05-27

- **UX:** Reduced end-of-turn gap — `Separator.TrailingGap` set to 0.
  The separator line + `Echo.LeadingGap` provide enough visual boundary
  without the extra blank line after the rule.

## v0.6.8 — 2026-05-27

- **UX:** Preserve 1 trailing newline after rendered markdown in
  `EndAssistantCard`. The v0.6.6 aggressive trim removed all trailing
  whitespace, eliminating the natural paragraph gap before the turn
  separator. Now the text has breathing room at end of turn while
  keeping the text→tool gap tight.

## v0.6.7 — 2026-05-27

- **UX:** Added end-of-turn trailing gap after the turn separator line.
  New `style.S.Separator.TrailingGap` token (1 blank line) prevents
  the prompt from crowding the assistant's last line of output.

## v0.6.6 — 2026-05-26

- **Bug fix:** Task routing agents (delegator, cheap-task, moderate-task,
  frontier-task) are now hidden from the model when `taskRouting.enabled`
  is false. Previously the model could dispatch to routing agents even
  with routing disabled.
- **UX:** User input marker changed from dark blue `»` to `❯` in
  sky-300 (#7dd3fc) for better visibility on dark terminals.
- **UX:** Added breathing room (1 blank line) above each user input echo.
- **UX:** Reduced idle-check spinner delay from 700ms to 400ms so the
  "Thinking" indicator reappears faster during text→tool gaps.
- **UX:** Tighter spacing between assistant text and compact tool lines
  (trimmed trailing newlines from markdown renderer output).
- **UX:** Stripped "Phase X" dev build names from `/config` catalog
  group descriptions.
- **UX:** "no changes to save" → "config is up to date" on `/config`
  commit with no pending changes.
- **UX:** `sov config` now exits cleanly after save (S) or ESC on the
  root menu instead of leaving a dead screen.

## v0.6.5 — 2026-05-25

- Blank line after user echo (`»` prompt) before the first tool or text
  event — prevents the echo from crashing into the next line.
- Task router preset indicator in the status bar now updates live when a
  preset is applied or routing config changes via `/config`.
- Status bar immediately clears "Task Router Active" when routing is
  disabled via `/config`, confirming the setting took effect.

## v0.6.4 — 2026-05-25

Global TUI style guide. New `packages/tui/internal/style/` package
centralizes every spacing, padding, margin, border, glyph, brand-color,
and typography token across the TUI into a single authoritative source.
Components reference `style.S.*` instead of hardcoded values. Themes
remain separate for switchable color palettes.

Visual output is byte-identical to v0.6.3 — all tokens seeded from exact
current values. Future UX updates are single-line changes in the style
package instead of ad-hoc edits across 17+ component files.

## v0.6.3 — 2026-05-25

Replace "basic blue" (`t.Primary`) with fixed sky-300 (`#7dd3fc`) in all
delegator event lines and the AgentTool "Dispatched" verb. The saturated
blue rendered poorly on dark terminals; the pinned light blue is
consistent with the inline-code convention from M11.13.

Convention rule added to `docs/conventions/tui-color-rendering.md`:
`t.Primary` must not be used for text in tool/routing output — use
`DelegatorAccentColor` or `CompactLineVerbColor` instead.

## v0.6.2 — 2026-05-25

Delegator event line visual improvements (follow-up to v0.6.1):

- **Brighter text**: structural text ("atom N on") uses foreground color
  instead of muted info; details (duration, lane distribution) use info
  instead of dim. Lane names are now bold. Much higher contrast on dark
  backgrounds.
- **Preview truncation**: atom dispatch lines now respect terminal width —
  the prompt preview is clipped with ellipsis instead of wrapping to the
  next line.
- **Intra-group spacing**: blank lines between the plan header, atom
  events, and summary footer create a 3-section visual with breathing room.

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
