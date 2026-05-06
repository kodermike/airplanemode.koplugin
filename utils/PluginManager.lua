--[[
PluginManager module for AirplaneMode
]]
local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")
local PluginLoader = require("pluginloader")
local ffiutil = require("ffi/util")

local T = ffiutil.template

local logger = require("logger")
local _ = require("gettext")

local APMConfig = require("utils/APMConfig")

local airplanemode_config = DataStorage:getDataDir() .. "/settings/airplanemode.lua"

local BUILTIN_PLUGINS = {
  ["archiveviewer"] = true,
  ["autodim"] = true,
  ["autostandby"] = true,
  ["autosuspend"] = true,
  ["autoturn"] = true,
  ["autowarmth"] = true,
  ["batterystat"] = true,
  ["bookshortcuts"] = true,
  ["calibre"] = true,
  ["cloudstorage"] = true,
  ["coverbrowser"] = true,
  ["coverimage"] = true,
  ["docsettingtweak"] = true,
  ["exporter"] = true,
  ["externalkeyboard"] = true,
  ["gestures"] = true,
  ["hello"] = true,
  ["hotkeys"] = true,
  ["httpinspector"] = true,
  ["japanese"] = true,
  ["keepalive"] = true,
  ["kosync"] = true,
  ["movetoarchive"] = true,
  ["newsdownloader"] = true,
  ["opds"] = true,
  ["perceptionexpander"] = true,
  ["profiles"] = true,
  ["qrclipboard"] = true,
  ["readtimer"] = true,
  ["SSH"] = true,
  ["statistics"] = true,
  ["systemstat"] = true,
  ["terminal"] = true,
  ["texteditor"] = true,
  ["timesync"] = true,
  ["vocabbuilder"] = true,
  ["wallabag"] = true,

}
local apm_settings = LuaSettings:open(airplanemode_config)
local check_plugins = apm_settings:readSetting("disabled_plugins") or {}


local PluginManager = {}

-- Lifted whole from pluginloader because it was the only way to dup the function :/
local function getPluginInfo(plugin)
  local t = {}
  t.name = plugin.name
  t.fullname = string.format("%s", plugin.fullname or plugin.name)
  t.description = string.format("%s", plugin.description)
  return t
end

function PluginManager:getPlugins(builtin)
  local os_enabled_plugins, os_disabled_plugins = PluginLoader:loadPlugins()
  local plugin_list = {}

  --Loop through os plugins that are enabled and mark that
  for _, plugin in ipairs(os_enabled_plugins) do
    local element = getPluginInfo(plugin)
    element.enable = true
    if builtin then
      if BUILTIN_PLUGINS[plugin.name] == true then
        table.insert(plugin_list, element)
      end
    else
      if BUILTIN_PLUGINS[plugin.name] == nil then
        table.insert(plugin_list, element)
      end
    end
  end
  -- first loop through disabled plugins and mark them in our own file if they don't already exist
  for _, plugin in ipairs(os_disabled_plugins) do
    local element = getPluginInfo(plugin)
    if not check_plugins[plugin.name] then
      check_plugins[element.name] = true
    end
    element.enable = nil
    table.insert(plugin_list, element)
  end
  table.sort(plugin_list, function(a, b) return a.fullname < b.fullname end)
  return plugin_list
end

function PluginManager:restorePluginSettings(settings)
  local backups = LuaSettings:open(settings.settings_backup)
  local koreader_settings = LuaSettings:open(settings.koreader)
  apm_settings = LuaSettings:open(settings.airplanemode)
  -- restore calibrewireless seperately since it is independent of the calibre plugin
  -- re-set calibre_wirless to previous setting, or delete it if it didn't exist
  if backups:isTrue("calibre_wireless") then
    koreader_settings:makeTrue("calibre_wireless")
  elseif backups:isFalse("calibre_wireless") then
    koreader_settings:makeFalse("calibre_wireless")
  else
    koreader_settings:delSetting("calibre_wireless")
  end
  -- restore the rest of the plugins
  local apm_disabled = apm_settings:readSetting("disabled_plugins") or {}
  -- create a list of what is currently disabled
  local previously_disabled = backups:readSetting("plugins_disabled") or {}
  -- Build the list of plugins disabled right now
  local currently_disabled = koreader_settings:readSetting("plugins_disabled") or {}
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
    koreader_settings:delSetting("plugins_disabled")
  else
    -- Save the updated list of disabled plugins
    koreader_settings:saveSetting("plugins_disabled", to_disable)
    koreader_settings:flush()
  end

  koreader_settings:flush()
  koreader_settings:close()
  apm_settings:close()
  backups:close()
end

function PluginManager:toggleAirPlaneMode(settings, toggle)
  if settings.koreader:saveSetting("airplanemode", toggle) then
    settings.koreader:flush()
    settings.koreader:close()
  else
    logger.err("Failed to set AirPlane Mode:",toggle)
  end
end

-- Build a menu from the passed plugin list
function PluginManager:menuBuilder( builtin, plugin_list)
  local airplane_plugin_table = {}
  if #plugin_list == 0 then
    logger.dbg("AirPlaneMode: menuBuilder plugin_list is empty")
    return airplane_plugin_table
  end
  for __, plugin in ipairs(plugin_list) do
    if (builtin == true and BUILTIN_PLUGINS[plugin.name]) or (builtin == false and not BUILTIN_PLUGINS[plugin.name]) then
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
  end
  return airplane_plugin_table
end

return PluginManager
