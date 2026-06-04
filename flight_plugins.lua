--[[
PluginManager module for AirplaneMode
]]
---@class PluginEntry
---@field name string
---@field fullname string
---@field description string
---@field enable boolean|nil

---@class PluginManager

local PluginLoader = require("pluginloader")

local U = require("utils/flight_utilities")

local logger = require("logger")
local _ = require("gettext")

--- Returns the list of plugins to load.
---@return table<string, boolean>
return function(AirPlaneMode)
  function AirPlaneMode:plugin_list()
    return {
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
  end

  -- Lifted whole from pluginloader because it was the only way to dup the function :/
  ---@param plugin table
  ---@return PluginEntry
  local function getPluginInfo(plugin)
    local t = {}
    t.name = plugin.name
    t.fullname = string.format("%s", plugin.fullname or plugin.name)
    t.description = string.format("%s", plugin.description)
    return t
  end

  --- Stops all other plugins except the one being stopped.
  local function stopOtherPlugins(stopp, fplugin, plugin)
    -- try to run stopPlugin if available since it's cleaner
    logger.dbg("AIRPLANEMODE: Stopping plugin", plugin)
    if stopp then
      local mstatus, __ = pcall(function()
        pcall(fplugin["stopPlugin"]())
      end)
      -- if H.stringto(mstatus) == false then
      if mstatus == "false" then
        -- stopPlugin failed, just do a normal stop
        local sstatus, serr = pcall(function()
          pcall(fplugin["stop"]())
        end)
        -- if H.stringto(sstatus) == false then
        if sstatus == "false" then
          logger.err("AIRPLANEMODE: Failed to stop", plugin, ":", serr)
        end
      end
    else
      -- no stopPlugin, fallback to regular stop
      local sstatus, serr = pcall(function()
        pcall(fplugin["stop"]())
      end)
      -- if H.stringto(sstatus) == false then
      if sstatus == "false" then
        logger.err("AIRPLANEMODE: Failed to stop", plugin, ":", serr)
      end
    end
  end

  ---Get plugins (builtin or user)
  ---@param builtin boolean
  ---@param settings table
  ---@return PluginEntry[]
  function AirPlaneMode:getPlugins(builtin, settings)
    logger.dbg("AIRPLANEMODE: PluginManager - getPlugins - builtin: ", builtin, " settings: ", settings.koreader_plugins, settings.airplanemode)
    local check_plugins = U:readFlightplugins(settings.koreader_plugins, settings.airplanemode)
    local os_enabled_plugins, os_disabled_plugins = PluginLoader:loadPlugins()
    local plugin_list = {}
    local BUILTIN_PLUGINS = self:plugin_list()

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

  ---Disable plugins listed in settings
  ---@param settings table
  ---@return nil
  function AirPlaneMode:disablePlugins(settings)
    --[[ start ]]
    logger.dbg("AIRPLANEMODE: retrieving list of plugins to disable")
    local check_plugins = U:readFlightplugins(settings.koreader_plugins, settings.airplanemode)
    logger.dbg("AIRPLANEMODE: retrieving list of already disabled plugins")
    local disabled_plugins = U:readFlightsetting(settings.koreader_plugins, settings.koreader) or {}
    -- a pair of loops for the logger
    if type(check_plugins) == "string" then
      if disabled_plugins[check_plugins] ~= true then
        disabled_plugins[check_plugins] = true
        logger.dbg("AIRPLANEMODE: Disabling [string]", check_plugins)
      end
    else
      for plugin, _ in pairs(check_plugins) do
        logger.dbg("AIRPLANEMODE: Disabling", plugin)
        if disabled_plugins[plugin] ~= true then
          logger.dbg("AIRPLANEMODE: Disabling", plugin, "was true")
          -- Check the current plugin  for status and stop if necessary
          local modcheck = self.ui[plugin]
          -- if the passed name was a plugin continue
          if modcheck and (type(modcheck) == "table") then
            -- if the passed plugin has either a stop or stopPlugin method
            logger.dbg("AIRPLANEMODE: checking stop method for", plugin)
            local stopmethod = type(modcheck["stop"]) == "function"
            local stopPluginmethod = type(modcheck["stopPlugin"]) == "function"
            if stopmethod or stopPluginmethod then
              -- The plugin has a stop method
              logger.dbg("AIRPLANEMODE: stop method found for", plugin)

              if type(modcheck["isRunning"]) == "function" then
                -- The plugin has an isRunning method - use that to determine if we should try and stop it
                logger.dbg("AIRPLANEMODE: isRunning method found for", plugin)
                local status, __ = pcall(function()
                  pcall(modcheck["isRunning"]())
                end)
                -- if the status came back that the plugin was running
                -- if H.stringto(status) == true then
                if status == "true" then
                  -- try to run stopPlugin if available since it's cleaner
                  logger.dbg("AIRPLANEMODE: isRunning returned true, trying to stop", plugin)
                  stopOtherPlugins(stopPluginmethod, modcheck, plugin)
                end
              else
                -- stop methods were found but no isRunning, so we'll just try to run stop and hope
                logger.dbg("AIRPLANEMODE: no isRunning method found, trying to stop", plugin)
                stopOtherPlugins(stopPluginmethod, modcheck, plugin)
              end
            end
          end
          -- After our attempts to stop, go ahead and mark the plugin disabled.
          -- Moved to the end to avoid confusion if for some reason we crash
          -- attempting to stop a plugin.
          logger.dbg("AIRPLANEMODE: marking stopped:", plugin)
          disabled_plugins[plugin] = true
        end
      end
    end
    logger.dbg("AIRPLANEMODE: Saving", disabled_plugins)
    U:saveFlightsetting("plugins_disabled", disabled_plugins, settings.koreader)
  end

  ---Restore plugin settings from backup
  ---@param settings table
  ---@return nil
  function AirPlaneMode:restorePluginSettings(settings)
    -- restore calibrewireless seperately since it is independent of the calibre plugin
    -- re-set calibre_wirless to previous setting, or delete it if it didn't exist
    if U:FlightisTrue("calibre_wireless", settings.backup) then
      U:FlightmakeTrue("calibre_wireless", settings.koreader)
    elseif U:FlightisFalse("calibre_wireless", settings.backup) then
      U:FlightmakeFalse("calibre_wireless", settings.koreader)
    else
      U:delFlightsetting("calibre_wireless", settings.koreader)
    end
    -- restore the rest of the plugins
    local apm_disabled = U:readFlightsetting(settings.koreader_plugins, settings.airplanemode) or {}
    -- create a list of what is currently disabled
    local previously_disabled = U:readFlightsetting(settings.koreader_plugins, settings.backup) or {}
    -- Build the list of plugins disabled right now
    local currently_disabled = U:readFlightsetting(settings.koreader_plugins, settings.koreader) or {}
    local to_disable = {}
    -- loop currently disabled items
    for plugin, __ in pairs(currently_disabled) do
      -- if airplanemode disabled it and it was disabled before, keep it disabled
      if apm_disabled[plugin] and previously_disabled[plugin] then
        to_disable[plugin] = true
      -- if it wasn't disabled in airplanemode, keep it disabled
      elseif not apm_disabled[plugin] then
        to_disable[plugin] = true
      end
    end

    if not next(to_disable) then
      -- We now have an empty list - the only disabled plugins were the ones added by Flight
      U:delFlightsetting(settings.koreader_plugins, settings.koreader)
    else
      -- Save the updated list of disabled plugins
      U:saveFlightsetting(settings.koreader_plugins, to_disable, settings.koreader)
    end
  end

  ---Enable/restore calibre related settings
  ---@param settings table
  function AirPlaneMode:enableCalibre(settings)
    -- re-set calibre_wirless to previous setting, or delete it if it didn't exist
    if U:FlightisTrue("calibre_wireless", settings.backup) then
      logger.dbg("AIRPLANEMODE: Saving calibre_wireless setting: true")
      U:FlightmakeTrue("calibre_wireless", settings.koreader)
    elseif U:FlightisFalse("calibre_wireless", settings.backup) then
      logger.dbg("AIRPLANEMODE: Saving calibre_wireless setting: false")
      U:FlightmakeFalse("calibre_wireless", settings.koreader)
    else
      logger.dbg("AIRPLANEMODE: Deleting calibre_wireless setting")
      U:delFlightsetting("calibre_wireless", settings.koreader)
    end
  end
end
-- return PluginManager
