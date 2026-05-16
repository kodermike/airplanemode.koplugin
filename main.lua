local ConfirmBox = require("ui/widget/confirmbox")
local DataStorage = require("datastorage")
local Device = require("device")
local Dispatcher = require("dispatcher")
local Event = require("ui/event")
local InfoMessage = require("ui/widget/infomessage")
local NetworkMgr = require("ui/network/manager")
local PluginLoader = require("pluginloader")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local ffiutil = require("ffi/util")
local T = ffiutil.template
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local _ = require("gettext")

local APMConfig = require("modules/APMConfig")
local settings = APMConfig:init()

local H = require("modules/helpers")
local U = require("modules/utilities")
local A = require("modules/APMNetwork")
local P = require("modules/PluginManager")

local meta = require("_meta")
local icon_on = "\u{F1D8}"
local icon_off = "\u{F1D9}"

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

function AirPlaneMode.getStatus()
  -- test we can see the real settings file.
  if not H.isFile(settings.airplanemode) then
    logger.err("AIRPLANEMODE: Settings file not found! Abort!", settings.airplanemode)
    return false
  end
  -- check if we currently have a backup of our settings
  -- also verify if the airplanemode flag is set. we will use this to decide if something is funky
  local airplanemode_active = U:readAPMsetting("airplanemode_enabled", settings.airplanemode) or false
  if H.isFile(settings.backup) and airplanemode_active then
    return true
  elseif not airplanemode_active then
    return false
  end
  return false
end

function AirPlaneMode.onDispatcherRegisterActions()
  Dispatcher:registerAction("airplanemode_enable", { category = "none", event = "Enable", title = _("AirPlaneMode Enable"), device = true })
  Dispatcher:registerAction("airplanemode_disable", { category = "none", event = "Disable", title = _("AirPlaneMode Disable"), device = true })
  Dispatcher:registerAction("airplanemode_toggle", { category = "none", event = "Toggle", title = _("AirPlaneMode Toggle"), device = true, separator = true })
end

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
    logger.dbg("AIRPLANEMODE: koreader config found, migrating to new layout")
    -- move things around for the new configuration layout
    -- in case it is running
    if U:APMisTrue("airplanemode", settings.koreader) then
      U:APMmakeTrue("airplanemode_enabled", settings.airplanemode)
    elseif U:APMisFalse("airplanemode", settings.koreader) then
      U:APMmakeFalse("airplanemode_enabled", settings.airplanemode)
    end
    -- if we have anything configured, update the variable name
    U:delAPMsetting("airplanemode", settings.koreader)
    if U:APMhas("disabled_plugins", settings.airplanemode) then
      local disabled_plugins = U:readAPMsetting("disabled_plugins", settings.airplanemode)
      if disabled_plugins then
        U:saveAPMsetting(settings.koreader_plugins, disabled_plugins, settings.airplanemode)
        U:delAPMsetting("disabled_plugins", settings.airplanemode)
      end
    end
  end

  self.additional_footer_content_func = function()
    local item_prefix = self.ui.view.footer.settings.item_prefix
    if item_prefix == "icons" then
      if self:getStatus() then
        return icon_on
      else
        return icon_off
      end
    end
  end
  self.show_value_in_footer = U:readAPMsetting("airplanemode_in_footer", settings.airplanemode)
  if self.show_value_in_footer then
    self:addAdditionalFooterContent()
  end
  self.ui.menu:registerToMainMenu(self)
end

--[[ reader statusbar hooks ]]
--
function AirPlaneMode:update_status_bars()
  if self.show_value_in_footer then
    UIManager:broadcastEvent(Event:new("RefreshAdditionalContent"))
  end
end

function AirPlaneMode:addAdditionalFooterContent()
  if self.ui.view then
    self.ui.view.footer:addAdditionalFooterContent(self.additional_footer_content_func)
    self:update_status_bars()
  end
end

function AirPlaneMode:removeAdditionalFooterContent()
  if self.ui.view then
    self.ui.view.footer:removeAdditionalFooterContent(self.additional_footer_content_func)
    self:update_status_bars()
    UIManager:broadcastEvent(Event:new("UpdateFooter", true))
  end
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

    U:saveAPMsetting("version", meta.version, settings.airplanemode)
    local default_disable = {}
    local default_disable_list = { "newsdownloader", "wallabag", "kosync", "opds", "SSH", "timesync", "httpinspector" }
    for __, plugin in ipairs(default_disable_list) do
      default_disable[plugin] = true
    end
    logger.dbg("AIRPLANEMODE: Saving default settings to ", settings.airplanemode, " at ", os.time(), "\nstack:\n", debug.traceback())
    U:saveAPMplugins("disabled_plugins", default_disable, settings.airplanemode)
  end
end

function AirPlaneMode.dumpSettings()
  -- Short-lived verification: read on-disk file contents and log them
  local fh = io.open(settings.airplanemode, "r")
  if fh then
    local contents = fh:read("*a")
    fh:close()
    logger.dbg("AIRPLANEMODE: on-disk airplanemode.lua after save:\n", contents)
  else
    logger.err("AIRPLANEMODE: failed to open on-disk airplanemode.lua for verification: ", airplanemode_config)
  end
end
-- migrate old config to new format if necessary
function AirPlaneMode.migrateconfig()
  logger.info("AIRPLANEMODE: migrating config from ", settings.prev_config, " to ", settings.airplanemode)
  U:saveAPMsetting("version", meta.version, settings.airplanemode)
  local disabled = U:readAPMsetting("disabled_plugins", settings.prev_config)
  if disabled then
    if disabled["calibre"] then
      disabled["calibre"] = nil
    end
    U:saveAPMsetting("disabled_plugins", disabled, settings.airplanemode)
  end
  -- I know, why wouldn't it be there, but caution always
  H.removeFile(settings.prev_config)
end

-- hook for stopPlugin support
function AirPlaneMode.stopPlugin()
  logger.info("AIRPLANEMODE: stopPlugin called at ", os.time())
  logger.dbg("AIRPLANEMODE: stopPlugin called at ", os.time(), "\nstack:\n", debug.traceback())
  -- restore plugin settings
  P:restorePluginSettings(settings)
  -- disable airplanemode in settings
  P:toggleAirPlaneMode(settings, false)
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

function AirPlaneMode.backup()
  logger.dbg("AIRPLANEMODE: backup starting")

  if H.isFile(settings.koreader) then
    logger.dbg("AIRPLANEMODE: backup found, copying to backup file")
    if H.isFile(settings.backup) then
      logger.dbg("AIRPLANEMODE: removing leftover backup file")
      H.removeFile(settings.backup)
    end
    logger.dbg("AIRPLANEMODE: copying settings to backup file")
    ffiutil.copyFile(settings.koreader, settings.backup)
    logger.dbg("AIRPLANEMODE: backup completed")
    return H.isFile(settings.backup)
  else
    logger.err("AIRPLANEMODE: Failed to find settings file at: ", settings.koreader)
    return false
  end
end

local function stopOtherPlugins(stopp, fplugin, plugin)
  -- try to run stopPlugin if available since it's cleaner
  logger.dbg("AIRPLANEMODE: Stopping plugin", plugin)
  if stopp then
    local mstatus, __ = pcall(function()
      pcall(fplugin["stopPlugin"]())
    end)
    if H.stringto(mstatus) == false then
      -- stopPlugin failed, just do a normal stop
      local sstatus, serr = pcall(function()
        pcall(fplugin["stop"]())
      end)
      if H.stringto(sstatus) == false then
        logger.err("AIRPLANEMODE: Failed to stop", plugin, ":", serr)
      end
    end
  else
    -- no stopPlugin, fallback to regular stop
    local sstatus, serr = pcall(function()
      pcall(fplugin["stop"]())
    end)
    if H.stringto(sstatus) == false then
      logger.err("AIRPLANEMODE: Failed to stop", plugin, ":", serr)
    end
  end
end

function AirPlaneMode:Enable()
  logger.dbg("AIRPLANEMODE: enabling")

  logger.dbg("AIRPLANEMODE: dumping settings before running backup")
  self.dumpSettings()
  local current_config = self:backup()
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
    logger.dbg("AIRPLANEMODE: retrieving list of plugins to disable")
    local check_plugins = U:readAPMplugins(settings.koreader_plugins, settings.airplanemode)
    logger.dbg("AIRPLANEMODE: retrieving list of already disabled plugins")
    local disabled_plugins = U:readAPMsetting("plugins_disabled", settings.koreader) or {}
    -- a pair of loops for the logger
    if type(check_plugins) == "string" then
      if disabled_plugins[check_plugins] ~= true then
        disabled_plugins[check_plugins] = true
        logger.dbg("AIRPLANEMODE: Disabling [string]", check_plugins)
      end
    else
      for plugin, _ in pairs(check_plugins) do
        logger.dbg("AIRPLANEMODE: Disabling", plugin)
        if disabled_plugins[plugin] ~= true then
          logger.dbg("AIRPLANEMODE: Disabling", plugin, "was true")
          -- Check the current plugin  for status and stop if necessary
          local modcheck = self.ui[plugin]
          -- if the passed name was a plugin continue
          if modcheck and (type(modcheck) == "table") then
            -- if the passed plugin has either a stop or stopPlugin method
            logger.dbg("AIRPLANEMODE: checking stop method for", plugin)
            local stopmethod = type(modcheck["stop"]) == "function"
            local stopPluginmethod = type(modcheck["stopPlugin"]) == "function"
            if stopmethod or stopPluginmethod then
              -- The plugin has a stop method
              logger.dbg("AIRPLANEMODE: stop method found for", plugin)

              if type(modcheck["isRunning"]) == "function" then
                -- The plugin has an isRunning method - use that to determine if we should try and stop it
                logger.dbg("AIRPLANEMODE: isRunning method found for", plugin)
                local status, __ = pcall(function()
                  pcall(modcheck["isRunning"]())
                end)
                -- if the status came back that the plugin was running
                if H.stringto(status) == true then
                  -- try to run stopPlugin if available since it's cleaner
                  logger.dbg("AIRPLANEMODE: isRunning returned true, trying to stop", plugin)
                  stopOtherPlugins(stopPluginmethod, modcheck, plugin)
                end
              else
                -- stop methods were found but no isRunning, so we'll just try to run stop and hope
                logger.dbg("AIRPLANEMODE: no isRunning method found, trying to stop", plugin)
                stopOtherPlugins(stopPluginmethod, modcheck, plugin)
              end
            end
          end
          -- After our attempts to stop, go ahead and mark the plugin disabled.
          -- Moved to the end to avoid confusion if for some reason we crash
          -- attempting to stop a plugin.
          logger.dbg("AIRPLANEMODE: marking stopped:", plugin)
          disabled_plugins[plugin] = true
        end
      end
    end
    logger.dbg("AIRPLANEMODE: Saving", disabled_plugins)
    U:saveAPMsetting("plugins_disabled", disabled_plugins, settings.koreader)

    -- exclude anything without getNetworkInterfaceName - like android - since we can't control their wifi
    if
      (NetworkMgr:getNetworkInterfaceName() or Device:isEmulator())
      and ((U:APMhasNot("managewifi", settings.airplanemode)) or (U:APMhas("managewifi", settings.airplanemode) and U:APMnilOrFalse("managewifi", settings.airplanemode)))
    then
      logger.dbg("AIRPLANEMODE: disabling wifi")
      A:disableWifi(settings)
    end
    ----- temp
    -- mark airplane as active
    logger.dbg("AIRPLANEMODE: marking airplane as active")
    self.dumpSettings()
    P:toggleAirPlaneMode(settings, true)
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

        -- UIManager:askForRestart(_("KOReader needs to restart to finish applying changes for AirPlaneMode."))
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

  P:toggleAirPlaneMode(settings, false)
  self:dumpSettings()
  logger.dbg("AIRPLANEMODE: re-enabled, restoring network next")
  -- If managing wifi, revert settingss
  if
    (NetworkMgr:getNetworkInterfaceName() or Device:isEmulator())
    and ((U:APMhasNot("managewifi", settings.airplanemode)) or (U:APMhas("managewifi", settings.airplanemode) and U:APMnilOrFalse("managewifi", settings.airplanemode)))
  then
    logger.dbg("AIRPLANEMODE: re-enabling wifi")
    A:reenableWifi(settings)
  end

  P:enableCalibre(settings)

  logger.dbg("AIRPLANEMODE: Reading APM plugins")
  local apm_disabled = U:readAPMplugins(settings.koreader_plugins, settings.airplanemode)
  -- create a list of what is currently disabled
  logger.dbg("AIRPLANEMODE: Reading previous plugins_disabled setting")
  local previously_disabled = U:readAPMsetting("plugins_disabled", settings.backup) or {}
  -- Build the list of plugins disabled right now
  logger.dbg("AIRPLANEMODE: Reading current plugins_disabled setting")
  local currently_disabled = U:readAPMsetting("plugins_disabled", settings.koreader) or {}
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
    U:saveAPMsetting("plugins_disabled", to_disable, settings.koreader)
  end

  logger.dbg("AIRPLANEMODE: restoring plugin settings")
  P:restorePluginSettings(settings)
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

function AirPlaneMode:getConfigMenuItems()
  local airplane_config_table = {}
  local airmode = self:getStatus()

  if airmode then
    table.insert(airplane_config_table, {
      text = T(_("%1  Plugin management suspended while in flight"), icon_on),
      enabled = false,
    })
  else
    table.insert(airplane_config_table, {
      text = _("Manage Builtin Plugins"),
      help_text = _("Checked plugins will be disabled when AirPlaneMode is enabled."),
      sub_item_table_func = function()
        return self:PluginMenu(true, settings)
      end,
    })

    table.insert(airplane_config_table, {
      text = _("Manage User Added Plugins"),
      help_text = _("Checked plugins will be disabled when AirPlaneMode is enabled."),
      sub_item_table_func = function()
        return self:PluginMenu(false, settings)
      end,
    })
  end
  table.insert(airplane_config_table, {
    text = _("Silence the restart message"),
    callback = function()
      U:APMtoggle("silentmode", settings.airplanemode)
    end,
    checked_func = function()
      if U:APMisTrue("silentmode", settings.airplanemode) then
        return true
      else
        return false
      end
    end,
    enabled_func = function()
      if Device:canRestart() then
        return true
      else
        return false
      end
    end,
  })
  table.insert(airplane_config_table, {
    text = _("Show AirPlaneMode in reader footer"),
    checked_func = function()
      if self.show_value_in_footer then
        return true
      else
        return false
      end
    end,
    callback = function()
      self.show_value_in_footer = not self.show_value_in_footer
      U:saveAPMsetting("airplanemode_in_footer", self.show_value_in_footer, settings.airplanemode)
      if self.show_value_in_footer then
        self:addAdditionalFooterContent()
      else
        self:removeAdditionalFooterContent()
      end
    end,
  })
  if Device:canRestart() then
    table.insert(airplane_config_table, {
      text = _("Restore session after restart"),
      callback = function()
        if self:getStatus() then
          UIManager:show(InfoMessage:new({
            text = _("You cannot change the restore option while AirPlaneMode is in flight."),
            timeout = 3,
          }))
        else
          U:APMtoggle("restoreopt", settings.airplanemode)
        end
      end,
      checked_func = function()
        if U:APMisTrue("restoreopt", settings.airplanemode) then
          return true
        else
          return false
        end
      end,
    })
  end

  table.insert(airplane_config_table, {
    text = _("Roaming Mode"),
    callback = function()
      U:APMtoggle("managewifi", settings.airplanemode)
    end,
    help_text = _("AirPlaneMode will only manage settings, not the wifi device"),
    checked_func = function()
      if U:APMhas("managewifi", settings.airplanemode) and U:APMisTrue("managewifi", settings.airplanemode) then
        return true
      else
        return false
      end
    end,
    enabled_func = function()
      if NetworkMgr:getNetworkInterfaceName() or Device:isEmulator() then
        return true
      else
        if not U:APMisTrue("managewifi", settings.airplanemode) then
          U:APMmakeTrue("managewifi", settings.airplanemode)
        end
        return false
      end
    end,
  })
  return airplane_config_table
end

function AirPlaneMode.PluginMenu(self, builtin, settings)
  logger.dbg("AIRPLANEMODE: PluginMenu - builtin: ", builtin)
  local plugin_list = P:getPlugins(builtin, settings)
  local plugin_menu = P:menuBuilder(builtin, plugin_list, settings)
  return plugin_menu
end

function AirPlaneMode:addToMainMenu(menu_items)
  local airmode = self:getStatus()
  menu_items.airplanemode = {
    text_func = function()
      if airmode then
        return T(_("%1 AirplaneMode"), icon_on)
      else
        return T(_("%1 AirplaneMode"), icon_off)
      end
    end,
    help_text = T(_("A simple plugin that helps you when you're on the go.\n\n\nv.%1"), meta.version),
    sorting_hint = "network",
    sub_item_table = {
      {
        text_func = function()
          local curversion = U:readAPMsetting("version", settings.airplanemode)
          if (curversion == nil) or (curversion ~= meta.version) then
            U:saveAPMsetting("version", meta.version, settings.airplanemode)
          end
          if airmode then
            return T(_("%1 Disable AirPlaneMode"), icon_on)
          else
            return T(_("%1 Enable AirPlaneMode"), icon_off)
          end
        end,
        separator = true,
        callback = function()
          if airmode then
            --airplanemode = true
            self:Disable()
          else
            --airplanemode = false
            self:Enable()
          end
        end,
      },
      {
        text = _("Configuration"),
        sub_item_table_func = function()
          return self:getConfigMenuItems()
        end,
      },
    },
  }
end

return AirPlaneMode
