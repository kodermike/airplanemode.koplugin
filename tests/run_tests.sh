#!/usr/bin/env sh
# run_tests.sh - runs the plugin test suite using busted and optionally luacov
set -e

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

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
# prepend plugin paths so require can find modules
LUA_PATH="$ROOT_DIR/?.lua;$ROOT_DIR/utils/?.lua;;"

# If KOREADER_HOME is provided and is a directory, prefer the emulator's LuaJIT but keep plugin mocks
# We deliberately DO NOT add KOReader paths to LUA_PATH here: tests will run against plugin-local mocks
# while using the emulator's luajit binary when available.
if [ -n "$KOREADER_HOME" ] && [ -d "$KOREADER_HOME" ]; then
  printf "%10s\n" "${yellow}KOReader checkout found at: $KOREADER_HOME (running tests with plugin mocks)${reset}"
  # Prefer the emulator-provided luajit if present
  EMU_GLOB="${KOREADER_HOME}/koreader-emulator-*-pc-linux-gnu-debug/koreader"
  for d in $EMU_GLOB; do
    if [ -d "$d" ]; then
      EMU_DIR="$d"
      break
    fi
  done
  if [ -n "$EMU_DIR" ] && [ -x "$EMU_DIR/luajit" ]; then
    LUAJIT_BIN="$EMU_DIR/luajit"
    printf "%10s\n" "${yellow}Using emulator LuaJIT at: $LUAJIT_BIN${reset}"
    # force plugin-local mocks even when KOREADER_HOME exists
    export FORCE_PLUGIN_MOCKS=1
    # Add emulator libs to LD_LIBRARY_PATH so native libs are discoverable by this interpreter
    if [ -d "$KOREADER_HOME/base/build/x86_64-pc-linux-gnu-debug/libs" ]; then
      LD_LIBRARY_PATH="$KOREADER_HOME/base/build/x86_64-pc-linux-gnu-debug/libs:${LD_LIBRARY_PATH:-}"
      export LD_LIBRARY_PATH
      # make compiled modules discoverable for package.cpath when running under the emulator luajit
      LUA_CPATH="$KOREADER_HOME/base/build/x86_64-pc-linux-gnu-debug/?.so;${LUA_CPATH:-}"
      # Also include system LuaRocks/busted paths so we can use busted under the emulator luajit
      LUA_CPATH="/usr/lib/lua/5.1/?.so;/usr/local/lib/lua/5.1/?.so;/usr/lib/lua/5.5/?.so;/usr/local/lib/lua/5.5/?.so;"$LUA_CPATH
      export LUA_CPATH
      # Expose common system Lua paths so busted modules are found under the emulator luajit
      LUA_PATH="/usr/share/lua/5.1/?.lua;/usr/share/lua/5.1/?/init.lua;/usr/local/share/lua/5.1/?.lua;/usr/local/share/lua/5.1/?/init.lua;"$LUA_PATH
      export LUA_PATH
    fi
  elif [ -x "/bin/luajit" ]; then
    LUAJIT_BIN=/bin/luajit
    printf "%10s\n" "${red}Using system LuaJIT at: $LUAJIT_BIN${reset}"
  else
    LUAJIT_BIN=""
  fi
fi

export LUA_PATH

# tmp dir for tests
TMP_DIR="$ROOT_DIR/tests/tmp"
mkdir -p "$TMP_DIR"

cleanup() {
  # if [ -z "$KEEP_TEST_TMP" ]; then
    if [ -d "$TMP_DIR" ]; then
      rm -rf "$TMP_DIR" 2>/dev/null || true
    fi
  # fi
}
trap cleanup EXIT

HELPER="tests/luacov_helper.lua"

VERBOSITY="$1"

# Prefer running busted under LuaJIT if available (KOReader needs LuaJIT ffi)
if [ -x "$LUAJIT_BIN" ]; then
  # check that busted is available as a Lua module under this luajit
  if $LUAJIT_BIN -e "local ok=pcall(require,'busted.runner'); if not ok then os.exit(2) end" 2>/dev/null; then
    printf "%10s\n" "${yellow}Running tests with busted (via luajit at $LUAJIT_BIN)...${reset}"
    if [ -f "$HELPER" ]; then
      # Use luajit to run the installed busted script so it executes under LuaJIT's runtime
      BUSTED_SCRIPT="/usr/lib/luarocks/rocks-5.1/busted/2.3.0-1/bin/busted"
      if [ -x "$BUSTED_SCRIPT" ]; then
        if [ -z "$VERBOSITY" ]; then
          $LUAJIT_BIN "$BUSTED_SCRIPT" --verbose --helper "$HELPER" tests/
        else
          for x in tests/*.lua; do
            if [ ! -e "$x" ]; then break; fi
            printf "%10s\n" "${green}----------------------------------------------------------${reset}"
            printf "%10s\n" "${green}${x}${reset}"
            $LUAJIT_BIN "$BUSTED_SCRIPT" --verbose --helper "$HELPER" "$x"
            echo ""
          done
        fi
        exit 0
      fi
    else
      BUSTED_SCRIPT="/usr/lib/luarocks/rocks-5.1/busted/2.3.0-1/bin/busted"
      if [ -x "$BUSTED_SCRIPT" ]; then
        if [ -z "$VERBOSITY" ]; then
          $LUAJIT_BIN "$BUSTED_SCRIPT" --verbose tests/
        else
          for x in tests/*.lua; do
            if [ ! -e "$x" ]; then break; fi
            printf "%10s\n" "${green}----------------------------------------------------------${reset}"
            printf "%10s\n" "${green}${x}${reset}"
            $LUAJIT_BIN "$BUSTED_SCRIPT" --verbose "$x"
            echo ""
          done
        fi
        exit 0
      fi
    fi
  fi
fi

# Fallback to system 'busted' executable
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
  echo "busted not found for LuaJIT or system Lua. Install busted for LuaJIT or system Lua: luarocks install busted"
  exit 1
fi
