---@class FlightUpdater

local _ = require("gettext")

local FlightConfig = require("flight_config")
local settings = FlightConfig:init()

local U = require("utils/flight_utilities")
local Updater = require("utils/flight_updater")

local FlightUpdaterMenu = {}

--- Show the flight plan menu.
---@return table
function FlightUpdaterMenu:showMenu()
  local check_updates = U:readFlightSetting("check_updates") or false
  return {
    {
      text = _("Check for updates after waking"),
      checked_func = function()
        return check_updates
      end,
      callback = function()
        check_updates = not check_updates
        U:saveFlightSetting("check_updates", check_updates)
      end,
    },
    {
      text_func = function()
        local available = Updater.getAvailableUpdate()
        local source = U:readFlightSetting("last_install_source") or "release"
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
            local b = U:readFlightSetting("dev_branch") or ""
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
            local b = U:readFlightSetting("dev_branch") or ""
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
            local source = U:FlightHas("Last_install_source") and U:readFlightSetting("last_install_source") or "release"
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

return FlightUpdaterMenu
