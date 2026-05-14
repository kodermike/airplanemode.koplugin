local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")
local logger = require("logger")

local APMConfig = require("modules/APMConfig")
local settings = APMConfig:init()

local Utilities = {}

function Utilities:readAPMplugins(listname, settings_file)
  logger.dbg("AIRPLANEMODE: readAPMplugins - reading plugins from ", settings_file)
  local config = LuaSettings:open(settings_file)
  local disabled_plugins = config:readSetting(listname) or {}
  config:close()
  return disabled_plugins
end

function Utilities:saveAPMplugins(plugin_list, settings_file)
  if not plugin_list or not type(plugin_list) == "table" then
    logger.err("AIRPLANEMODE: plugin_list is not a table, cannot save")
    return false
  end
  local config = LuaSettings:open(settings_file)
  config:saveSetting("disabled_plugins", plugin_list)
  config:flush()
  config:close()
end

function Utilities:readAPMsetting(object, settings_file)
  if not object then
    logger.err("AIRPLANEMODE: readAPMsetting - object sent is nil, cannot read")
    return false
  end
  local config = LuaSettings:open(settings_file)
  local setting = config:readSetting(object) or nil
  config:close()
  return setting
end

function Utilities:saveAPMsetting(object, value, settings_file)
  if not object then
    logger.err("AIRPLANEMODE: saveAPMsetting - object sent is nil, cannot save")
    return false
  else
    logger.dbg("AIRPLANEMODE: saveAPMsetting - object: ", object)
  end
  if value == nil then
    logger.err("AIRPLANEMODE: saveAPMsetting - value sent is nil, cannot save for object: ", object)
    return false
  else
    logger.dbg("AIRPLANEMODE: saveAPMsetting - value: ", value)
  end
  logger.dbg("AIRPLANEMODE: saveAPMsetting - saving setting: ", object, " = ", value)
  if object == "airplanemode" then
    logger.dbg("AIRPLANEMODE: saveAPMsetting called for 'airplanemode' at ", os.time(), "\nstack:\n", debug.traceback())
  end
  local config = LuaSettings:open(settings_file)
  if config:saveSetting(object, value) then
    config:flush()
    config:close()
    return true
  else
    config:flush()
    config:close()
    return false
  end
end

function Utilities:delAPMsetting(object, settings_file)
  if not object then
    logger.err("AIRPLANEMODE: delAPMsetting - object sent is nil, cannot delete")
    return false
  end
  local config = LuaSettings:open(settings_file)
  if object == "airplanemode" then
    logger.dbg("AIRPLANEMODE: delAPMsetting called for 'airplanemode' at ", os.time(), "\nstack:\n", debug.traceback())
  end
  local response = config:delSetting(object)
  config:flush()
  config:close()
  return response
end

function Utilities:APMhas(object, settings_file)
  if not object then
    logger.err("AIRPLANEMODE: APMhas - object sent is nil, cannot check")
    return false
  end
  local config = LuaSettings:open(settings_file)
  local value = config:has(object)
  config:close()
  return value
end

function Utilities:APMhasNot(object, settings_file)
  if not object then
    logger.err("AIRPLANEMODE: APMhasNot - object sent is nil, cannot check")
    return false
  end
  local config = LuaSettings:open(settings_file)
  local value = config:hasNot(object)
  config:close()
  return value
end

function Utilities:APMtoggle(object, settings_file)
  if not object then
    logger.err("AIRPLANEMODE: APMtoggle - object sent is nil, cannot toggle")
    return false
  end
  local config = LuaSettings:open(settings_file)
  local response = config:toggle(object)
  config:flush()
  config:close()
  return response
end

function Utilities:APMisTrue(object, settings_file)
  if not object then
    logger.err("AIRPLANEMODE: APMisTrue - object sent is nil, cannot check")
    return
  end
  local config = LuaSettings:open(settings_file)
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

function Utilities:APMisFalse(object, settings_file)
  if not object then
    logger.err("AIRPLANEMODE: APMisFalse - object sent is nil, cannot check")
    return
  end
  local config = LuaSettings:open(settings_file)
  if config:isFalse(object) then
    config:flush()
    config:close()
    return true
  else
    config:flush()
    config:close()
    return false
  end
end

function Utilities:APMmakeTrue(object, settings_file)
  if not object then
    logger.err("AIRPLANEMODE: APMmakeTrue - object sent is nil, cannot make true")
    return
  end
  local config = LuaSettings:open(settings_file)
  if config:makeTrue(object) then
    config:flush()
    config:close()
    return true
  else
    config:flush()
    config:close()
    return false
  end
end

function Utilities:APMmakeFalse(object, settings_file)
  if not object then
    logger.err("AIRPLANEMODE: APMmakeFalse - object sent is nil, cannot make false")
    return
  end
  local config = LuaSettings:open(settings_file)
  if config:makeFalse(object) then
    config:flush()
    config:close()
    return true
  else
    config:flush()
    config:close()
    return false
  end
end

function Utilities:APMnilOrFalse(object, settings_file)
  if not object then
    logger.err("AIRPLANEMODE: UTILITIES - apmnilorfalse has no object")
    return
  end
  logger.dbg("AIRPLANEMODE: UTILITIES - apmnilorfalse checking:", object)
  local config = LuaSettings:open(settings_file)
  if config:nilOrFalse(object) then
    logger.dbg("AIRPLANEMODE: UTILITIES - apmnilorfalse is nil or false:", object)
    config:flush()
    config:close()
    return true
  else
    config:flush()
    config:close()
    return false
  end
end

function Utilities:APMnilOrTrue(object, settings_file)
  if not object then
    logger.err("AIRPLANEMODE: APMnilOrTrue - object sent is nil, cannot toggle")
    return
  end
  if not settings_file then
    logger.err("AIRPLANEMODE: APMnilOrTrue - settings_file sent is nil, cannot toggle")
    return
  end

  local config = LuaSettings:open(settings_file)
  if config:nilOrTrue(object) then
    config:flush()
    config:close()
    return true
  else
    config:flush()
    config:close()
    return false
  end
end

function Utilities:APMflipNilOrFalse(object, settings_file)
  if not object then
    logger.err("AIRPLANEMODE: APMflipNilOrFalse - object sent is nil, cannot flip")
    return
  end
  if not settings_file then
    logger.err("AIRPLANEMODE: APMflipNilOrFalse - settings_file sent is nil, cannot flip")
    return
  end
  local config = LuaSettings:open(settings_file)
  if config:flipNilOrFalse(object) then
    config:flush()
    config:close()
    return true
  else
    config:flush()
    config:close()
    return false
  end
end

return Utilities
