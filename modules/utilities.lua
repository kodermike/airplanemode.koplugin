local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")
local logger = require("logger")

local airplanemode_config = DataStorage:getDataDir() .. "/settings/airplanemode.lua"

local Utilities = {}

function Utilities:saveAPMplugins(plugin_list)
  if not plugin_list or not type(plugin_list) == "table" then
    logger.err("AIRPLANEMODE: plugin_list is not a table, cannot save")
    return
  end
  local apm_settings = LuaSettings:open(airplanemode_config)
  apm_settings:saveSetting("disabled_plugins", plugin_list)
  apm_settings:flush()
  apm_settings:close()
end

function Utilities:readAPMplugins()
  local apm_settings = LuaSettings:open(airplanemode_config)
  local disabled_plugins = apm_settings:readSetting("disabled_plugins") or {}
  apm_settings:close()
  return disabled_plugins
end

function Utilities:readAPMsetting(object)
  if not object then
    logger.err("AIRPLANEMODE: readAPMsetting - object sent is nil, cannot read")
    return
  end
  local apm_settings = LuaSettings:open(airplanemode_config)
  local setting = apm_settings:readSetting(object)
  apm_settings:close()
  return setting
end

function Utilities:saveAPMsetting(object, value)
  if not object then
    logger.err("AIRPLANEMODE: saveAPMsetting - object sent is nil, cannot save")
    return
  end
  if not value then
    logger.err("AIRPLANEMODE: saveAPMsetting - value sent is nil, cannot save")
    return
  end
  local apm_settings = LuaSettings:open(airplanemode_config)
  if apm_settings:saveSetting(object, value) then
    apm_settings:flush()
    apm_settings:close()
  else
    apm_settings:close()
    return false
  end
end

function Utilities:APMtoggle(object)
  if not object then
    logger.err("AIRPLANEMODE: APMtoggle - object sent is nil, cannot toggle")
    return
  end

  local apm_settings = LuaSettings:open(airplanemode_config)
  local response = apm_settings:toggle(object)
  apm_settings:close()
  return response
end

function Utilities:APMisTrue(object)
  if not object then
    logger.err("AIRPLANEMODE: APMisTrue - object sent is nil, cannot check")
    return
  end
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

function Utilities:APMmakeTrue(object)
  if not object then
    logger.err("AIRPLANEMODE: APMmakeTrue - object sent is nil, cannot make true")
    return
  end
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

function Utilities:APMnilOrFalse(object)
  if not object then
    logger.err("AIRPLANEMODE: APMyoggle - object sent is nil, cannot toggle")
    return
  end
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

function Utilities:APMnilOrTrue(object)
  if not object then
    logger.err("AIRPLANEMODE: APMyoggle - object sent is nil, cannot toggle")
    return
  end
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

return Utilities
