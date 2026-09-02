---@class FlightAdvancedMenu
---@field device_model_name string
---@field device_firmware_info string
---@field KOReader_version string
---@field menu table

local BD = require("ui/bidi")
local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local ConfirmBox = require("ui/widget/confirmbox")

local ffiutil = require("ffi/util")
local T = ffiutil.template
local _ = require("gettext")

local Device = require("device")
local NetworkMgr = require("ui/network/manager")

local FlightConfig = require("flight_config")
local settings = FlightConfig:init()
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

local function branch_or_tree()
  local version_string
  if U:FlightHas("dev_branch") then
    version_string = "branch: " .. U:readFlightSetting("dev_branch")
  else
    version_string = settings.fullname .. ": v" .. settings.version
  end
  return version_string
end

local function about_table(self)
  local aboutme = {}
  local button_list = {
    T(_("%1"), branch_or_tree()),
    T(_("KOReader Version: %s"):format(BD.ltr(self:getKOReaderVersion()))),
    T(_("Device: %s"):format(BD.ltr(FM:get_device_model_name()))),
    T(_("Firmware: %s"):format(BD.ltr(FM:get_device_firmware_info()))),
  }
  for _, text in ipairs(button_list) do
    -- table.insert(airplane_specs, generic_entry(text))
    table.insert(aboutme, {
      text_func = function()
        return text
      end,
      keep_menu_open = true,
    })
  end
  return aboutme
end

---FlightAdvancedMenu:menu()
---Genrates the advance details menu
---@return table
function FlightAdvancedMenu:menu(AirPlaneMode_Self)
  local airplane_specs = {}
  -- Generate information buttons - all use the same popup for displaying About
  -- Dev mode toggle for showing in-progress features

  -- Silent restarts
  table.insert(airplane_specs, {
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
  table.insert(airplane_specs, {
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
        AirPlaneMode_Self:addAdditionalFooterContent()
        UIManager:show(InfoMessage:new({
          text = _("Remember to enable External Content in the status bar for AirPlaneMode to show in the footer."),
          timeout = 3,
        }))
      else
        AirPlaneMode_Self:removeAdditionalFooterContent()
      end
    end,
  })
  -- Restore session after restart if available
  if Device:canRestart() then
    local airmode = U:getFlightStatus()
    table.insert(airplane_specs, {
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
  table.insert(airplane_specs, {
    text = _("Don't Manage WiFi"),
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
  -- Add debug logging enabled/disabled
  -- This is not valid for stable releases
  if settings.release == false then
    table.insert(airplane_specs, {
      text = _("Debug logging"),
      callback = function()
        if U:FlightHas("debug_is_on") and U:FlightIsTrue("debug_is_on") then
          U:FlightMakeFalse("debug_is_on")
          settings.debug_is_on = false
          local logger = require("logger")
          local LvDEBUG = logger.LvDEBUG
          if LvDEBUG == "dbg" then
            logger:setLevel(logger.levels.info)
          end
        else
          U:FlightMakeTrue("debug_is_on")
          settings.debug_is_on = true
          local logger = require("logger")
          local LvDEBUG = logger.LvDEBUG
          if LvDEBUG ~= "dbg" then
            logger:setLevel(logger.levels.dbg)
          end
        end
      end,
      checked_func = function()
        if U:FlightHas("debug_is_on") and U:FlightIsTrue("debug_is_on") then
          return true
        else
          return false
        end
      end,
    })
  end

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
    })
  end

  table.insert(airplane_specs, {
    text = _("About"),
    sub_item_table_func = function()
      return about_table(self)
    end,
  })
  -- Give the option to reset all settings
  table.insert(airplane_specs, {
    text = _("Clear all settings"),
    callback = function()
      UIManager:show(ConfirmBox:new({
        text = _("Remove and reset AirPlaneMode settings?"),
        ok_text = _("Reset"),
        cancel_text = "Cancel",
        ok_callback = function()
          local FlightControl = require("utils.flight_control")
          -- if U:getFlightStatus() then
          --   -- disable airplanemode
          --   FlightControl.Disable(AirPlaneMode_Self)
          -- end
          FlightControl.deletePluginSettings()
        end,
      }))
    end,
  })
  return airplane_specs
end

return FlightAdvancedMenu
