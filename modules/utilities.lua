local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")
local airplanemode_config = DataStorage:getDataDir() .. "/settings/airplanemode.lua"

local Utilities = {}

function Utilities.savePlugins(self, plugin_list)
  local apm_settings = LuaSettings:open(airplanemode_config)
  apm_settings:saveSetting("disabled_plugins", plugin_list)
  apm_settings:flush()
  apm_settings:close()
end

function Utilities.readPlugins(self)
  local apm_settings = LuaSettings:open(airplanemode_config)
  local disabled_plugins = apm_settings:readSetting("disabled_plugins") or {}
  apm_settings:close()
  return disabled_plugins
end

return Utilities
