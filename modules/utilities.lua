local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")
local airplanemode_config = DataStorage:getDataDir() .. "/settings/airplanemode.lua"

local Utilities = {}

function Utilities.saveAPMPlugins(self, plugin_list)
  local apm_settings = LuaSettings:open(airplanemode_config)
  apm_settings:saveSetting("disabled_plugins", plugin_list)
  apm_settings:flush()
  apm_settings:close()
end

function Utilities.readAPMPlugins(self)
  local apm_settings = LuaSettings:open(airplanemode_config)
  local disabled_plugins = apm_settings:readSetting("disabled_plugins") or {}
  apm_settings:close()
  return disabled_plugins
end

function Utilities:readAPMSetting(self, object)
  local apm_settings = LuaSettings:open(airplanemode_config)
  local setting = apm_settings:readSetting(object)
  apm_setting:close()
  return setting
end

function Utilities.saveAPMPlugins(self, object, value)
  local apm_settings = LuaSettings:open(airplanemode_config)
  if apm_settings:saveSetting(object, value) then
    apm_settings:flush()
    apm_settings:close()
  else
    apm_settings:close()
    return false
  end
end

function Utilities:APMtoggle(self, object)
  local apm_settings = LuaSettings:open(airplanemode_config)
  if apm_settings:toggle(object) then
    apm_settings:flush()
    apm_settings:close()
    return
  else
    apm_settings:flush()
    apm_settings:close()
    return false
  end
end

function Utilities:APMisTrue(self, object)
  local apm_settings = LuaSettings:open(airplanemode_config)
  if apm_settings:isTrue(object) then
    apm_settings:flush()
    apm_settings:close()
    return true
  else
    apm_settings:flush()
    apm_settings:close()
    return false
  end
end

function Utilities:APMmakeTrue(self, object)
  local apm_settings = LuaSettings:open(airplanemode_config)
  if apm_settings:makeTrue(object) then
    apm_settings:flush()
    apm_settings:close()
    return
  else
    apm_settings:flush()
    apm_settings:close()
    return false
  end
end

function Utilities:APMnilOrFalse(self, object)
  local apm_settings = LuaSettings:open(airplanemode_config)
  if apm_settings:nilOrFalse(object) then
    apm_settings:flush()
    apm_settings:close()
    return
  else
    apm_settings:flush()
    apm_settings:close()
    return false
  end
end

function Utilities:APMnilOrTrue(self, object)
  local apm_settings = LuaSettings:open(airplanemode_config)
  if apm_settings:nilOrTrue(object) then
    apm_settings:flush()
    apm_settings:close()
    return
  else
    apm_settings:flush()
    apm_settings:close()
    return false
  end
end

--[[
TODO:
- nilOrFalse

]]

return Utilities
