---@class WidgetContainer
---@class AirPlaneMode : WidgetContainer
---@field name string
---@field is_doc_only boolean
---@field ui table
---@field additional_footer_content_func function|nil
---@field show_value_in_footer boolean|nil

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

local APMConfig = require("modules/APMConfig")
---@type SettingsConfig
local settings = APMConfig:init()

local H = require("modules/helpers")
local U = require("modules/utilities")
local A = require("modules/APMNetwork")
local M = require("modules/FlightMenu")

local function restoreState()
  -- we just rebooted to change apm states, now switch pref back
  if U:APMhas("restoreopt", settings.airplanemode) and U:APMisTrue("restoreopt", settings.airplanemode) then
    logger.dbg("AIRPLANEMODE: Restore activated")
    local last_start = U:readAPMsetting("restart_with", settings.airplanemode) or nil
    -- make sure we didn't enable this while already in airplanemode
    if last_start ~= nil then
      logger.dbg("AIRPLANEMODE: resetting the main config to use", last_start)
      U:saveAPMsetting("start_with", last_start, settings.koreader)
      U:delAPMsetting("restart_with", settings.airplanemode)
    end
  end
end

local function saveState(name)
  -- grab the current startup mode
  logger.dbg("AIRPLANEMODE: saving state")
  logger.dbg("AIRPLANEMODE: Activated while in", name)
  local cur_start = U:readAPMsetting("start_with", settings.koreader) or nil
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
    U:saveAPMsetting("restart_with", cur_start, settings.airplanemode)
    -- set our new restart mode
    U:saveAPMsetting("start_with", ui_mode, settings.koreader)
  end
end

restoreState()

local AirPlaneMode = WidgetContainer:extend({
  name = "airplanemode",
  is_doc_only = false,
})

local PluginManager = require("modules/PluginManager")
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
local APMfooter = require("modules/APMfooter")
if type(APMfooter) == "function" then
  APMfooter(AirPlaneMode)
end

---Dump current on-disk airplanemode settings for debugging
---@return nil
function AirPlaneMode.dumpSettings()
  -- Short-lived verification: read on-disk file contents and log them
  local fh = io.open(settings.airplanemode, "r")
  if fh then
    local contents = fh:read("*a")
    fh:close()
    logger.dbg("AIRPLANEMODE: on-disk airplanemode.lua after save:\n", contents)
  else
    logger.err("AIRPLANEMODE: failed to open on-disk airplanemode.lua for verification: ", settings.airplanemode)
  end
  local check_state = U:readAPMsetting("airplanemode", settings.koreader) or false
  logger.dbg("AIRPLANEMODE: check state after dumpSettings: ", check_state)
  return
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
  logger.dbg("AIRPLANEMODE: calling airplanemode dump")
  self:dumpSettings()
  self:onDispatcherRegisterActions()
  if H.isFile(settings.prev_config) then
    self:migrateconfig()
  else
    if not H.isFile(settings.airplanemode) then
      self:initSettingsFile()
    end
  end
  if U:APMhas("airplanemode", settings.koreader) then
    self:migratesettings()
  end
  self.additional_footer_content_func = function()
    local item_prefix = self.ui.view.footer.settings.item_prefix
    if item_prefix == "icons" then
      if U:getStatus() then
        return settings.icon_on
      else
        return settings.icon_off
      end
    end
  end

  self.show_value_in_footer = U:readAPMsetting("airplanemode_in_footer", settings.airplanemode)
  if self.show_value_in_footer then
    self:addAdditionalFooterContent()
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
    local cur_disabled = U:readAPMplugins(settings.koreader_plugins, settings.koreader)
    if cur_disabled ~= nil then
      logger.dbg("AIRPLANEMODE: initSettingsFile - disabled_plugins already present, skipping. traceback:\n", debug.traceback())
      return
    end

    U:saveAPMsetting("version", settings.version, settings.airplanemode)
    local default_disable = {}
    local default_disable_list = { "newsdownloader", "wallabag", "kosync", "opds", "SSH", "timesync", "httpinspector" }
    for __, plugin in ipairs(default_disable_list) do
      default_disable[plugin] = true
    end
    logger.dbg("AIRPLANEMODE: Saving default settings to ", settings.airplanemode, " at ", os.time(), "\nstack:\n", debug.traceback())
    U:saveAPMplugins(default_disable, settings.airplanemode)
  end
end

-- migrate old config to new format if necessary
function AirPlaneMode.migrateconfig()
  logger.info("AIRPLANEMODE: migrating config from ", settings.prev_config, " to ", settings.airplanemode)
  U:saveAPMsetting("version", settings.version, settings.airplanemode)
  local disabled = U:readAPMsetting("disabled_plugins", settings.prev_config)
  if disabled then
    if disabled["calibre"] then
      disabled["calibre"] = nil
    end
    U:saveAPMsetting(settings.koreader_plugins, disabled, settings.airplanemode)
  end
  -- I know, why wouldn't it be there, but caution always
  H.removeFile(settings.prev_config)
end

function AirPlaneMode:migratesettings()
  logger.dbg("AIRPLANEMODE: koreader config found, migrating to new layout")
  -- move things around for the new configuration layout
  -- in case it is running
  if U:APMisTrue("airplanemode", settings.koreader) then
    U:APMmakeTrue("airplanemode_enabled", settings.airplanemode)
  elseif U:APMisFalse("airplanemode", settings.koreader) then
    U:APMmakeFalse("airplanemode_enabled", settings.airplanemode)
  end
  -- if we have anything configured to disable, update the variable name
  U:delAPMsetting("airplanemode", settings.koreader)
  if U:APMhas(settings.koreader_plugins, settings.airplanemode) then
    local disabled_plugins = U:readAPMsetting(settings.koreader_plugins, settings.airplanemode)
    if disabled_plugins then
      U:saveAPMsetting(settings.koreader_plugins, disabled_plugins, settings.airplanemode)
      U:delAPMsetting(settings.koreader_plugins, settings.airplanemode)
    end
  end
  -- move footer toggle
  if U:APMhas("airplanemode_in_footer", settings.koreader) then
    U:saveAPMsetting("airplanemode_in_footer", U:readAPMsetting("airplanemode_in_footer", settings.koreader), settings.airplanemode)
    U:delAPMsetting("airplanemode_in_footer", settings.koreader)
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
  if U:readAPMsetting("airplanemode", settings.airplanemode) then
    UIManager:show(InfoMessage:new({
      text = _("Removing AirPlaneMode while still running. Plugins and networking will not be automatically restored."),
      timeout = 3,
    }))
  end
  if U:APMhas("airplanemode", settings.airplanemode) then
    U:delAPMsetting("airplanemode", settings.airplanemode)
  end
  if U:APMhas("airplanemode_in_footer", settings.airplanemode) then
    U:delAPMsetting("airplanemode_in_footer", settings.airplanemode)
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

  logger.dbg("AIRPLANEMODE: dumping settings before running backup")
  self.dumpSettings()
  local current_config = U:backup(settings.koreader, settings.backup)
  logger.dbg("AIRPLANEMODE: dumping settings after running backup")
  self.dumpSettings()
  if current_config then
    -- [[ disable plugins, wireless, all of it ]]

    -- instead of disabling the calibre plugin, just disable the wireless part -  this lets you still search calibre metadata
    logger.dbg("AIRPLANEMODE: disabling calibre wireless")
    if U:APMnilOrTrue("calibre_wireless", settings.koreader) then
      U:APMmakeFalse("calibre_wireless", settings.koreader)
    end

    logger.dbg("AIRPLANEMODE: disabling plugins")
    self:disablePlugins(settings)
    -- exclude anything without getNetworkInterfaceName - like android - since we can't control their wifi
    if
      (NetworkMgr:getNetworkInterfaceName() or Device:isEmulator())
      and ((U:APMhasNot("managewifi", settings.airplanemode)) or (U:APMhas("managewifi", settings.airplanemode) and U:APMnilOrFalse("managewifi", settings.airplanemode)))
    then
      logger.dbg("AIRPLANEMODE: disabling wifi")
      A:disableWifi()
    end
    -- mark airplane as active
    logger.dbg("AIRPLANEMODE: marking airplane as active")
    self.dumpSettings()
    U:toggleAirPlaneMode(true)
    logger.dbg("AIRPLANEMODE: after enabling")
    self.dumpSettings()
    -- Only attempt to save reading state if we are in the reader
    if string.match(self.name, "reader") then
      logger.dbg("AIRPLANEMODE: saving settings for reader")
      self.ui:saveSettings()
    end

    if Device:canRestart() then
      logger.dbg("AIRPLANEMODE: can restart, saving state and restarting")
      logger.dbg("AIRPLANEMODE: dump just before restart")
      self.dumpSettings()
      if U:APMisTrue("restoreopt", settings.airplanemode) then
        logger.dbg("AIRPLANEMODE: restoreopt is true, saving state of", self.name)
        saveState(self.name)
      end
      logger.dbg("AIRPLANEMODE: dump just after restoreopt")
      self.dumpSettings()
      if U:APMnilOrFalse("silentmode", settings.airplanemode) then
        logger.dbg("AIRPLANEMODE: dump without silentmode")
        self.dumpSettings()
        UIManager:show(ConfirmBox:new({
          text = _("KOReader needs to restart to finish applying changes for AirPlaneMode."),
          ok_text = _("OK"),
          cancel_text = _("Later"),
          ok_callback = function()
            UIManager:broadcastEvent(Event:new("Restart"))
          end,
        }))
      else
        logger.dbg("AIRPLANEMODE: dump with silentmode")
        self.dumpSettings()
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
  self:dumpSettings()
  logger.dbg("AIRPLANEMODE: re-enabled, restoring network next")
  -- If managing wifi, revert settingss
  if
    (NetworkMgr:getNetworkInterfaceName() or Device:isEmulator())
    and ((U:APMhasNot("managewifi", settings.airplanemode)) or (U:APMhas("managewifi", settings.airplanemode) and U:APMnilOrFalse("managewifi", settings.airplanemode)))
  then
    logger.dbg("AIRPLANEMODE: re-enabling wifi")
    A:reenableWifi()
  end

  self:enableCalibre(settings)

  logger.dbg("AIRPLANEMODE: Reading APM plugins")
  local apm_disabled = U:readAPMplugins(settings.koreader_plugins, settings.airplanemode)
  -- create a list of what is currently disabled
  logger.dbg("AIRPLANEMODE: Reading previous plugins_disabled setting")
  local previously_disabled = U:readAPMsetting(settings.koreader_plugins, settings.backup) or {}
  -- Build the list of plugins disabled right now
  logger.dbg("AIRPLANEMODE: Reading current plugins_disabled setting")
  local currently_disabled = U:readAPMsetting(settings.koreader_plugins, settings.koreader) or {}
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
    -- We still have an empty list - the only disabled plugins were the ones added by APM
    logger.dbg("AIRPLANEMODE: no plugins to re-disable")
    U:delAPMsetting("plugins_disabled", settings.koreader)
  else
    -- Save the updated list of disabled plugins
    logger.dbg("AIRPLANEMODE: saving updated plugins_disabled setting")
    U:saveAPMsetting(settings.koreader_plugins, to_disable, settings.koreader)
  end

  logger.dbg("AIRPLANEMODE: restoring plugin settings")
  self:restorePluginSettings(settings)
  -- remove the backup settings file

  logger.dbg("AIRPLANEMODE: removing backup settings file")
  if H.isFile(settings.backup) then
    H.removeFile(settings.backup)
  end

  self:dumpSettings()
  if string.match(self.name, "reader") then
    -- regardless of options, if we're in a document then save our position
    logger.dbg("AIRPLANEMODE - saving settings for reader")
    self.ui:saveSettings()
  end
  UIManager:unschedule(self.update_status_bars, self)
  if Device:canRestart() then
    logger.dbg("AIRPLANEMODE: device can restart, checking restart options and restarting")
    if U:APMisTrue("restoreopt", settings.airplanemode) then
      logger.dbg("AIRPLANEMODE: saving state name")
      saveState(self.name)
    end
    if U:APMnilOrFalse("silentmode", settings.airplanemode) then
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
  if self:getStatus() then
    self:Disable()
  else
    self:Enable()
  end
end

function AirPlaneMode:addToMainMenu(menu_items)
  M:init(menu_items, self)
end

return AirPlaneMode
