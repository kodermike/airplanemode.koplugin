local ConfirmBox = require("ui/widget/confirmbox")
local DataStorage = require("datastorage")
local Device = require("device")
local Dispatcher = require("dispatcher")
local Event = require("ui/event")
local InfoMessage = require("ui/widget/infomessage")
local LuaSettings = require("luasettings")
local NetworkMgr = require("ui/network/manager")
local PluginLoader = require("pluginloader")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local ffiutil = require("ffi/util")
local T = ffiutil.template
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local _ = require("gettext")
local PluginChecker = require("modules/pluginchecker")

local meta = require("_meta")

local U = require("modules/utilities")

local icon_on = "\u{F1D8}"
local icon_off = "\u{F1D9}"

local settings_file = DataStorage:getDataDir() .. "/settings.reader.lua"
local settings_bk = DataStorage:getDataDir() .. "/settings.reader.lua.airplane"
local settings_bk_exists = false

local airplanemode_config = DataStorage:getDataDir() .. "/settings/airplanemode.lua"

-- establish the main settings file
if G_reader_settings == nil then
  G_reader_settings = LuaSettings:open(settings_file)
end

local function restoreState()
  -- grab the current startup mode
  -- we just rebooted to change apm states, now switch pref back
  local last_start = U:readAPMsetting("restartMode")
  if U:APMisTrue("restoreopt") then
    if last_start ~= nil then
      G_reader_settings:saveSetting("start_with", last_start)
      U:saveAPMsetting("restartMode", nil)
    end
    G_reader_settings:flush()
  end
end

local function saveState(name)
  -- grab the current startup mode
  local cur_start = G_reader_settings:readSetting("start_with")
  local ui_mode
  -- figure out where we are./
  if string.match(name, "reader") then
    ui_mode = "last"
  elseif string.match(name, "filemanager") then
    ui_mode = "filemanager"
  end
  if ui_mode ~= nil then
    -- save that state in our config
    U:saveAPMsetting("restartMode", cur_start)
    -- set our new restart mode
    G_reader_settings:saveSetting("start_with", ui_mode)
  end
  G_reader_settings:flush()
end

restoreState()

local AirPlaneMode = WidgetContainer:extend({
  name = "airplanemode",
  is_doc_only = false,
})

local function isFile(filename)
  if filename and (lfs.attributes(filename, "mode") == "file") then
    return true
  end
  return false
end

function AirPlaneMode.getStatus()
  -- test we can see the real settings file.
  if not isFile(settings_file) then
    logger.err("AIRPLANEMODE: Settings file not found! Abort!", settings_file)
    return false
  end
  -- check if we currently have a backup of our settings running
  settings_bk_exists = isFile(settings_bk) or false

  -- also verify if the airplanemode flag is set. we will use this to decide if something is funky
  local airplanemode_active = G_reader_settings:readSetting("airplanemode") or false
  if settings_bk_exists and airplanemode_active then
    return true
  elseif not airplanemode_active then
    return false
  end
  return false
end

function AirPlaneMode.onDispatcherRegisterActions()
  Dispatcher:registerAction("airplanemode_enable", { category = "none", event = "Enable", title = _("AirPlane Mode Enable"), device = true })
  Dispatcher:registerAction("airplanemode_disable", { category = "none", event = "Disable", title = _("AirPlane Mode Disable"), device = true })
  Dispatcher:registerAction("airplanemode_toggle", { category = "none", event = "Toggle", title = _("AirPlane Mode Toggle"), device = true, separator = true })
end

function AirPlaneMode:init()
  self:onDispatcherRegisterActions()
  if isFile(DataStorage:getDataDir() .. "/settings/airplane_plugins.lua") then
    self:migrateconfig()
  else
    if not isFile(airplanemode_config) then
      self:initSettingsFile()
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
  self.show_value_in_footer = G_reader_settings:readSetting("airplanemode_in_footer")
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
  if isFile(airplanemode_config) == true then
    logger.dbg("AIRPLANEMODE: initSettingsFile - file exists, skipping: ", airplanemode_config)
    return
  else
    -- Only write defaults if the setting is not already present (avoid clobbering)
    local cur_disabled = U:readAPMplugins()
    if cur_disabled ~= nil then
      logger.dbg("AIRPLANEMODE: initSettingsFile - disabled_plugins already present, skipping. traceback:\n", debug.traceback())
      return
    end

    U:saveAPMsetting("version", meta.version)
    local default_disable = {}
    local default_disable_list = { "newsdownloader", "wallabag", "kosync", "opds", "SSH", "timesync", "httpinspector" }
    for __, plugin in ipairs(default_disable_list) do
      default_disable[plugin] = true
    end
    logger.dbg("AIRPLANEMODE: Saving default settings to ", airplanemode_config, " at ", os.time(), "\nstack:\n", debug.traceback())
    U:saveAPMsetting("disabled_plugins", default_disable)
  end
end

function AirPlaneMode.dumpSettings()
  -- Short-lived verification: read on-disk file contents and log them
  local fh = io.open(airplanemode_config, "r")
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
  local old_config_file = DataStorage:getDataDir() .. "/settings/airplane_plugins.lua"
  local old_config = LuaSettings:open(old_config_file)
  local new_config = LuaSettings:open(airplanemode_config)
  new_config:saveSetting("version", meta.version)
  local disabled = old_config:readSetting("disabled_plugins")
  if disabled then
    if disabled["calibre"] then
      disabled["calibre"] = nil
    end
    new_config:saveSetting("disabled_plugins", disabled)
  end
  new_config:flush()
  old_config:close()
  -- I know, why wouldn't it be there, but caution always
  if isFile(old_config_file) then
    os.remove(old_config_file)
  end
end

-- hook for stopPlugin support
--[[--
NOTE: Because of the changes AirPlaneMode makes to KOReader, it is not possible to re-enable everything if being called from outside of AirPlaneMode. This hook will disable AirPlaneMode and reset setting for disabled plugins, but cannot restart wifi or the device.
--]]
--
function AirPlaneMode.stopPlugin()
  local BK_Settings = LuaSettings:open(settings_bk)
  -- disable airplane mode
  G_reader_settings:saveSetting("airplanemode", false)
  G_reader_settings:flush()

  -- If managing wifi, revert settingss
  if NetworkMgr:getNetworkInterfaceName() or Device:isEmulator() then
    if Device:hasWifiRestore() and BK_Settings:isTrue("auto_restore_wifi") then
      G_reader_settings:makeTrue("auto_restore_wifi")
    end

    if BK_Settings:nilOrFalse("auto_disable_wifi") then
      -- flip the real config
      G_reader_settings:flipNilOrFalse("auto_disable_wifi")
    end

    -- According to network manager, this setting always has a value and defaults to prompt
    if BK_Settings:hasNot("wifi_enable_action") then
      G_reader_settings:delSetting("wifi_enable_action")
    else
      local bk_wifi_enable_action_setting = BK_Settings:readSetting("wifi_enable_action") or "prompt"
      G_reader_settings:saveSetting("wifi_enable_action", bk_wifi_enable_action_setting)
      G_reader_settings:flush()
    end

    -- According to network manager, this setting always has a value and defaults to prompt
    if BK_Settings:hasNot("wifi_disable_action") then
      G_reader_settings:delSetting("wifi_disable_action")
    else
      local bk_wifi_disable_action_setting = BK_Settings:readSetting("wifi_disable_action") or "prompt"
      G_reader_settings:saveSetting("wifi_disable_action", bk_wifi_disable_action_setting)
      G_reader_settings:flush()
    end

    -- got to watch out for our emulator friends :) (ie, me, testing)
    if Device:isEmulator() and BK_Settings:has("emulator_fake_wifi_connected") then
      local old_emulator_fake_wifi_connected = BK_Settings:readSetting("emulator_fake_wifi_connected")
      -- flip the real config
      G_reader_settings:saveSetting("emulator_fake_wifi_connected", old_emulator_fake_wifi_connected)
    else
      G_reader_settings:delSetting("emulator_fake_wifi_connected")
    end
    G_reader_settings:flush()

    if BK_Settings:isTrue("http_proxy_enabled") then
      -- flip the real config
      G_reader_settings:makeTrue("http_proxy_enabled")
    end

    --if NetworkMgr:getWifiState() == false and BK_Settings:isTrue("wifi_was_on") then
    if BK_Settings:hasNot("wifi_was_on") then
      G_reader_settings:delSetting("wifi_was_on")
    elseif BK_Settings:isTrue("wifi_was_on") then
      G_reader_settings:makeTrue("wifi_was_on")
      NetworkMgr:enableWifi(nil, true)
    end
  end
  -- re-set calibre_wirless to previous setting, or delete it if it didn't exist
  if BK_Settings:isTrue("calibre_wireless") then
    G_reader_settings:makeTrue("calibre_wireless")
  elseif BK_Settings:isFalse("calibre_wireless") then
    G_reader_settings:makeFalse("calibre_wireless")
  else
    G_reader_settings:delSetting("calibre_wireless")
  end

  local apm_disabled = U:readAPMplugins()
  -- create a list of what is currently disabled
  local previously_disabled = BK_Settings:readSetting("plugins_disabled") or {}
  -- Build the list of plugins disabled right now
  local currently_disabled = G_reader_settings:readSetting("plugins_disabled") or {}
  local to_disable = {}

  -- loop currently disabled items
  for plugin, __ in pairs(currently_disabled) do
    -- if airplane mode disabled it and it was disabled before, keep it disabled
    if apm_disabled[plugin] and previously_disabled[plugin] then
      to_disable[plugin] = true
      -- if it wasn't disabled in airplanemode, keep it disabled
    elseif not apm_disabled[plugin] then
      to_disable[plugin] = true
    end
  end

  if not next(to_disable) then
    -- We now have an empty list - the only disabled plugins were the ones added by APM
    G_reader_settings:delSetting("plugins_disabled")
  else
    -- Save the updated list of disabled plugins
    G_reader_settings:delSetting("plugins_disabled")
    G_reader_settings:saveSetting("plugins_disabled", to_disable)
    G_reader_settings:flush()
  end

  G_reader_settings:flush()
  if isFile(settings_bk) then
    os.remove(settings_bk)
  end
end

-- hook for deleteplugin calls
function AirPlaneMode.deletePluginSettings()
  logger.dbg("AIRPLANEMODE: deletePluginSettings called at ", os.time(), "\nstack:\n", debug.traceback())
  if G_reader_settings:readSetting("airplanemode") then
    UIManager:show(InfoMessage:new({
      text = _("Removing AirPlane Mode while still running. Plugins and networking will not be automatically restored."),
      timeout = 3,
    }))
  end
  if G_reader_settings:has("airplanemode") then
    G_reader_settings:delSetting("airplanemode")
  end
  if G_reader_settings:has("airplanemode_in_footer") then
    G_reader_settings:delSetting("airplanemode_in_footer")
  end
  G_reader_settings:flush()
  if isFile(airplanemode_config) then
    logger.dbg("AIRPLANEMODE: deletePluginSettings removing file: ", airplanemode_config)
    os.remove(airplanemode_config)
  end
  if isFile(airplanemode_config .. ".old") then
    logger.dbg("AIRPLANEMODE: deletePluginSettings removing file: ", airplanemode_config .. ".old")
    os.remove(airplanemode_config .. ".old")
  end
end

function AirPlaneMode.backup()
  if isFile(settings_file) then
    if isFile(settings_bk) then
      os.remove(settings_bk)
    end
    ffiutil.copyFile(settings_file, settings_bk)
    return isFile(settings_bk) and true or false
  else
    logger.err("AIRPLANEMODE: Failed to find settings file at: ", settings_file)
    return false
  end
end

local function stringto(v)
  if type(v) == string and v == "true" then
    return true
  end
  if type(v) == string and v == "false" then
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
    if stringto(mstatus) == false then
      -- stopPlugin failed, just do a normal stop
      local sstatus, serr = pcall(function()
        pcall(fplugin["stop"]())
      end)
      if stringto(sstatus) == false then
        logger.err("AIRPLANEMODE: Failed to stop", plugin, ":", serr)
      end
    end
  else
    -- no stopPlugin, fallback to regular stop
    local sstatus, serr = pcall(function()
      pcall(fplugin["stop"]())
    end)
    if stringto(sstatus) == false then
      logger.err("AIRPLANEMODE: Failed to stop", plugin, ":", serr)
    end
  end
end

function AirPlaneMode:Enable()
  self.dumpSettings()
  local current_config = self:backup()
  self.dumpSettings()
  if current_config then
    -- mark airplane as active
    G_reader_settings:saveSetting("airplanemode", true)
    G_reader_settings:flush()

    -- [[ disable plugins, wireless, all of it ]]

    -- instead of disabling the calibre plugin, just disable the wireless part -  this lets you still search
    if G_reader_settings:nilOrTrue("calibre_wireless") then
      G_reader_settings:makeFalse("calibre_wireless")
    end

    local check_plugins = U:readAPMplugins()
    local disabled_plugins = G_reader_settings:readSetting("plugins_disabled") or {}
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
            local stopmethod = type(modcheck["stop"]) == "function"
            local stopPluginmethod = type(modcheck["stopPlugin"]) == "function"
            if stopmethod or stopPluginmethod then
              -- The plugin has a stop method
              if type(modcheck["isRunning"]) == "function" then
                -- The plugin has an isRunning method - use that to determine if we should try and stop it
                local status, __ = pcall(function()
                  pcall(modcheck["isRunning"]())
                end)
                -- if the status came back that the plugin was running
                if stringto(status) == true then
                  -- try to run stopPlugin if available since it's cleaner
                  stopOtherPlugins(stopPluginmethod, modcheck, plugin)
                end
              else
                -- stop methods were found but no isRunning, so we'll just try to run stop and hope
                stopOtherPlugins(stopPluginmethod, modcheck, plugin)
              end
            end
          end
          -- After our attempts to stop, go ahead and mark the plugin disabled.
          -- Moved to the end to avoid confusion if for some reason we crash
          -- attempting to stop a plugin.
          disabled_plugins[plugin] = true
        end
      end
    end
    logger.dbg("AIRPLANEMODE: Saving", disabled_plugins)
    G_reader_settings:saveSetting("plugins_disabled", disabled_plugins)
    G_reader_settings:flush()

    -- exclude anything without getNetworkInterfaceName - like android - since we can't control their wifi
    if (NetworkMgr:getNetworkInterfaceName() or Device:isEmulator()) and U:APMnilOrFalse("managewifi") then
      --set this regardless of original setting to ensure no resumes
      if Device:hasWifiRestore() then --t
        G_reader_settings:flipNilOrFalse("auto_restore_wifi")
      end

      --G_reader_settings:saveSetting("auto_disable_wifi",true)
      if G_reader_settings:nilOrFalse("auto_disable_wifi") then --f
        G_reader_settings:flipNilOrFalse("auto_disable_wifi")
      end

      -- According to network manager, this setting always has a value and defaults to prompt
      local wifi_enable_action_setting = G_reader_settings:readSetting("wifi_enable_action") or "prompt"
      if wifi_enable_action_setting == "turn_on" then
        G_reader_settings:saveSetting("wifi_enable_action", "prompt")
        G_reader_settings:flush()
      end

      -- According to network manager, this setting always has a value and defaults to prompt
      local wifi_disable_action_setting = G_reader_settings:readSetting("wifi_disable_action") or "prompt"
      if wifi_disable_action_setting ~= "turn_off" then
        G_reader_settings:saveSetting("wifi_disable_action", "turn_off")
        G_reader_settings:flush()
      end

      if Device:isEmulator() and G_reader_settings:isTrue("emulator_fake_wifi_connected") then
        G_reader_settings:flipNilOrFalse("emulator_fake_wifi_connected", false)
      end

      --G_reader_settings:saveSetting("http_proxy_enabled",false)
      if G_reader_settings:isTrue("http_proxy_enabled") then --t
        G_reader_settings:flipNilOrFalse("http_proxy_enabled")
      end

      if NetworkMgr:isWifiOn() then
        NetworkMgr:disableWifi(nil, true)
      end
    end

    G_reader_settings:flush()

    -- Only attempt to save reading state if we are in the reader
    if string.match(self.name, "reader") then
      self.ui:saveSettings()
    end

    if Device:canRestart() then
      if U:APMisTrue("restoreopt") then
        saveState(self.name)
      end
      if U:APMnilOrFalse("silentmode") then
        UIManager:askForRestart(_("KOReader needs to restart to finish applying changes for AirPlane Mode."))
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
  local BK_Settings = LuaSettings:open(settings_bk)

  -- disable airplane mode
  G_reader_settings:saveSetting("airplanemode", false)
  G_reader_settings:flush()

  -- If managing wifi, revert settingss
  if (NetworkMgr:getNetworkInterfaceName() or Device:isEmulator()) and U:APMnilOrFalse("managewifi") then
    if Device:hasWifiRestore() and BK_Settings:isTrue("auto_restore_wifi") then
      G_reader_settings:makeTrue("auto_restore_wifi")
    end

    if BK_Settings:nilOrFalse("auto_disable_wifi") then
      -- flip the real config
      G_reader_settings:flipNilOrFalse("auto_disable_wifi")
    end

    -- According to network manager, this setting always has a value and defaults to prompt
    if BK_Settings:hasNot("wifi_enable_action") then
      G_reader_settings:delSetting("wifi_enable_action")
    else
      local bk_wifi_enable_action_setting = BK_Settings:readSetting("wifi_enable_action") or "prompt"
      G_reader_settings:saveSetting("wifi_enable_action", bk_wifi_enable_action_setting)
      G_reader_settings:flush()
    end

    -- According to network manager, this setting always has a value and defaults to prompt
    if BK_Settings:hasNot("wifi_disable_action") then
      G_reader_settings:delSetting("wifi_disable_action")
    else
      local bk_wifi_disable_action_setting = BK_Settings:readSetting("wifi_disable_action") or "prompt"
      G_reader_settings:saveSetting("wifi_disable_action", bk_wifi_disable_action_setting)
      G_reader_settings:flush()
    end

    -- got to watch out for our emulator friends :) (ie, me, testing)
    if Device:isEmulator() and BK_Settings:has("emulator_fake_wifi_connected") then
      local old_emulator_fake_wifi_connected = BK_Settings:readSetting("emulator_fake_wifi_connected")
      -- flip the real config
      G_reader_settings:saveSetting("emulator_fake_wifi_connected", old_emulator_fake_wifi_connected)
    else
      G_reader_settings:delSetting("emulator_fake_wifi_connected")
    end
    G_reader_settings:flush()

    if BK_Settings:isTrue("http_proxy_enabled") then
      -- flip the real config
      G_reader_settings:makeTrue("http_proxy_enabled")
    end

    --if NetworkMgr:getWifiState() == false and BK_Settings:isTrue("wifi_was_on") then
    if BK_Settings:hasNot("wifi_was_on") then
      G_reader_settings:delSetting("wifi_was_on")
    elseif BK_Settings:isTrue("wifi_was_on") then
      G_reader_settings:makeTrue("wifi_was_on")
      NetworkMgr:enableWifi(nil, true)
    end
  end

  -- re-set calibre_wirless to previous setting, or delete it if it didn't exist
  if BK_Settings:isTrue("calibre_wireless") then
    G_reader_settings:makeTrue("calibre_wireless")
  elseif BK_Settings:isFalse("calibre_wireless") then
    G_reader_settings:makeFalse("calibre_wireless")
  else
    G_reader_settings:delSetting("calibre_wireless")
  end

  local apm_disabled = U:readAPMplugins()

  -- create a list of what is currently disabled
  local previously_disabled = BK_Settings:readSetting("plugins_disabled") or {}
  -- Build the list of plugins disabled right now
  local currently_disabled = G_reader_settings:readSetting("plugins_disabled") or {}
  local to_disable = {}

  -- loop currently disabled items
  for plugin, __ in pairs(currently_disabled) do
    -- if airplane mode disabled it and it was disabled before, keep it disabled
    if apm_disabled[plugin] and previously_disabled[plugin] then
      to_disable[plugin] = true
      -- if it wasn't disabled in airplanemode, keep it disabled
    elseif not apm_disabled[plugin] then
      to_disable[plugin] = true
    end
  end

  if not next(to_disable) then
    -- We now have an empty list - the only disabled plugins were the ones added by APM
    G_reader_settings:delSetting("plugins_disabled")
  else
    -- Save the updated list of disabled plugins
    G_reader_settings:saveSetting("plugins_disabled", to_disable)
    G_reader_settings:flush()
  end

  G_reader_settings:flush()
  if isFile(settings_bk) then
    os.remove(settings_bk)
  end

  -- remove the backup settings file
  settings_bk_exists = false
  if string.match(self.name, "reader") then
    -- regardless of options, if we're in a document then save our position
    self.ui:saveSettings()
  end
  UIManager:unschedule(self.update_status_bars, self)
  if Device:canRestart() then
    if U:APMisTrue("restoreopt") then
      saveState(self.name)
    end
    if U:APMnilOrFalse("silentmode") then
      UIManager:askForRestart(_("KOReader needs to restart to finish disabling plugins for AirPlane Mode."))
    else
      UIManager:restartKOReader()
    end
  else
    UIManager:show(ConfirmBox:new({
      dismissable = false,
      text = _("You will need to restart KOReader to finish disabling AirPlane Mode."),
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
        return self:PluginMenu(true, apm_settings)
      end,
    })

    table.insert(airplane_config_table, {
      text = _("Manage User Added Plugins"),
      help_text = _("Checked plugins will be disabled when AirPlaneMode is enabled."),
      sub_item_table_func = function()
        return self:PluginMenu(false, apm_settings)
      end,
    })
  end
  table.insert(airplane_config_table, {
    text = _("Silence the restart message"),
    callback = function()
      U:APMtoggle("silentmode")
    end,
    checked_func = function()
      if U:APMisTrue("silentmode") then
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
      G_reader_settings:saveSetting("airplanemode_in_footer", self.show_value_in_footer)
      G_reader_settings:flush()
      if self.show_value_in_footer then
        self:addAdditionalFooterContent()
      else
        self:removeAdditionalFooterContent()
      end
    end,
  })
  table.insert(airplane_config_table, {
    text = _("Restore session after restart [EXPERIMENTAL]"),
    callback = function()
      U:APMtoggle("restoreopt")
    end,
    checked_func = function()
      if U:APMisTrue("restoreopt") then
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
    text = _("Roaming Mode [EXPERIMENTAL]"),
    callback = function()
      U:APMtoggle("managewifi")
    end,
    help_text = _("Disable managing the WiFi device when AirPlane Mode is engaged."),
    checked_func = function()
      if U:APMisTrue("managewifi") then
        return true
      else
        return false
      end
    end,
    enabled_func = function()
      if NetworkMgr:getNetworkInterfaceName() or Device:isEmulator() then
        return true
      else
        if not U:APMisTrue("managewifi") then
          U:APMmakeTrue("managewifi")
        end
        return false
      end
    end,
  })
  return airplane_config_table
end

function AirPlaneMode.PluginMenu(self, builtin, settings_handle)
  local plugin_list = PluginChecker:getPlugins(builtin)
  local plugin_menu = PluginChecker:menuBuilder(builtin, plugin_list)
  return plugin_menu
end

function AirPlaneMode:addToMainMenu(menu_items)
  local airmode = self:getStatus()
  menu_items.airplanemode = {
    text_func = function()
      if airmode then
        return T(_("%1 Airplane Mode"), icon_on)
      else
        return T(_("%1 Airplane Mode"), icon_off)
      end
    end,
    help_text = T(_("A simple plugin that helps you when you're on the go.\n\n\nv.%1"), meta.version),
    sorting_hint = "network",
    sub_item_table = {
      {
        text_func = function()
          local curversion = U:readAPMsetting("version")
          if (curversion == nil) or (curversion ~= meta.version) then
            U:saveAPMsetting("version", meta.version)
          end
          if airmode then
            return T(_("%1 Disable AirPlane Mode"), icon_on)
          else
            return T(_("%1 Enable AirPlane Mode"), icon_off)
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
        text = _("Configuration Menu"),
        sub_item_table_func = function()
          return self:getConfigMenuItems()
        end,
      },
    },
  }
end

return AirPlaneMode
