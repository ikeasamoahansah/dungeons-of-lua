#!/usr/bin/env bash
# BUILD-WEB ------------------------------------------------------------------------------------
# Packages the game into a .love file and compiles it into a static browser build
# (love.js compatibility build — works on itch.io, GitHub Pages, Netlify, etc.
# without Cross-Origin-Isolation headers).
#
# Usage:  ./build-web.sh [output-dir]     (default: web)
#
# Requires: zip, node/npm. love.js is fetched on the fly via `npx --yes love.js`.
set -euo pipefail
cd "$(dirname "$0")"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# 1) Zip the game exactly how LÖVE runs it: project root files + src/assets/libraries.
#    (screenshots, web/, and other non-game files stay out of the bundle)
zip -q -r "$WORK/game.love" main.lua conf.lua src assets libraries

OUT="${1:-web}"

# 2) Compile with love.js: `-t` sets the page title, `-c` picks the compatibility
#    build (no SharedArrayBuffer requirement — required for itch.io/GitHub Pages).
npx --yes love.js "$WORK/game.love" "$WORK/out" -t "Dungeons of Lua" -c

# 3) Publish into the output folder, PRESERVING a local custom index.html if one
#    already exists there (edit web/index.html freely; rebuilds won't clobber it).
mkdir -p "$OUT"
if [ -f "$OUT/index.html" ]; then
    cp -f "$WORK/out"/{game.data,game.js,love.js,love.wasm} "$OUT"/
else
    cp -r "$WORK/out"/. "$OUT"/
fi

echo "Web build written to $OUT/ — serve it with:  python3 -m http.server 8000 -d $OUT"
