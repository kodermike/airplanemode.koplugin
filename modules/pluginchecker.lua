--[[
PluginChecker module for AirplaneMode
]]
local PluginLoader = require("pluginloader")
local ffiutil = require("ffi/util")

local T = ffiutil.template

local logger = require("logger")
local _ = require("gettext")

local U = require("modules/utilities")

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

local PluginChecker = {
  show_info = true,
  enabled_plugins = nil,
  disabled_plugins = nil,
  loaded_plugins = nil,
  all_plugins = nil,
}

-- Lifted whole from pluginloader because it was the only way to dup the function :/
local function getPluginInfo(plugin)
  local t = {}
  t.name = plugin.name
  t.fullname = string.format("%s", plugin.fullname or plugin.name)
  t.description = string.format("%s", plugin.description)
  return t
end

function PluginChecker.getPlugins(self, builtin)
  local check_plugins = U:readAPMplugins()
  local os_enabled_plugins, os_disabled_plugins = PluginLoader:loadPlugins()
  local plugin_list = {}

  --Loop through os plugins that are enabled and mark that
  for _, plugin in ipairs(os_enabled_plugins) do
    if (builtin == true and BUILTIN_PLUGINS[plugin.name]) or (builtin == false and not BUILTIN_PLUGINS[plugin.name]) then
      local element = getPluginInfo(plugin)
      element.enable = true

      table.insert(plugin_list, element)
    end
  end
  -- first loop through disabled plugins and mark them in our own file if they don't already exist
  for _, plugin in ipairs(os_disabled_plugins) do
    if (builtin == true and BUILTIN_PLUGINS[plugin.name]) or (builtin == false and not BUILTIN_PLUGINS[plugin.name]) then
      local element = getPluginInfo(plugin)
      if not check_plugins[plugin.name] then
        check_plugins[element.name] = true
      end
      element.enable = nil
      table.insert(plugin_list, element)
    end
  end
  table.sort(plugin_list, function(a, b)
    return a.fullname < b.fullname
  end)
  return plugin_list
end

-- Build a menu from the passed plugin list
function PluginChecker.menuBuilder(self, builtin, plugin_list)
  local airplane_plugin_table = {}
  -- Since we're in AirPlaneMode, and we skip AirPlaneMode, then a list of 0 is an empty list in this context
  if builtin == false and #plugin_list == 0 then
    logger.dbg("AIRPLANEMODE: menuBuilder plugin_list is empty")
    table.insert(airplane_plugin_table, {
      text = _("No user installed plugins available to manage"),
      enabled = false,
      help_text = _("The only plugin installed is AirPlaneMode - nothing to manage"),
    })
    return airplane_plugin_table
  end
  for __, plugin in ipairs(plugin_list) do
    if (builtin == true and BUILTIN_PLUGINS[plugin.name]) or (builtin == false and not BUILTIN_PLUGINS[plugin.name]) then
      if plugin.name ~= "airplanemode" then
        table.insert(airplane_plugin_table, {
          text = _(plugin.fullname),
          checked_func = function()
            -- Read the latest setting from disk to avoid stale in-memory cache
            local cp = U:readAPMplugins()
            local val = cp[plugin.name]
            return val
          end,
          enabled_func = function()
            if (plugin.enable == false) or (plugin.enable == nil) then
              return false
            else
              return true
            end
          end,
          callback = function()
            -- Re-open settings on each toggle to ensure we operate on latest on-disk state
            local cp = U:readAPMplugins()
            if cp[plugin.name] then
              cp[plugin.name] = nil
              logger.dbg("AIRPLANEMODE: Disabled ", plugin.name)
            else
              cp[plugin.name] = true
              logger.dbg("AIRPLANEMODE: Enabled ", plugin.name)
            end
            U:saveAPMplugins(cp)
            -- Broadcast a UI update so menus/checkboxes refresh
            local UIManager = require("ui/uimanager")
            local Event = require("ui/event")
            UIManager:broadcastEvent(Event:new("UpdateMenu", true))
          end,
          help_text = T(_("%1\n\nThis plugin is already disabled in KOReader"), plugin.description),
        })
      end
    end
  end
  return airplane_plugin_table
end

return PluginChecker
