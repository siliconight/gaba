#!/usr/bin/env bash
# Install gaba into the current Godot project.
#
# One-liner:
#   curl -fsSL https://raw.githubusercontent.com/siliconight/gaba/main/scripts/install.sh | bash
#
# Pin a version:
#   GABA_TAG=v0.4.0 curl -fsSL https://raw.githubusercontent.com/siliconight/gaba/main/scripts/install.sh | bash
#
# Local invocation:
#   bash install.sh [PROJECT_DIR] [TAG]
#
# Exits 0 on success, non-zero on any error.

set -euo pipefail

PROJECT_DIR="${1:-${GABA_PROJECT_DIR:-.}}"
TAG="${2:-${GABA_TAG:-main}}"

# Resolve to absolute so error messages are unambiguous.
PROJECT_DIR="$(cd "$PROJECT_DIR" 2>/dev/null && pwd || echo "$PROJECT_DIR")"

if [[ ! -f "$PROJECT_DIR/project.godot" ]]; then
	echo "gaba install: no project.godot found in '$PROJECT_DIR'." >&2
	echo "Run this from your Godot project root, or pass the project path as the first argument:" >&2
	echo "  bash install.sh /path/to/godot/project" >&2
	exit 1
fi

ADDON_DIR="$PROJECT_DIR/addons/gaba"
if [[ -d "$ADDON_DIR" ]]; then
	echo "gaba install: '$ADDON_DIR' already exists." >&2
	echo "Remove it first if you want to reinstall:  rm -rf '$ADDON_DIR'" >&2
	exit 1
fi

mkdir -p "$PROJECT_DIR/addons"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# GitHub's /archive/<ref>.tar.gz handles both branch names and tag names.
TARBALL_URL="https://github.com/siliconight/gaba/archive/$TAG.tar.gz"
TARBALL_PATH="$TMP_DIR/gaba.tar.gz"

echo "gaba install: downloading $TAG..."
if command -v curl >/dev/null 2>&1; then
	curl -fsSL "$TARBALL_URL" -o "$TARBALL_PATH"
elif command -v wget >/dev/null 2>&1; then
	wget -q "$TARBALL_URL" -O "$TARBALL_PATH"
else
	echo "gaba install: need curl or wget to download." >&2
	exit 1
fi

tar -xzf "$TARBALL_PATH" -C "$TMP_DIR"

# GitHub names the extracted directory gaba-<ref>. Find it without guessing.
EXTRACTED="$(find "$TMP_DIR" -maxdepth 1 -type d -name 'gaba-*' | head -n 1)"
if [[ -z "$EXTRACTED" || ! -d "$EXTRACTED/addons/gaba" ]]; then
	echo "gaba install: extracted archive doesn't contain addons/gaba — check the tag '$TAG'." >&2
	exit 1
fi

cp -R "$EXTRACTED/addons/gaba" "$ADDON_DIR"

echo "gaba install: copied to $ADDON_DIR"
echo ""
echo "Next steps:"
echo "  1. Open your project in Godot 4."
echo "  2. Project → Project Settings → Plugins → enable 'Gaba'."
echo "  3. Look for the 'Gaba' tab in the right-side editor docks."
