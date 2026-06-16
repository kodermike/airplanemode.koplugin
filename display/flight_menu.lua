---@class FlightMenu
---@field show_value_in_footer boolean|nil
---@field apm any
---@field menuBuilder fun(self, builtin: boolean, plugin_list: table): table

local Device = require("device")
local NetworkMgr = require("ui/network/manager")
local logger = require("utils/flight_log")

local ffiutil = require("ffi/util")
local T = ffiutil.template
local _ = require("gettext")

local FlightConfig = require("flight_config")
local settings = FlightConfig:init()

local FlightDetails = require("display/flight_details")

local U = require("utils/flight_utilities")

local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")

local FlightMenu = {}

---Initialize main menu item for AirPlaneMode
---@param menu_items table
---@param AirPlaneMode table
---@return nil
function FlightMenu:init(menu_items, AirPlaneMode)
  local airmode = U:getFlightStatus()
  self.apm = AirPlaneMode
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
    sub_item_table_func = function()
      return self:getMenuItems()
    end,
  }
end

---Get configuration menu items
---@return table
function FlightMenu:getMenuItems()
  local airplane_config_table = {}
  local airmode = U:getFlightStatus()

  table.insert(airplane_config_table, {
    text_func = function()
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
        self.apm:Disable()
      else
        --airplanemode = false
        self.apm:Enable()
      end
    end,
  })
  -- Plugin management
  if airmode then
    table.insert(airplane_config_table, {
      text = T(_("%1  Plugin management suspended while in flight"), settings.icon_on),
      enabled = false,
    })
  else
    table.insert(airplane_config_table, {
      text = _("Builtin Plugins to Disable"),
      help_text = _("Checked plugins will be disabled when AirPlaneMode is enabled."),
      sub_item_table_func = function()
        return self:PluginMenu(true)
      end,
    })

    local user_list = self:PluginMenu(false)
    if #user_list > 0 then
      table.insert(airplane_config_table, {
        text = _("User Added Plugins to Disable"),
        help_text = _("Checked plugins will be disabled when AirPlaneMode is enabled."),
        sub_item_table_func = function()
          return user_list
        end,
      })
    end
  end
  -- Silent restarts
  table.insert(airplane_config_table, {
    text = _("Silence the restart message"),
    callback = function()
      U:FlightToggle("silentmode")
    end,
    checked_func = function()
      if U:FlightIsTrue("silentmode") then
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
  -- Show AirPlaneMode in reader footer
  table.insert(airplane_config_table, {
    text = _("Show AirPlaneMode in reader footer"),
    checked_func = function()
      if U:FlightIsTrue("airplanemode_in_footer") then
        return true
      else
        return false
      end
    end,
    callback = function()
      self.show_value_in_footer = not self.show_value_in_footer
      U:saveFlightSetting("airplanemode_in_footer", self.show_value_in_footer)
      if self.show_value_in_footer then
        self.apm:addAdditionalFooterContent()
      else
        self.apm:removeAdditionalFooterContent()
      end
    end,
  })
  -- Restore session after restart if available
  if Device:canRestart() then
    table.insert(airplane_config_table, {
      text = _("Restore session after restart"),
      callback = function()
        if airmode then
          UIManager:show(InfoMessage:new({
            text = _("You cannot change the restore option while AirPlaneMode is in flight."),
            timeout = 3,
          }))
        else
          U:FlightToggle("restoreopt")
        end
      end,
      checked_func = function()
        if U:FlightIsTrue("restoreopt") then
          return true
        else
          return false
        end
      end,
    })
  end
  -- Roaming Mode
  table.insert(airplane_config_table, {
    text = _("Roaming Mode"),
    callback = function()
      U:FlightToggle("managewifi")
    end,
    help_text = _("AirPlaneMode will only manage settings, not the wifi device"),
    checked_func = function()
      if U:FlightHas("managewifi") and U:FlightIsTrue("managewifi") then
        return true
      else
        return false
      end
    end,
    enabled_func = function()
      if NetworkMgr:getNetworkInterfaceName() or Device:isEmulator() then
        return true
      else
        if not U:FlightIsTrue("managewifi") then
          U:FlightMakeTrue("managewifi")
        end
        return false
      end
    end,
  })
  -- About popup
  table.insert(airplane_config_table, {
    text = _("Advanced Settings"),
    keep_menu_open = true,
    sub_item_table_func = function()
      return FlightDetails:menu()
    end,
  })
  return airplane_config_table
end

---Build menu from plugin list
---@param builtin boolean
---@param plugin_list table
---@return table
function FlightMenu:menuBuilder(builtin, plugin_list)
  local airplane_plugin_table = {}
  -- Since we're in AirPlaneMode, and we skip AirPlaneMode, then a list of 0 is an empty list in this context
  if builtin == false and #plugin_list == 0 then
    if settings.debug_is_on then
      local funcname = debug.getinfo(1, "n").name
      logger.dbg(funcname, "PluginManager - menuBuilder plugin_list is empty")
    end
    table.insert(airplane_plugin_table, {
      text = _("No user installed plugins available to manage"),
      enabled = false,
      help_text = _("The only plugin installed is AirPlaneMode - nothing to manage"),
    })
    return airplane_plugin_table
  end
  local BUILTIN_PLUGINS = self.apm:plugin_list()
  for __, plugin in ipairs(plugin_list) do
    if (builtin == true and BUILTIN_PLUGINS[plugin.name]) or (builtin == false and not BUILTIN_PLUGINS[plugin.name]) then
      if plugin.name ~= "airplanemode" then
        table.insert(airplane_plugin_table, {
          text = _(plugin.fullname),
          checked_func = function()
            -- Read the latest setting from disk to avoid stale in-memory cache
            local cp = U:readFlightPlugins(settings.koreader_plugins)
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
            local cp = U:readFlightPlugins(settings.koreader_plugins)
            if cp[plugin.name] then
              cp[plugin.name] = nil
              if settings.debug_is_on then
                local funcname = debug.getinfo(1, "n").name
                logger.dbg(funcname, "PluginManager - Disabled ", plugin.name)
              end
            else
              cp[plugin.name] = true
              if settings.debug_is_on then
                local funcname = debug.getinfo(1, "n").name
                logger.dbg(funcname, "PluginManager - Enabled ", plugin.name)
              end
            end
            U:saveFlightPlugins(cp)
            -- Broadcast a UI update so menus/checkboxes refresh
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
---@param self FlightMenu
---@param builtin boolean
---@return table
function FlightMenu:PluginMenu(builtin)
  if settings.debug_is_on then
    local funcname = debug.getinfo(1, "n").name
    logger.dbg(funcname, "PluginMenu - builtin: ", builtin)
  end
  local plugin_list = self.apm:getPlugins(builtin, settings)
  local plugin_menu = self:menuBuilder(builtin, plugin_list)
  return plugin_menu
end

return FlightMenu
