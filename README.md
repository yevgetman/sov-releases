# Sovereign AI Harness — Binary Releases

This repository distributes compiled binaries of the **Sovereign AI Harness**
(`sov`) for personal evaluation and testing.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/yevgetman/sov-releases/main/install.sh | bash
```

This script:

1. Detects your platform (`darwin-arm64`, `darwin-x64`, or `linux-x64`).
2. Downloads the latest release tarball and verifies its SHA256 checksum.
3. Installs to `~/.sov/` (no `sudo` required).
4. Appends `~/.sov/bin` to your shell's `PATH` (zsh / bash auto-detected).

Re-run the same command anytime to upgrade.

## What you get

- `sov` — the Sovereign AI agent runtime CLI
- `sov-tui` — the bundled Bubble Tea TUI binary
- `bundle-default/` — the default agent bundle (skills, agents, prompts)

## Supported platforms (day-one)

| Platform | Status |
|---|---|
| macOS Apple Silicon (`darwin-arm64`) | Primary |
| macOS Intel (`darwin-x64`) | Supported |
| Linux x86_64 (`linux-x64`) | Supported |
| Windows | Not supported (Unix-isms in the runtime) |
| Linux ARM64 | Not supported (request via email) |

## macOS first-run

Unsigned binaries downloaded via `curl` get quarantined by Gatekeeper.
First run may show "macOS cannot verify the developer." Dismiss permanently
with:

```bash
xattr -d com.apple.quarantine ~/.sov/bin/sov ~/.sov/bin/sov-tui
```

(A future release will be signed + notarized; this step won't be needed.)

## Upgrade

```bash
sov upgrade
```

`sov upgrade` auto-detects the binary install and re-runs this installer.
Idempotent.

## License

Beta evaluation license — see [`LICENSE.txt`](LICENSE.txt). NOT open
source. Source code is not distributed.

## Support

This is a personal beta. For issues or feedback, contact
**yevgetman@gmail.com**.
