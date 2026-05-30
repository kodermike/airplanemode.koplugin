---@class FlightPlan

local _ = require("gettext")

local FlightConfig = require("flight_config")
local settings = FlightConfig:init()

local U = require("utils/flight_utilities")
local Updater = require("utils/flight_plan")

local FlightPlanMenu = {}

function FlightPlanMenu:showMenu()
  local check_updates = U:readFlightsetting("check_updates", settings.airplanemode) or false
  return {
    {
      text = _("Notify on wake when update available"),
      checked_func = function()
        return check_updates
      end,
      callback = function()
        check_updates = not check_updates
        U:saveFlightsetting("check_updates", check_updates, settings.airplanemode)
      end,
    },
    {
      text_func = function()
        local available = Updater.getAvailableUpdate()
        local source = U:readFlightsetting("last_install_source", settings.airplanemode) or "release"
        local source_suffix = ""
        if source ~= "release" then
          local branch = source:match("^branch:(.+)$") or source
          source_suffix = " (branch: " .. branch .. ")"
        end
        if available then
          return _("Update available") .. ": v" .. settings.version .. source_suffix .. " \xE2\x86\x92 v" .. available
        end
        return _("Installed version") .. ": v" .. settings.version .. source_suffix
      end,
      keep_menu_open = true,
      callback = function()
        Updater:checkForUpdates()
      end,
    },
    {
      text = _("Developer updates"),
      sub_item_table = {
        {
          text_func = function()
            local b = U:readFlightsetting("dev_branch", settings.airplanemode) or ""
            if b == "" then
              return _("Development branch")
            end
            return _("Development branch") .. ": " .. b
          end,
          keep_menu_open = true,
          callback = function(touchmenu_instance)
            Updater:editDevBranch(touchmenu_instance)
          end,
        },
        {
          text_func = function()
            local b = U:readFlightsetting("dev_branch", settings.airplanemode) or ""
            if b == "" then
              return _("Check for updates")
            end
            return _("Install branch") .. ": " .. b
          end,
          keep_menu_open = true,
          callback = function()
            Updater:checkForUpdates()
          end,
        },
        {
          text = _("Reset to latest stable release"),
          keep_menu_open = true,
          callback = function()
            Updater:resetToStableRelease()
          end,
        },
        {
          -- Disabled status row: shows "Installed: vX (release)" /
          -- "(branch: foo)". Tap is a no-op via enabled_func=false.
          text_func = function()
            local source = U:Flighthas("Last_install_source", settings.airplanemode) and U:readFlightplugins("last_install_source", settings.airplanemode) or "release"
            if source == "release" then
              return _("Installed: v") .. settings.version .. " (release)"
            end
            local branch = source:match("^branch:(.+)$") or source
            return _("Installed: v") .. settings.version .. " (branch: " .. branch .. ")"
          end,
          enabled_func = function()
            return false
          end,
          keep_menu_open = true,
        },
      },
    },
  }
end

return FlightPlanMenu
