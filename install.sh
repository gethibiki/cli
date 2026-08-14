#!/bin/sh
# Hibiki — standalone CLI installer.
#
# Detects the host OS + architecture, downloads the matching `hibiki` binary
# from the latest GitHub Release, verifies it against the published checksum,
# and places it on PATH.
#
# Usage:
#   curl -fsSL https://cli.gethibiki.com | sh
#   curl -fsSL https://cli.gethibiki.com | sh -s -- --version v0.1.0
#   curl -fsSL https://cli.gethibiki.com | sh -s -- --dir ~/.local/bin
#
# Supported targets: linux-x64, linux-arm64, darwin-x64, darwin-arm64.
# The binaries are bun-compiled single files — no Node, no npm, no extraction.
# Default install path is /usr/local/bin/hibiki (with sudo fallback if it
# isn't writable); pass --dir to override.

set -eu

REPO="gethibiki/cli"
BIN_NAME="hibiki"
VERSION=""
INSTALL_DIR=""

# ---- arg parsing -----------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --version)
      VERSION="${2:-}"
      shift 2 || { echo "missing value for --version" >&2; exit 2; }
      ;;
    --version=*)
      VERSION="${1#--version=}"
      shift
      ;;
    --dir)
      INSTALL_DIR="${2:-}"
      shift 2 || { echo "missing value for --dir" >&2; exit 2; }
      ;;
    --dir=*)
      INSTALL_DIR="${1#--dir=}"
      shift
      ;;
    -h|--help)
      cat <<'HELP'
Usage: curl -fsSL https://cli.gethibiki.com | sh [-s -- [options]]

Options:
  --version <tag>   install a specific release (e.g. v0.1.0). Default: latest
  --dir <path>      install dir (default: /usr/local/bin)
  -h, --help        show this help
HELP
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      exit 2
      ;;
  esac
done

# ---- platform detection ----------------------------------------------------
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

case "$OS" in
  linux)  TARGET_OS="linux" ;;
  darwin) TARGET_OS="darwin" ;;
  *) echo "unsupported OS: $OS (linux or macOS only)" >&2; exit 1 ;;
esac

case "$ARCH" in
  x86_64|amd64)  TARGET_ARCH="x64" ;;
  arm64|aarch64) TARGET_ARCH="arm64" ;;
  *) echo "unsupported arch: $ARCH (x86_64 or arm64 only)" >&2; exit 1 ;;
esac

ASSET="${BIN_NAME}-${TARGET_OS}-${TARGET_ARCH}"

# ---- resolve release tag ---------------------------------------------------
if [ -z "$VERSION" ]; then
  # GitHub redirects /releases/latest to /releases/tag/<latest>; capture the
  # resolved URL and take the tag off the end. Works without a token.
  if ! VERSION="$(
    curl -fsSL -o /dev/null -w '%{url_effective}' \
      "https://github.com/${REPO}/releases/latest" \
      | sed -E 's|.*/tag/(.+)$|\1|'
  )"; then
    echo "could not resolve latest release. Pass --version <tag> explicitly." >&2
    exit 1
  fi
fi

URL="https://github.com/${REPO}/releases/download/${VERSION}/${ASSET}"

# ---- install dir -----------------------------------------------------------
if [ -z "$INSTALL_DIR" ]; then
  INSTALL_DIR="/usr/local/bin"
fi

# Elevated privileges are needed if the dir isn't writable. Tested up front so
# we can say so clearly instead of failing halfway through on the mv.
NEEDS_SUDO=0
if [ ! -w "$INSTALL_DIR" ]; then
  if ! mkdir -p "$INSTALL_DIR" 2>/dev/null; then
    NEEDS_SUDO=1
  elif [ ! -w "$INSTALL_DIR" ]; then
    NEEDS_SUDO=1
  fi
fi

if [ "$NEEDS_SUDO" = "1" ]; then
  if ! command -v sudo >/dev/null 2>&1; then
    echo "$INSTALL_DIR is not writable and sudo is unavailable." >&2
    echo "Pass --dir <writable-path> to install elsewhere (e.g. ~/.local/bin)." >&2
    exit 1
  fi
fi

# ---- download + install ----------------------------------------------------
echo "==> Hibiki CLI installer"
echo "  target:  ${TARGET_OS}-${TARGET_ARCH}"
echo "  version: ${VERSION}"
echo "  source:  ${URL}"
echo "  dest:    ${INSTALL_DIR}/${BIN_NAME}"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

if ! curl -fsSL "$URL" -o "$TMPDIR/$BIN_NAME"; then
  echo "download failed. Check the release exists at:" >&2
  echo "  https://github.com/${REPO}/releases/tag/${VERSION}" >&2
  exit 1
fi

# ---- verify checksum -------------------------------------------------------
# Releases publish SHA256SUMS alongside the binaries. Verify before trusting
# the file:
#   - SHA256SUMS missing, asset unlisted, or no sha256 tool: warn + continue.
#   - MISMATCH: fail hard. Never install a binary that doesn't match.
# macOS has no `sha256sum`; fall back to `shasum -a 256`.
SUMS_URL="https://github.com/${REPO}/releases/download/${VERSION}/SHA256SUMS"
if curl -fsSL "$SUMS_URL" -o "$TMPDIR/SHA256SUMS" 2>/dev/null; then
  expected="$(awk -v a="$ASSET" '$2 == a { print $1 }' "$TMPDIR/SHA256SUMS")"
  if [ -z "$expected" ]; then
    echo "warning: $ASSET not listed in SHA256SUMS; skipping verification." >&2
  else
    actual=""
    if command -v sha256sum >/dev/null 2>&1; then
      actual="$(sha256sum "$TMPDIR/$BIN_NAME" | cut -d' ' -f1)"
    elif command -v shasum >/dev/null 2>&1; then
      actual="$(shasum -a 256 "$TMPDIR/$BIN_NAME" | cut -d' ' -f1)"
    else
      echo "warning: no sha256 tool (sha256sum/shasum) found; skipping verification." >&2
    fi
    if [ -n "$actual" ]; then
      if [ "$actual" = "$expected" ]; then
        echo "  checksum: verified (sha256)"
      else
        echo "checksum MISMATCH for $ASSET" >&2
        echo "  expected: $expected" >&2
        echo "  actual:   $actual" >&2
        echo "Refusing to install a binary that doesn't match the published checksum." >&2
        exit 1
      fi
    fi
  fi
else
  echo "warning: SHA256SUMS not found for ${VERSION}; skipping checksum verification." >&2
fi

chmod +x "$TMPDIR/$BIN_NAME"

if [ "$NEEDS_SUDO" = "1" ]; then
  echo "  (elevating with sudo to write to $INSTALL_DIR)"
  sudo mkdir -p "$INSTALL_DIR"
  sudo mv "$TMPDIR/$BIN_NAME" "$INSTALL_DIR/$BIN_NAME"
else
  mkdir -p "$INSTALL_DIR"
  mv "$TMPDIR/$BIN_NAME" "$INSTALL_DIR/$BIN_NAME"
fi

echo
echo "✓ installed $BIN_NAME to $INSTALL_DIR/$BIN_NAME"
echo

# On PATH? If not, say how to fix it rather than leaving a binary nobody can run.
if ! command -v "$BIN_NAME" >/dev/null 2>&1; then
  echo "Note: $INSTALL_DIR is not on your PATH."
  echo "      Add it (or move $INSTALL_DIR/$BIN_NAME somewhere that is):"
  echo "      export PATH=\"$INSTALL_DIR:\$PATH\""
  echo
fi

# No prompting, and nothing run on the user's behalf. `hibiki login` reads a
# secret from the terminal, and driving an interactive prompt through a
# curl-to-sh pipe is how installers end up hanging in raw mode with no way to
# Ctrl-C out. The next step is one line; the operator can type it.
echo "Next:"
echo "  $BIN_NAME login          # paste an API key from Settings → API Keys"
echo "  $BIN_NAME brand use <id> # pin a brand to this directory"
echo "  $BIN_NAME draft \"...\"    # ask the agent for a post"
