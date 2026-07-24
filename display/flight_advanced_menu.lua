---@class FlightAdvancedMenu
---@field device_model_name string
---@field device_firmware_info string
---@field KOReader_version string
---@field menu table

local BD = require("ui/bidi")
local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")

local ffiutil = require("ffi/util")
local T = ffiutil.template
local _ = require("gettext")

local FlightConfig = require("flight_config")
local H = require("utils/flight_helpers")
local U = require("utils/flight_utilities")
local FM = require("utils/flight_deviceinfo")

local FlightAdvancedMenu = {}

---Retrieve KOReader version
---@return string
function FlightAdvancedMenu.getKOReaderVersion()
  local ok, v_info = pcall(require, "version")
  if ok then
    if type(v_info) == "string" and v_info ~= "" then
      return v_info
    end
    if type(v_info) == "table" then
      local value = H.first_non_empty(v_info.version, v_info.short, v_info.git, v_info.git_rev, v_info.build, v_info.tag)
      if value then
        return value
      end
    end
  end

  local value = H.first_non_empty(rawget(_G, "KOREADER_VERSION"), rawget(_G, "KO_VERSION"), rawget(_G, "GIT_REV"))
  return value or "unknown"
end

local function generic_entry(t)
  local settings = FlightConfig:init()
  local icon = U:getFlightStatus() and settings.icon_on or settings.icon_off
  return {
    text = _(t),
    keep_menu_open = true,
    callback = function()
      UIManager:show(InfoMessage:new({
        text = T(_("%1  %2 v%3\n\n%4\n\nLicensed under Affero GPL v3."), icon, BD.ltr(settings.fullname), BD.ltr(settings.version), BD.ltr(settings.description)),
      }))
    end,
  }
end

---FlightAdvancedMenu:menu()
---Genrates the advance details menu
---@return table
function FlightAdvancedMenu:menu()
  local settings = FlightConfig:init()
  local airplane_specs = {}
  -- Generate information buttons - all use the same popup for displaying About
  local button_list = {
    T(_("%1: v%2"), settings.fullname, settings.version),
    T(_("KOReader Version: %s"):format(BD.ltr(self:getKOReaderVersion()))),
    T(_("Device: %s"):format(BD.ltr(FM:get_device_model_name()))),
    T(_("Firmware: %s"):format(BD.ltr(FM:get_device_firmware_info()))),
  }
  for _, text in ipairs(button_list) do
    table.insert(airplane_specs, generic_entry(text))
  end

  -- Dev mode toggle for showing in-progress features
  table.insert(airplane_specs, {
    text = _("Developer Mode"),
    callback = function()
      if settings.dev_mode then
        U:FlightMakeFalse("dev_mode")
        settings.dev_mode = false
        if U:FlightIsTrue("debug_is_on") then
          U:FlightMakeFalse("debug_is_on")
        end
        settings = FlightConfig:init()
      else
        U:FlightMakeTrue("dev_mode")
        UIManager:show(InfoMessage:new({
          text = _("Developer Mode Enabled\n\nSome features may not yet function correctly."),
          timeout = 3,
        }))
        settings.dev_mode = true
      end
    end,
    checked_func = function()
      return settings.dev_mode
    end,
  })

  -- Updater management
  if U:getFlightStatus() then
    table.insert(airplane_specs, {
      text = T(_("%1  Update management suspended while in flight"), settings.icon_on),
      enabled = false,
    })
  else
    table.insert(airplane_specs, {
      text = _("Update management"),
      sub_item_table_func = function()
        local updater_menu = require("display/flight_updater_menu")
        return updater_menu:showMenu()
      end,
      enabled_func = function()
        return settings.dev_mode
      end,
    })
  end

  -- Add debug logging enabled/disabled
  table.insert(airplane_specs, {
    text = _("Toggle logging"),
    callback = function()
      if U:FlightHas("debug_is_on") and U:FlightIsTrue("debug_is_on") then
        U:delFlightSetting("debug_is_on")
        settings.debug_is_on = nil
        settings = FlightConfig:init()
        -- local logger = require("logger")
        -- local LvDEBUG = logger.LvDEBUG
        -- if LvDEBUG == "dbg" then
        --   logger:setLevel(logger.levels.info)
        -- end
      else
        U:FlightMakeTrue("debug_is_on")
        settings.debug_is_on = true
        settings = FlightConfig:init()
        -- local logger = require("logger")
        -- local LvDEBUG = logger.LvDEBUG
        -- if LvDEBUG ~= "dbg" then
        -- logger:setLevel(logger.levels.dbg)
        -- end
      end
    end,
    checked_func = function()
      if U:FlightHas("debug_is_on") and U:FlightIsTrue("debug_is_on") then
        return true
      else
        return false
      end
    end,
    enabled_func = function()
      return settings.dev_mode
    end,
  })

  return airplane_specs
end

return FlightAdvancedMenu
