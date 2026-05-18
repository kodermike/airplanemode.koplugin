#!/usr/bin/env sh
# run_tests.sh - runs the plugin test suite using busted and optionally luacov
set -e
ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
# prepend plugin paths so require can find modules
LUA_PATH="$ROOT_DIR/?.lua;$ROOT_DIR/modules/?.lua;;"
export LUA_PATH

HELPER="tests/luacov_helper.lua"

if command -v busted >/dev/null 2>&1; then
  echo "Running tests with busted..."
  if [ -f "$HELPER" ]; then
    busted --pattern "tests/" --verbose --helper "$HELPER"
  else
    busted --pattern "tests/" --verbose
  fi
else
  echo "busted not found. Install it with: luarocks install busted"
  exit 1
fi
