---@class FlightControl
---@field Enable  fun(self): nil
---@field Disable fun(self): nil

local ConfirmBox = require("ui/widget/confirmbox")
local Device = require("device")
local Event = require("ui/event")

local NetworkMgr = require("ui/network/manager")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local _ = require("gettext")
local logger = require("utils/flight_log")

local FlightConfig = require("flight_config")
local settings = FlightConfig:init()

local H = require("utils/flight_helpers")
local U = require("utils/flight_utilities")
local A = require("flight_network")
local P = require("utils/flight_plugins")

local FlightControl = {}

local function saveState(name)
  -- grab the current startup mode
  if settings.debug_is_on then
    local funcname = debug.getinfo(1, "n").name
    logger.dbg(funcname, "saving state")
  end
  if settings.debug_is_on then
    local funcname = debug.getinfo(1, "n").name
    logger.dbg(funcname, "Activated while in", name)
  end
  if U:FlightHas("start_with", settings.koreader) then
    local cur_start = U:readFlightSetting("start_with", settings.koreader)
    local ui_mode
    ui_mode = name:gsub("airplanemode", "")
    if ui_mode == "reader" then
      ui_mode = "last"
    else
      ui_mode = U:readFlightSetting("start_with", settings.koreader)
    end
    -- save that state in our config
    U:saveFlightSetting("restart_with", cur_start)
    if settings.debug_is_on then
      local funcname = debug.getinfo(1, "n").name
      logger.dbg(funcname, "Saving restart as:", cur_start)
    end
    -- set our new restart mode
    U:saveFlightSetting("start_with", ui_mode, settings.koreader)
  end
end
--- Hook for deleteplugin calls
---@return nil
function FlightControl.deletePluginSettings()
  if settings.debug_is_on then
    local funcname = debug.getinfo(1, "n").name
    logger.dbg(funcname, "called at ", os.time(), "\nstack:\n", debug.traceback())
  end
  if U:readFlightSetting("airplanemode") then
    UIManager:show(InfoMessage:new({
      text = _(
        "Removing AirPlaneMode while still running. Plugins and networking will not be automatically restored."
      ),
      timeout = 3
    }))
  end
  if U:FlightHas("airplanemode") then
    U:delFlightSetting("airplanemode")
  end
  if U:FlightHas("airplanemode_in_footer") then
    U:delFlightSetting("airplanemode_in_footer")
  end
  if H.isFile(settings.airplanemode) then
    if settings.debug_is_on then
      local funcname = debug.getinfo(1, "n").name
      logger.dbg(funcname, "removing file: ", settings.airplanemode)
    end
    H.removeFile(settings.airplanemode)
  end
  if H.isFile(settings.airplanemode_old) then
    if settings.debug_is_on then
      local funcname = debug.getinfo(1, "n").name
      logger.dbg(funcname, "removing file: ", settings.airplanemode_old)
    end
    H.removeFile(settings.airplanemode_old)
  end
end

--- Disable AirPlaneMode
---@return nil
function FlightControl:Disable(AirPlaneMode_Self, interactive)
  if type(interactive) ~= "boolean" then
    interactive = true
  end
  if settings.debug_is_on then
    local funcname = debug.getinfo(1, "n").name
    logger.dbg(funcname, "Disabling AirPlaneMode")
  end
  -- disable airplanemode

  U:toggleAirPlaneMode(false)
  if settings.debug_is_on then
    local funcname = debug.getinfo(1, "n").name
    logger.dbg(funcname, "re-enabled, restoring network next")
  end
  -- If managing wifi, revert settingss
  if (NetworkMgr:getNetworkInterfaceName() or Device:isEmulator())
      and ((U:FlightHasNot("managewifi")) or (U:FlightHas("managewifi") and U:FlightNilOrFalse("managewifi"))) then
    if settings.debug_is_on then
      local funcname = debug.getinfo(1, "n").name
      logger.dbg(funcname, "re-enabling wifi")
    end
    A:reenableWifi()
  end

  P:enableCalibre(settings)

  if settings.debug_is_on then
    local funcname = debug.getinfo(1, "n").name
    logger.dbg(funcname, "Reading Flight plugins")
  end
  local apm_disabled = U:readFlightPlugins(settings.koreader_plugins)
  -- create a list of what is currently disabled
  if settings.debug_is_on then
    local funcname = debug.getinfo(1, "n").name
    logger.dbg(funcname, "Reading previous plugins_disabled setting")
  end
  local previously_disabled = U:readFlightSetting(settings.koreader_plugins, settings.backup) or {}
  -- Build the list of plugins disabled right now
  if settings.debug_is_on then
    local funcname = debug.getinfo(1, "n").name
    logger.dbg(funcname, "Reading current plugins_disabled setting")
  end
  local currently_disabled = U:readFlightSetting(settings.koreader_plugins, settings.koreader) or {}
  local to_disable = {}

  -- loop currently disabled items
  for plugin, __ in pairs(currently_disabled) do
    -- if airplanemode disabled it and it was disabled before, keep it disabled
    if settings.debug_is_on then
      local funcname = debug.getinfo(1, "n").name
      logger.dbg(funcname, "re-disabling plugin " .. plugin)
    end
    if (apm_disabled[plugin] and previously_disabled[plugin]) or not apm_disabled[plugin] then
      to_disable[plugin] = true
    end
  end

  if not next(to_disable) then
    -- We still have an empty list - the only disabled plugins were the ones added by Flight
    if settings.debug_is_on then
      local funcname = debug.getinfo(1, "n").name
      logger.dbg(funcname, "no plugins to re-disable")
    end
    U:delFlightSetting("plugins_disabled", settings.koreader)
  else
    -- Save the updated list of disabled plugins
    if settings.debug_is_on then
      local funcname = debug.getinfo(1, "n").name
      logger.dbg(funcname, "saving updated plugins_disabled setting")
    end
    U:saveFlightSetting(settings.koreader_plugins, to_disable, settings.koreader)
  end

  if settings.debug_is_on then
    local funcname = debug.getinfo(1, "n").name
    logger.dbg(funcname, "restoring plugin settings")
  end
  P:restorePluginSettings(settings)
  -- remove the backup settings file

  if settings.debug_is_on then
    local funcname = debug.getinfo(1, "n").name
    logger.dbg(funcname, "removing backup settings file")
  end
  if H.isFile(settings.backup) then
    H.removeFile(settings.backup)
  end

  if string.match(AirPlaneMode_Self.name, "reader") then
    -- regardless of options, if we're in a document then save our position
    if settings.debug_is_on then
      local funcname = debug.getinfo(1, "n").name
      logger.dbg(funcname, "saving settings for reader")
    end
    AirPlaneMode_Self.ui:saveSettings()
  end
  UIManager:unschedule(AirPlaneMode_Self.update_status_bars, AirPlaneMode_Self)
  if interactive then
    if Device:canRestart() then
      if settings.debug_is_on then
        local funcname = debug.getinfo(1, "n").name
        logger.dbg(funcname, "device can restart, checking restart options and restarting")
      end
      if U:FlightIsTrue("restoreopt") then
        if settings.debug_is_on then
          local funcname = debug.getinfo(1, "n").name
          logger.dbg(funcname, "saving state name")
        end
        saveState(AirPlaneMode_Self.name)
      end
      if U:FlightNilOrFalse("silentmode") then
        UIManager:askForRestart(_("KOReader needs to restart to finish disabling plugins for AirPlaneMode."))
      else
        UIManager:restartKOReader()
      end
    else
      if settings.debug_is_on then
        local funcname = debug.getinfo(1, "n").name
        logger.dbg(funcname, "device cannot restart, showing confirm box")
      end
      UIManager:show(ConfirmBox:new({
        dismissable = false,
        text = _("You will need to restart KOReader to finish disabling AirPlaneMode."),
        ok_text = _("OK"),
        ok_callback = function()
          UIManager:quit()
        end
      }))
    end
  end
end

--- Enable AirPlaneMode
---@return nil
function FlightControl:Enable(AirPlaneMode_Self)
  if settings.debug_is_on then
    local funcname = debug.getinfo(1, "n").name
    logger.dbg(funcname, "enabling")
  end

  local current_config = U:backupFlight(settings.koreader, settings.backup)

  if current_config then
    -- [[ disable plugins, wireless, all of it ]]

    -- instead of disabling the calibre plugin, just disable the wireless part -  this lets you still search calibre metadata
    if settings.debug_is_on then
      local funcname = debug.getinfo(1, "n").name
      logger.dbg(funcname, "disabling calibre wireless")
    end
    if U:FlightNilOrTrue("calibre_wireless", settings.koreader) then
      U:FlightMakeFalse("calibre_wireless", settings.koreader)
    end

    if settings.debug_is_on then
      local funcname = debug.getinfo(1, "n").name
      logger.dbg(funcname, "disabling plugins")
    end
    P:disablePlugins(AirPlaneMode_Self, settings)
    -- exclude anything without getNetworkInterfaceName - like android - since we can't control their wifi
    if (NetworkMgr:getNetworkInterfaceName() or Device:isEmulator())
        and ((U:FlightHasNot("managewifi")) or (U:FlightHas("managewifi") and U:FlightNilOrFalse("managewifi"))) then
      if settings.debug_is_on then
        local funcname = debug.getinfo(1, "n").name
        logger.dbg(funcname, "disabling wifi")
      end
      A:disableWifi()
    end
    -- mark airplane as active
    U:toggleAirPlaneMode(true)
    -- Only attempt to save reading state if we are in the reader
    if string.match(AirPlaneMode_Self.name, "reader") then
      if settings.debug_is_on then
        local funcname = debug.getinfo(1, "n").name
        logger.dbg(funcname, "saving settings for reader")
      end
      AirPlaneMode_Self.ui:saveSettings()
    end

    if Device:canRestart() then
      if settings.debug_is_on then
        local funcname = debug.getinfo(1, "n").name
        logger.dbg(funcname, "can restart, saving state and restarting")
      end
      if U:FlightIsTrue("restoreopt") then
        if settings.debug_is_on then
          local funcname = debug.getinfo(1, "n").name
          logger.dbg(funcname, "restoreopt is true, saving state of", AirPlaneMode_Self.name)
        end
        saveState(AirPlaneMode_Self.name)
      end
      if U:FlightNilOrFalse("silentmode") then
        UIManager:show(ConfirmBox:new({
          text = _("KOReader needs to restart to finish applying changes for AirPlaneMode."),
          ok_text = _("OK"),
          cancel_text = _("Later"),
          ok_callback = function()
            UIManager:broadcastEvent(Event:new("Restart"))
          end
        }))
      else
        UIManager:restartKOReader()
      end
    else
      UIManager:show(ConfirmBox:new({
        dismissable = false,
        text = _("KOReader needs to be restarted to finish applying changes for AirPlane Mode."),
        ok_text = _("OK"),
        ok_callback = function()
          UIManager:quit()
        end
      }))
    end
  else
    local funcname = debug.getinfo(1, "n").name
    logger.err(funcname, "Failed to create backup file and execute")
  end
end

return FlightControl
