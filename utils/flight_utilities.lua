---@class Utilities

local LuaSettings = require("luasettings")
local logger = require("utils/flight_log")
local ffiutil = require("ffi/util")

local FlightConfig = require("flight_config")
local H = require("utils/flight_helpers")

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
---@param settings_file? string
---@return table<string, boolean>
function Utilities:readFlightPlugins(listname, settings_file)
  local settings = FlightConfig:init()
  settings_file = settings_file or settings.airplanemode
  if settings.debug_is_on then
    local funcname = debug.getinfo(1, "n").name
    logger.dbg(funcname, "reading plugins from ", settings_file)
  end
  local config = sethandler(settings_file)
  local disabled_plugins = config:readSetting(listname) or {}
  config:close()
  return disabled_plugins
end

---Save plugins table to settings file
---@param plugin_list table<string, boolean>
---@param settings_file? string
---@return boolean
function Utilities:saveFlightPlugins(plugin_list, settings_file)
  local settings = FlightConfig:init()
  settings_file = settings_file or settings.airplanemode
  if not plugin_list or type(plugin_list) ~= "table" then
    local funcname = debug.getinfo(1, "n").name
    logger.err(funcname, "plugin_list is not a table, cannot save")
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
---@param settings_file? string
---@return any
function Utilities:readFlightSetting(object, settings_file)
  local settings = FlightConfig:init()
  settings_file = settings_file or settings.airplanemode
  if not object then
    local funcname = debug.getinfo(1, "n").name
    logger.err(funcname, "object sent is nil, cannot read")
    return false
  end
  local config = sethandler(settings_file)
  local setting = config:readSetting(object) or nil
  if settings.debug_is_on then
    local funcname = debug.getinfo(1, "n").name
    logger.dbg(funcname, "object: ", object, " = ", setting)
  end
  config:close()
  return setting
end

---Save a single setting
---@param object string
---@param value any
---@param settings_file? string
---@return boolean
function Utilities:saveFlightSetting(object, value, settings_file)
  local settings = FlightConfig:init()
  settings_file = settings_file or settings.airplanemode
  if not object then
    local funcname = debug.getinfo(1, "n").name
    logger.err(funcname, "object sent is nil, cannot save")
    return false
  else
    if settings.debug_is_on then
      local funcname = debug.getinfo(1, "n").name
      logger.dbg(funcname, "object: ", object)
    end
  end
  if value == nil then
    local funcname = debug.getinfo(1, "n").name
    logger.err(funcname, "value sent is nil, cannot save for object: ", object)
    return false
  else
    if settings.debug_is_on then
      local funcname = debug.getinfo(1, "n").name
      logger.dbg(funcname, "value: ", value)
    end
  end
  if settings.debug_is_on then
    local funcname = debug.getinfo(1, "n").name
    logger.dbg(funcname, "saving setting: ", object, " = ", value)
  end

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
---@param settings_file? string
---@return boolean
function Utilities:delFlightSetting(object, settings_file)
  local settings = FlightConfig:init()
  settings_file = settings_file or settings.airplanemode
  if not object then
    local funcname = debug.getinfo(1, "n").name
    logger.err(funcname, "object sent is nil, cannot delete")
    return false
  end
  local config = sethandler(settings_file)
  if object == "airplanemode" then
    if settings.debug_is_on then
      local funcname = debug.getinfo(1, "n").name
      logger.dbg(funcname, "delFlightsetting called for 'airplanemode' at ", os.time(), "\nstack:\n", debug.traceback())
    end
  end
  local response = config:delSetting(object)
  config:flush()
  config:close()
  return response
end

---Check if a setting exists
---@param object string
---@param settings_file? string
---@return boolean
function Utilities:FlightHas(object, settings_file)
  local settings = FlightConfig:init()
  settings_file = settings_file or settings.airplanemode
  if not object then
    local funcname = debug.getinfo(1, "n").name
    logger.err(funcname, "object sent is nil, cannot check")
    return false
  end
  local config = sethandler(settings_file)
  local value = config:has(object)
  config:close()
  if value == nil then
    return false
  else
    return value
  end
end

---Check if a setting does not exist
---@param object string
---@param settings_file? string
---@return boolean
function Utilities:FlightHasNot(object, settings_file)
  local settings = FlightConfig:init()
  settings_file = settings_file or settings.airplanemode
  if not object then
    local funcname = debug.getinfo(1, "n").name
    logger.err(funcname, "object sent is nil, cannot check")
    return false
  end
  local config = sethandler(settings_file)
  local value = config:hasNot(object)
  config:close()
  return value
end

---Toggle a boolean setting
---@param object string
---@param settings_file? string
---@return boolean
function Utilities:FlightToggle(object, settings_file)
  local settings = FlightConfig:init()
  settings_file = settings_file or settings.airplanemode
  if not object then
    local funcname = debug.getinfo(1, "n").name
    logger.err(funcname, "object sent is nil, cannot toggle")
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
---@param settings_file? string
---@return boolean
function Utilities:FlightIsTrue(object, settings_file)
  local settings = FlightConfig:init()
  settings_file = settings_file or settings.airplanemode
  if not object then
    local funcname = debug.getinfo(1, "n").name
    logger.err(funcname, "object sent is nil, cannot check")
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
---@param settings_file? string
---@return boolean
function Utilities:FlightIsFalse(object, settings_file)
  local settings = FlightConfig:init()
  settings_file = settings_file or settings.airplanemode
  if not object then
    local funcname = debug.getinfo(1, "n").name
    logger.err(funcname, "object sent is nil, cannot check")
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
---@param settings_file? string
function Utilities:FlightMakeTrue(object, settings_file)
  local settings = FlightConfig:init()
  settings_file = settings_file or settings.airplanemode
  if not object then
    local funcname = debug.getinfo(1, "n").name
    logger.err(funcname, "object sent is nil, cannot make true")
    return
  end
  local config = sethandler(settings_file)
  config:makeTrue(object)
  if config:isTrue(object) then
    config:flush()
    config:close()
    return
  else
    config:flush()
    config:close()
    return
  end
end

---Make a setting false
---@param object string
---@param settings_file? string
function Utilities:FlightMakeFalse(object, settings_file)
  local settings = FlightConfig:init()
  settings_file = settings_file or settings.airplanemode
  if not object then
    local funcname = debug.getinfo(1, "n").name
    logger.err(funcname, "object sent is nil, cannot make false")
    return
  end
  local config = sethandler(settings_file)
  config:makeFalse(object)
  if config:isFalse(object) then
    config:flush()
    config:close()
    return
  else
    config:flush()
    config:close()
    return
  end
end

---Check if setting is nil or false
---@param object string
---@param settings_file? string
---@return boolean
function Utilities:FlightNilOrFalse(object, settings_file)
  local settings = FlightConfig:init()
  settings_file = settings_file or settings.airplanemode
  local funcname = debug.getinfo(1, "n").name
  if not object then
    logger.err(funcname, "apmnilorfalse has no object")
    return false
  end
  logger.dbg(funcname, "checking:", object)
  local config = sethandler(settings_file)
  if config:nilOrFalse(object) then
    logger.dbg(funcname, "is nil or false:", object)
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
---@param settings_file? string
---@return boolean
function Utilities:FlightNilOrTrue(object, settings_file)
  local settings = FlightConfig:init()
  settings_file = settings_file or settings.airplanemode
  if not object then
    local funcname = debug.getinfo(1, "n").name
    logger.err(funcname, "object sent is nil, cannot toggle")
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
---@param settings_file? string
---@return boolean
function Utilities:FlightFlipNilOrFalse(object, settings_file)
  local settings = FlightConfig:init()
  settings_file = settings_file or settings.airplanemode
  if not object then
    local funcname = debug.getinfo(1, "n").name
    logger.err(funcname, "object sent is nil, cannot flip")
    return false
  end
  if not settings_file then
    local funcname = debug.getinfo(1, "n").name
    logger.err(funcname, "settings_file sent is nil, cannot flip")
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
---@param settings_file? string
---@param backup_file? string
function Utilities:backupFlight(settings_file, backup_file)
  local settings = FlightConfig:init()
  settings_file = settings_file or settings.airplanemode
  backup_file = backup_file or settings.backup
  local funcname = debug.getinfo(1, "n").name
  logger.dbg(funcname, "starting")

  if H.isFile(settings_file) then
    logger.dbg(funcname, "backup found, copying to backup file")
    if H.isFile(backup_file) then
      logger.dbg(funcname, "removing leftover backup file")
      H.removeFile(backup_file)
    end
    logger.dbg(funcname, "copying settings to backup file")
    ffiutil.copyFile(settings_file, backup_file)
    logger.dbg(funcname, "backup completed")
    return H.isFile(backup_file)
  else
    logger.err(funcname, "failed to find settings file at: ", settings_file)
    return false
  end
end

---Get current AirPlaneMode status
---@return boolean
function Utilities:getFlightStatus()
  local settings = FlightConfig:init()
  -- test we can see the real settings file.
  if not H.isFile(settings.airplanemode) then
    local funcname = debug.getinfo(1, "n").name
    logger.err(funcname, "Settings file not found! Abort!", settings.airplanemode)
    return false
  end
  -- check if we currently have a backup of our settings
  -- also verify if the airplanemode flag is set. we will use this to decide if something is funky
  local airplanemode_active = self:readFlightSetting("airplanemode_enabled") or false
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
  local settings = FlightConfig:init()
  local funcname = debug.getinfo(1, "n").name
  logger.dbg(funcname, "desired state:", toggle)
  if toggle == true then
    self:FlightMakeTrue("airplanemode_enabled")
    if self:FlightIsTrue("airplanemode_enabled") then
      logger.dbg(funcname, "AirPlaneMode explicitly set to true")
      local p = LuaSettings:open(settings.airplanemode)
      logger.dbg(funcname, "AirPlaneMode read from settings:", p:readSetting("airplanemode_enabled"))
      p:close()
    else
      logger.err(funcname, "Failed to set AirPlaneMode true")
    end
  elseif toggle == false then
    -- persist explicit false so the setting survives restarts
    self:FlightMakeFalse("airplanemode_enabled")
    if self:FlightIsFalse("airplanemode_enabled") then
      logger.dbg(funcname, "AirPlaneMode explicitly set to false")
      local p = LuaSettings:open(settings.airplanemode)
      logger.dbg(funcname, "AirPlaneMode read from settings:", p:readSetting("airplanemode_enabled"))
      p:close()
    else
      logger.err(funcname, "Failed to set AirPlaneMode false")
    end
  else
    logger.err(funcname, "toggleAirPlaneMode called without explicit boolean: ", tostring(toggle))
  end
  return
end

---Dump current on-disk airplanemode settings for debugging
---@return nil
function Utilities:dumpSettings()
  local settings = FlightConfig:init()
  -- Short-lived verification: read on-disk file contents and log them
  local fh = io.open(settings.airplanemode, "r")
  if fh then
    local contents = fh:read("*a")
    fh:close()
    local funcname = debug.getinfo(1, "n").name
    logger.dbg(funcname, "on-disk airplanemode.lua after save:\n", contents)
  else
    local funcname = debug.getinfo(1, "n").name
    logger.err(funcname, "failed to open on-disk airplanemode.lua for verification: ", settings.airplanemode)
  end
  local check_state = self:readFlightSetting("airplanemode") or false
  local funcname = debug.getinfo(1, "n").name
  logger.dbg(funcname, "check state after dumpSettings: ", check_state)
  return
end

return Utilities
