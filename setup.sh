#!/bin/sh
# Install a verified Tarn release into the runner tool cache and put it on PATH.
# Mirrors tools/release/install.sh in tarn-lng/tarn: HTTPS only, SHA-256 checked
# against the release's SHA256SUMS, regular files only, version confirmed.
# Inputs (environment): TARN_VERSION ("latest" or X.Y.Z), GITHUB_TOKEN (optional,
# only for resolving "latest"), RUNNER_TOOL_CACHE, RUNNER_TEMP, GITHUB_PATH,
# GITHUB_OUTPUT.
set -eu
fail() { echo "::error::$1" >&2; exit 1; }
[ "$(uname -s)" = Linux ] || fail 'Tarn supports Linux runners only'
case "$(uname -m)" in
  x86_64) ARCH=x86_64 ;;
  aarch64|arm64) ARCH=aarch64 ;;
  *) fail "Tarn supports x86_64 and ARM64 (aarch64) runners, not $(uname -m)" ;;
esac
for tool in curl sha256sum tar; do command -v "$tool" >/dev/null || fail "missing tool: $tool"; done
VERSION=${TARN_VERSION:-latest}
VERSION=${VERSION#v}
if [ "$VERSION" = latest ]; then
  # Every Tarn release is a prerelease, which "releases/latest" skips; the
  # list is newest first.
  AUTH=
  [ -n "${GITHUB_TOKEN:-}" ] && AUTH="Authorization: Bearer $GITHUB_TOKEN"
  VERSION=$(curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 --retry 3 \
    -H 'Accept: application/vnd.github+json' ${AUTH:+-H "$AUTH"} \
    'https://api.github.com/repos/tarn-lng/tarn/releases?per_page=1' |
    sed -n 's/.*"tag_name": *"v\([0-9][0-9.]*\)".*/\1/p' | head -n 1)
  [ -n "$VERSION" ] || fail 'cannot determine the newest Tarn release; set version: X.Y.Z'
fi
case "$VERSION" in ''|*[!0-9.]*|.*|*..*|*.) fail "use a numeric X.Y.Z version, not '$VERSION'" ;; esac
DEST="${RUNNER_TOOL_CACHE:?}/tarn/$VERSION/$ARCH"
if [ -x "$DEST/tarn" ] && [ "$("$DEST/tarn" version)" = "tarn $VERSION" ]; then
  echo "Tarn $VERSION found in the tool cache"
else
  TEMP=$(mktemp -d "${RUNNER_TEMP:-/tmp}/setup-tarn.XXXXXX")
  trap 'rm -rf "$TEMP"' EXIT HUP INT TERM
  ASSET="tarn-$VERSION-linux-$ARCH.tar.gz"
  BASE="https://github.com/tarn-lng/tarn/releases/download/v$VERSION"
  for file in "$ASSET" SHA256SUMS; do
    curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' --tlsv1.2 --retry 3 \
      "$BASE/$file" -o "$TEMP/$file" || fail "cannot download $file for Tarn $VERSION"
  done
  awk -v asset="$ASSET" '$2 == asset {print; count++} END {if (count != 1) exit 1}' "$TEMP/SHA256SUMS" > "$TEMP/selected" ||
    fail "SHA256SUMS has no single entry for $ASSET"
  (cd "$TEMP"; sha256sum --check --strict --status selected) || fail "checksum mismatch for $ASSET"
  # Exactly the four core files plus lib/tarn/<name> helpers, all regular files.
  CORE=$(tar -tzf "$TEMP/$ASSET" | grep -v '^lib/tarn/' | LC_ALL=C sort | tr '\n' ' ')
  [ "$CORE" = "COPYING README.md tarn tarn-lsp " ] || fail 'unexpected release archive contents'
  for helper in $(tar -tzf "$TEMP/$ASSET" | grep '^lib/tarn/' || true); do
    case "${helper#lib/tarn/}" in ''|*[!a-zA-Z0-9-]*) fail "unexpected helper path: $helper" ;; esac
  done
  tar -tvzf "$TEMP/$ASSET" | awk 'substr($1,1,1)!="-" {bad=1} END {exit bad}' || fail 'archive contains non-regular files'
  mkdir "$TEMP/extracted"
  tar -xzf "$TEMP/$ASSET" --no-same-owner --no-same-permissions -C "$TEMP/extracted"
  chmod 755 "$TEMP/extracted/tarn" "$TEMP/extracted/tarn-lsp"
  [ "$("$TEMP/extracted/tarn" version)" = "tarn $VERSION" ] || fail 'compiler version mismatch'
  rm -rf "$DEST"
  mkdir -p "$(dirname "$DEST")"
  mv "$TEMP/extracted" "$DEST"
  echo "Installed Tarn $VERSION ($ARCH)"
fi
echo "$DEST" >> "${GITHUB_PATH:?}"
{
  echo "version=$VERSION"
  echo "path=$DEST"
} >> "${GITHUB_OUTPUT:?}"
