---@class SettingsConfig
---@field koreader string
---@field backup string
---@field airplanemode string
---@field airplanemode_old string
---@field prev_config string
---@field koreader_plugins string
---@field airplane_plugins string
---@field icon_on string
---@field icon_off string
---@field version string

---@class Utilities

local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")
local logger = require("logger")
local ffiutil = require("ffi/util")

local APMConfig = require("modules/APMConfig")
local settings = APMConfig:init()
local H = require("modules/helpers")

local Utilities = {}

local function sethandler(file)
  if string.match(file, "settings.reader.lua$") then
    if G_reader_settings == nil then
      G_reader_settings = LuaSettings:open(file)
    end
    return G_reader_settings
  else
    return LuaSettings:open(file)
  end
end

---Read plugins table from settings file
---@param listname string
---@param settings_file string
---@return table<string, boolean>
function Utilities:readAPMplugins(listname, settings_file)
  logger.dbg("AIRPLANEMODE: readAPMplugins - reading plugins from ", settings_file)
  local config = sethandler(settings_file)
  local disabled_plugins = config:readSetting(listname) or {}
  config:close()
  return disabled_plugins
end

---Save plugins table to settings file
---@param plugin_list table<string, boolean>
---@param settings_file string
---@return boolean
function Utilities:saveAPMplugins(plugin_list, settings_file)
  if not plugin_list or not type(plugin_list) == "table" then
    logger.err("AIRPLANEMODE: plugin_list is not a table, cannot save")
    return false
  end
  local config = sethandler(settings_file)
  config:saveSetting(settings.koreader_plugins, plugin_list)
  config:flush()
  config:close()
  return true
end

---Read a single setting
---@param object string
---@param settings_file string
---@return any
function Utilities:readAPMsetting(object, settings_file)
  if not object then
    logger.err("AIRPLANEMODE: readAPMsetting - object sent is nil, cannot read")
    return false
  end
  local config = sethandler(settings_file)
  local setting = config:readSetting(object) or nil
  logger.dbg("AIRPLANEMODE: readAPMsetting - object: ", object, " = ", setting)
  config:close()
  return setting
end

---Save a single setting
---@param object string
---@param value any
---@param settings_file string
---@return boolean
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

  local config = sethandler(settings_file)
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

---Delete a setting
---@param object string
---@param settings_file string
---@return boolean
function Utilities:delAPMsetting(object, settings_file)
  if not object then
    logger.err("AIRPLANEMODE: delAPMsetting - object sent is nil, cannot delete")
    return false
  end
  local config = sethandler(settings_file)
  if object == "airplanemode" then
    logger.dbg("AIRPLANEMODE: delAPMsetting called for 'airplanemode' at ", os.time(), "\nstack:\n", debug.traceback())
  end
  local response = config:delSetting(object)
  config:flush()
  config:close()
  return response
end

---Check if a setting exists
---@param object string
---@param settings_file string
---@return boolean
function Utilities:APMhas(object, settings_file)
  if not object then
    logger.err("AIRPLANEMODE: APMhas - object sent is nil, cannot check")
    return false
  end
  local config = sethandler(settings_file)
  local value = config:has(object)
  config:close()
  return value
end

---Check if a setting does not exist
---@param object string
---@param settings_file string
---@return boolean
function Utilities:APMhasNot(object, settings_file)
  if not object then
    logger.err("AIRPLANEMODE: APMhasNot - object sent is nil, cannot check")
    return false
  end
  local config = sethandler(settings_file)
  local value = config:hasNot(object)
  config:close()
  return value
end

---Toggle a boolean setting
---@param object string
---@param settings_file string
---@return boolean
function Utilities:APMtoggle(object, settings_file)
  if not object then
    logger.err("AIRPLANEMODE: APMtoggle - object sent is nil, cannot toggle")
    return false
  end
  local config = sethandler(settings_file)
  local response = config:toggle(object)
  config:flush()
  config:close()
  return response
end

---Check if a setting is true
---@param object string
---@param settings_file string
---@return boolean
function Utilities:APMisTrue(object, settings_file)
  if not object then
    logger.err("AIRPLANEMODE: APMisTrue - object sent is nil, cannot check")
    return false
  end
  local config = sethandler(settings_file)
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

---Check if a setting is false
---@param object string
---@param settings_file string
---@return boolean
function Utilities:APMisFalse(object, settings_file)
  if not object then
    logger.err("AIRPLANEMODE: APMisFalse - object sent is nil, cannot check")
    return false
  end
  local config = sethandler(settings_file)
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

---Make a setting true
---@param object string
---@param settings_file string
---@return boolean
function Utilities:APMmakeTrue(object, settings_file)
  if not object then
    logger.err("AIRPLANEMODE: APMmakeTrue - object sent is nil, cannot make true")
    return false
  end
  local config = sethandler(settings_file)
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

---Make a setting false
---@param object string
---@param settings_file string
---@return boolean
function Utilities:APMmakeFalse(object, settings_file)
  if not object then
    logger.err("AIRPLANEMODE: APMmakeFalse - object sent is nil, cannot make false")
    return false
  end
  local config = sethandler(settings_file)
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

---Check if setting is nil or false
---@param object string
---@param settings_file string
---@return boolean
function Utilities:APMnilOrFalse(object, settings_file)
  if not object then
    logger.err("AIRPLANEMODE: UTILITIES - apmnilorfalse has no object")
    return false
  end
  logger.dbg("AIRPLANEMODE: UTILITIES - apmnilorfalse checking:", object)
  local config = sethandler(settings_file)
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

---Check if setting is nil or true
---@param object string
---@param settings_file string
---@return boolean
function Utilities:APMnilOrTrue(object, settings_file)
  if not object then
    logger.err("AIRPLANEMODE: APMnilOrTrue - object sent is nil, cannot toggle")
    return false
  end
  if not settings_file then
    logger.err("AIRPLANEMODE: APMnilOrTrue - settings_file sent is nil, cannot toggle")
    return false
  end

  local config = sethandler(settings_file)
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

---Flip nil or false to true and vice versa
---@param object string
---@param settings_file string
---@return boolean
function Utilities:APMflipNilOrFalse(object, settings_file)
  if not object then
    logger.err("AIRPLANEMODE: APMflipNilOrFalse - object sent is nil, cannot flip")
    return false
  end
  if not settings_file then
    logger.err("AIRPLANEMODE: APMflipNilOrFalse - settings_file sent is nil, cannot flip")
    return false
  end
  local config = sethandler(settings_file)
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

---Backup settings file
---@param settings_file string
---@param backup_file string
---@return boolean
function Utilities:backup(settings_file, backup_file)
  logger.dbg("AIRPLANEMODE: Backup - starting")

  if H.isFile(settings_file) then
    logger.dbg("AIRPLANEMODE: Backup - backup found, copying to backup file")
    if H.isFile(backup_file) then
      logger.dbg("AIRPLANEMODE: Backup - removing leftover backup file")
      H.removeFile(backup_file)
    end
    logger.dbg("AIRPLANEMODE: Backup - copying settings to backup file")
    ffiutil.copyFile(settings_file, backup_file)
    logger.dbg("AIRPLANEMODE: Backup - backup completed")
    return H.isFile(backup_file)
  else
    logger.err("AIRPLANEMODE: Backup - failed to find settings file at: ", settings_file)
    return false
  end
end

---Get current AirPlaneMode status
---@return boolean
function Utilities:getStatus()
  -- test we can see the real settings file.
  if not H.isFile(settings.airplanemode) then
    logger.err("AIRPLANEMODE: Settings file not found! Abort!", settings.airplanemode)
    return false
  end
  -- check if we currently have a backup of our settings
  -- also verify if the airplanemode flag is set. we will use this to decide if something is funky
  local airplanemode_active = self:readAPMsetting("airplanemode_enabled", settings.airplanemode) or false
  if H.isFile(settings.backup) and airplanemode_active then
    return true
  elseif not airplanemode_active then
    return false
  end
  return false
end

---Toggle AirPlaneMode persisted state
---@param toggle boolean
---@return nil
function Utilities:toggleAirPlaneMode(toggle)
  logger.dbg("AIRPLANEMODE: Utilities - toggleAirPlaneMode request, desired state:", toggle)
  if toggle == true then
    if self:APMmakeTrue("airplanemode_enabled", settings.airplanemode) then
      logger.dbg("AIRPLANEMODE: Utilities - AirPlaneMode explicitly set to true")
      local p = LuaSettings:open(settings.airplanemode)
      logger.dbg("AIRPLANEMODE: Utilities - AirPlaneMode read from settings:", p:readSetting("airplanemode_enabled"))
      p:close()
    else
      logger.err("AIRPLANEMODE: Utilities - Failed to set AirPlaneMode true")
    end
  elseif toggle == false then
    -- persist explicit false so the setting survives restarts
    if self:APMmakeFalse("airplanemode_enabled", settings.airplanemode) then
      logger.dbg("AIRPLANEMODE: Utilities - AirPlaneMode explicitly set to false")
      local p = LuaSettings:open(settings.airplanemode)
      logger.dbg("AIRPLANEMODE: Utilities - AirPlaneMode read from settings:", p:readSetting("airplanemode_enabled"))
      p:close()
    else
      logger.err("AIRPLANEMODE: Utilities - Failed to set AirPlaneMode false")
    end
  else
    logger.err("AIRPLANEMODE: Utilities - toggleAirPlaneMode called without explicit boolean: ", tostring(toggle))
  end
  return
end

return Utilities
