#!/usr/bin/env sh
# run_tests.sh - runs the plugin test suite using busted and optionally luacov
set -e
ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
# prepend plugin paths so require can find modules
LUA_PATH="$ROOT_DIR/?.lua;$ROOT_DIR/modules/?.lua;;"
export LUA_PATH

red=$(tput setaf 1)
yellow=$(tput setaf 3)
green=$(tput setaf 2)
reset=$(tput sgr0)

HELPER="tests/luacov_helper.lua"

if command -v busted >/dev/null 2>&1; then
  printf "%10s\n" "${yellow}Running tests with busted...${reset}"
  if [ -f "$HELPER" ]; then
    CMD="busted --verbose --helper ${HELPER}"
  else
    CMD="busted --verbose"
  fi
  for x in $(ls tests/*.lua); do
    echo ""
    printf "%10s\n" "${green}----------------------------------------------------------${reset}"
    printf "%10s\n" "${green}${x}${reset}"
    echo ""
    $CMD $x
  done
  $CMD tests/
else
  echo "busted not found. Install it with: luarocks install busted"
  exit 1
fi
