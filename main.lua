local ConfirmBox = require("ui/widget/confirmbox")
local DataStorage = require("datastorage")
local Device = require("device")
local Dispatcher = require("dispatcher")
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

local meta = require("_meta")

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
  local apm_settings = LuaSettings:open(airplanemode_config)
  -- we just rebooted to change apm states, now switch pref back
  local last_start = apm_settings:readSetting("restartMode")
  if apm_settings:isTrue("restoreopt") then
    if last_start ~= nil then
      G_reader_settings:saveSetting("start_with", last_start)
      apm_settings:saveSetting("restartMode", nil)
    end
    apm_settings:flush()
    apm_settings:close()
    G_reader_settings:flush()
  end
end

local function saveState(name)
  -- grab the current startup mode
  local cur_start = G_reader_settings:readSetting("start_with")
  local apm_settings = LuaSettings:open(airplanemode_config)
  local ui_mode
  -- figure out where we are./
  if string.match(name, "reader") then
    ui_mode = "last"
  elseif string.match(name, "filemanager") then
    ui_mode = "filemanager"
  end
  if ui_mode ~= nil then
    -- save that state in our config
    apm_settings:saveSetting("restartMode", cur_start)
    -- set our new restart mode
    G_reader_settings:saveSetting("start_with", ui_mode)
  end
  apm_settings:flush()
  apm_settings:close()
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

function AirPlaneMode:onDispatcherRegisterActions()
  Dispatcher:registerAction("airplanemode_enable", { category = "none", event = "Enable", title = _("AirPlane Mode Enable"), device = true })
  Dispatcher:registerAction("airplanemode_disable", { category = "none", event = "Disable", title = _("AirPlane Mode Disable"), device = true })
  Dispatcher:registerAction("airplanemode_toggle", { category = "none", event = "Toggle", title = _("AirPlane Mode Toggle"), device = true, separator = true })
end

function AirPlaneMode:init()
  self:onDispatcherRegisterActions()
  if isFile(DataStorage:getDataDir() .. "/settings/airplane_plugins.lua") then
    self:migrateconfig()
  else
    self:initSettingsFile()
  end
  self.ui.menu:registerToMainMenu(self)
end

function AirPlaneMode:initSettingsFile()
  if isFile(airplanemode_config) == true then
    return
  else
    local apm_settings = LuaSettings:open(airplanemode_config)
    apm_settings:saveSetting("version", meta.version)
    local default_disable = {}
    local default_disable_list = { "newsdownloader", "wallabag", "kosync", "opds", "SSH", "timesync", "httpinspector" }
    for __, plugin in ipairs(default_disable_list) do
      default_disable[plugin] = true
    end
    apm_settings:saveSetting("disabled_plugins", default_disable)
    apm_settings:flush()
    apm_settings:close()
  end
end

function AirPlaneMode:migrateconfig()
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

function AirPlaneMode:backup()
  if isFile(settings_file) then
    if isFile(settings_bk) then
      os.remove(settings_bk)
    end
    ffiutil.copyFile(settings_file, settings_bk)
    return isFile(settings_bk) and true or false
  else
    logger.err("AirPlaneMode: Failed to find settings file at: ", settings_file)
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
  if stopp then
    local mstatus, merr = pcall(function()
      pcall(fplugin["stopPlugin"]())
    end)
    if stringto(mstatus) == false then
      -- stopPlugin failed, just do a normal stop
      local sstatus, serr = pcall(function()
        pcall(fplugin["stop"]())
      end)
      if stringto(sstatus) == false then
        logger.err("AirPlaneMode: Failed to stop", plugin, ":", serr)
      end
    end
  else
    -- no stopPlugin, fallback to regular stop
    local sstatus, serr = pcall(function()
      pcall(fplugin["stop"]())
    end)
    if stringto(sstatus) == false then
      logger.err("AirPlaneMode: Failed to stop", plugin, ":", serr)
    end
  end
end

local function split(str)
  local t = {}
  local i = 0
  for v in string.gmatch(str, '.') do
    if v ~= "." then
      t[i] = v
      i = i + 1
    end
  end
  return (t)
end
--[[
compare versions - return true means current is greater, false older
]]
local function compareversions(old, new)
  local oldv = split(old)
  local newv = split(new)
  if oldv[0] > newv[0] then
    return false
  elseif oldv[1] > newv[1] then
    return false
  elseif oldv[2] > newv[2] then
    return false
  else
    return true
  end
end


function AirPlaneMode:Enable()
  local current_config = self:backup()
  if current_config then
    self:initSettingsFile()
    -- mark airplane as active
    G_reader_settings:saveSetting("airplanemode", true)

    -- [[ disable plugins, wireless, all of it ]]

    -- instead of disabling the calibre plugin, just disable the wireless part -  this lets you still search
    if G_reader_settings:nilOrTrue("calibre_wireless") then
      G_reader_settings:makeFalse("calibre_wireless")
    end

    local apm_settings = LuaSettings:open(airplanemode_config)
    local check_plugins = apm_settings:readSetting("disabled_plugins") or {}
    local disabled_plugins = G_reader_settings:readSetting("plugins_disabled") or {}

    -- a pair of loops for the logger
    if type(check_plugins) == "string" then
      if disabled_plugins[check_plugins] ~= true then
        disabled_plugins[check_plugins] = true
        -- logger.dbg("Disabling", check_plugins)
      end
    else
      for plugin, __ in pairs(check_plugins) do
        if disabled_plugins[plugin] ~= true then
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
                local status, err = pcall(function()
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
    -- logger.dbg("AIRPLANE: Saving", disabled_plugins)
    G_reader_settings:saveSetting("plugins_disabled", disabled_plugins)
    G_reader_settings:flush()

    -- exclude anything without getNetworkInterfaceName - like android - since we can't control their wifi
    if (NetworkMgr:getNetworkInterfaceName() or Device:isEmulator()) and apm_settings:nilOrFalse("managewifi") then
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
      end

      -- According to network manager, this setting always has a value and defaults to prompt
      local wifi_disable_action_setting = G_reader_settings:readSetting("wifi_disable_action") or "prompt"
      if wifi_disable_action_setting ~= "turn_off" then
        G_reader_settings:saveSetting("wifi_disable_action", "turn_off")
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
      if apm_settings:isTrue("restoreopt") then
        saveState(self.name)
      end
      if apm_settings:nilOrFalse("silentmode") then
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
    logger.err("AirPlaneMode: Failed to create backup file and execute")
  end
end

function AirPlaneMode:Disable()
  local apm_settings = LuaSettings:open(airplanemode_config)
  local BK_Settings = LuaSettings:open(settings_bk)

  -- disable airplane mode
  G_reader_settings:saveSetting("airplanemode", false)

  -- If managing wifi, revert settingss
  if (NetworkMgr:getNetworkInterfaceName() or Device:isEmulator()) and apm_settings:nilOrFalse("managewifi") then
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
    end

    -- According to network manager, this setting always has a value and defaults to prompt
    if BK_Settings:hasNot("wifi_disable_action") then
      G_reader_settings:delSetting("wifi_disable_action")
    else
      local bk_wifi_disable_action_setting = BK_Settings:readSetting("wifi_disable_action") or "prompt"
      G_reader_settings:saveSetting("wifi_disable_action", bk_wifi_disable_action_setting)
    end

    -- got to watch out for our emulator friends :) (ie, me, testing)
    if Device:isEmulator() and BK_Settings:has("emulator_fake_wifi_connected") then
      local old_emulator_fake_wifi_connected = BK_Settings:readSetting("emulator_fake_wifi_connected")
      -- flip the real config
      G_reader_settings:saveSetting("emulator_fake_wifi_connected", old_emulator_fake_wifi_connected)
    else
      G_reader_settings:delSetting("emulator_fake_wifi_connected")
    end

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

  -- re-enable calibre wirless if it was before
  if not BK_Settings:isFalse("calibre_wireless") then
    G_reader_settings:makeTrue("calibre_wireless")
  end

  -- first remove *everything* currently disabled

  -- create a list of what is currently disabled
  local currently_disabled = G_reader_settings:readSetting("plugins_disabled") or {}
  -- create a list of what apm disabled
  local apm_disabled = apm_settings:readSetting("disabled_plugins") or {}

  -- Build the list of plugins disabled right now
  local to_disable = {}
  if type(currently_disabled) == "string" then
    to_disable = { currently_disabled }
  elseif type(currently_disabled) == "table" then
    to_disable = currently_disabled
  end
  -- Remove plugins that were added by airplane mode
  for plugin, __ in pairs(apm_disabled) do
    if to_disable[plugin] == true then
      to_disable[plugin] = nil
    end
  end

  if not next(to_disable) then
    -- We now have an empty list - the only disabled plugins were the ones added by APM
    G_reader_settings:delSetting("plugins_disabled")
  else
    -- Save the updated list of disabled plugins
    G_reader_settings:saveSetting("plugins_disabled", to_disable)
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
  if Device:canRestart() then
    if apm_settings:isTrue("restoreopt") then
      saveState(self.name)
    end
    if apm_settings:nilOrFalse("silentmode") then
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

function AirPlaneMode:getStatus()
  -- test we can see the real settings file.
  if not isFile(settings_file) then
    logger.err("AirPlaneMode: Settings file not found! Abort!", settings_file)
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

-- Lifted whole from pluginloader because it was the only way to dup the function :/
local function getMenuTable(plugin)
  local t = {}
  t.name = plugin.name
  t.fullname = string.format("%s", plugin.fullname or plugin.name)
  t.description = string.format("%s", plugin.description)
  return t
end

function AirPlaneMode:getConfigMenuItems()
  local apm_settings = LuaSettings:open(airplanemode_config)
  local airplane_config_table = {}
  local airmode = self:getStatus()

  table.insert(airplane_config_table,
    {
      text = _("AirPlane Mode Plugin Manager"),
      sub_item_table_func = function()
        if airmode then
          UIManager:show(InfoMessage:new({
            text = _("AirPlane Mode cannot be configured while running"),
            timeout = 3,
          }))
        else
          return self:getSubMenuItems()
        end
      end,
    }
  )
  table.insert(airplane_config_table,
    {
      text = _("Silence the restart message"),
      callback = function()
        apm_settings:toggle("silentmode")
        apm_settings:flush()
      end,
      checked_func = function()
        if apm_settings:isTrue("silentmode") then
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
    }
  )
  table.insert(airplane_config_table,
    {
      text = _("Restore session after restart [EXPERIMENTAL]"),
      callback = function()
        apm_settings:toggle("restoreopt")
        apm_settings:flush()
      end,
      checked_func = function()
        if apm_settings:isTrue("restoreopt") then
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
    }
  )
  table.insert(airplane_config_table,
    {
      text = _("Roaming Mode [EXPERIMENTAL]"),
      callback = function()
        apm_settings:toggle("managewifi")
        apm_settings:flush()
      end,
      help_text = _("Disable managing the WiFi device when AirPlane Mode is engaged."),
      checked_func = function()
        if apm_settings:isTrue("managewifi") then
          return true
        else
          return false
        end
      end,
      enabled_func = function()
        if (NetworkMgr:getNetworkInterfaceName() or Device:isEmulator()) then
          return true
        else
          if not apm_settings:isTrue("managewifi") then
            apm_settings:makeTrue("managewifi")
            apm_settings:flush()
          end
          return false
        end
      end,
    }
  )
  return airplane_config_table
end

function AirPlaneMode:getSubMenuItems()
  local apm_settings = LuaSettings:open(airplanemode_config)
  local check_plugins = apm_settings:readSetting("disabled_plugins") or {}
  local os_enabled_plugins, os_disabled_plugins = PluginLoader:loadPlugins()
  local os_all_plugins = {}

  --Loop through os plugins that are enabled and mark that
  for _, plugin in ipairs(os_enabled_plugins) do
    local element = getMenuTable(plugin)
    element.enable = true
    table.insert(os_all_plugins, element)
  end
  -- first loop through disabled plugins and mark them in our own file if they don't already exist
  for _, plugin in ipairs(os_disabled_plugins) do
    local element = getMenuTable(plugin)
    if not check_plugins[plugin.name] then
      check_plugins[element.name] = true
    end
    element.enable = nil
    table.insert(os_all_plugins, element)
  end

  table.sort(os_all_plugins, function(v1, v2)
    return v1.fullname < v2.fullname
  end)

  local airplane_plugin_table = {}
  for __, plugin in ipairs(os_all_plugins) do
    if plugin.name ~= "airplanemode" then
      table.insert(airplane_plugin_table, {
        text = _(plugin.fullname),
        checked_func = function()
          return check_plugins[plugin.name]
        end,
        enabled_func = function()
          if (plugin.enable == false) or (plugin.enable == nil) then
            return false
          else
            return true
          end
        end,
        callback = function()
          if check_plugins[plugin.name] then
            check_plugins[plugin.name] = nil
            -- logger.dbg("Disabled ", plugin.name)
            apm_settings:saveSetting("disabled_plugins", check_plugins)
            apm_settings:flush()
          else
            check_plugins[plugin.name] = true
            -- logger.dbg("Enabled ", plugin.name)
            apm_settings:saveSetting("disabled_plugins", check_plugins)
            apm_settings:flush()
          end
        end,
        help_text = T(_("%1\n\nThis plugin is already disabled in KOReader"), plugin.description),
      })
    end
  end
  apm_settings:flush()
  apm_settings:close()
  return airplane_plugin_table
end

function AirPlaneMode:addToMainMenu(menu_items)
  local apm_settings = LuaSettings:open(airplanemode_config)
  local airmode = self:getStatus()
  menu_items.airplanemode = {
    text_func = function()
      if airmode then
        return _("\u{F1D8} Airplane Mode")
      else
        return _("\u{F1D9} Airplane Mode")
      end
    end,
    help_text = T(_("A simple plugin that helps you when you're on the go.\n\n\nv.%1"), meta.version),
    sorting_hint = "network",
    sub_item_table = {
      {
        text_func = function()
          local curversion = apm_settings:readSetting("version")
          if (curversion ~= nil) and (curversion ~= meta.version) then
            if compareversions(curversion, meta.version) then
              apm_settings:saveSetting("version", meta.version)
              apm_settings:flush()
            else
              UIManager:show(InfoMessage:new({
                text = T(_("You are running a version of AirPlane Mode older than your configuration file. You may experience issues.")),
                timeout = 3,
              }))
            end
          end
          if airmode then
            return _("\u{F1D8} Disable AirPlane Mode")
          else
            return _("\u{F1D9} Enable AirPlane Mode")
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
