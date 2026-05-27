-- spec_helper.lua
-- Test environment for AirPlaneMode plugin.
-- Sets up minimal mocks for KOReader modules and utilities so tests can run without a full KOReader checkout.

local plugin_root = "."
local tmp_dir = plugin_root .. "/tests/tmp"
-- ensure tmp dir exists
os.execute("mkdir -p " .. tmp_dir)

-- Make sure our modules are found
package.path = package.path .. ";" .. plugin_root .. "/?.lua;" .. plugin_root .. "/modules/?.lua;./?.lua"

-- Provide a minimal lfs attributes stub used by modules/helpers
local _lfs = {}
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
local Dispatcher = {
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
local UIManager = {
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
-- Minimal APMConfig
local APMConfig = {}
function APMConfig:init()
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
package.loaded["modules/APMConfig"] = APMConfig

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
package.loaded["modules/helpers"] = H

-- Utilities module (U) - simple in-memory settings storage
local U = {}
local storage = {}

local function key_path(key, file)
  return (file or "memory") .. ":" .. tostring(key)
end

function U:readAPMsetting(key, file)
  return storage[key_path(key, file)]
end
function U:saveAPMsetting(key, val, file)
  storage[key_path(key, file)] = val
end
function U:delAPMsetting(key, file)
  storage[key_path(key, file)] = nil
end
function U:APMhas(key, file)
  return U:readAPMsetting(key, file) ~= nil
end
function U:APMisTrue(key, file)
  return U:readAPMsetting(key, file) == true
end
function U:APMisFalse(key, file)
  return U:readAPMsetting(key, file) == false
end
function U:APMnilOrTrue(key, file)
  local v = U:readAPMsetting(key, file)
  return v == nil or v == true
end
function U:APMnilOrFalse(key, file)
  local v = U:readAPMsetting(key, file)
  return v == nil or v == false
end
function U:APMhasNot(key, file)
  return not U:APMhas(key, file)
end

function U:readAPMplugins(key, file)
  return U:readAPMsetting(key, file)
end
function U:saveAPMplugins(tbl, file)
  U:saveAPMsetting("plugins_disabled", tbl, file)
end

function U:backup(src, dst)
  local fh = io.open(dst, "w")
  if fh then
    fh:write("backup")
    fh:close()
    return true
  end
  return false
end

function U:toggleAirPlaneMode(val)
  U:saveAPMsetting("airplanemode", val, nil)
end
function U:getStatus()
  return U:readAPMsetting("airplanemode", nil)
end

function U:APMmakeTrue(key, file)
  U:saveAPMsetting(key, true, file)
end
function U:APMmakeFalse(key, file)
  U:saveAPMsetting(key, false, file)
end

package.loaded["modules/utilities"] = U

-- APMNetwork mock
local APMNetwork = {
  disableWifi = function(self)
    self._disabled = true
  end,
  reenableWifi = function(self)
    self._disabled = false
  end,
}
package.loaded["modules/APMNetwork"] = APMNetwork

-- PluginManager mock
local AirPlaneMode = {
  _disabled = {},
  disablePlugins = function(self, settings)
    self._disabled = true
  end,
  enableCalibre = function() end,
  restorePluginSettings = function() end,
}
package.loaded["modules/PluginManager"] = AirPlaneMode

-- FlightMenu mock
package.loaded["modules/FlightMenu"] = { init = function(_, _) end }

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

local M = {
  reset = function()
    -- reset in-memory state
    Dispatcher:reset()
    storage = {}
    package.loaded["modules/utilities"] = U
    -- restore lfs mock so tests that override it don't leak between tests
    package.loaded["libs/libkoreader-lfs"] = _lfs

    -- remove tmp dir unless tests request to keep it
    if not keep_tmp_dir() then
      os.execute('rm -rf "' .. tmp_dir .. '" 2>/dev/null || true')
    end

    -- recreate tmp dir for next test
    ensure_dir(tmp_dir)
  end,
  tmp_dir = tmp_dir,
  Dispatcher = Dispatcher,
  UIManager = UIManager,
  U = U,
}

return M
