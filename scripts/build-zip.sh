#!/usr/bin/env bash
# Builds uploadable archives of the plugin into dist/.
#
# The docs do not state whether claude.ai wants .claude-plugin/ at the archive
# root or nested inside one folder, so both are produced. Try -root.zip first.
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1
ROOT=$(pwd)
PLUGIN=plugins/resolved-markets
NAME=resolved-markets

rm -rf dist && mkdir -p dist

# A: .claude-plugin/ at the archive root
( cd "$PLUGIN" && zip -qr "$ROOT/dist/${NAME}-root.zip" . -x '.DS_Store' -x '__MACOSX/*' )

# B: nested under a single top-level folder
tmp=$(mktemp -d)
cp -R "$PLUGIN" "$tmp/$NAME"
( cd "$tmp" && zip -qr "$ROOT/dist/${NAME}-nested.zip" "$NAME" -x '.DS_Store' -x '__MACOSX/*' )
rm -rf "$tmp"

echo "Built:"
ls -lh dist/*.zip | awk '{print "  " $9 "  " $5}'
echo
echo "Test locally:  claude --plugin-dir ./dist/${NAME}-root.zip"
