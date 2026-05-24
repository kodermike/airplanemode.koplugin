#!/usr/bin/env sh
# run_tests.sh - runs the plugin test suite using busted and optionally luacov
set -e

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
# prepend plugin paths so require can find modules
LUA_PATH="$ROOT_DIR/?.lua;$ROOT_DIR/modules/?.lua;;"
export LUA_PATH

# tmp dir for tests
TMP_DIR="$ROOT_DIR/tests/tmp"
mkdir -p "$TMP_DIR"

cleanup() {
  if [ -z "$KEEP_TEST_TMP" ]; then
    rm -rf "$TMP_DIR" 2>/dev/null || true
  fi
}
trap cleanup EXIT

if [ -t 1 ]; then
  red=$(tput setaf 1)
  yellow=$(tput setaf 3)
  green=$(tput setaf 2)
  reset=$(tput sgr0)
else
  red=""
  yellow=""
  green=""
  reset=""
fi

HELPER="tests/luacov_helper.lua"

VERBOSITY="$1"

if command -v busted >/dev/null 2>&1; then
  printf "%10s\n" "${yellow}Running tests with busted...${reset}"
  if [ -f "$HELPER" ]; then
    CMD="busted --verbose --helper ${HELPER}"
  else
    CMD="busted --verbose"
  fi
  if [ -z "$VERBOSITY" ]; then
    $CMD tests/
  else
    for x in tests/*.lua; do
      if [ ! -e "$x" ]; then break; fi
      printf "%10s\n" "${green}----------------------------------------------------------${reset}"
      printf "%10s\n" "${green}${x}${reset}"
      $CMD $x
      echo ""
    done
  fi
else
  echo "busted not found. Install it with: luarocks install busted"
  exit 1
fi
