-- spec_helper.lua
-- Test environment for AirPlaneMode plugin.
-- Sets up minimal mocks for KOReader modules and utilities so tests can run without a full KOReader checkout.

local plugin_root = ".."
local tmp_dir = plugin_root .. "/tests/tmp"
-- ensure tmp dir exists
os.execute("mkdir -p " .. tmp_dir)

-- Make sure our modules are found
package.path = package.path .. ";" .. plugin_root .. "/?.lua;" .. plugin_root .. "/modules/?.lua;./?.lua"

-- Provide a minimal lfs attributes stub used by modules/helpers
package.loaded["libs/libkoreader-lfs"] = {
  attributes = function(path, mode)
    if not path then
      return nil
    end
    -- check for file
    local fh = io.open(path, "r")
    if fh then
      fh:close()
      if mode == "mode" then
        return "file"
      else
        return { mode = "file" }
      end
    end
    -- if path ends with '/' treat as directory
    if string.sub(path, -1) == "/" then
      if mode == "mode" then
        return "directory"
      else
        return { mode = "directory" }
      end
    end
    return nil
  end,
}

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
local M = {
  reset = function()
    Dispatcher:reset()
    storage = {}
    package.loaded["modules/utilities"] = U
  end,
  tmp_dir = tmp_dir,
  Dispatcher = Dispatcher,
  UIManager = UIManager,
  U = U,
}

return M
