-- spec_helper.lua
-- Test environment for AirPlaneMode plugin.
-- Sets up minimal mocks for KOReader modules and utilities so tests can run without a full KOReader checkout.

local plugin_root = "."
local tmp_dir = plugin_root .. "/tests/tmp"
-- ensure tmp dir exists
os.execute("mkdir -p " .. tmp_dir)

-- Decide whether to use a real KOReader checkout or the local mocks.
local KOREADER_HOME = os.getenv("KOREADER_HOME")
local FORCE_PLUGIN_MOCKS = os.getenv("FORCE_PLUGIN_MOCKS")
local use_koreader = false
if KOREADER_HOME and type(KOREADER_HOME) == "string" and (not FORCE_PLUGIN_MOCKS or FORCE_PLUGIN_MOCKS == "0") then
  -- simple directory existence check
  local p = io.popen('if [ -d "' .. KOREADER_HOME .. '" ]; then echo yes; fi')
  if p then
    local res = p:read("*a") or ""
    p:close()
    if string.find(res, "yes") then
      use_koreader = true
    end
  end
end

-- Configure package.path depending on whether we use KOReader or local plugin paths
if use_koreader then
  package.path = package.path
    .. ";"
    .. KOREADER_HOME
    .. "/?.lua;"
    .. KOREADER_HOME
    .. "/libs/?.lua;"
    .. KOREADER_HOME
    .. "/engine/?.lua;"
    .. KOREADER_HOME
    .. "/frontend/?.lua;"
    .. KOREADER_HOME
    .. "/base/?.lua;"
    .. KOREADER_HOME
    .. "/plugins/?.lua;"
  -- provide a lightweight 'bit' compatibility shim if the environment lacks it
  local ok, _ = pcall(require, "bit")
  if not ok then
    local function touint32(x)
      return x % 2 ^ 32
    end
    local bit = {}
    function bit.rshift(a, b)
      return math.floor(touint32(a) / 2 ^ b)
    end
    function bit.lshift(a, b)
      return touint32(touint32(a) * 2 ^ b)
    end
    function bit.band(a, b)
      local res = 0
      for i = 0, 31 do
        local bit_a = (math.floor(a / 2 ^ i) % 2)
        local bit_b = (math.floor(b / 2 ^ i) % 2)
        if bit_a == 1 and bit_b == 1 then
          res = res + 2 ^ i
        end
      end
      return res
    end
    function bit.bor(a, b)
      local res = 0
      for i = 0, 31 do
        local bit_a = (math.floor(a / 2 ^ i) % 2)
        local bit_b = (math.floor(b / 2 ^ i) % 2)
        if bit_a == 1 or bit_b == 1 then
          res = res + 2 ^ i
        end
      end
      return res
    end
    function bit.bxor(a, b)
      local res = 0
      for i = 0, 31 do
        local bit_a = (math.floor(a / 2 ^ i) % 2)
        local bit_b = (math.floor(b / 2 ^ i) % 2)
        if (bit_a + bit_b) % 2 == 1 then
          res = res + 2 ^ i
        end
      end
      return res
    end
    function bit.bnot(a)
      return touint32(0xFFFFFFFF - touint32(a))
    end
    package.loaded["bit"] = bit
  end

  -- Ensure settings dir exists so file operations succeed under KOReader mode
  os.execute("mkdir -p " .. tmp_dir .. "/settings")

  -- Provide a small shim for ffi.loadlib when the emulator's ffi lacks it.
  if package.loaded["ffi"] and type(package.loaded["ffi"]) == "table" and type(package.loaded["ffi"].loadlib) ~= "function" then
    package.loaded["ffi"].loadlib = function(_)
      return {}
    end
  end

  -- Minimal hybrid mocks: when running against a full KOReader checkout we still provide small
  -- plugin-scoped mocks for modules the tests expect to be deterministic.
  local function ensure_mock(name, tbl)
    if not package.loaded[name] then
      package.loaded[name] = tbl
    end
  end

  -- datastorage: make KOReader read/write use our tmp dir so tests don't touch real settings
  ensure_mock("datastorage", {
    getDataDir = function()
      return tmp_dir
    end,
    getSettingsDir = function()
      return tmp_dir .. "/settings"
    end,
    getFullDataDir = function()
      return tmp_dir
    end,
  })

  -- Minimal dispatcher spy
  ensure_mock("dispatcher", {
    _actions = {},
    registerAction = function(self, name, tbl)
      self._actions[name] = tbl
    end,
    reset = function(self)
      self._actions = {}
    end,
  })

  -- Minimal UIManager mock
  ensure_mock("ui/uimanager", {
    shown = {},
    last_broadcast = nil,
    show = function(self, what)
      table.insert(self.shown, what)
    end,
    restartKOReader = function() end,
    askForRestart = function(...) end,
    quit = function() end,
    broadcastEvent = function(self, ev)
      self.last_broadcast = ev
    end,
    unschedule = function(...) end,
  })

  -- Device mock
  ensure_mock("device", {
    isEmulator = function()
      return false
    end,
    canRestart = function()
      return true
    end,
    canOpenLink = function()
      return false
    end,
    openLink = function() end,
  })

  -- ConfirmBox / InfoMessage stubs
  ensure_mock("ui/widget/confirmbox", {
    new = function(opts)
      return opts
    end,
  })
  ensure_mock("ui/widget/infomessage", {
    new = function(opts)
      return opts
    end,
  })
  ensure_mock("ui/event", {
    new = function(tbl)
      return tbl
    end,
  })

  -- ensure ffi/util is present
  ensure_mock("ffi/util", {
    template = function(s, ...)
      return s
    end,
  })

  -- Stub common FFI/native modules that are not needed by the plugin tests
  local ffi_stubs = {
    "ffi/mupdf",
    "ffi/blitbuffer",
    "ffi/freetype",
    "ffi/posix_h",
    "ffi/harfbuzz",
    "ffi/harfbuzz_h",
    "ffi/harfbuzz_coverage",
    "ffi/harfbuzz_shaper",
    "ffi/harfbuzz_buffer",
    "ffi/harfbuzz_other",
  }
  for _, name in ipairs(ffi_stubs) do
    ensure_mock(name, {})
  end

  ensure_mock("libs/libkoreader-xtext", { setDefaultParaDirection = function() end, setDefaultLang = function() end })
  -- Provide a lightweight libkoreader-lfs mock if the emulator-provided one isn't present
  if not package.loaded["libs/libkoreader-lfs"] then
    local _lfs = {}
    _lfs._curdir = tmp_dir
    _lfs.attributes = function(path, mode)
      if not path then
        return nil
      end
      if type(path) ~= "string" then
        return nil
      end
      local quote = function(s)
        return s:gsub('"', '\\"')
      end
      local cmd = string.format('if [ -d "%s" ]; then echo DIR; elif [ -f "%s" ]; then echo FILE; fi', quote(path), quote(path))
      local p = io.popen(cmd)
      if not p then
        return nil
      end
      local res = p:read("*a") or ""
      p:close()
      if string.find(res, "DIR") then
        if mode == "mode" then
          return "directory"
        else
          return { mode = "directory" }
        end
      elseif string.find(res, "FILE") then
        if mode == "mode" then
          return "file"
        else
          return { mode = "file" }
        end
      end
      if string.sub(path, -1) == "/" then
        if mode == "mode" then
          return "directory"
        else
          return { mode = "directory" }
        end
      end
      return nil
    end
    _lfs.currentdir = function()
      return _lfs._curdir
    end
    _lfs.chdir = function(path)
      if type(path) ~= "string" then
        return nil
      end
      if path == "." then
        return true
      end
      local attr = _lfs.attributes(path)
      if attr and ((type(attr) == "string" and attr == "directory") or (type(attr) == "table" and attr.mode == "directory")) then
        _lfs._curdir = path
        return true
      end
      if string.sub(path, -1) == "/" then
        _lfs._curdir = path
        return true
      end
      return false
    end
    ensure_mock("libs/libkoreader-lfs", _lfs)
  end
  -- stub ui/font to avoid depending on global KOReader initialisation
  ensure_mock("ui/font", {})

  -- minimal util implementation (gsplit used by bidi.lua)
  ensure_mock("util", {
    gsplit = function(s, sep, plain, include_sep)
      -- return an iterator yielding segments and optionally separators
      return coroutine.wrap(function()
        if not s or s == "" then
          return
        end
        if sep == "" then
          for i = 1, #s do
            coroutine.yield(string.sub(s, i, i))
          end
          return
        end
        local last = 1
        while true do
          local a, b = string.find(s, sep, last, plain)
          if not a then
            coroutine.yield(string.sub(s, last))
            break
          end
          coroutine.yield(string.sub(s, last, a - 1))
          if include_sep then
            coroutine.yield(string.sub(s, a, b))
          end
          last = b + 1
        end
      end)
    end,
  })
else
  -- Make sure our modules are found (plugin-local paths)
  package.path = package.path .. ";" .. plugin_root .. "/?.lua;" .. plugin_root .. "/utils/?.lua;./?.lua"
end

-- If not using a real KOReader checkout, set up local mocks for required modules
local _lfs, bidi, Dispatcher, UIManager, U, storage
if not use_koreader then
  -- Provide a minimal lfs attributes stub used by utils/flight_helpers
  _lfs = {}
  _lfs._curdir = tmp_dir

  _lfs.attributes = function(path, mode)
    if not path then
      return nil
    end
    if type(path) ~= "string" then
      return nil
    end
    -- Prefer shell checks for file/directory detection since io.open may
    -- behave inconsistently for directories. Using 'test -d'/'test -f'
    -- works across environments the tests run in.
    local quote = function(s)
      return s:gsub('"', '\\"')
    end
    local cmd = string.format('if [ -d "%s" ]; then echo DIR; elif [ -f "%s" ]; then echo FILE; fi', quote(path), quote(path))
    local p = io.popen(cmd)
    if not p then
      return nil
    end
    local res = p:read("*a") or ""
    p:close()
    if string.find(res, "DIR") then
      if mode == "mode" then
        return "directory"
      else
        return { mode = "directory" }
      end
    elseif string.find(res, "FILE") then
      if mode == "mode" then
        return "file"
      else
        return { mode = "file" }
      end
    end
    -- fallback: treat paths ending with '/' as directory
    if string.sub(path, -1) == "/" then
      if mode == "mode" then
        return "directory"
      else
        return { mode = "directory" }
      end
    end
    return nil
  end

  _lfs.currentdir = function()
    return _lfs._curdir
  end

  _lfs.chdir = function(path)
    if type(path) ~= "string" then
      return nil
    end
    -- treat '.' as success
    if path == "." then
      return true
    end
    -- if attributes says directory, accept
    local attr = _lfs.attributes(path)
    if attr and ((type(attr) == "string" and attr == "directory") or (type(attr) == "table" and attr.mode == "directory")) then
      _lfs._curdir = path
      return true
    end
    -- accept paths that end with '/'
    if string.sub(path, -1) == "/" then
      _lfs._curdir = path
      return true
    end
    return false
  end

  package.loaded["libs/libkoreader-lfs"] = _lfs

  -- Simple bidi mock
  local bidi = {
    ltr = function(...) end,
    rtl = function(...) end,
  }
  package.loaded["ui/bidi"] = bidi

  -- Simple logger mock
  local logger = {
    dbg = function(...) end,
    info = function(...) end,
    err = function(...) end,
  }
  package.loaded["logger"] = logger

  -- gettext stub (KOReader uses gettext as function)
  package.loaded["gettext"] = function(s)
    return s
  end

  -- Event and UI widget stubs
  package.loaded["ui/event"] = {
    new = function(tbl)
      return tbl
    end,
  }
  package.loaded["ui/widget/confirmbox"] = {
    new = function(opts)
      return opts
    end,
  }
  package.loaded["ui/widget/infomessage"] = {
    new = function(opts)
      return opts
    end,
  }

  -- Dispatcher spy
  Dispatcher = {
    _actions = {},
    registerAction = function(self, name, tbl)
      self._actions[name] = tbl
    end,
    reset = function(self)
      self._actions = {}
    end,
  }
  package.loaded["dispatcher"] = Dispatcher

  -- UIManager mock
  UIManager = {
    shown = {},
    last_broadcast = nil,
    show = function(self, what)
      table.insert(self.shown, what)
    end,
    restartKOReader = function() end,
    askForRestart = function(...) end,
    quit = function() end,
    broadcastEvent = function(self, ev)
      self.last_broadcast = ev
    end,
    unschedule = function(...) end,
  }
  package.loaded["ui/uimanager"] = UIManager

  -- Network manager mock
  local NetworkMgr = {
    getNetworkInterfaceName = function()
      return "wlan0"
    end,
  }
  package.loaded["ui/network/manager"] = NetworkMgr

  -- Device mock
  local Device = {
    isEmulator = function()
      return false
    end,
    canRestart = function()
      return true
    end,
  }
  package.loaded["device"] = Device

  -- ffi util template stub
  package.loaded["ffi/util"] = {
    template = function(s, ...)
      return s
    end,
  }

  -- Minimal WidgetContainer base so :extend works
  local WidgetContainer = {
    extend = function(self, t)
      local cls = t or {}
      cls._super = self
      function cls:new(o)
        o = o or {}
        setmetatable(o, { __index = cls })
        return o
      end
      return cls
    end,
  }
  package.loaded["ui/widget/container/widgetcontainer"] = WidgetContainer
  -- Minimal FlightConfig
  local FlightConfig = {}
  function FlightConfig:init()
    local s = {
      airplanemode = tmp_dir .. "/airplanemode.lua",
      airplanemode_old = tmp_dir .. "/airplanemode.lua.old",
      prev_config = tmp_dir .. "/prev_config.lua",
      koreader = tmp_dir .. "/koreader_config.lua",
      koreader_plugins = "plugins_disabled",
      backup = tmp_dir .. "/backup.lua",
      version = "0.0-test",
      icon_on = "[ON]",
      icon_off = "[OFF]",
    }
    return s
  end
  package.loaded["flight_config"] = FlightConfig

  -- helpers module
  local H = {
    isFile = function(path)
      local f = io.open(path, "r")
      if f then
        f:close()
        return true
      end
      return false
    end,
    removeFile = function(path)
      os.remove(path)
    end,
  }
  package.loaded["utils/flight_helpers"] = H

  -- Utilities module (U) - simple in-memory settings storage
  U = {}
  storage = {}

  local function key_path(key, file)
    return (file or "memory") .. ":" .. tostring(key)
  end

  function U:readFlightsetting(key, file)
    return storage[key_path(key, file)]
  end
  function U:saveFlightsetting(key, val, file)
    storage[key_path(key, file)] = val
  end
  function U:delFlightsetting(key, file)
    storage[key_path(key, file)] = nil
  end
  function U:Flighthas(key, file)
    return U:readFlightsetting(key, file) ~= nil
  end
  function U:FlightisTrue(key, file)
    return U:readFlightsetting(key, file) == true
  end
  function U:FlightisFalse(key, file)
    return U:readFlightsetting(key, file) == false
  end
  function U:FlightnilOrTrue(key, file)
    local v = U:readFlightsetting(key, file)
    return v == nil or v == true
  end
  function U:FlightnilOrFalse(key, file)
    local v = U:readFlightsetting(key, file)
    return v == nil or v == false
  end
  function U:FlighthasNot(key, file)
    return not U:Flighthas(key, file)
  end

  function U:readFlightplugins(key, file)
    return U:readFlightsetting(key, file)
  end
  function U:saveFlightplugins(tbl, file)
    U:saveFlightsetting("plugins_disabled", tbl, file)
  end

  function U:backupFlight(src, dst)
    local fh = io.open(dst, "w")
    if fh then
      fh:write("backup")
      fh:close()
      return true
    end
    return false
  end

  function U:toggleAirPlaneMode(val)
    U:saveFlightsetting("airplanemode", val, nil)
  end
  function U:getStatus()
    return U:readFlightsetting("airplanemode", nil)
  end

  function U:FlightmakeTrue(key, file)
    U:saveFlightsetting(key, true, file)
  end
  function U:FlightmakeFalse(key, file)
    U:saveFlightsetting(key, false, file)
  end

  package.loaded["utils/flight_utilities"] = U

  -- FlightNetwork mock
  local FlightNetwork = {
    disableWifi = function(self)
      self._disabled = true
    end,
    reenableWifi = function(self)
      self._disabled = false
    end,
  }
  package.loaded["flight_net"] = FlightNetwork

  -- PluginManager mock
  local AirPlaneMode = {
    _disabled = {},
    disablePlugins = function(self, settings)
      self._disabled = true
    end,
    enableCalibre = function() end,
    restorePluginSettings = function() end,
  }
  package.loaded["flight_plugins"] = AirPlaneMode

  -- FlightMenu mock
  package.loaded["flight_menu"] = { init = function(_, _) end }
end

-- expose a small helper to reset mocked state between tests
local function keep_tmp_dir()
  -- first check environment variable
  local env = os.getenv("KEEP_TEST_TMP")
  if env ~= nil then
    env = tostring(env):lower()
    return not (env == "" or env == "0" or env == "false" or env == "no")
  end
  -- then check a Lua global if set
  if _G and _G.KEEP_TEST_TMP ~= nil then
    local v = _G.KEEP_TEST_TMP
    if type(v) == "boolean" then
      return v
    end
    v = tostring(v):lower()
    return not (v == "" or v == "0" or v == "false" or v == "no")
  end
  return false
end

local function rm_rf_inside(dir)
  -- remove everything inside dir but keep dir itself
  -- safe POSIX removal; redirect errors to /dev/null
  local cmd = string.format('rm -rf "%s"/* "%s"/.[!.]* "%s"/..?* 2>/dev/null || true', dir, dir, dir)
  os.execute(cmd)
end

local function ensure_dir(dir)
  os.execute("mkdir -p " .. dir)
end

-- Build a helper object that's usable in both mock and real-KOReader modes
local function safe_require(name)
  local ok, mod = pcall(require, name)
  if ok then
    return mod
  end
  return package.loaded[name]
end

local function reset_helper_state()
  -- helper reset behavior: if running with mocks, do a thorough reset;
  -- otherwise attempt a best-effort shallow reset on KOReader-provided modules.
  if not use_koreader then
    -- reset in-memory state
    if Dispatcher and Dispatcher.reset then
      Dispatcher:reset()
    end
    storage = {}
    package.loaded["utils/flight_utilities"] = U
    -- restore lfs mock so tests that override it don't leak between tests
    package.loaded["libs/libkoreader-lfs"] = _lfs

    -- remove tmp dir unless tests request to keep it
    if not keep_tmp_dir() then
      os.execute('rm -rf "' .. tmp_dir .. '" 2>/dev/null || true')
    end

    -- recreate tmp dir for next test
    ensure_dir(tmp_dir)
  else
    -- best-effort no-op or light cleanup when using real KOReader checkout
    local disp = package.loaded["dispatcher"]
    if type(disp) == "table" and type(disp.reset) == "function" then
      pcall(function()
        disp:reset()
      end)
    end
  end
end

local M = {
  reset = reset_helper_state,
  tmp_dir = tmp_dir,
  Dispatcher = package.loaded["dispatcher"] or safe_require("dispatcher"),
  UIManager = package.loaded["ui/uimanager"] or safe_require("ui/uimanager"),
  U = package.loaded["utils/flight_utilities"] or safe_require("utils/flight_utilities"),
}

return M
