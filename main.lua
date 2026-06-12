---@class WidgetContainer
---@class AirPlaneMode : WidgetContainer
---@field name string
---@field is_doc_only boolean
---@field ui table
---@field additional_footer_content_func fun(): (string|nil)
---@field show_value_in_footer boolean|nil
---@field Enable fun(self): nil
---@field Disable fun(self): nil
---@field init fun(self): nil
---@field onEnable fun(self): nil
---@field onDisable fun(self): nil
---@field getPlugins fun(self, builtin: boolean, settings: table): table

local ConfirmBox = require("ui/widget/confirmbox")
local Device = require("device")
local Dispatcher = require("dispatcher")
local Event = require("ui/event")

local InfoMessage = require("ui/widget/infomessage")
local NetworkMgr = require("ui/network/manager")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")
local _ = require("gettext")

local FlightConfig = require("flight_config")
local settings = FlightConfig:init()

local H = require("utils/flight_helpers")
local U = require("utils/flight_utilities")
local A = require("flight_net")
local M = require("display/flight_menu")

local function restoreState()
  -- we just rebooted to change apm states, now switch pref back
  if U:FlightHas("restoreopt", settings.airplanemode) and U:FlightIsTrue("restoreopt", settings.airplanemode) then
    logger.dbg("AIRPLANEMODE: Restore activated")
    local last_start = U:readFlightSetting("restart_with", settings.airplanemode) or nil
    -- make sure we didn't enable this while already in airplanemode
    if last_start ~= nil then
      logger.dbg("AIRPLANEMODE: resetting the main config to use", last_start)
      U:saveFlightSetting("start_with", last_start, settings.koreader)
      U:delFlightSetting("restart_with", settings.airplanemode)
    end
  end
end

local function saveState(name)
  -- grab the current startup mode
  logger.dbg("AIRPLANEMODE: saving state")
  logger.dbg("AIRPLANEMODE: Activated while in", name)
  local cur_start = U:readFlightSetting("start_with", settings.koreader) or nil
  local ui_mode
  -- figure out where we are./
  if cur_start == nil then
    cur_start = "filemanager"
  end
  ui_mode = name:gsub("airplanemode", "")
  if ui_mode == "reader" then
    ui_mode = "last"
  end
  if ui_mode ~= nil then
    -- save that state in our config
    U:saveFlightSetting("restart_with", cur_start, settings.airplanemode)
    -- set our new restart mode
    U:saveFlightSetting("start_with", ui_mode, settings.koreader)
  end
end

restoreState()

local AirPlaneMode = WidgetContainer:extend({
  name = "airplanemode",
  is_doc_only = false,
})

local PluginManager = require("flight_plugins")
if type(PluginManager) == "function" then
  PluginManager(AirPlaneMode)
elseif type(PluginManager) == "table" then
  -- wrap functions from the mocked module so tests can replace them after requiring main
  for k, v in pairs(PluginManager) do
    if type(v) == "function" and AirPlaneMode[k] == nil then
      AirPlaneMode[k] = function(...)
        return PluginManager[k](...)
      end
    end
  end
end
local Flightfooter = require("flight_footer")
if type(Flightfooter) == "function" then
  Flightfooter(AirPlaneMode)
end

---Register actions with dispatcher
---@return nil
function AirPlaneMode.onDispatcherRegisterActions()
  Dispatcher:registerAction("airplanemode_enable", { category = "none", event = "Enable", title = _("AirPlaneMode Enable"), device = true })
  Dispatcher:registerAction("airplanemode_disable", { category = "none", event = "Disable", title = _("AirPlaneMode Disable"), device = true })
  Dispatcher:registerAction("airplanemode_toggle", { category = "none", event = "Toggle", title = _("AirPlaneMode Toggle"), device = true, separator = true })
end

---Initialize plugin
---@return nil
function AirPlaneMode:init()
  self:onDispatcherRegisterActions()
  if H.isFile(settings.prev_config) then
    self:migrateconfig()
  else
    if not H.isFile(settings.airplanemode) then
      self:initSettingsFile()
    end
  end
  if U:FlightHas("airplanemode", settings.koreader) then
    self:migratesettings()
  end
  self.additional_footer_content_func = function()
    local item_prefix = self.ui.view.footer.settings.item_prefix
    if item_prefix == "icons" then
      if U:getFlightStatus() then
        return settings.icon_on
      else
        return settings.icon_off
      end
    end
  end

  self.show_value_in_footer = U:readFlightSetting("airplanemode_in_footer", settings.airplanemode)
  if self.show_value_in_footer then
    self:addAdditionalFooterContent()
  end
  local curversion = U:readFlightSetting("version", settings.airplanemode)
  if (curversion == nil) or (curversion ~= settings.version) then
    U:saveFlightSetting("version", settings.version, settings.airplanemode)
  end
  self.ui.menu:registerToMainMenu(self)
end

--[[ settings ]]
--
function AirPlaneMode.initSettingsFile()
  -- If the file already exists, bail out early
  if H.isFile(settings.airplanemode) == true then
    logger.dbg("AIRPLANEMODE: initSettingsFile - file exists, skipping: ", settings.airplanemode)
    return
  else
    -- Only write defaults if the setting is not already present (avoid clobbering)
    local cur_disabled = U:readFlightPlugins(settings.koreader_plugins, settings.koreader)
    if cur_disabled ~= nil then
      logger.dbg("AIRPLANEMODE: initSettingsFile - disabled_plugins already present, skipping. traceback:\n", debug.traceback())
      return
    end

    U:saveFlightSetting("version", settings.version, settings.airplanemode)
    local default_disable = {}
    local default_disable_list = { "newsdownloader", "wallabag", "kosync", "opds", "SSH", "timesync", "httpinspector" }
    for __, plugin in ipairs(default_disable_list) do
      default_disable[plugin] = true
    end
    logger.dbg("AIRPLANEMODE: Saving default settings to ", settings.airplanemode, " at ", os.time(), "\nstack:\n", debug.traceback())
    U:saveFlightPlugins(default_disable, settings.airplanemode)
  end
end

-- migrate old config to new format if necessary
function AirPlaneMode.migrateconfig()
  logger.info("AIRPLANEMODE: migrating config from ", settings.prev_config, " to ", settings.airplanemode)
  U:saveFlightSetting("version", settings.version, settings.airplanemode)
  local disabled = U:readFlightSetting("disabled_plugins", settings.prev_config)
  if disabled then
    if disabled["calibre"] then
      disabled["calibre"] = nil
    end
    U:saveFlightSetting(settings.koreader_plugins, disabled, settings.airplanemode)
  end
  -- I know, why wouldn't it be there, but caution always
  H.removeFile(settings.prev_config)
end

function AirPlaneMode:migratesettings()
  logger.dbg("AIRPLANEMODE: koreader config found, migrating to new layout")
  -- move things around for the new configuration layout
  -- in case it is running
  if U:FlightIsTrue("airplanemode", settings.koreader) then
    U:FlightMakeTrue("airplanemode_enabled", settings.airplanemode)
  elseif U:FlightIsFalse("airplanemode", settings.koreader) then
    U:FlightMakeFalse("airplanemode_enabled", settings.airplanemode)
  end
  -- if we have anything configured to disable, update the variable name
  U:delFlightSetting("airplanemode", settings.koreader)
  if U:FlightHas(settings.koreader_plugins, settings.airplanemode) then
    local disabled_plugins = U:readFlightSetting(settings.koreader_plugins, settings.airplanemode)
    if disabled_plugins then
      U:saveFlightSetting(settings.koreader_plugins, disabled_plugins, settings.airplanemode)
      U:delFlightSetting(settings.koreader_plugins, settings.airplanemode)
    end
  end
  -- move footer toggle
  if U:FlightHas("airplanemode_in_footer", settings.koreader) then
    U:saveFlightSetting("airplanemode_in_footer", U:readFlightSetting("airplanemode_in_footer", settings.koreader), settings.airplanemode)
    U:delFlightSetting("airplanemode_in_footer", settings.koreader)
  end
end
-- hook for stopPlugin support
function AirPlaneMode:stopPlugin()
  logger.info("AIRPLANEMODE: stopPlugin called at ", os.time())
  self:Disable()
end
-- expose non-method API (some callers invoke stopPlugin() without a self)
local _method_stopPlugin = AirPlaneMode.stopPlugin
if type(_method_stopPlugin) == "function" then
  AirPlaneMode.stopPlugin = function()
    return _method_stopPlugin(AirPlaneMode)
  end
end

-- hook for deleteplugin calls
function AirPlaneMode.deletePluginSettings()
  logger.dbg("AIRPLANEMODE: deletePluginSettings called at ", os.time(), "\nstack:\n", debug.traceback())
  if U:readFlightSetting("airplanemode", settings.airplanemode) then
    UIManager:show(InfoMessage:new({
      text = _("Removing AirPlaneMode while still running. Plugins and networking will not be automatically restored."),
      timeout = 3,
    }))
  end
  if U:FlightHas("airplanemode", settings.airplanemode) then
    U:delFlightSetting("airplanemode", settings.airplanemode)
  end
  if U:FlightHas("airplanemode_in_footer", settings.airplanemode) then
    U:delFlightSetting("airplanemode_in_footer", settings.airplanemode)
  end
  if H.isFile(settings.airplanemode) then
    logger.dbg("AIRPLANEMODE: deletePluginSettings removing file: ", settings.airplanemode)
    H.removeFile(settings.airplanemode)
  end
  if H.isFile(settings.airplanemode_old) then
    logger.dbg("AIRPLANEMODE: deletePluginSettings removing file: ", settings.airplanemode_old)
    H.removeFile(settings.airplanemode_old)
  end
end

function AirPlaneMode:Enable()
  logger.dbg("AIRPLANEMODE: enabling")

  local current_config = U:backupFlight(settings.koreader, settings.backup)

  if current_config then
    -- [[ disable plugins, wireless, all of it ]]

    -- instead of disabling the calibre plugin, just disable the wireless part -  this lets you still search calibre metadata
    logger.dbg("AIRPLANEMODE: disabling calibre wireless")
    if U:FlightNilOrTrue("calibre_wireless", settings.koreader) then
      U:FlightMakeFalse("calibre_wireless", settings.koreader)
    end

    logger.dbg("AIRPLANEMODE: disabling plugins")
    self:disablePlugins(settings)
    -- exclude anything without getNetworkInterfaceName - like android - since we can't control their wifi
    if
      (NetworkMgr:getNetworkInterfaceName() or Device:isEmulator())
      and ((U:FlightHasNot("managewifi", settings.airplanemode)) or (U:FlightHas("managewifi", settings.airplanemode) and U:FlightNilOrFalse("managewifi", settings.airplanemode)))
    then
      logger.dbg("AIRPLANEMODE: disabling wifi")
      A:disableWifi()
    end
    -- mark airplane as active
    U:toggleAirPlaneMode(true)
    -- Only attempt to save reading state if we are in the reader
    if string.match(self.name, "reader") then
      logger.dbg("AIRPLANEMODE: saving settings for reader")
      self.ui:saveSettings()
    end

    if Device:canRestart() then
      logger.dbg("AIRPLANEMODE: can restart, saving state and restarting")
      if U:FlightIsTrue("restoreopt", settings.airplanemode) then
        logger.dbg("AIRPLANEMODE: restoreopt is true, saving state of", self.name)
        saveState(self.name)
      end
      if U:FlightNilOrFalse("silentmode", settings.airplanemode) then
        UIManager:show(ConfirmBox:new({
          text = _("KOReader needs to restart to finish applying changes for AirPlaneMode."),
          ok_text = _("OK"),
          cancel_text = _("Later"),
          ok_callback = function()
            UIManager:broadcastEvent(Event:new("Restart"))
          end,
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
        end,
      }))
    end
  else
    logger.err("AIRPLANEMODE: Failed to create backup file and execute")
  end
end

function AirPlaneMode:Disable()
  logger.dbg("AIRPLANEMODE: Disabling AirPlaneMode")
  -- disable airplanemode

  U:toggleAirPlaneMode(false)
  logger.dbg("AIRPLANEMODE: re-enabled, restoring network next")
  -- If managing wifi, revert settingss
  if
    (NetworkMgr:getNetworkInterfaceName() or Device:isEmulator())
    and ((U:FlightHasNot("managewifi", settings.airplanemode)) or (U:FlightHas("managewifi", settings.airplanemode) and U:FlightNilOrFalse("managewifi", settings.airplanemode)))
  then
    logger.dbg("AIRPLANEMODE: re-enabling wifi")
    A:reenableWifi()
  end

  self:enableCalibre(settings)

  logger.dbg("AIRPLANEMODE: Reading Flight plugins")
  local apm_disabled = U:readFlightPlugins(settings.koreader_plugins, settings.airplanemode)
  -- create a list of what is currently disabled
  logger.dbg("AIRPLANEMODE: Reading previous plugins_disabled setting")
  local previously_disabled = U:readFlightSetting(settings.koreader_plugins, settings.backup) or {}
  -- Build the list of plugins disabled right now
  logger.dbg("AIRPLANEMODE: Reading current plugins_disabled setting")
  local currently_disabled = U:readFlightSetting(settings.koreader_plugins, settings.koreader) or {}
  local to_disable = {}

  -- loop currently disabled items
  for plugin, __ in pairs(currently_disabled) do
    -- if airplanemode disabled it and it was disabled before, keep it disabled
    logger.dbg("AIRPLANEMODE: re-disabling plugin " .. plugin)
    if (apm_disabled[plugin] and previously_disabled[plugin]) or not apm_disabled[plugin] then
      to_disable[plugin] = true
    end
  end

  if not next(to_disable) then
    -- We still have an empty list - the only disabled plugins were the ones added by Flight
    logger.dbg("AIRPLANEMODE: no plugins to re-disable")
    U:delFlightSetting("plugins_disabled", settings.koreader)
  else
    -- Save the updated list of disabled plugins
    logger.dbg("AIRPLANEMODE: saving updated plugins_disabled setting")
    U:saveFlightSetting(settings.koreader_plugins, to_disable, settings.koreader)
  end

  logger.dbg("AIRPLANEMODE: restoring plugin settings")
  self:restorePluginSettings(settings)
  -- remove the backup settings file

  logger.dbg("AIRPLANEMODE: removing backup settings file")
  if H.isFile(settings.backup) then
    H.removeFile(settings.backup)
  end

  if string.match(self.name, "reader") then
    -- regardless of options, if we're in a document then save our position
    logger.dbg("AIRPLANEMODE - saving settings for reader")
    self.ui:saveSettings()
  end
  UIManager:unschedule(self.update_status_bars, self)
  if Device:canRestart() then
    logger.dbg("AIRPLANEMODE: device can restart, checking restart options and restarting")
    if U:FlightIsTrue("restoreopt", settings.airplanemode) then
      logger.dbg("AIRPLANEMODE: saving state name")
      saveState(self.name)
    end
    if U:FlightNilOrFalse("silentmode", settings.airplanemode) then
      UIManager:askForRestart(_("KOReader needs to restart to finish disabling plugins for AirPlaneMode."))
    else
      UIManager:restartKOReader()
    end
  else
    logger.dbg("AIRPLANEMODE: device cannot restart, showing confirm box")
    UIManager:show(ConfirmBox:new({
      dismissable = false,
      text = _("You will need to restart KOReader to finish disabling AirPlaneMode."),
      ok_text = _("OK"),
      ok_callback = function()
        UIManager:quit()
      end,
    }))
  end
end

function AirPlaneMode:onEnable()
  self:Enable()
end

function AirPlaneMode:onDisable()
  self:Disable()
end

function AirPlaneMode:onToggle()
  if U:getFlightStatus() then
    self:Disable()
  else
    self:Enable()
  end
end

function AirPlaneMode:addToMainMenu(menu_items)
  M:init(menu_items, self)
end

return AirPlaneMode
