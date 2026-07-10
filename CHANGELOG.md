# Changelog

## v0.6.57 — 2026-07-09

**Mid-turn steering: `sov run --steer-file`.** A machine adapter (e.g. a Telegram
bridge) can now inject operator messages into a **running** `sov run` turn.

- `--steer-file <path>` names a JSONL file (`{"text": "..."}` per line) that the
  turn loop polls at agent-loop boundaries and consumes atomically. At a tool
  boundary the framed message merges into the tool batch's user message; when
  the model has already composed its final answer, a pending steer becomes a
  standalone user message and the turn **continues** to address it (`maxTurns`
  bounds continuations, and a steer is never consumed on the final iteration —
  it stays at the source for the adapter to deliver as a follow-up).
- A `steer_injected` event announces each injection on the wire (additive).
- Consume discipline is loss-proof: read failures restore the file, swaps
  stranded by a killed consumer are recovered and re-ingested, swap names are
  collision-free, and injected text always carries untrusted-content framing.
- SDK surface: `QueryParams` / `AgentConfig` / `PerTurn.pollSteering` — a host
  thunk mirroring `recall`. Without `--steer-file`, behavior is byte-identical.

## v0.6.56 — 2026-07-09

**`sov run` hardening: clean SIGINT/SIGTERM shutdown + whitespace-stdin guard.** A deep testing/debugging pass (round 2) on the headless machine contract.

- **SIGINT/SIGTERM handled.** An interrupt mid-turn (Ctrl-C, adapter timeout/kill, scheduler stop) now cancels the in-flight turn, emits a terminal `turn.error { error: "interrupted", recoverable: true }` carrying the persisted session id, and exits the conventional 128+signum code (130 SIGINT / 143 SIGTERM) — with the in-process server and runtime still torn down cleanly in the `finally`. `recoverable: true` tells the adapter it can `--resume`. Previously an interrupt left the caller reading a truncated JSONL stream with no terminal event.
- **Whitespace-only stdin is empty.** A blank/whitespace prompt is now rejected side-effect-free (structured `turn.error`, `sessionId: null`, no session DB/transcript) instead of running a wasted turn.

No critical/high findings; the surface remains loopback-only with structured, clean error envelopes. `sov drive` and day-to-day CLI behavior are unchanged.

## v0.6.55 — 2026-07-09

**A machine-readable headless runner — `sov run --json --stdin` — so external harnesses (Telekit) can drive `sov` without scraping `sov drive` text.**

- **New: `sov run` machine contract.** `sov run --json --stdin` reads **all stdin as one prompt** (newlines preserved — no more one-turn-per-line splitting), runs exactly one turn through the same in-process server the TUI uses, and emits newline-delimited JSON on stdout: a `session.started` bootstrap event, protocol passthrough events (`text_delta`, `tool_use_*`, `permission_request`, …), and a terminal `turn.completed` (with `reply`, `finishReason`, `usage`) or `turn.error`. Supports `--resume <id>`, `--provider`, `--model`, `--effort`, `--permission-mode`, `--db`, `--max-tokens`, `--no-cache`, `--no-preflight`. Headless `permission_request` auto-denies, so `ask` mode can never block forever.
- **Why.** `sov drive` is line-oriented and human-readable — fine for semantic tests, wrong as an integration contract. `sov run` is the stable machine surface Telekit (and other adapters) shell out to.
- **Input hardening.** stdin is read and validated *before* the runtime boots; empty stdin is a clean usage error (exit 2), not a silent no-op.
- **Source-mode install fixes.** `sov upgrade` (the developer `~/.bun/bin/sov` install) now resolves workspace packages via a source checkout, repairing workspace source upgrades.

`sov drive` is unchanged. The new surface is additive.

## v0.6.54 — 2026-07-07

**Inject a one-turn system instruction over the gateway — for workflow/SOP steering that never touches session history — plus a first-class Linux ARM64 binary.**

- **Gateway: per-turn system instructions.** A posted turn can now carry an optional `instructions` field that becomes an **ephemeral** system directive for that turn only — augmented onto the session's system prompt, sent to the model, and never persisted in session history. Built for injecting a one-turn workflow/SOP directive without polluting the conversation. (Mirrors the per-turn `model` override from 0.6.53.)
- **New release target — `linux-arm64`.** The pipeline now ships a first-class `sov-linux-arm64.tar.gz` alongside darwin-arm64 / darwin-x64 / linux-x64, for aarch64 / Graviton Linux containers that previously needed ad-hoc cross-compiles.

Day-to-day `sov` CLI behavior is unchanged — the per-turn instruction channel is a gateway-API feature for embedders.

## v0.6.53 — 2026-07-07

**Gateway: switch models per turn within one session.** A posted turn can now carry an optional `model`, so one chat session can run a turn on Haiku and the next on Sonnet without starting a new gateway process. Additive and validated at the untrusted boundary — a turn with no `model` is byte-identical to before. Primarily a gateway-API feature for embedders; the standalone CLI is unaffected.

## v0.6.52 — 2026-07-07

**The model-router lane ships in a published binary — plus turn-log recorder fixes.** This is the first published build carrying the `manifest` model-router lane introduced in 0.6.51 (which was tagged but not published due to a release collision — see the 0.6.51 notes below for the full router-lane description). It also lands turn-log recorder fixes for SDK embedders:

- **One tool-call row per execution.** Wire block indexes restart per assistant message, which previously collapsed repeated tool executions into a single record; each execution is now recorded distinctly.
- **One thinking row per reasoning phase.** An agentic turn's reasoning was merging into one thinking unit (chronologically misleading, and at risk of the store's content cap on long turns); reasoning now finalizes at each non-thinking content boundary.
- **`flushOpen` — durably capture a stalled turn.** A new recorder method seals and flushes a turn that errored or never emitted `turn_complete`, marking those records `incomplete` with a reason — so a crashed or stalled turn isn't silently lost.

Day-to-day CLI behavior on existing providers is unchanged.

## v0.6.51 — 2026-07-06

**Stop picking models — give `sov` a model router.** This release adds a model-router provider lane: point `sov` at a self-hosted [Manifest](https://github.com/mnfst/manifest) instance, ask for model `auto`, and the router chooses the upstream per request — cost tiers, fallbacks, and spend limits are the router's job, not yours.

- **New provider: `manifest`.** `sov --provider manifest` (or `/config` → Providers → **Manifest (model router)**). Defaults: model `auto`, endpoint `http://localhost:2099/v1` (a loopback self-hosted Manifest), key via `MANIFEST_API_KEY`. Live-applied like the other lanes.
- **Generic by design.** The lane is an OpenAI-compatible router transport (`RouterProvider`, `@yevgetman/sov-sdk` 0.5.0) — nothing Manifest-specific is imported, so a different router later is just a `baseUrl` change. Routing hints ride ordinary HTTP headers (`providers.manifest.headers`): Manifest custom-tier headers, `x-session-key` for sticky sessions/prompt caching.
- **See what the router did.** SDK embedders get an opt-in `onRouteResolved` callback reporting the routed model/provider/tier per request (parsed from the router's response headers). Verified live end-to-end: an `auto` request routed to a real upstream with the route reported.
- **Honest limits (documented):** `/effort` is a no-op on this lane (the routed upstream is unknown); in-process cost estimates price the `auto` alias, so Manifest's own spend tracking is authoritative here. Recipe: `docs/04-extending/routing-an-agent.md` in the source repo.
- **For SDK embedders — turn-log recorder** (`createTurnLogRecorder`, new since 0.6.50): canonical full-content turn records over the live wire, handed per-turn to a pluggable sink (fail-open, zero dependencies) — including a fix for how turns are delimited on the real gateway stream.

Day-to-day behavior on your existing providers is unchanged — every existing lane is byte-identical; the router lane is opt-in.

## v0.6.50 — 2026-07-06

**Meter any `sov` agent's token usage into Assay — in real time, and without a single line of content ever leaving the process.**

This release adds the SDK's official token-accounting export, wiring `sov` to Assay — the token-audit and valuation tool — at the protocol level. Neither product imports the other; they agree on a span contract and a shared, byte-pinned conformance fixture tested independently in both repos ("protocol marriage, not code marriage").

- **New SDK export — `createAssayUsageRecorder`** (`@yevgetman/sov-sdk` 0.3.0): a zero-dependency recorder that converts the usage events the SDK already emits into standard OpenTelemetry `gen_ai` spans and streams them as OTLP/JSON to a local `assay serve`. One priced chat span per model call (carrying the dominant tool that call invoked), one span per tool run, one trace per turn (`sov.turn.id` → an Assay task).
- **Usage only — never content.** Token counts, model/tool identities, and timings leave the process; prompts, completions, and tool arguments never do. Even a misconfigured off-box endpoint could leak no text.
- **Real-time ROI.** Once wired, every Assay analytic — pricing, work-type classification, waste, per-turn task ROI, judge valuation — runs natively on live `sov` data.
- **Robust by contract.** Fire-and-forget transport: retry-once-then-drop, a bounded drop-oldest queue, and a recorder that never throws into your agent loop.

Day-to-day `sov` CLI behavior is unchanged — this is an opt-in export for SDK embedders.

## v0.6.49 — 2026-07-03

**Your token counts and costs are now accurate — and richer.**

Previously, a turn where the agent used tools (which makes several model calls under the hood) reported only the *last* model call's tokens and cost — so multi-step turns silently under-reported what they actually consumed. This release fixes that everywhere the numbers surface (live status, per-session cost records, session summaries) and upgrades what's reported:

- **Bug fix — full-turn totals.** Token counts and estimated cost now sum *every* model call in the turn, not just the final one. Expect numbers on tool-heavy turns to be larger than before — they were always this large; now they're reported honestly.
- **Bug fix — no more dropped fields.** Per-call usage records could lose input/cache token figures depending on how the provider streamed them; fields are now merged correctly.
- **Cache visibility.** The end-of-turn status now includes a prompt-cache hit rate, and the turn-complete event carries the full phase-broken usage (input / output / cache-write / cache-read) for API consumers.
- **For SDK embedders** (`@yevgetman/sov-sdk` 0.2.0): `RunResult` now returns the run's summed `usage` + `estimatedCostUsd`; the usage accumulator and the pricing table (`PRICE_TABLE`, `PRICING_VERSION`, `estimateCostUsd`) are public exports; a new informational `reasoningTokens` field breaks out reasoning tokens where providers report them; OpenAI-compatible providers now map cached and reasoning token details correctly.

## v0.6.48 — 2026-07-03

**The Sovereign AI Harness is now the Sovereign AI SDK.**

Repo-wide rename plus a deep internal hardening pass: an exhaustive security audit + remediation of the SDK core, dependency advisories cleared, and consumable packaging for the open-core `@yevgetman/sov-sdk` + `@yevgetman/sov-protocol` packages. Day-to-day `sov` behavior is unchanged; see the release notes for details.

## v0.6.47 — 2026-06-15

**The subscription-executor now actually gets used when you turn it on.**

Previously, enabling the subscription-executor only made it a *legal* delegation target — nothing nudged the model to pick it, so it would often just do the work itself (e.g. build a page inline) and never hand off to your `claude -p` subscription. This release adds a soft delegation bias: when `subscriptionExecutor.enabled` is on, the model is instructed to **prefer delegating substantive work** (writing/editing files, running commands, builds, multi-step tasks, research, debugging) to the headless `claude -p` subprocess, while still handling trivial conversation (greetings, clarifying questions, quick facts) directly.

- It's a *soft* bias — the model still judges each turn, but defaults to the shell when in doubt — not a forced dispatch of every message.
- Restart-to-apply, like the rest of the subscription-executor config. Turns off cleanly when the feature is off.
- No change to how delegation runs; this only changes how *often* the model chooses the shell. Personal/attended use only (unchanged ToS boundary — still off cron, channels, and the gateway).

## v0.6.46 — 2026-06-15

**Your conversations are now saved as readable per-session transcript files — and the subscription-executor shows up in the status bar when it's on.**

- **Session transcripts (on by default).** Every session now writes a human-readable JSONL transcript — one file per session — under your harness home: `~/.harness/projects/<your-project-path>/<session-id>.jsonl` (browsable, just like Claude Code's `~/.claude/projects/...`). It's appended as the conversation happens and includes the full messages (text, thinking, tool calls + results). Works across every surface: the TUI, the gateway, channels (Slack/Telegram/etc.), the OpenAI-compatible API, and post-compaction sessions. The conversation was always saved in the session database; this adds the portable, inspectable file form.
  - **Secrets are redacted by default** before writing (set `transcripts.redactSecrets: false` to opt out).
  - **Configure** via `/config` → **Transcripts** (or the `transcripts` block in config): `enabled` (default true), `dir` (default `~/.harness`), `redactSecrets` (default true).
  - The `harness_info` tool now reports where transcripts are being written.
- **"Debug mode" transcript settings fixed.** The old `debugMode.transcript` / `debugMode.transcriptDir` settings and the `--transcript` flag never actually wrote anything (leftover dead config). They're now retired and superseded by the always-on `transcripts` block above; `debugMode.transcriptDir` is still honored as a fallback for `transcripts.dir`.
- **Subscription-executor indicator.** When the opt-in subscription-executor is enabled, the TUI status line now shows a loud red **`⚠ SUB-EXEC`** chip — so you can always tell, while working, that delegated tasks may be routed to a headless `claude -p --dangerously-skip-permissions` subprocess. (Restart-to-apply, like the feature itself.)

Existing sessions and resume behavior are unchanged — the session database remains the source of truth; transcripts are an additional, always-on mirror.

**Hardening: an adversarial review of the new multi-agent workflows closed two data-race bugs in parallel write fan-out and made the headline parallelism reliable.**

A deep review of the workflow feature shipped in v0.6.44 found and fixed every confirmed correctness and safety issue. Nothing changes in how you author or run workflows — they're simply correct under more conditions now.

- **Parallel write fan-out no longer races.** Two fixes: tasks whose write scopes looked disjoint but could touch the same file (e.g. `writes: ['src/foo*']` vs `writes: ['src/foobar.ts']`, or paths differing only in letter case on macOS) are now correctly serialized; and the opt-in subscription-executor (headless Claude Code) now takes the whole-tree write lock so it can't clash with sibling tasks.
- **Wide fan-out runs every task.** A phase with more than 4 parallel tasks (e.g. a `map` over many findings) previously dropped the extras silently — they now all run, bounded to a sensible in-flight width.
- **A failing step degrades gracefully** instead of crashing the whole run when a later phase references the failed step's output.
- **Workflows are validated up front** — an unknown agent, an unknown cost lane, or a bad `{{reference}}` now fails fast with a clear message before any work starts, on every surface (CLI, `/workflow`, and the new tool).
- **The model can now trigger a workflow itself** via the `workflow_run` tool (it was CLI/slash-only).
- **`/workflow` now accepts quoted multi-word arguments** (e.g. `/workflow review diff="the broken parser"`).
- Smaller fixes: scoped tasks can use memory/skill tools again; a default list argument is parsed correctly; the loader tolerates an unreadable subdirectory; workflow runs feed the learning loop.

In-TUI workflow progress is still coming in a follow-up; the CLI shows live progress today.

No config changes required.

## v0.6.44 — 2026-06-15

**New: declarative multi-agent workflows — define a parallel fan-out plan once and run it, with write-capable steps now running in parallel.**

You can now define a **workflow** — a YAML plan that fans sub-agents out in parallel across a list or a set of dimensions, waits (barriers between phases), threads each phase's output into the next, and synthesizes a result — and run it deterministically. This is the structured counterpart to letting the model improvise delegation.

- **Author a workflow** as a YAML file under `workflows/` (in your project, your harness home, or the bundle): ordered **phases**, each a parallel set of tasks or a **map** that fans one task across a list; outputs thread forward with `{{phase.field}}` templating; each task can declare a **cost lane** and a **write scope**.
- **Run it** three ways: `sov workflow run <name> --arg k=v …` (and `sov workflow list` / `sov workflow show <name>`), or `/workflow <name> k=v …` inside a session.
- **Write-capable fan-out now runs in parallel.** Previously all file-writing sub-agents shared one global lock and ran one-at-a-time. A workflow task can declare which paths it writes (`writes: [...]`); tasks touching **disjoint** paths now run concurrently, while overlapping ones still serialize — so e.g. a parallel multi-file pass is genuinely parallel. The declared scope is also **enforced** (a task can't write outside it), so the parallelism is safe.
- A bundled example workflow (`review`) ships in the default bundle: `sov workflow show review`.

Everything is backward-compatible — existing sub-agent delegation behaves exactly as before. (The agent-invocable `workflow_run` tool and in-TUI workflow progress are coming in a follow-up; the CLI + `/workflow` are fully functional now.)

No config changes required.

## v0.6.43 — 2026-06-14

**`/config` now tells you — for every setting — whether your change took effect right away or needs a restart, and applies far more of them live.**

Editing settings in the live config menu (`/config` in a session, or `sov config`) used to be murky: some changes applied immediately, some quietly didn't until you restarted, and the badge could disagree with what actually happened. This release makes it unambiguous and applies many more settings on the spot.

- **Every save tells you exactly what happened, and names the setting.** You'll see one of: *"applied to this session"* (green — it's live now, including in your current conversation), *"restart sov to take effect"* (for the few settings captured at startup), or *"applies to the gateway/serve process"* (for settings that only a separate `sov gateway`/`sov serve` process uses). The row badge and the save message always agree.
- **Far more settings apply immediately** — to your *running* conversation, no restart: the **model** and **provider** (and API keys / endpoints / router lanes — the whole provider stack re-resolves between turns), **reasoning effort** (`/config` now matches `/effort` — previously editing it here did nothing), **task routing**, **permission mode** (with a loud indicator when you switch to `bypass`), **web search**, **learning/recall**, **compaction thresholds**, and the **UI appearance** flags.
- **A loud indicator when you enable `bypass`** permission mode, so auto-approve is never silently on.
- **More settings are reachable** in the menu (recall tuning, the `sov` local-engine provider, and several gateway fields that were previously only editable by hand), and partially-hidden config blocks now surface their stray fields.

No config changes required.

## v0.6.42 — 2026-06-14

**Security + correctness hardening: a second deep-dive bug hunt closed 46 issues, including a remotely-reachable command-execution hole on the chat-channel gateway.**

This release follows up the 2026-06-10 full-codebase audit with a focused second pass over the code that audit *changed* — because fixes can introduce bugs, and a few were incomplete. 46 issues were found and all fixed (1 critical, 10 high, 12 medium, 23 low). The ones that affect you:

- **Closed a channel-gateway remote command-execution hole (critical).** If you expose the `sov gateway` to inbound chat channels (Slack/Telegram/webhook/SMS), an untrusted sender could run a destructive shell command (e.g. a quoted `find … -delete` / `find … -exec …`) with **no permission prompt** — the read-only-command classifier was fooled by quoting the dangerous part. Now closed; local single-user use was never affected.
- **Tightened the web-fetch protections against internal-network access (SSRF).** Fetching a URL (the WebFetch tool and `@url` references) now blocks more private/cloud-metadata address forms (additional IPv6 private ranges, carrier-grade NAT, an IPv6 form that embeds a private IPv4), pins the connection to the address it validated, and bounds the DNS lookup by the request timeout.
- **Reasoning models (OpenAI o-series / GPT-5) now start correctly.** Pinning your default model to one of these no longer fails at startup — the request used a field those models reject.
- **Long-running gateways no longer crash-loop on restart.** A session-cleanup query could exceed a database limit once enough scheduled/channel sessions had accumulated; it's now bounded.
- **The learning loop keeps working as a project's history grows.** The observations file is now capped to a recent window, so background synthesis no longer silently stops once it crosses a size limit.
- **Terminal UI:** idle connections no longer spin in a tight reconnect loop; failed tool calls now show an error marker; reasoning wraps correctly on narrow terminals.
- **More secrets are masked** in `sov config show` (the Twilio Account SID and from-number now join the auth token), and several smaller correctness fixes across the OpenAI-compatible API, the local/frontier router, cron locking, and the web UI.

No config changes required.

## v0.6.41 — 2026-06-14

**Multi-user gateway fix: `/effort` is now per-session, so one user can no longer change another user's reasoning depth.**

- **`/effort` is scoped to your own session.** On a shared `sov gateway` with multiple users (principals), the reasoning-depth level you set with `/effort` was stored globally on the server — so one user's `/effort high` silently changed the depth for *every* other user, and for scheduled (cron) and channel (Slack/Telegram/webhook) turns too. It's now stored per session: your `/effort` affects only your own conversation, and cron/channel turns always use the operator's configured default. Single-user surfaces (the local TUI, `sov drive`, `sov serve`) were never affected. (Known limit: a session's effort returns to the configured default if the session is reclaimed after a long idle period or after a mid-turn compaction — just re-run `/effort` to restore it.)

No config changes required.

## v0.6.40 — 2026-06-11

**Two terminal-UI fixes: reasoning no longer lingers in your scrollback, and more file types get highlighted.**

- **Reasoning streams in place and then gets out of the way.** With `/effort` on, the model's thinking now streams live in a compact dim region just above the prompt and **disappears the moment the answer arrives** — it's no longer left permanently in your terminal history. You watch it think; once it answers (or the turn ends), only the answer remains. (v0.6.39 made reasoning readable but committed it to the transcript forever; this puts it where it belongs — ephemeral.)
- **More filenames get highlighted.** File references in the model's replies are colorized, but the matcher only knew a code-centric set of extensions — so a listing of your files lit up `.png`/`.md`/`.txt` while leaving `.pdf`, `.mov`, `.zip` and friends plain. It now recognizes the common document, image, audio/video, archive, and data extensions too, including multi-word names like `Vulcan — Deployed Agent Orchestrators.pdf`.

No config changes required.

## v0.6.39 — 2026-06-10

**Local-model reasoning, fixed end to end — readable thinking and direct answers on the `sov` lane.**

If you run a local model on the `sov` lane (e.g. Qwen3 via an MLX/vLLM server), two rough edges are gone:

- **Reasoning no longer renders as a broken vertical sliver.** Local engines stream reasoning one token at a time; the TUI was printing each token on its own line (1–3 words per line). Reasoning now buffers into one clean, word-wrapped block at the terminal width — the same as any other text. (Cloud models were never affected; they stream in larger chunks.)
- **The model no longer "reasons into the void" and exits without answering.** A small local model in thinking mode could spend its entire token budget reasoning and never produce an answer. `/effort off` is now a real off-switch (the `sov` lane defaults to **direct answers**, with reasoning opt-in via `/effort low|medium|high|max`) — previously the off-switch was a no-op because the model's chat template defaulted thinking *on*. And when thinking is off, the answer the engine returns on its reasoning channel is now surfaced as the actual response instead of dim "thinking" text.

Plus two small touches: a turn that hits the token limit now shows an actionable hint (try `/effort off`, or raise `maxTokens`), and a malformed tool call with no command renders `(no command)` instead of a blank line.

No config changes required.

## v0.6.38 — 2026-06-10

**Full-codebase security & robustness audit — 17 fixes across every subsystem, all confirmed Critical/High findings closed.**

- **Security.** Closed an unauthenticated remote-code-execution path on the channels gateway: the Bash "read-only" classifier (which the safe-by-default channel posture relies on) misclassified `env bash -c …`, `find -delete`/`-exec`, and commands smuggled after a newline or `&` as harmless, so an untrusted Slack/Telegram/webhook/SMS message could run shell unprompted. Also closed SSRF bypasses in WebFetch and the `@url` context reference (IPv4-mapped IPv6 + DNS-rebinding now blocked), config prototype-pollution via `/config set`, and a skill-args shell-injection path.
- **Secrets.** Stopped secrets reaching disk/logs in several places — the learning corpus, config display, replay fixtures, and escaped JSON auth headers are now redacted. Release tarballs no longer bundle captured session state (a prior leak of old releases was purged).
- **Multi-user.** `/clear` no longer locks a gateway user out of their own conversation; `/resume` and `/routing-stats --all` no longer list other users' sessions; `/review` ids are validated.
- **Reasoning depth.** With `/effort` on, tool-using turns on Claude 4.x no longer fail — the model's thinking signature is preserved across the tool round-trip. OpenAI reasoning models now send the right token field.
- **Automation.** Cron pre-agent scripts no longer block the server; cron-expression schedules run in your local timezone; `cron show/run/...` accept the short id prefixes that `cron list` prints; `sov mission run` and `sov eval run` work again.
- **Terminal UI.** A cancelled/errored turn no longer bleeds its partial text into the next one; tool output renders with real line breaks; failed tools show an error marker; a lost connection retries with backoff instead of spinning.

Plus many smaller correctness, lifecycle, and consistency fixes. No config changes required. Full report in the repo at `docs/audits/2026-06-10-full-codebase-audit.md`.

## v0.6.37 — 2026-06-09

**Dial how hard the model thinks with the new `/effort` command — named reasoning-depth levels, off by default.**

- **New `/effort` command.** Set per-session reasoning depth with `/effort off | low |
  medium | high | max`, or run `/effort` with no argument to pick from a menu;
  `/effort status` shows the current level. Higher effort gives the model a larger
  extended-thinking budget before it answers — the dial to reach for on hard problems.
- **Works across providers.** On Claude 4.x models (Haiku / Sonnet / Opus) the level maps
  to an extended-thinking token budget; on OpenAI reasoning models (o-series / gpt-5) it
  maps to `reasoning_effort`; on the local `sov` engine it turns thinking on. If the
  active model can't reason, `/effort` tells you and stays a no-op — it never sends a
  parameter the model would reject.
- **Pick a default.** A new `thinking.effort` setting (editable in `/config`) chooses the
  starting reasoning depth for new sessions.
- **Off by default — nothing changes unless you opt in.** At `off` (the default) every
  request is byte-for-byte identical to before, so there's no added cost or latency until
  you dial it up.

(ollama reasoning depth is planned for a later release — `/effort` is currently a no-op on ollama models.)

## v0.6.36 — 2026-06-09

**Run your local engine from `/config` — and see exactly which model you're using.**

- **The local Sovereign engine is a first-class choice in `/config`.** Pick `sov` as
  your provider (or as a task-routing lane) right from the config UI, and the model
  picker suggests the engine's installed model. Two ready-made task-routing presets —
  **`sov-cheap`** (basic atoms run local, escalate the rest to Claude) and
  **`sov-first`** (cheap + moderate local, only frontier to Claude) — let you go
  local-first with one `/config apply-preset`.
- **Models show their real names — no aliases.** The local engine now advertises models
  under their real id (e.g. `mlx-community/Qwen3-4B-4bit`) instead of a generic
  "sovereign" label, so the `/config` picker and your requests always say exactly what's
  running. (If you previously pinned `model: "sovereign"` for the `sov` lane, switch it
  to the real model id.)

If you don't use the local `sov` engine, nothing changes.

## v0.6.35 — 2026-06-09

**Install plugins — bundles of skills and slash-commands — behind a consent gate that keeps third-party code from running anything you didn't approve.**

- **Plugins are now a thing.** A plugin is one installable folder bundling **skills + slash-commands** (Claude-Code-compatible format). Manage them with `/plugins install <dir>`, `uninstall`, `enable`, `disable`, `list`, and `info`. They live under `~/.harness/plugins/` and load at startup (restart to apply).
- **Nothing loads without your consent.** Installing shows a plain-language **capability disclosure** (what skills/commands it adds, what it ships, anything flagged) and asks for an explicit `y/N`. A plugin contributes **nothing** until you've consented — and consent is bound to a content hash of the whole plugin: if the files change after you approved them, the plugin goes **inert** until you reinstall. Dropping a folder into the plugins directory by hand does nothing on its own.
- **Safe by default.** Plugin skills **cannot run shell commands** when they expand (unlike your own skills) — they're prompt/template only. Install is a **local-terminal-only** action, so a plugin can never be installed or consented remotely (via the gateway, web UI, or a channel). A plugin can override a bundled skill but can **never shadow your own** project/user skills, and built-in slash commands always win over a plugin's.
- **Honest Claude-Code compatibility.** Claude-Code-format **skill and command** packs install and work today. If a plugin also declares hooks, MCP servers, or sub-agents, those are **shown to you but not run** in this version (coming in a later release) — so you always know what a plugin *wants* even when the harness doesn't act on it yet.
- **Opt-in config.** A `plugins: { enabled, disabled }` block in your config gives you allow/deny control; by default a consented plugin is active.
- **Reliability fix under the hood.** The harness now reliably keeps its session database and config under the home directory you point it at — fixing a contention slowdown that could make the first turn time out on a busy machine.

If you don't install any plugins, nothing changes — `sov`, `sov serve`, `sov gateway`, and the TUI all behave exactly as before.

## v0.6.34 — 2026-06-09

**Run your own local inference engine as a first-class provider — and reasoning models no longer leak their thinking into the answer.**

- **New `sov` provider — a keyless local lane.** You can now point the harness at
  a local OpenAI-compatible inference server (the Sovereign L1 engine on
  `127.0.0.1:8000`) as a first-class provider — set `router.localProvider: "sov"`
  and/or a `providers.sov` block. No API key required (it's loopback), and `sov`
  is selectable anywhere a provider is. It defaults to the served model name
  `sovereign`. This is the harness side of running your own owned, private-local
  inference instead of a third-party API.
- **Reasoning is separated from the answer.** For models that stream a reasoning
  channel (`reasoning_content`), the harness now routes that into the `thinking`
  stream instead of mixing it into the reply text — cleaner answers, with the
  reasoning shown where thinking belongs. This also improves the existing
  `openai` / `openrouter` lanes, not just `sov`.

If you don't configure a `sov` provider, your normal `sov`, `sov serve`,
`sov drive`, and gateway usage is unchanged.

## v0.6.33 — 2026-06-08

**Fix: the response no longer loops forever after a turn completes.**

- **Infinite turn re-stream fixed.** After a turn finished, the TUI and `sov drive`
  reconnected to the event stream without a `Last-Event-ID`, so the server replayed
  the whole just-completed turn — including its completion event — which ended the
  stream again and triggered another reconnect, re-rendering the same assistant
  response over and over until you hit Ctrl-C. Both clients now send `Last-Event-ID`
  on reconnect (the standard SSE resume mechanism, which the web UI already used), so
  a post-turn reconnect resumes *after* the last event instead of re-fetching the
  turn. The server is unchanged.

Update with `sov upgrade`.

## v0.6.32 — 2026-06-08

**The subscription executor runs unattended-friendly by default; skills hardening.**

- **Subscription executor defaults to `--dangerously-skip-permissions`.** The opt-in
  headless Claude Code executor now defaults its `permissionMode` to `bypass`, because
  a headless `claude -p` has no interactive approver — under the old `plan` default any
  tool the subprocess needed permission for would auto-deny and stall, leaving the
  executor largely inert. With bypass it can actually do the delegated work. Set
  `permissionMode` to `plan` / `acceptEdits` / `default` for a constrained posture
  instead. This stays bounded to the attended, interactive-only delegation seam — it is
  NOT available to cron, channels, or the gateway (those keep their own bypass
  rejection), and the whole executor is still off by default.
- **Skills hardening.** A malformed skill `allowedTools` entry no longer crashes the
  `/skill` turn; an all-invalid `allowedTools` list now fails loud rather than
  fail-open; skill install-name extraction uses the real YAML parser; and the
  comma-list splitter is paren/bracket-depth aware.

If you don't enable the subscription executor, your normal usage is unchanged.

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
