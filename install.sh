#!/usr/bin/env bash
# Sovereign AI Harness — public installer
# Phase 21 M1 — re-runnable; idempotent; atomic install/upgrade.

set -euo pipefail

OWNER="yevgetman"
REPO="sov-releases"
INSTALL_ROOT="${HOME}/.sov"
INSTALL_TMP="${HOME}/.sov.tmp.$$"

die() { printf 'sov-install: %s\n' "$1" >&2; exit 1; }
note() { printf 'sov-install: %s\n' "$1"; }

# ---------- detect platform ----------
detect_target() {
  local uname_s uname_m
  uname_s="$(uname -s)"
  uname_m="$(uname -m)"
  case "${uname_s}-${uname_m}" in
    Darwin-arm64)  echo "darwin-arm64" ;;
    Darwin-x86_64) echo "darwin-x64" ;;
    Linux-x86_64)  echo "linux-x64" ;;
    *)
      die "unsupported platform: ${uname_s} ${uname_m}. Supported: darwin-arm64, darwin-x64, linux-x64."
      ;;
  esac
}
TARGET="$(detect_target)"
note "platform: ${TARGET}"

# ---------- discover latest release ----------
note "querying latest release..."
LATEST_JSON="$(curl -fsSL "https://api.github.com/repos/${OWNER}/${REPO}/releases/latest")"
TAG="$(echo "${LATEST_JSON}" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n1)"
[ -z "${TAG}" ] && die "could not parse latest release tag from GitHub API"
note "latest tag: ${TAG}"

ASSET_URL="https://github.com/${OWNER}/${REPO}/releases/download/${TAG}/sov-${TARGET}.tar.gz"
SUMS_URL="https://github.com/${OWNER}/${REPO}/releases/download/${TAG}/SHA256SUMS"

# ---------- download tarball + checksum ----------
TMPDIR="$(mktemp -d)"
trap "rm -rf '${TMPDIR}'" EXIT
TARBALL="${TMPDIR}/sov-${TARGET}.tar.gz"
SUMS="${TMPDIR}/SHA256SUMS"

note "downloading tarball..."
curl -fL --output-dir "${TMPDIR}" -O "${ASSET_URL}"

note "downloading checksums..."
curl -fsSL -o "${SUMS}" "${SUMS_URL}"

# ---------- verify checksum ----------
EXPECTED="$(grep "sov-${TARGET}.tar.gz" "${SUMS}" | awk '{print $1}')"
[ -z "${EXPECTED}" ] && die "no checksum line for sov-${TARGET}.tar.gz in SHA256SUMS"

if command -v sha256sum >/dev/null 2>&1; then
  ACTUAL="$(sha256sum "${TARBALL}" | awk '{print $1}')"
else
  # macOS ships shasum, not sha256sum
  ACTUAL="$(shasum -a 256 "${TARBALL}" | awk '{print $1}')"
fi

[ "${EXPECTED}" != "${ACTUAL}" ] && die "checksum mismatch — expected ${EXPECTED}, got ${ACTUAL}"
note "checksum ok"

# ---------- extract atomically ----------
note "extracting to ${INSTALL_ROOT}..."
rm -rf "${INSTALL_TMP}"
mkdir -p "${INSTALL_TMP}"
tar -xzf "${TARBALL}" -C "${INSTALL_TMP}"

if [ -d "${INSTALL_ROOT}" ]; then
  BACKUP="${INSTALL_ROOT}.bak.$(date +%s)"
  note "backing up previous install to ${BACKUP}"
  mv "${INSTALL_ROOT}" "${BACKUP}"
fi
mv "${INSTALL_TMP}" "${INSTALL_ROOT}"

# ---------- mark executables ----------
chmod +x "${INSTALL_ROOT}/bin/sov" "${INSTALL_ROOT}/bin/sov-tui"

# ---------- write version marker ----------
echo "${TAG}" > "${INSTALL_ROOT}/version"

# ---------- PATH append (idempotent) ----------
PATH_LINE='export PATH="$HOME/.sov/bin:$PATH"'
case "$(basename "${SHELL:-}")" in
  zsh)  RC="${HOME}/.zshrc" ;;
  bash) RC="${HOME}/.bashrc" ;;
  *)    RC="" ;;
esac

if [ -n "${RC}" ]; then
  if [ -f "${RC}" ] && grep -Fq "${PATH_LINE}" "${RC}"; then
    note "PATH already set in ${RC}"
  else
    echo "" >> "${RC}"
    echo "# Added by sov installer ($(date -u +%FT%TZ))" >> "${RC}"
    echo "${PATH_LINE}" >> "${RC}"
    note "appended PATH to ${RC} — open a new shell or run: source ${RC}"
  fi
else
  note "unknown shell ($SHELL) — add this to your shell rc manually:"
  printf '  %s\n' "${PATH_LINE}"
fi

# ---------- macOS quarantine note ----------
if [ "${TARGET#darwin-}" != "${TARGET}" ]; then
  note "macOS note: first run may show 'macOS cannot verify the developer.'"
  note "to dismiss permanently:"
  printf '  xattr -d com.apple.quarantine %s/bin/sov %s/bin/sov-tui\n' "${INSTALL_ROOT}" "${INSTALL_ROOT}"
fi

# ---------- done ----------
note "installed ${TAG} to ${INSTALL_ROOT}"
note "run: sov --version"
