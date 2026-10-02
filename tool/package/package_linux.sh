#!/usr/bin/env bash
#
# Build and package the Linux release bundle.
#
# Produces (in dist/):
#   compositor-<version>-linux-<arch>.tar.gz     always
#   compositor-<version>-linux-<arch>.AppImage   when appimagetool is available
#
# Usage:
#   tool/package/package_linux.sh [--skip-build]
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT_DIR"

SKIP_BUILD=0
for arg in "$@"; do
  case "$arg" in
    --skip-build) SKIP_BUILD=1 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

VERSION="$(sed -n 's/^version: *\([0-9][^+ ]*\).*/\1/p' pubspec.yaml | head -n1)"
if [ -z "$VERSION" ]; then
  echo "could not read version from pubspec.yaml" >&2
  exit 1
fi

ARCH="$(uname -m)"
DIST="$ROOT_DIR/dist"
STAGE="$ROOT_DIR/build/package"
NAME="compositor-${VERSION}-linux-${ARCH}"

BUNDLE="$(find build/linux -maxdepth 4 -type d -path '*/release/bundle' 2>/dev/null | head -n1)"
if [ "$SKIP_BUILD" -eq 0 ]; then
  echo "==> flutter build linux --release"
  flutter build linux --release
  BUNDLE="$(find build/linux -maxdepth 4 -type d -path '*/release/bundle' 2>/dev/null | head -n1)"
fi
if [ -z "$BUNDLE" ] || [ ! -d "$BUNDLE" ]; then
  echo "release bundle not found; run without --skip-build" >&2
  exit 1
fi

rm -rf "$STAGE" "$DIST"
mkdir -p "$STAGE" "$DIST"

# --- tar.gz -----------------------------------------------------------------
echo "==> tar.gz"
TAR_ROOT="$STAGE/$NAME"
mkdir -p "$TAR_ROOT"
cp -a "$BUNDLE/." "$TAR_ROOT/"
tar -czf "$DIST/$NAME.tar.gz" -C "$STAGE" "$NAME"

# --- AppImage ---------------------------------------------------------------
APPIMAGETOOL="${APPIMAGETOOL:-$(command -v appimagetool || true)}"
if [ -z "$APPIMAGETOOL" ]; then
  echo "==> appimagetool not found; skipping AppImage (set APPIMAGETOOL=/path/to/appimagetool)"
else
  echo "==> AppImage"
  APPDIR="$STAGE/AppDir"
  rm -rf "$APPDIR"
  mkdir -p "$APPDIR"
  cp -a "$BUNDLE/." "$APPDIR/"
  cp "$SCRIPT_DIR/compositor.svg" "$APPDIR/compositor.svg"
  cat > "$APPDIR/compositor.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Compositor
Comment=Layer-based image editor
Exec=compositor %F
Icon=compositor
Categories=Graphics;2DGraphics;RasterGraphics;
MimeType=application/x-compositor-project;
Terminal=false
EOF
  cat > "$APPDIR/AppRun" <<'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/compositor" "$@"
EOF
  chmod +x "$APPDIR/AppRun"
  ARCH="$ARCH" "$APPIMAGETOOL" --no-appstream \
    "$APPDIR" "$DIST/$NAME.AppImage"
fi

echo
echo "Artifacts in $DIST:"
ls -lh "$DIST"
