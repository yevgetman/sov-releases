# Changelog

## v0.6.31 — 2026-06-08

**Configure the subscription executor from the TUI; MCP remote-transport hardening.**

- **Subscription executor is now in the config UI.** The opt-in
  `subscriptionExecutor` block — which hands a delegated sub-agent task to a
  headless `claude -p` subprocess so heavy agentic work runs under your Claude
  subscription instead of per-token API billing — was previously schema-only,
  editable only by hand-editing `~/.harness/config.json`. It now appears in the
  config TUI under **Subscription executor** (`/config` → Subscription executor,
  or `sov config`), next to Task routing. All six fields (enabled, engine,
  binary, permissionMode, timeoutMs, maxTurns) are editable, each marked "next
  session" since the scheduler binds the executor config at startup. Still off
  by default and still personal/attended-use-only.
- **MCP remote-transport hardening (review-fix batch).** Auth is kept across a
  same-host `http`→`https` redirect upgrade (but still dropped cross-origin); an
  env MCP token (`SOV_MCP_<ALIAS>_TOKEN`) now wins over a committed
  `Authorization` header; the connect-timeout timer is cleared and stdio error
  codes are surfaced; and the MCP config schema reports a single clear error on
  a malformed entry. These refine the remote-MCP support that shipped in
  v0.6.30.

If you don't enable the subscription executor or configure a remote MCP server,
your normal usage is unchanged.

## v0.6.30 — 2026-06-08

**Connect to remote MCP servers, not just local ones.**

- **Remote MCP transport (HTTP/SSE).** An `mcpServers` entry can now point at a
  hosted MCP server over Streamable HTTP or legacy SSE, in addition to the
  existing local-process (stdio) form. A remote entry is
  `{ "type": "http" | "sse", "url": "...", "headers"?, "bearerToken"?,
  "apiKey"? }`; the local `{ "command": ... }` form is unchanged. Auth is
  env-first — set `SOV_MCP_<ALIAS>_TOKEN` or `SOV_MCP_<ALIAS>_API_KEY` rather
  than putting a secret in the config file. This opens the harness to the
  growing ecosystem of hosted/remote MCP servers.
- **Security: auth headers are stripped on cross-origin redirects.** If a remote
  MCP server redirects to a different origin, your bearer token / API key is
  dropped from the redirected request, so a malicious or compromised server
  can't exfiltrate it. Secrets are never logged, and `/status` shows the server
  origin only, not the full URL.

These changes only affect MCP server connections; if you don't configure a
remote MCP server, your normal `sov`, `sov serve`, `sov drive`, and gateway
usage is unchanged.

## v0.6.29 — 2026-06-08

**Bring your Claude Code skills over — and skill tool limits are now real.**

- **Import a Claude Code skill as-is.** A Claude Code `SKILL.md` now loads
  natively: its `allowed-tools` frontmatter key (including the common
  comma-separated-string form, e.g. `allowed-tools: Read, Grep`) is accepted as
  an alias for the harness's `allowedTools`. The new `/skills import <path>`
  command brings one in for you — it rewrites the frontmatter to the harness's
  canonical form, validates it, copies any bundled references and scripts, and
  reports what it converted and any warnings.
- **Skill `allowedTools` is now enforced, not just advisory.** When you run a
  skill via `/skill`, its declared `allowedTools` now actually restrict which
  tools that turn can use (and sub-agents forked mid-turn inherit the same
  restricted set) — previously the list was documentation only. (The
  model-invoked `Skill` tool stays advisory by design.)
- **Hardening: skill import/install reject out-of-tree symlinks.** A skill tree
  being imported or installed can no longer smuggle in symlinks that point
  outside the skill directory.

These changes only affect skills; your normal `sov`, `sov serve`, `sov drive`,
and gateway usage is unchanged.

## v0.6.28 — 2026-06-08

**Delegation answers show up in `sov drive`; one safer config guardrail.**

- **Fix: delegated answers now show in `sov drive`.** When you delegate work
  to the subscription executor, `sov drive` was printing
  `[result AgentTool] (no summary)` even though the delegated answer had come
  back — the answer was only missing from the display, never from the model.
  The delegated result now renders correctly. (The TUI was already fine.)
- **Config guardrail: subscription executor and task routing are mutually
  exclusive.** They are two different cost strategies — a flat-rate
  subscription vs. routing by API cost tier — so enabling both at once now
  fails config validation up front with a clear message telling you to pick
  one, instead of silently letting them conflict.

Both changes are inert unless you use the relevant features; your normal `sov`,
`sov serve`, `sov drive`, and gateway usage is unchanged.

## v0.6.27 — 2026-06-08

**Opt-in: delegate heavy work to a headless Claude Code session under your own
Claude install.**

- **Subscription executor (opt-in, off by default).** You can now hand a
  delegated sub-agent task to a headless Claude Code session running under your
  **local `claude` install** — so heavy agentic work runs at your **subscription
  flat rate** instead of per-token API billing. The delegated session runs
  Claude Code's own loop and returns its result through the normal sub-agent
  path, and its per-tool work feeds the harness's memory/learning just like a
  native turn. Requires `claude` installed and logged in; enable it with the
  `subscriptionExecutor` config block (see the "Subscription executor" section
  in the usage docs).
- **Personal / attended use only.** This is for a human at the keyboard
  delegating to their own logged-in Claude Code — driving a consumer
  subscription as an automated or multi-tenant backend is against subscription
  terms, so the executor is wired only to the interactive sub-agent path and is
  deliberately **not** available to cron, channels, or the gateway (those stay
  on the per-token API). See the docs for the full terms boundary.

Off by default — your normal `sov`, `sov serve`, `sov drive`, and gateway usage
is byte-for-byte unchanged unless you explicitly enable it.

## v0.6.26 — 2026-06-06

**Text the harness over SMS (Twilio).**

- **New SMS channel.** A self-hosted `sov gateway` can now be driven over SMS via
  Twilio — text a question, get a reply. Like the other channels, it is
  **allow-listed** (only numbers you explicitly map can drive a turn — a phone
  number is publicly textable, so an unlisted sender gets nothing), **per-sender
  isolated** (each allowed number is its own principal with its own sessions,
  memory, and learning), and runs under the same **safe-by-default** permission
  posture as Slack / Telegram / webhook. Carrier-mandated STOP / HELP / START are
  handled automatically. See the SMS setup section in the usage docs (buy a Twilio
  number, point its Messaging webhook at `/channels/sms`, set the credentials and
  your allow-list).

Channels remain off unless configured, and your normal `sov`, `sov serve`, and
`sov drive` usage is unchanged.

## v0.6.25 — 2026-06-06

**Scheduled jobs (cron) now draw on memory and learned instincts, like
interactive sessions — plus CI/build maintenance.**

- **Cron joins the learning loop.** A scheduled job's turn now reads your
  project memory and gets relevant recalled context spliced in, just like an
  interactive session, a channel, or `sov drive` — so a recurring job benefits
  from what the harness has learned instead of starting cold every run.
- **CI/build maintenance.** The release pipeline was moved off the deprecated
  Node 20 runner onto current Node 24 runtimes.

No configuration changes — cron remains off unless you've scheduled jobs, and
your normal `sov`, `sov serve`, and `sov drive` usage is unchanged.

## v0.6.24 — 2026-06-06

**Channels now participate in the learning loop and stay responsive on long
conversations and concurrent messages — plus reliability and documentation fixes.**

A holistic review of the channels and gateway surfaces (E+F) hardened how inbound
Slack / Telegram / webhook messages are handled:

- **Channels join the learning loop.** A channel session now reads and writes
  memory and gets relevant recalled context spliced in, just like an interactive
  session — so a channel conversation accrues and benefits from what the harness
  has learned (per the channel's isolated principal).
- **Responsive on long + concurrent conversations.** Channel history is now
  bounded so a long-running conversation stays fast, and multiple messages on the
  same conversation are serialized so they no longer race.
- **Reliability fixes.** Telegram switches to a robust long-poll with backoff,
  stale channel sessions are swept automatically, errors surface instead of being
  silently swallowed, and source-id / request-body handling was hardened.
- **Documentation audit.** The usage and architecture docs were brought current.

No configuration changes — channels remain off unless configured, and your normal
`sov`, `sov serve`, and `sov drive` usage is unchanged.

## v0.6.23 — 2026-06-06

**Channels: drive the harness from Slack, Telegram, or a generic webhook — each
an isolated principal with a safe-by-default permission posture.**

A self-hosted `sov gateway` can now be driven by inbound messages. A Slack,
Telegram, or generic-webhook message routes to a per-conversation harness
session, runs a turn, and the reply comes back over the same channel:

- **Three adapters.** A **generic webhook** (`POST /channels/webhook/default`,
  HMAC-SHA256-signed, synchronous reply — no external account needed),
  **Telegram** (long-poll, no public endpoint — just a @BotFather bot token), and
  **Slack** (Events API: signing-secret verification, the URL-verification
  handshake, and an asynchronous reply).
- **Each channel is an isolated principal.** A channel binds to a configured
  principal, so its sessions, memory, and learning are isolated from every other
  principal — and never see a human user's data. Each sender gets a continuous,
  coherent conversation.
- **Safe by default.** A channel message is untrusted remote input, so a channel
  turn does **not** inherit your local allow-rules and auto-denies anything that
  would prompt — `Bash`, `Write`, `Edit`, and other dangerous tools are denied
  unless you add explicit per-channel allow rules. `bypass` mode is forbidden for
  channels.
- **Configure `gateway.channels`.** Each channel names a `principalId` and its
  secret (resolved env-first — `SOV_WEBHOOK_SECRET` / `SOV_TELEGRAM_BOT_TOKEN` /
  `SOV_SLACK_SIGNING_SECRET` + `SOV_SLACK_BOT_TOKEN`). See the usage guide for the
  full Slack/Telegram setup steps.

v1 limits: channel turns auto-deny (no in-channel approval UI), replies are plain
text (no rich Slack/Telegram UX), and a single very long conversation isn't
compacted yet. Shipped after a hard adversarial security review. Channels are off
unless configured — no change to your normal `sov`, `sov serve`, or `sov drive`
usage.

**This release completes the run-anywhere roadmap** — a secure remote gateway, a
multi-client reconnecting transport, a reference browser UI, a persistent
multi-session supervisor, multi-user isolation, and now inbound channels.

## v0.6.22 — 2026-06-06

**Multi-user gateway: configure named principals — each gets isolated sessions,
memory, and learning (within-org trust model).**

A single self-hosted `sov gateway` can now serve multiple named users, each
isolated from the others:

- **Named principals.** Configure `gateway.principals` (a list of
  `{ id, token, name? }`) instead of the single `gateway.token` — each user
  authenticates with their own bearer token. (The two are mutually exclusive:
  pick single-user or multi-user.)
- **Isolated sessions.** Each session is owned by the user who created it. Other
  users can't see it, resume it, or delete it — another user's session simply
  looks like it doesn't exist (404). `GET /sessions` lists only your own.
- **Isolated memory + learning.** Each user gets their own memory and learned
  instincts, scoped to them and never shared across users.
- **No anonymous access in multi-user mode.** When principals are configured, a
  valid token is required on every request — including on loopback.

This is the **within-org / single-trust-domain** model — trusted-but-separate
users on one operator-run gateway (a team, a household, a small org). It is not
hostile multi-tenant isolation. Shipped after a hard adversarial security
review. No change to your normal `sov`, `sov serve`, or `sov drive` usage —
single-user and no-auth modes are unchanged.

## v0.6.21 — 2026-06-06

**Persistent gateway: idle sessions are reclaimed automatically (transparent
resume); new GET/DELETE /sessions lifecycle routes; optional concurrency cap;
run-as-a-service docs.**

A long-running `sov gateway` is now a persistent multi-session host that stays
healthy over days of uptime:

- **Idle sessions are reclaimed automatically — transparently.** The gateway
  frees the in-memory state of sessions you've stopped using (idle past
  `gateway.idleSessionTimeoutMs`, default 30 min; swept every
  `gateway.idleSweepIntervalMs`, default 5 min). It's transparent: the durable
  session is kept on disk and resumes on your next request, so you can come back
  hours later and pick up the conversation. It never reclaims a session
  mid-turn or one with a connected client.
- **Manage sessions over the API.** `GET /sessions` lists sessions with live
  annotations (is it live, is a turn running, how many clients are watching);
  `DELETE /sessions/:id` permanently removes one.
- **Optional concurrency cap.** Set `gateway.maxConcurrentSessions` (default 0 =
  unlimited) to cap live sessions; the gateway sweeps idle ones first and only
  pushes back (429) when it's genuinely full.
- **Run it as a service.** New docs with ready-to-adapt systemd and macOS
  launchd definitions, so the gateway restarts on failure / boot and resumes
  sessions across restarts.

No change to your normal `sov`, `sov serve`, or `sov drive` usage — this is all
gateway-scoped.

## v0.6.20 — 2026-06-06

**Built-in web UI: open the gateway URL in a browser to chat with the harness —
streaming, tool approvals, reconnect.**

The gateway now ships a real browser chat client, served by the gateway itself:

- **Open it in a browser.** Run `sov gateway` and browse to its URL (default
  `http://127.0.0.1:8766/`, also at `/ui`). Paste your gateway bearer token on
  the connect screen and you're chatting — no separate install, no build step.
- **The full interactive experience.** Live token-by-token streaming, collapsible
  thinking blocks, tool cards, and **inline permission prompts** (Approve / Deny
  right in the page) — plus auto-reconnect if the connection drops, a new-chat
  button, and cancel.
- **Self-contained + same-origin.** It's a single page embedded in the binary
  and served by the gateway it talks to, so it needs no CORS setup. Your token
  stays in the browser (it's never baked into the page).

Also includes a fix so an idle reconnecting stream can't hang the web UI.

No change to your normal `sov`, `sov serve`, or `sov drive` usage.

## v0.6.19 — 2026-06-05

**Multi-client gateway: multiple clients per session, reconnect-with-replay,
and a persistent `?follow` stream.**

Building on the new `sov gateway`, the session event stream is now multi-client
and reconnect-safe — so a real web or mobile UI can sit on top of it:

- **Multiple clients per session.** Two devices can watch the same session at
  once; every client receives every event.
- **Reconnect without losing events.** Each event carries a sequence id, so a
  client that drops can reconnect with `Last-Event-ID` (or a `?lastEventId`
  query) and the gateway replays the events it missed, then continues live. The
  replay window is bounded (configurable via `gateway.eventBufferSize`, default
  512 events per session).
- **Persistent `?follow` stream.** `GET /sessions/:id/events?follow=true` keeps
  the stream open across turns — subscribe once and watch the whole session,
  instead of re-opening the stream for each turn. Combine it with
  `Last-Event-ID` for seamless reconnect.

No change to your normal `sov`, `sov serve`, or `sov drive` usage — the default
per-turn stream behavior is unchanged.

## v0.6.18 — 2026-06-05

Gateway hardening + docs for driving the gateway from a browser.

- **Sturdier under bad input.** A malformed or empty request body on the
  turns and approvals routes now returns a clear `400` instead of a `500`,
  and the gateway validates its port at startup (failing fast on `0`,
  out-of-range, or garbage values rather than silently binding a random port).
- **Cleaner shutdown.** Pressing Ctrl-C mid-turn now cancels the in-flight
  work before closing the database, so the gateway (and `sov serve`) shut down
  cleanly even while a turn is running.
- **New docs: driving the gateway from a browser.** A live cross-origin
  browser test confirmed the gateway is genuinely browser-drivable and
  surfaced the one big gotcha — the browser `EventSource` API can't send an
  auth header, so web clients must consume the event stream with `fetch()`
  instead. The usage guide now includes a copy-pasteable browser client
  example plus CORS, status-code, and permission-mode notes.

No change to your normal `sov`, `sov serve`, or `sov drive` usage.

## v0.6.17 — 2026-06-05

New **`sov gateway`** — drive the harness from any remote UI over an
authenticated HTTP+SSE gateway. It exposes the harness's native, interactive
protocol (live turns, streaming output, tool activity, permission prompts,
slash commands, skills) so a web app, a phone, or a custom client can run a
full session over the network — not just one-shot completions like `sov serve`.

Secure by default:

- **Loopback-only out of the box.** Reachable only from the same machine
  unless you explicitly bind it elsewhere (`--host`, `SOV_GATEWAY_HOST`, or
  `gateway.host`; default port `8766`).
- **Refuses to start exposed without a token.** If you bind it off-loopback
  without setting an auth token (`SOV_GATEWAY_TOKEN` or `gateway.token`), it
  exits with a clear message instead of standing up an open, tool-running
  agent.
- **Bearer auth on every session route** (including the live event stream); a
  `/health` probe stays open. CORS is closed by default and opens only to the
  browser origins you allow-list (`gateway.corsOrigins`).

Whoever holds the token gets the harness's full tool powers, so expose the
gateway only behind a constrained permission policy (and TLS). Your normal
`sov`, `sov serve`, and `sov drive` usage is unchanged.

## v0.6.16 — 2026-06-04

Learned lessons are now **recalled into the agent by default** (opt out with
`learning.recall.enabled=false`). Since the spike's Phase-1 proof cleared its
bar, recall is now on out of the box: lessons the harness has learned are
surfaced in front of a turn so they can shape its behavior. It stays
fail-open and is a no-op when there's nothing learned yet, so a fresh harness
behaves exactly as before.

## v0.6.15 — 2026-06-04

Learning-loop spike, Phase 1 — **complete**. The loop is now closed end to
end: the harness can synthesize a lesson from what it observed, recall it in
front of a later turn, and have that lesson change its behavior — with no human
in the loop. As in v0.6.14, recall stays **off by default** (enable it with
`learning.recall.enabled: true`), so default behavior is unchanged.

Two fixes made the loop actually yield:

- **Synthesis now produces usable lessons from realistic evidence.** The
  confidence curve was effectively unreachable — a lesson needed on the order of
  tens of millions of observations to clear the bar. It now saturates sensibly
  (roughly ~6 observations to survive pruning, ~20 to be promoted). Observations
  of the same tool with different arguments now group together instead of
  fragmenting, and synthesis can also be triggered at the end of a session
  (`learning.synthesizeOnSessionEndAfter`). The synthesizer fails loudly on
  error rather than silently producing nothing, and has more room to reason.
- **Recalled lessons are now scoped to the right project.** Recall was reading a
  different project identifier than the one lessons are written under, so
  project-scoped lessons were never surfaced. Read and write paths now agree.

## v0.6.14 — 2026-06-03

Learning-loop spike, Phase 1 — the learning layer is now constructed at runtime
boot and its per-turn "recall" path is wired into the conversation turn. Recall
(surfacing relevant learned lessons in front of a turn) is **off by default** —
enable it with `learning.recall.enabled: true` (tunable `maxLessons` /
`tokenBudget`). When off, behavior is unchanged.

This release also fixes a latent bug: on the TUI / API-server surface, your
project + global `MEMORY.md` was never being injected into turns (only the CLI
paths injected it). MEMORY.md now injects on every surface, as intended.

## v0.6.13 — 2026-05-29

TUI polish: markdown **headings** now render in a clearly lighter sky-blue
(`#e0f2fe`, Tailwind sky-100) so they stand apart from **bold** text and
`inline code`, which use the slightly darker sky-300 (`#7dd3fc`). Previously
headings sat only one shade lighter (sky-200) and read as nearly the same blue
as inline emphasis. Heading color remains theme-independent.

## v0.6.12 — 2026-05-28

Robustness release: a conservative whole-codebase bug audit found 21 objective,
function-breaking defects (1 critical, 11 high, 8 medium, 1 low); all are fixed,
each with a new regression test.

**Security / permissions**

- **Web-fetch SSRF protection is live again.** The tool input-validation step
  was never invoked by the runtime, so web-fetch's scheme + private-host/
  loopback guard was effectively off. It now runs, and additionally re-validates
  every redirect hop and blocks link-local / cloud-metadata (`169.254.x`) and
  `0.0.0.0` addresses.
- **Shell commands that write a file via `>` are no longer auto-approved.** A
  command like `cat secret > /file` was misclassified as harmless "read-only"
  and ran with no permission prompt; output redirects are now treated as writes
  (both detection sites), while `2>&1`-style fd-duplications stay read-only.
- A mistyped `-p <profile>` or a corrupted profile-pointer file can no longer
  escape the profiles directory (path-traversal); profile names are validated.

**Reliability / crashes**

- A turn aimed at a nonexistent session no longer crashes the whole server
  process — it returns a clean 404.
- Typing `@file:`/`@folder:` on an unreadable path no longer silently freezes
  the turn; it inlines an error marker instead.
- When the default provider (Anthropic) rate-limits or rejects your key, the
  harness now backs off / fails over (and shows the right startup error)
  instead of ignoring it.
- A startup database-cleanup step no longer crashes boot when the DB is briefly
  busy (now that the API server and scheduler share it).
- The background daemon's single-instance lock no longer mistakes a live
  process it can't signal for a dead one.

**TUI**

- The interface no longer freezes after `/clear` or `/rollback` — the live
  update stream now reconnects to the new session.
- A large file-read (or big tool output) no longer kills the live update
  stream mid-turn.

**API server**

- The OpenAI-compatible server no longer leaks an event channel per streaming
  request, and a failed message-save no longer returns a broken error or leaks
  a session.
- OpenAI / OpenRouter turns now report token usage and cost (was always `$0`).

**Other correctness**

- Skills that embed shell commands or take arguments no longer garble text
  containing `$` sequences (prices, `awk $1`, git diffs, etc.).
- Saved memory/skill review proposals that quote multi-line text round-trip
  losslessly (were silently truncated/corrupted on disk).
- File-pattern search (`Glob`) returns deterministic, sorted results when
  truncating to a limit.
- Deterministic test-replay no longer swaps results between concurrent
  same-tool calls.

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
