local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")
local logger = require("logger")

local APMConfig = require("modules/APMConfig")
local settings = APMConfig:init()

local Utilities = {}

function Utilities.saveAPMplugins(self, plugin_list)
  if not plugin_list or not type(plugin_list) == "table" then
    logger.err("AIRPLANEMODE: plugin_list is not a table, cannot save")
    return
  end
  local config = LuaSettings:open(settings.airplanemode)
  config:saveSetting("disabled_plugins", plugin_list)
  config:flush()
  config:close()
end

function Utilities.readAPMplugins(self)
  local config = LuaSettings:open(settings.airplanemode)
  local disabled_plugins = config:readSetting("disabled_plugins") or {}
  config:close()
  return disabled_plugins
end

function Utilities:readAPMsetting(self, object)
  if not object then
    logger.err("AIRPLANEMODE: readAPMsetting - object sent is nil, cannot read")
    return
  end
  local config = LuaSettings:open(settings.airplanemode)
  local setting = config:readSetting(object)
  config:close()
  return setting
end

function Utilities.saveAPMsetting(self, object, value)
  if not object then
    logger.err("AIRPLANEMODE: saveAPMsetting - object sent is nil, cannot save")
    return
  end
  if not value then
    logger.err("AIRPLANEMODE: saveAPMsetting - value sent is nil, cannot save")
    return
  end
  local config = LuaSettings:open(settings.airplanemode)
  if config:saveSetting(object, value) then
    config:flush()
    config:close()
  else
    config:close()
    return false
  end
end

function Utilities:APMtoggle(object)
  if not object then
    logger.err("AIRPLANEMODE: APMtoggle - object sent is nil, cannot toggle")
    return
  end

  local config = LuaSettings:open(settings.airplanemode)
  local response = config:toggle(object)
  config:close()
  return response
end

function Utilities:APMisTrue(object)
  if not object then
    logger.err("AIRPLANEMODE: APMisTrue - object sent is nil, cannot check")
    return
  end
  local config = LuaSettings:open(settings.airplanemode)
  if config:isTrue(object) then
    config:flush()
    config:close()
    return true
  else
    config:flush()
    config:close()
    return false
  end
end

function Utilities:APMmakeTrue(object)
  if not object then
    logger.err("AIRPLANEMODE: APMmakeTrue - object sent is nil, cannot make true")
    return
  end
  local config = LuaSettings:open(settings.airplanemode)
  if config:makeTrue(object) then
    config:flush()
    config:close()
    return
  else
    config:flush()
    config:close()
    return false
  end
end

function Utilities:APMnilOrFalse(object)
  if not object then
    logger.err("AIRPLANEMODE: APMyoggle - object sent is nil, cannot toggle")
    return
  end
  local config = LuaSettings:open(settings.airplanemode)
  if config:nilOrFalse(object) then
    config:flush()
    config:close()
    return
  else
    config:flush()
    config:close()
    return false
  end
end

function Utilities:APMnilOrTrue(object)
  if not object then
    logger.err("AIRPLANEMODE: APMyoggle - object sent is nil, cannot toggle")
    return
  end
  local config = LuaSettings:open(settings.airplanemode)
  if config:nilOrTrue(object) then
    config:flush()
    config:close()
    return
  else
    config:flush()
    config:close()
    return false
  end
end

return Utilities
