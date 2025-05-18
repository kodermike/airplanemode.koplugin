-- TODO - init the plugins file
-- TODO - move our current list of plugins to disable to the init process for the config
-- TODO - in editPluginList, loop our config and compare to os config for final list
    -- TODO - skip plugins already disabled in main config
-- TODO - change the off function to just loop through our config + wireless settings

local ButtonDialog = require("ui/widget/buttondialog")
local ConfirmBox = require("ui/widget/confirmbox")
local Device = require("device")
local Dispatcher = require("dispatcher")
local InfoMessage = require("ui/widget/infomessage")
local LuaSettings = require("luasettings")
local NetworkMgr = require("ui/network/manager")
local PluginLoader = require("pluginloader")
local Screen = require("device").screen
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local dump = require("dump")
local ffiutil = require("ffi/util")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local util = require("util")
local _ = require("gettext")
local T = ffiutil.template
local rootpath = lfs.currentdir()
local settings_file = rootpath.."/settings.reader.lua"
local settings_bk = rootpath.."/settings.reader.lua.airplane"
local settings_bk_exists = false
-- establish the main settings file
local DataStorage = require("datastorage")
if G_reader_settings == nil then
    G_reader_settings = require("luasettings"):open(DataStorage:getDataDir().."/settings.reader.lua")
end

local AirPlaneMode = WidgetContainer:extend{
    name = "airplanemode",
    is_doc_only = false,
}

local function isFile(filename)
    logger.dbg("Airplane - checking existence of ",filename)
    if lfs.attributes(filename, "mode") == "file" then
        return true
    end
    return false
end

function AirPlaneMode:onDispatcherRegisterActions()
    logger.dbg("AirPlane - dispatching")
    Dispatcher:registerAction("airplanemode_action", { category="none", event="SwitchAirPlane", title=_("AirPlane Mode"), general=true,})
end

function AirPlaneMode:init()
    logger.dbg("AirPlane - init'ing")
    self:onDispatcherRegisterActions()
    self.ui.menu:registerToMainMenu(self)
    self.airplane_plugins_file = rootpath.."/settings/airplane_plugins.lua"
    logger.dbg("AirPlane - plugins file is ",self.airplane_plugins_file)
    -- MPC REMOVE
    -- TODO

    --self.airplane_plugins = require("luasettings"):open(DataStorage:getSettingsDir() .. "/airplane_plugins.lua")

end

function AirPlaneMode:initSettingsFile()
    logger.dbg("AirPlane - setting up plugin tracker ",self.airplane_plugins_file)
    if isFile(self.airplane_plugins_file) == true then
        logger.dbg("AirPlane - plugin tracker already exists")
        return
    else
        logger.dbg("Airplane - Opening settings file ",self.airplane_plugins_file)
        local airplane_plugins = require("luasettings"):open(self.airplane_plugins_file)
        airplane_plugins:saveSetting("goodreads",true)
        airplane_plugins:saveSetting("newsdownloader",true)
        airplane_plugins:saveSetting("wallabag",true)
        airplane_plugins:saveSetting("calibre",true)
        airplane_plugins:saveSetting("kosync",true)
        airplane_plugins:saveSetting("opds",true)
        airplane_plugins:saveSetting("SSH",true)
        airplane_plugins:saveSetting("timesync",true)
        airplane_plugins:saveSetting("httpinspector",true)
        airplane_plugins:flush()
    end
end




function AirPlaneMode:backup()
    -- settings_file = settings_file or self.settings_file
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
        -- mark airplane as active
        G_reader_settings:saveSetting("airplanemode",true)
        -- disable plugins, wireless, all of it

        G_reader_settings:saveSetting("auto_restore_wifi",false)
        G_reader_settings:saveSetting("auto_disable_wifi",true)
        G_reader_settings:saveSetting("wifi_was_on",false)
        G_reader_settings:saveSetting("http_proxy_enabled",false)
        G_reader_settings:saveSetting("kosync",{auto_sync = false, checksum_method = "0", sync_backward="3", sync_forward = "1"})
        if Device:isEmulator() then
            G_reader_settings:saveSetting("emulator_fake_wifi_connected",false)
        end
        local check_plugins = {"goodreads","newsdownloader","wallabag","calibre","kosync","opds","SSH","timesync","httpinspector"}
        local plugins_disabled = G_reader_settings:readSetting("plugins_disabled") or {}

        for __, plugin in ipairs(check_plugins) do
            logger.dbg("AirPlane Mode - checking plugin ",plugin)
            if not plugins_disabled[plugin] == true then
                plugins_disabled[plugin] = true
                logger.dbg("AirPlane Mode - adding to plugin list ",plugin)
            end
        end
        G_reader_settings:saveSetting("plugins_disabled", plugins_disabled)
        G_reader_settings:saveSetting("wifi_enable_action","prompt")
        G_reader_settings:saveSetting("wifi_disable_action","turn_off")



        if Device:hasWifiManager() then
                NetworkMgr:disableWifi()
        end
        --settings_bk_exists = true
        --airplanemode_active = true
        if Device:canRestart() then
            UIManager:show(ConfirmBox:new{
                dismissable = false,
                text = _("KOReader needs to be restarted to finish enabling AirPlane Mode."),
                ok_text = _("Restart"),
                ok_callback = function()
                        UIManager:restartKOReader()
                end,
            })
        else
            UIManager:show(ConfirmBox:new{
                dismissable = false,
                text = _("You will need to restart KOReader to finish enabling AirPlane Mode."),
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
    local BK_Settings = require("luasettings"):open(DataStorage:getDataDir().."/settings.reader.lua.airplane")
    --BK_Settings = require("luasettings"):open(DataStorage:getDataDir().."/settings.reader.lua")

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
        local wifi_enable_action = BK_Settings:readSetting("wifi_enable_action")
        G_reader_settings:saveSetting("wifi_enable_action",wifi_enable_action)
    else
        G_reader_settings:delSetting("wifi_enable_action")
    end


    if BK_Settings:has("wifi_disable_action") then
        local wifi_disable_action = BK_Settings:readSetting("wifi_disable_action")
        G_reader_settings:saveSetting("wifi_disable_action",wifi_disable_action)
    else
        G_reader_settings:delSetting("wifi_disable_action")
    end


    if BK_Settings:has("http_proxy_enabled") then
        local old_http_proxy_enabled = BK_Settings:readSetting("http_proxy_enabled")
        -- flip the real config
        G_reader_settings:saveSetting("http_proxy_enabled",old_http_proxy_enabled)
    end

    if BK_Settings:has("kosync",{auto_sync}) then
        local old_auto_sync =  BK_Settings:readSetting("kosync",{auto_sync})
        -- flip the real config
        G_reader_settings:saveSetting("kosync",old_auto_sync)
    end
    if BK_Settings:has("kosync",{checksum_method}) then
        local old_checksum_method =  BK_Settings:readSetting("kosync",{checksum_method})
        -- flip the real config
        G_reader_settings:saveSetting("kosync",old_checksum_method)
    end
    if BK_Settings:has("kosync",{sync_backward}) then
        local old_sync_backward =  BK_Settings:readSetting("kosync",{sync_backward})
        -- flip the real config
        G_reader_settings:saveSetting("kosync",old_sync_backward)
    end
    if BK_Settings:has("kosync",{sync_forward}) then
        local old_sync_forward =  BK_Settings:readSetting("kosync",{sync_forward})
        -- flip the real config
        G_reader_settings:saveSetting("kosync",old_sync_forward)
    end

    local old_check_plugins = {"goodreads","newsdownloader","wallabag","calibre","kosync","opds","SSH","timesync","httpinspector"}
    -- remove the disables from airplane mode
    for __, oldplugin in ipairs(old_check_plugins) do
        if not BK_Settings:readSetting("plugins_disabled",oldplugin) == true then
            G_reader_settings:delSetting("plugins_disabled", oldplugin)
        end
    end
    -- Now add back our saved disbles

    local disable_again = BK_Settings:readSetting("plugins_disabled")
    if disable_again then
        G_reader_settings:saveSetting("plugins_disabled", disable_again)
    end

    if isFile(settings_bk) then
        os.remove(settings_bk)
    end

    if Device:hasWifiManager() then
        NetworkMgr:enableWifi()
    end
    settings_bk_exists = false
    local airplanemode_active = false
    if G_reader_settings:readSetting("airplanemode") then
        airplanemode_active = G_reader_settings:readSetting("airplanemode")
    end
    airplanemode_active = false
    if Device:canRestart() then
        UIManager:show(ConfirmBox:new{
            dismissable = false,
            text = _("KOReader needs to be restarted to finish disabling AirPlane Mode."),
            ok_text = _("Restart"),
            ok_callback = function()
                    UIManager:restartKOReader()
            end,
        })
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
    ---------
    if settings_bk_exists == true and airplanemode_active == true then
        return true
    elseif airplanemode_active == false then
        return false
    end
end

function AirPlaneMode:onMenuHold()
    local edit_dialog
    local title = _("Edit Plugins To Decactivate")
    if airplanemode_status() == true then
        edit_dialog = {
            title = title,
            callback = function()
                UIManager:show(InfoMessage:new{
                    text = _("AirPlane Mode can't be configured while running"),
                })
            end,
        }
        UIManager:show(edit_dialog)
    else -- TODO replace with call to the menu page for plugins

        edit_dialog = {
            title = title,
            callback = function()
                UIManager:show(InfoMessage:new{
                    text = _("For now nothing can be configured in AirPlane Mode"),
                })
            end,
        }
        UIManager:show(edit_dialog)
    end
end

function AirPlaneMode:onShowAirPlaneModeMenu()
    local plugin_dialog
    local title = _("Are we testing?")
    plugin_dialog = ButtonDialog:new{
        --checked_func = function() return airplanemode_status() end,
        title = title,
        is_popout = false,
        is_borderless = true,
        title_bar_fm_style = true,
        _manager = self,
        buttons = {
            {
                {
                    text = T(_("Toggle %1"),onoff ),
                    callback = function()
                        if Device:isAndroid() then
                            UIManager:show(ConfirmBox:new{
                                dismissable = false,
                                text = _("AirPlane Mode should be managed in your device's network settings."),
                                ok_text = _("OK"),
                                ok_callback = function()
                                    UIManager:close()
                                end
                            })
                        else
                            if onoff == "Off" then
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
                    text = _("Select plugins"),
                    callback = function()
                        UIManager:close(plugin_dialog)
                        self:editPluginList(menu_items)
                    end
                },
                {
                    text = _("Cancel"),
                    id = "close",
                    callback = function()
                        UIManager:close(plugin_dialog)
                    end,
                },
            },
        },
    }
    UIManager:show(plugin_dialog)
    return true
end

-- TODO - remove?
-- This is verbatim borrowed, but since it was a local function I don't another way of referencing it
-- Deprecated plugins are still available, but show a hint about deprecation.
local function getMenuTable(plugin)
    local t = {}
    t.name = plugin.name
    t.fullname = string.format("%s%s", plugin.fullname or plugin.name,
        plugin.deprecated and " (" .. _("outdated") .. ")" or "")

    local deprecated, message = deprecationFmt(plugin.deprecated)
    t.description = string.format("%s%s", plugin.description,
        deprecated and "\n\n" .. message or "")
    return t
end

function AirPlaneMode:editPluginList(menu_items)
    -- check if airplane mode is on - if so, tell the user we can't configure while running
    -- get the list of plugins
    -- get the list of plugins we've already said we want to disable if it exists
    -- present list, marking the already marked
    -- save changes

    local os_sub_item_table = PluginLoader:genPluginManagerSubItem()

    local plugin_dialog
    local title = _("Are we testing?")
    plugin_dialog = ButtonDialog:new{
        --checked_func = function() return airplanemode_status() end,
        title = title,
        is_popout = false,
        is_borderless = true,
        title_bar_fm_style = true,
        _manager = self,
        buttons = {
            {
                {
                    callback = function()
                        if airplanemode_status() == true then
                            UIManager:show(InfoMessage:new{
                                text = _("AirPlane Mode can't be configured while running"),
                            })
                        else
                            menu_items.editPluginList = {
                                callback = function()
                                    UIManager:show(ConfirmBox:new{
                                        dismissable = false,
                                        text = _("This part not yet written. Sorry!"),
                                    })
                                end,
                                keep_menu_open = true,
                                separator = true
                            }
                        end
                    end,
                },
            },
        },
    }
end

function AirPlaneMode:addToMainMenu(menu_items)
    local rootpath = lfs.currentdir()
    settings_file = rootpath.."/settings.reader.lua"
    settings_bk = rootpath.."/settings.reader.lua.airplane"

    menu_items.airplanemode = {
        text = _("AirPlane Mode"),
        sorting_hint = "network",
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
                if airplanemode_status() then
                    --airplanemode = true
                    self:turnoff()
                else
                    --airplanemode = false
                    self:turnon()
                end
            end
        end,
        hold_callback = function()
            --local edit_dialog
            local title = _("Edit Plugins To Decactivate")
            if airplanemode_status() == true then
                UIManager:show(InfoMessage:new{
                    title = title,
                    text = _("AirPlane Mode can't be configured while running"),
                    ok_text = _("OK"),
                    ok_callback = function()
                        UIManager:close()
                    end,
                })
            else
                logger.dbg("Airplane - checking settings file")
                self:initSettingsFile()
                UIManager:show(InfoMessage:new{
                    title = title,
                    text = _("For now nothing can be configured in AirPlane Mode, sorry"),
                    ok_text = _("OK"),
                    ok_callback = function()
                        UIManager:close()
                    end,
                })
            end
        end,
    }
end

return AirPlaneMode
