local ConfirmBox = require("ui/widget/confirmbox")
local DataStorage = require("datastorage")
local Device = require("device")
local Dispatcher = require("dispatcher")
local InfoMessage = require("ui/widget/infomessage")
local LuaSettings = require("luasettings")
local NetworkMgr = require("ui/network/manager")
local PluginLoader = require("pluginloader")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local ffiutil = require("ffi/util")
local T = ffiutil.template
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local _ = require("gettext")

local settings_file = DataStorage:getDataDir().."/settings.reader.lua"
local settings_bk = DataStorage:getDataDir().."/settings.reader.lua.airplane"
local settings_bk_exists = false

-- establish the main settings file
if G_reader_settings == nil then
    G_reader_settings = LuaSettings:open(DataStorage:getDataDir().."/settings.reader.lua")
end

local AirPlaneMode = WidgetContainer:extend{
    name = "airplanemode",
    is_doc_only = false,
}

local function isFile(filename)
    if lfs.attributes(filename, "mode") == "file" then
        return true
    end
    return false
end

function AirPlaneMode:onDispatcherRegisterActions()
    Dispatcher:registerAction("airplanemode_action", { category="none", event="SwitchAirPlane", title=_("AirPlane Mode"), general=true,})
end

function AirPlaneMode:init()
    self:onDispatcherRegisterActions()
    self.ui.menu:registerToMainMenu(self)
    self.airplane_plugins_file = DataStorage:getDataDir().."/settings/airplane_plugins.lua"
end

function AirPlaneMode:initSettingsFile()
    if isFile(self.airplane_plugins_file) == true then
        return
    else
        local airplane_plugins = LuaSettings:open(self.airplane_plugins_file)
        local default_disable = {}
        local default_disable_list = {"newsdownloader","wallabag","calibre","kosync","opds","SSH","timesync","httpinspector"}
        for __, plugin in ipairs(default_disable_list) do
            default_disable[plugin] = true
        end
        airplane_plugins:saveSetting("disabled_plugins",default_disable)
        airplane_plugins:flush()
        airplane_plugins:close()
    end
end

function AirPlaneMode:backup()
    if isFile(settings_file) then
        if isFile(settings_bk) then
            os.remove(settings_bk)
        end
        ffiutil.copyFile(settings_file,settings_bk )
        return isFile(settings_bk) and true or false
    else
        logger.err("AirPlane Mode [ERROR] - Failed to find settings file at: ",settings_file)
        return false
    end
end

function AirPlaneMode:turnon()
    local current_config = self:backup()
    if current_config then
        self:initSettingsFile()
        -- mark airplane as active
        G_reader_settings:saveSetting("airplanemode",true)
        -- disable plugins, wireless, all of it
        G_reader_settings:saveSetting("auto_restore_wifi",false)
        G_reader_settings:saveSetting("auto_disable_wifi",true)
        G_reader_settings:saveSetting("wifi_was_on",false)
        G_reader_settings:saveSetting("http_proxy_enabled",false)
        if Device:isEmulator() then
            G_reader_settings:saveSetting("emulator_fake_wifi_connected",false)
        end

        local airplane_plugins = LuaSettings:open(self.airplane_plugins_file)
        local check_plugins = airplane_plugins:readSetting("disabled_plugins") or {}
        local plugins_disabled = G_reader_settings:readSetting("plugins_disabled") or {}

        if type(check_plugins) == "string" then
            if not plugins_disabled[check_plugins] == true then
                plugins_disabled[check_plugins] = true
            end
        else
            for plugin, __ in pairs(check_plugins) do
                if not plugins_disabled[plugin] == true then
                    plugins_disabled[plugin] = true
                end
            end
        end
        airplane_plugins:flush()
        airplane_plugins:close()

        G_reader_settings:saveSetting("plugins_disabled", plugins_disabled)
        G_reader_settings:saveSetting("wifi_enable_action","prompt")
        G_reader_settings:saveSetting("wifi_disable_action","turn_off")
        G_reader_settings:flush()

        if NetworkMgr:isWifiOn() then
            NetworkMgr:disableWifi(nil, true)
        end

        if Device:canRestart() then
            UIManager:askForRestart(_("KOReader needs to restart to finish applying changes for AirPlane Mode."))
        else
            UIManager:show(ConfirmBox:new{
                dismissable = false,
                text = _("KOReader needs to be restarted to finish applying changes for AirPlane Mode."),
                ok_text = _("OK"),
                ok_callback = function()
                    UIManager:quit()
                end,
            })
        end
    else
        logger.err("AirPlane Mode [ERROR] - Failed to create backup file and execute")
    end
end

function AirPlaneMode:turnoff()
    G_reader_settings:saveSetting("airplanemode",false)
    local BK_Settings = LuaSettings:open(DataStorage:getDataDir().."/settings.reader.lua.airplane")

    if BK_Settings:has("auto_restore_wifi") then
        local old_auto_restore_wifi = BK_Settings:readSetting("auto_restore_wifi")
        -- flip the real config
        G_reader_settings:saveSetting("auto_restore_wifi",old_auto_restore_wifi)
    else
        G_reader_settings:delSetting("auto_restore_wifi")
    end

    if BK_Settings:has("auto_disable_wifi") then
        local old_auto_disable_wifi = BK_Settings:readSetting("auto_disable_wifi")
        -- flip the real config
        G_reader_settings:saveSetting("auto_disable_wifi",old_auto_disable_wifi)
    else
        G_reader_settings:delSetting("auto_disable_wifi")
    end

    -- got to watch out for our emulator friends :) (ie, me, testing)
    if BK_Settings:has("emulator_fake_wifi_connected") then
        local old_emulator_fake_wifi_connected = BK_Settings:readSetting("emulator_fake_wifi_connected")
        -- flip the real config
        G_reader_settings:saveSetting("emulator_fake_wifi_connected",old_emulator_fake_wifi_connected)
    else
        G_reader_settings:delSetting("emulator_fake_wifi_connected")
    end

    if BK_Settings:has("wifi_enable_action") then
        local old_wifi_enable_action = BK_Settings:readSetting("wifi_enable_action")
        G_reader_settings:saveSetting("wifi_enable_action",old_wifi_enable_action)
    else
        G_reader_settings:delSetting("wifi_enable_action")
    end

    if BK_Settings:has("wifi_disable_action") then
        local old_wifi_disable_action = BK_Settings:readSetting("wifi_disable_action")
        G_reader_settings:saveSetting("wifi_disable_action",old_wifi_disable_action)
    else
        G_reader_settings:delSetting("wifi_disable_action")
    end

    if BK_Settings:has("http_proxy_enabled") then
        local old_http_proxy_enabled = BK_Settings:readSetting("http_proxy_enabled")
        -- flip the real config
        G_reader_settings:saveSetting("http_proxy_enabled",old_http_proxy_enabled)
    end

    if not NetworkMgr:isWifiOn() then
        NetworkMgr:enableWifi(nil, true)
    end

    local airplane_plugins = LuaSettings:open(self.airplane_plugins_file)
    local check_plugins = airplane_plugins:readSetting("disabled_plugins") or {}
    if type(check_plugins) == "string" then
        G_reader_settings:delSetting("plugins_disabled", check_plugins)
    else
        for plugin, __ in pairs(check_plugins) do
            G_reader_settings:delSetting("plugins_disabled", plugin)
        end
    end
    airplane_plugins:flush()
    airplane_plugins:close()

    -- Just in case we somehow have a plugin in both airplane's disable and the backup disable
    local disable_again = BK_Settings:readSetting("plugins_disabled")
    if disable_again then
        G_reader_settings:saveSetting("plugins_disabled", disable_again)
    end

    if isFile(settings_bk) then
        os.remove(settings_bk)
    end

    settings_bk_exists = false
    if Device:canRestart() then
        UIManager:askForRestart(_("KOReader needs to restart to finish disabling plugins for AirPlane Mode."))
    else
        UIManager:show(ConfirmBox:new{
            dismissable = false,
            text = _("You will need to restart KOReader to finish disabling AirPlane Mode."),
            ok_text = _("OK"),
            ok_callback = function()
                UIManager:quit()
            end,
        })
    end
end

local function airplanemode_status()
    -- test we can see the real settings file.
    if not isFile(settings_file) then
        logger.err("AirPlane Mode [ERROR] - Settings file not found! Abort!", settings_file)
    end
    -- check if we currently have a backup of our settings running
    if isFile(settings_bk) then
        settings_bk_exists = true
    end
    -- also verify if the airplanemode flag is set. we will use this to decide if something is funky
    local airplanemode_active = false
    if G_reader_settings:readSetting("airplanemode") then
        airplanemode_active = G_reader_settings:readSetting("airplanemode")
    end
    --
    if settings_bk_exists == true and airplanemode_active == true then
        return true
    elseif airplanemode_active == false then
        return false
    end
end

-- Lifted whole from pluginloader because it was the only way to dup the function :/
local function getMenuTable(plugin)
    local t = {}
    t.name = plugin.name
    t.fullname = string.format("%s", plugin.fullname or plugin.name)
    t.description = string.format("%s", plugin.description)
    return t
end

function AirPlaneMode:getSubMenuItems()
    self:initSettingsFile()
    local airplane_plugins = LuaSettings:open(self.airplane_plugins_file)
    local check_plugins = airplane_plugins:readSetting("disabled_plugins") or {}
    local os_enabled_plugins, os_disabled_plugins = PluginLoader:loadPlugins()
    local os_all_plugins = {}

    --Loop through os plugins that are enabled and mark that
    for _, plugin in ipairs(os_enabled_plugins) do
        local element = getMenuTable(plugin)
        element.enable = true
        table.insert(os_all_plugins, element)
    end
    -- first loop through disabled plugins and mark them in our own file if they don't already exist
    for _, plugin in ipairs(os_disabled_plugins) do
        local element = getMenuTable(plugin)
        if not check_plugins[plugin.name] then
            check_plugins[element.name] = true
        end
        element.enable = nil
        table.insert(os_all_plugins, element)
    end

    table.sort(os_all_plugins, function(v1, v2) return v1.fullname < v2.fullname end)

    local airplane_plugin_table = {}
    for __, plugin in ipairs(os_all_plugins) do
        if plugin.name ~= "airplanemode" then
            table.insert(airplane_plugin_table,
                {
                    text = _(plugin.fullname),
                    checked_func = function()
                        return check_plugins[plugin.name]
                    end,
                    enabled_func = function()
                        if (plugin.enable == false) or (plugin.enable == nil) then
                            return false
                        else
                            return true
                        end
                    end,
                    callback = function(touchmenu_instance)
                        if check_plugins[plugin.name] then
                            check_plugins[plugin.name] = nil
                        else
                            check_plugins[plugin.name] = true
                        end
                        airplane_plugins:saveSetting("disabled_plugins",check_plugins)
                        if touchmenu_instance then touchmenu_instance:updateItems() end
                        airplane_plugins:flush()
                    end,
                    help_text = T(_("%1\n\nThis plugin is already disabled in KOReader"),plugin.description),
                }
            )
        end
    end
    airplane_plugins:flush()
    airplane_plugins:close()
    return airplane_plugin_table
end

function AirPlaneMode:addToMainMenu(menu_items)
    menu_items.airplanemode = {
        text_func = function()
                    if airplanemode_status() == true then
                        return _("\u{F1D8} Airplane Mode")
                    else
                        return _("\u{F1D9} Airplane Mode")
                    end
                end,
        sorting_hint = "network",
        sub_item_table = {
            {
                text = _("AirPlane Mode"),
                separator = true,
            },
            {
                text_func = function()
                    if airplanemode_status() == true then
                        return _("\u{F1D8} Disable")
                    else
                        return _("\u{F1D9} Enable")
                    end
                end,
                checked_func = function() return airplanemode_status() end,
                callback = function()
                    if Device:isAndroid() then
                        UIManager:show(ConfirmBox:new{
                            dismissable = false,
                            text = _("AirPlane Mode should be managed in your device's network settings."),
                            ok_text = _("OK"),
                            ok_callback = function()
                                UIManager:close()
                            end,
                        })
                    else
                        if airplanemode_status() == true then
                            --airplanemode = true
                            self:turnoff()
                        else
                            --airplanemode = false
                            self:turnon()
                        end
                    end
                end,
            },
            {
                text = _("AirPlane Mode Plugin Manager"),
                sub_item_table_func = function()
                    if airplanemode_status() == true then
                    UIManager:show(InfoMessage:new{
                        text = _("AirPlane Mode cannot be configured while running"),
                        timeout = 3,
                    })
                    else
                        return self:getSubMenuItems()
                    end
                end,
            },
        },
    }
end

return AirPlaneMode
