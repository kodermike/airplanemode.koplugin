---@class WidgetContainer
---@class AirPlaneMode    : WidgetContainer
---@field name                           string
---@field is_doc_only                    boolean
---@field ui                             table
---@field additional_footer_content_func fun(): (string | nil)
---@field show_value_in_footer           boolean | nil
---@field init                           fun(self): nil
---@field onEnable                       fun(self): nil
---@field onDisable                      fun(self): nil
---@field getPlugins                     fun(self, builtin: boolean, settings: table): table

local Dispatcher = require("dispatcher")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("utils/flight_log")
local _ = require("gettext")

local FlightConfig = require("flight_config")
local settings = FlightConfig:init()
local FlightControl = require("utils.flight_control")

local H = require("utils/flight_helpers")
local U = require("utils/flight_utilities")
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
    if settings.debug_is_on then
      local funcname = debug.getinfo(1, "n").name
      logger.dbg(funcname, "resetting the main config to use", last_start)
    end
    if U:FlightHas("start_with", settings.koreader) and last_start ~= nil then
      U:saveFlightSetting("start_with", last_start, settings.koreader)
    end
    if U:FlightHas("restart_with") then
      U:delFlightSetting("restart_with")
    end
  end
end

restoreState()

local AirPlaneMode = WidgetContainer:extend({
  name = "airplanemode",
  is_doc_only = false
})

local Flightfooter = require("flight_footer")
if type(Flightfooter) == "function" then
  Flightfooter(AirPlaneMode)
end

--- Register actions with dispatcher
---@return nil
function AirPlaneMode.onDispatcherRegisterActions()
  Dispatcher:registerAction("airplanemode_enable", {
    category = "none",
    event = "Enable",
    title = _("AirPlaneMode Enable"),
    device = true
  })
  Dispatcher:registerAction("airplanemode_disable", {
    category = "none",
    event = "Disable",
    title = _("AirPlaneMode Disable"),
    device = true
  })
  Dispatcher:registerAction("airplanemode_toggle", {
    category = "none",
    event = "Toggle",
    title = _("AirPlaneMode Toggle"),
    device = true,
    separator = true
  })
end

--- Initialize plugin
---@return nil
function AirPlaneMode:init()
  self:onDispatcherRegisterActions()
  if H.isFile(settings.prev_config) then
    self:migrateconfig()
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

  if U:FlightHas("check_updates") and U:FlightIsTrue("check_updates") then
    local UP = require("utils/flight_updater")
    UP:checkForUpdates()
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

--- Hook for stopPlugin support
---@return nil
function AirPlaneMode:stopPlugin()
  local funcname = debug.getinfo(1, "n").name
  logger.dbg(funcname, "stopPlugin called at ", os.time())
  if U:getFlightStatus() then
    local interactive = false
    FlightControl:Disable(self, interactive)
  end
end

-- expose non-method API (some callers invoke stopPlugin() without a self)
local _method_stopPlugin = AirPlaneMode.stopPlugin
if type(_method_stopPlugin) == "function" then
  AirPlaneMode.stopPlugin = function()
    return _method_stopPlugin(AirPlaneMode)
  end
end

-- Expose FlightControl methods on AirPlaneMode for test compatibility and direct access
AirPlaneMode.deletePluginSettings = function()
  return FlightControl.deletePluginSettings()
end

AirPlaneMode.initSettingsFile = function(airplanemode_file, version)
  if not airplanemode_file then
    local cfg = FlightConfig:init()
    airplanemode_file = cfg.airplanemode
    version = cfg.version
  end
  return FlightConfig.initSettingsFile(airplanemode_file, version)
end

function AirPlaneMode:Enable()
  return FlightControl:Enable(self)
end

function AirPlaneMode:Disable()
  return FlightControl:Disable(self)
end

--- Handle Enable gesture
---@return nil
function AirPlaneMode:onEnable()
  self:Enable()
end

--- Handle disable gesture
---@return nil
function AirPlaneMode:onDisable()
  self:Disable()
end

--- Handle toggle events from gestures
---@return nil
function AirPlaneMode:onToggle()
  if U:getFlightStatus() then
    self:Disable()
  else
    self:Enable()
  end
end

--- Initialize main menu
---@return nil
function AirPlaneMode:addToMainMenu(menu_items)
  M:init(menu_items, self)
end

return AirPlaneMode
