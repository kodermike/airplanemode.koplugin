---@class FlightMenu
---@field show_value_in_footer boolean|nil

local Device = require("device")
local NetworkMgr = require("ui/network/manager")
local logger = require("logger")

local ffiutil = require("ffi/util")
local T = ffiutil.template
local _ = require("gettext")

local APMConfig = require("modules/APMConfig")
local settings = APMConfig:init()

local P = require("modules/PluginManager")
local U = require("modules/utilities")
local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")

local FlightMenu = {}

---Initialize main menu item for AirPlaneMode
---@param menu_items table
---@param AirPlaneMode table
---@return nil
function FlightMenu:init(menu_items, AirPlaneMode)
  local airmode = U:getStatus()
  menu_items.airplanemode = {
    text_func = function()
      if airmode then
        return T(_("%1 AirplaneMode"), settings.icon_on)
      else
        return T(_("%1 AirplaneMode"), settings.icon_off)
      end
    end,
    help_text = T(_("A simple plugin that helps you when you're on the go.\n\n\nv.%1"), settings.version),
    sorting_hint = "network",
    sub_item_table = {
      {
        text_func = function()
          local curversion = U:readAPMsetting("version", settings.airplanemode)
          if (curversion == nil) or (curversion ~= settings.version) then
            U:saveAPMsetting("version", settings.version, settings.airplanemode)
          end
          if airmode then
            return T(_("%1 Disable"), settings.icon_on)
          else
            return T(_("%1 Enable"), settings.icon_off)
          end
        end,
        separator = true,
        callback = function()
          if airmode then
            --airplanemode = true
            AirPlaneMode:Disable()
          else
            --airplanemode = false
            AirPlaneMode:Enable()
          end
        end,
      },
      {
        text = _("Configuration"),
        sub_item_table_func = function()
          return self:getConfigMenuItems(AirPlaneMode)
        end,
      },
    },
  }
end

---Get configuration menu items
---@param AirPlaneMode table
---@return table
function FlightMenu:getConfigMenuItems(AirPlaneMode)
  local airplane_config_table = {}
  local airmode = U:getStatus()

  if airmode then
    table.insert(airplane_config_table, {
      text = T(_("%1  Plugin management suspended while in flight"), settings.icon_on),
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
      if U:APMisTrue("airplanemode_in_footer", settings.airplanemode) then
        return true
      else
        return false
      end
    end,
    callback = function()
      self.show_value_in_footer = not self.show_value_in_footer
      U:saveAPMsetting("airplanemode_in_footer", self.show_value_in_footer, settings.airplanemode)
      if self.show_value_in_footer then
        AirPlaneMode:addAdditionalFooterContent()
      else
        AirPlaneMode:removeAdditionalFooterContent()
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

---Build menu from plugin list
---@param builtin boolean
---@param plugin_list table
---@param settings table
---@return table
function FlightMenu:menuBuilder(builtin, plugin_list, settings)
  local airplane_plugin_table = {}
  -- Since we're in AirPlaneMode, and we skip AirPlaneMode, then a list of 0 is an empty list in this context
  if builtin == false and #plugin_list == 0 then
    logger.dbg("AIRPLANEMODE: PluginManager - menuBuilder plugin_list is empty")
    table.insert(airplane_plugin_table, {
      text = _("No user installed plugins available to manage"),
      enabled = false,
      help_text = _("The only plugin installed is AirPlaneMode - nothing to manage"),
    })
    return airplane_plugin_table
  end
  local BUILTIN_PLUGINS = P:plugin_list()
  for __, plugin in ipairs(plugin_list) do
    if (builtin == true and BUILTIN_PLUGINS[plugin.name]) or (builtin == false and not BUILTIN_PLUGINS[plugin.name]) then
      if plugin.name ~= "airplanemode" then
        table.insert(airplane_plugin_table, {
          text = _(plugin.fullname),
          checked_func = function()
            -- Read the latest setting from disk to avoid stale in-memory cache
            local cp = U:readAPMplugins(settings.koreader_plugins, settings.airplanemode)
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
            local cp = U:readAPMplugins(settings.koreader_plugins, settings.airplanemode)
            if cp[plugin.name] then
              cp[plugin.name] = nil
              logger.dbg("AIRPLANEMODE: PluginManager - Disabled ", plugin.name)
            else
              cp[plugin.name] = true
              logger.dbg("AIRPLANEMODE: PluginManager - Enabled ", plugin.name)
            end
            U:saveAPMplugins(cp, settings.airplanemode)
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

---Return plugin menu for builtin/user plugins
---@param self table
---@param builtin boolean
---@param settings table
---@return table
function FlightMenu.PluginMenu(self, builtin, settings)
  logger.dbg("AIRPLANEMODE: PluginMenu - builtin: ", builtin)
  local plugin_list = P:getPlugins(builtin, settings)
  local plugin_menu = self:menuBuilder(builtin, plugin_list, settings)
  return plugin_menu
end

return FlightMenu
