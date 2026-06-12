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
  ---@param plugin table{name: string, fullname?: string, description?: string}
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
    local FlightConfig = require("flight_config")
    local settings = FlightConfig:init()
    if settings.debug_is_on then
      logger.dbg("AIRPLANEMODE: Stopping plugin", plugin)
    end
    if stopp then
      local mstatus, __ = pcall(function()
        pcall(fplugin["stopPlugin"])
      end)
      if mstatus == "false" then
        -- stopPlugin failed, just do a normal stop
        local sstatus, serr = pcall(function()
          pcall(fplugin["stop"])
        end)
        if sstatus == "false" then
          logger.err("AIRPLANEMODE: Failed to stop", plugin, ":", serr)
        end
      end
    else
      -- no stopPlugin, fallback to regular stop
      local sstatus, serr = pcall(function()
        pcall(fplugin["stop"])
      end)
      if sstatus == "false" then
        logger.err("AIRPLANEMODE: Failed to stop", plugin, ":", serr)
      end
    end
  end

  ---Get plugins (builtin or user)
  ---@param builtin boolean
  ---@param settings FlightConfig
  ---@return PluginEntry[]
  function AirPlaneMode:getPlugins(builtin, settings)
    if settings.debug_is_on then
      logger.dbg("AIRPLANEMODE: PluginManager - getPlugins - builtin: ", builtin, " settings: ", settings.koreader_plugins, settings.airplanemode)
    end
    local check_plugins = U:readFlightPlugins(settings.koreader_plugins, settings.airplanemode)
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
    if settings.debug_is_on then
      logger.dbg("AIRPLANEMODE: retrieving list of plugins to disable")
    end
    local check_plugins = U:readFlightPlugins(settings.koreader_plugins, settings.airplanemode)
    if settings.debug_is_on then
      logger.dbg("AIRPLANEMODE: retrieving list of already disabled plugins")
    end
    local disabled_plugins = U:readFlightSetting(settings.koreader_plugins, settings.koreader) or {}
    -- a pair of loops for the logger
    if type(check_plugins) == "string" then
      if disabled_plugins[check_plugins] ~= true then
        disabled_plugins[check_plugins] = true
        if settings.debug_is_on then
          logger.dbg("AIRPLANEMODE: Disabling [string]", check_plugins)
        end
      end
    else
      for plugin, _ in pairs(check_plugins) do
        if settings.debug_is_on then
          logger.dbg("AIRPLANEMODE: Disabling", plugin)
        end
        if disabled_plugins[plugin] ~= true then
          if settings.debug_is_on then
            logger.dbg("AIRPLANEMODE: Disabling", plugin, "was true")
          end
          -- Check the current plugin  for status and stop if necessary
          local modcheck = self.ui[plugin]
          -- if the passed name was a plugin continue
          if modcheck and (type(modcheck) == "table") then
            -- if the passed plugin has either a stop or stopPlugin method
            if settings.debug_is_on then
              logger.dbg("AIRPLANEMODE: checking stop method for", plugin)
            end
            local stopmethod = type(modcheck["stop"]) == "function"
            local stopPluginmethod = type(modcheck["stopPlugin"]) == "function"
            if stopmethod or stopPluginmethod then
              -- The plugin has a stop method
              if settings.debug_is_on then
                logger.dbg("AIRPLANEMODE: stop method found for", plugin)
              end

              if type(modcheck["isRunning"]) == "function" then
                -- The plugin has an isRunning method - use that to determine if we should try and stop it
                if settings.debug_is_on then
                  logger.dbg("AIRPLANEMODE: isRunning method found for", plugin)
                end
                local status, __ = pcall(function()
                  pcall(modcheck["isRunning"]())
                end)
                -- if the status came back that the plugin was running
                if status == "true" then
                  -- try to run stopPlugin if available since it's cleaner
                  if settings.debug_is_on then
                    logger.dbg("AIRPLANEMODE: isRunning returned true, trying to stop", plugin)
                  end
                  stopOtherPlugins(stopPluginmethod, modcheck, plugin)
                end
              else
                -- stop methods were found but no isRunning, so we'll just try to run stop and hope
                if settings.debug_is_on then
                  logger.dbg("AIRPLANEMODE: no isRunning method found, trying to stop", plugin)
                end
                stopOtherPlugins(stopPluginmethod, modcheck, plugin)
              end
            end
          end
          -- After our attempts to stop, go ahead and mark the plugin disabled.
          -- Moved to the end to avoid confusion if for some reason we crash
          -- attempting to stop a plugin.
          if settings.debug_is_on then
            logger.dbg("AIRPLANEMODE: marking stopped:", plugin)
          end
          disabled_plugins[plugin] = true
        end
      end
    end
    if settings.debug_is_on then
      logger.dbg("AIRPLANEMODE: Saving", disabled_plugins)
    end
    U:saveFlightSetting("plugins_disabled", disabled_plugins, settings.koreader)
  end

  ---Restore plugin settings from backup
  ---@param settings table
  ---@return nil
  function AirPlaneMode:restorePluginSettings(settings)
    -- restore calibrewireless seperately since it is independent of the calibre plugin
    -- re-set calibre_wirless to previous setting, or delete it if it didn't exist
    if U:FlightIsTrue("calibre_wireless", settings.backup) then
      U:FlightMakeTrue("calibre_wireless", settings.koreader)
    elseif U:FlightIsFalse("calibre_wireless", settings.backup) then
      U:FlightMakeFalse("calibre_wireless", settings.koreader)
    else
      U:delFlightSetting("calibre_wireless", settings.koreader)
    end
    -- restore the rest of the plugins
    local apm_disabled = U:readFlightSetting(settings.koreader_plugins, settings.airplanemode) or {}
    -- create a list of what is currently disabled
    local previously_disabled = U:readFlightSetting(settings.koreader_plugins, settings.backup) or {}
    -- Build the list of plugins disabled right now
    local currently_disabled = U:readFlightSetting(settings.koreader_plugins, settings.koreader) or {}
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
      U:delFlightSetting(settings.koreader_plugins, settings.koreader)
    else
      -- Save the updated list of disabled plugins
      U:saveFlightSetting(settings.koreader_plugins, to_disable, settings.koreader)
    end
  end

  ---Enable/restore calibre related settings
  ---@param settings table
  function AirPlaneMode:enableCalibre(settings)
    -- re-set calibre_wirless to previous setting, or delete it if it didn't exist
    if U:FlightIsTrue("calibre_wireless", settings.backup) then
      if settings.debug_is_on then
        logger.dbg("AIRPLANEMODE: Saving calibre_wireless setting: true")
      end
      U:FlightMakeTrue("calibre_wireless", settings.koreader)
      return
    elseif U:FlightIsFalse("calibre_wireless", settings.backup) then
      if settings.debug_is_on then
        logger.dbg("AIRPLANEMODE: Saving calibre_wireless setting: false")
      end
      U:FlightMakeFalse("calibre_wireless", settings.koreader)
      return
    else
      if settings.debug_is_on then
        logger.dbg("AIRPLANEMODE: Deleting calibre_wireless setting")
      end
      U:delFlightSetting("calibre_wireless", settings.koreader)
      return
    end
  end
end
