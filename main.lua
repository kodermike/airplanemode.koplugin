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
local logger = require("utils/flight_log")
local _ = require("gettext")

local FlightConfig = require("flight_config")
local settings = FlightConfig:init()

local H = require("utils/flight_helpers")
local U = require("utils/flight_utilities")
local A = require("flight_network")
local M = require("display/flight_menu")

local function restoreState()
  -- we just rebooted to change apm states, now switch pref back
  if U:FlightHas("restoreopt") and U:FlightIsTrue("restoreopt") then
    if settings.debug_is_on then
      local funcname = debug.getinfo(1, "n").name
      logger.dbg(funcname, "Restore activated")
    end
    local last_start = U:readFlightSetting("restart_with") or nil
    -- make sure we didn't enable this while already in airplanemode
    if last_start ~= nil then
      if settings.debug_is_on then
        local funcname = debug.getinfo(1, "n").name
        logger.dbg(funcname, "resetting the main config to use", last_start)
      end
      U:saveFlightSetting("start_with", last_start)
      U:delFlightSetting("restart_with")
    end
  end
end

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
    U:saveFlightSetting("restart_with", cur_start)
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
  if U:FlightHas("disabled_plugins") then
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

  self.show_value_in_footer = U:readFlightSetting("airplanemode_in_footer")
  if self.show_value_in_footer then
    self:addAdditionalFooterContent()
  end
  local curversion = U:readFlightSetting("version")
  if (curversion == nil) or (curversion ~= settings.version) then
    U:saveFlightSetting("version", settings.version)
  end
  self.ui.menu:registerToMainMenu(self)
end

---Settings initialized
---@return nil
function AirPlaneMode.initSettingsFile()
  -- If the file already exists, bail out early
  if H.isFile(settings.airplanemode) == true then
    if settings.debug_is_on then
      local funcname = debug.getinfo(1, "n").name
      logger.dbg(funcname, "file exists, skipping: ", settings.airplanemode)
    end
    return
  else
    -- Only write defaults if the setting is not already present (avoid clobbering)
    local cur_disabled = U:readFlightPlugins(settings.koreader_plugins, settings.koreader)
    if cur_disabled ~= nil then
      if settings.debug_is_on then
        local funcname = debug.getinfo(1, "n").name
        logger.dbg(funcname, "disabled_plugins already present, skipping. traceback:\n", debug.traceback())
      end
      return
    end

    U:saveFlightSetting("version", settings.version)
    local default_disable = {}
    local default_disable_list = { "newsdownloader", "wallabag", "kosync", "opds", "SSH", "timesync", "httpinspector" }
    for __, plugin in ipairs(default_disable_list) do
      default_disable[plugin] = true
    end
    if settings.debug_is_on then
      local funcname = debug.getinfo(1, "n").name
      logger.dbg(funcname, "Saving default settings to ", settings.airplanemode, " at ", os.time(), "\nstack:\n", debug.traceback())
    end
    U:saveFlightPlugins(default_disable)
  end
end

--- Migrate old config to new format if necessary
---@return nil
function AirPlaneMode.migrateconfig()
  local funcname = debug.getinfo(1, "n").name
  logger.dbg(funcname, "migrating config from ", settings.prev_config, " to ", settings.airplanemode)
  U:saveFlightSetting("version", settings.version)
  local disabled = U:readFlightSetting("disabled_plugins", settings.prev_config)
  if disabled then
    if disabled["calibre"] then
      disabled["calibre"] = nil
    end
    U:saveFlightSetting(settings.koreader_plugins, disabled)
  end
  -- I know, why wouldn't it be there, but caution always
  H.removeFile(settings.prev_config)
end

function AirPlaneMode:migratesettings()
  if settings.debug_is_on then
    local funcname = debug.getinfo(1, "n").name
    logger.dbg(funcname, "koreader config found, migrating to new layout")
  end
  -- move things around for the new configuration layout
  -- in case it is running
  if U:FlightIsTrue("airplanemode", settings.koreader) then
    U:FlightMakeTrue("airplanemode_enabled")
    U:delFlightSetting("airplanemode", settings.koreader)
  else
    U:FlightMakeFalse("airplanemode_enabled")
  end
  -- if we have anything configured to disable, update the variable name
  if U:FlightHas("disabled_plugins") then
    local disabled_plugins = U:readFlightSetting(settings.airplane_plugins)
    local transfer = {}
    for plugin, _ in pairs(disabled_plugins) do
      transfer[plugin] = true
    end
    U:saveFlightSetting(settings.koreader_plugins, transfer)
    U:delFlightSetting(settings.airplane_plugins)
  end
  -- move footer toggle
  if U:FlightHas("airplanemode_in_footer", settings.koreader) then
    U:saveFlightSetting("airplanemode_in_footer", U:readFlightSetting("airplanemode_in_footer", settings.koreader))
    U:delFlightSetting("airplanemode_in_footer", settings.koreader)
  end
end
---Hook for stopPlugin support
---@return nil
function AirPlaneMode:stopPlugin()
  local funcname = debug.getinfo(1, "n").name
  logger.dbg(funcname, "stopPlugin called at ", os.time())
  self:Disable()
end
-- expose non-method API (some callers invoke stopPlugin() without a self)
local _method_stopPlugin = AirPlaneMode.stopPlugin
if type(_method_stopPlugin) == "function" then
  AirPlaneMode.stopPlugin = function()
    return _method_stopPlugin(AirPlaneMode)
  end
end

---Hook for deleteplugin calls
---@return nil
function AirPlaneMode.deletePluginSettings()
  if settings.debug_is_on then
    local funcname = debug.getinfo(1, "n").name
    logger.dbg(funcname, "called at ", os.time(), "\nstack:\n", debug.traceback())
  end
  if U:readFlightSetting("airplanemode") then
    UIManager:show(InfoMessage:new({
      text = _("Removing AirPlaneMode while still running. Plugins and networking will not be automatically restored."),
      timeout = 3,
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

---Enable AirPlaneMode
---@return nil
function AirPlaneMode:Enable()
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
    self:disablePlugins(settings)
    -- exclude anything without getNetworkInterfaceName - like android - since we can't control their wifi
    if (NetworkMgr:getNetworkInterfaceName() or Device:isEmulator()) and ((U:FlightHasNot("managewifi")) or (U:FlightHas("managewifi") and U:FlightNilOrFalse("managewifi"))) then
      if settings.debug_is_on then
        local funcname = debug.getinfo(1, "n").name
        logger.dbg(funcname, "disabling wifi")
      end
      A:disableWifi()
    end
    -- mark airplane as active
    U:toggleAirPlaneMode(true)
    -- Only attempt to save reading state if we are in the reader
    if string.match(self.name, "reader") then
      if settings.debug_is_on then
        local funcname = debug.getinfo(1, "n").name
        logger.dbg(funcname, "saving settings for reader")
      end
      self.ui:saveSettings()
    end

    if Device:canRestart() then
      if settings.debug_is_on then
        local funcname = debug.getinfo(1, "n").name
        logger.dbg(funcname, "can restart, saving state and restarting")
      end
      if U:FlightIsTrue("restoreopt") then
        if settings.debug_is_on then
          local funcname = debug.getinfo(1, "n").name
          logger.dbg(funcname, "restoreopt is true, saving state of", self.name)
        end
        saveState(self.name)
      end
      if U:FlightNilOrFalse("silentmode") then
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
    local funcname = debug.getinfo(1, "n").name
    logger.err(funcname, "Failed to create backup file and execute")
  end
end

---Disable AirPlaneMode
---@return nil
function AirPlaneMode:Disable()
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
  if (NetworkMgr:getNetworkInterfaceName() or Device:isEmulator()) and ((U:FlightHasNot("managewifi")) or (U:FlightHas("managewifi") and U:FlightNilOrFalse("managewifi"))) then
    if settings.debug_is_on then
      local funcname = debug.getinfo(1, "n").name
      logger.dbg(funcname, "re-enabling wifi")
    end
    A:reenableWifi()
  end

  self:enableCalibre(settings)

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
  self:restorePluginSettings(settings)
  -- remove the backup settings file

  if settings.debug_is_on then
    local funcname = debug.getinfo(1, "n").name
    logger.dbg(funcname, "removing backup settings file")
  end
  if H.isFile(settings.backup) then
    H.removeFile(settings.backup)
  end

  if string.match(self.name, "reader") then
    -- regardless of options, if we're in a document then save our position
    if settings.debug_is_on then
      local funcname = debug.getinfo(1, "n").name
      logger.dbg(funcname, "saving settings for reader")
    end
    self.ui:saveSettings()
  end
  UIManager:unschedule(self.update_status_bars, self)
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
      saveState(self.name)
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
      end,
    }))
  end
end

---Handle Enable gesture
---@return nil
function AirPlaneMode:onEnable()
  self:Enable()
end

---Handle disable gesture
---@return nil
function AirPlaneMode:onDisable()
  self:Disable()
end

---Handle toggle events from gestures
---@return nil
function AirPlaneMode:onToggle()
  if U:getFlightStatus() then
    self:Disable()
  else
    self:Enable()
  end
end

---Initialize main menu
---@return nil
function AirPlaneMode:addToMainMenu(menu_items)
  M:init(menu_items, self)
end

return AirPlaneMode
