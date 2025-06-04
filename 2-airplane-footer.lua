local DataStorage = require("datastorage")
local Device = require("device")
local ReaderFooter = require("apps/reader/modules/readerfooter")
local LuaSettings = require("luasettings")


--local UIManager = require("ui/uimanager")
local logger = require("logger")

local userpatch = require("userpatch")

local T = require("ffi/util").template
local _ = require("gettext")
local C_ = _.pgettext

if G_reader_settings == nil then
    G_reader_settings = require("luasettings"):open(DataStorage:getDataDir().."/settings.reader.lua")
end

---
---first add to settings file - test what happens when the patch is gone too :/
---
--local check_footer = G_reader_settings:readSetting("footer") or {}
local set_footer = G_reader_settings:readSetting("footer") or {}

-- a pair of loops for the logger

set_footer["apm_status"] = true

--[[for footer, __ in pairs(check_footer) do
    logger.info("MIKE setting set_footer",footer," to ",check_footer[footer])
    set_footer[footer] = check_footer[footer]

    
end]]


--[[G_reader_settings:saveSetting("footer",set_footer)
G_reader_settings:flush()]]


local MODE = userpatch.getUpValue(ReaderFooter.init, "MODE")
local readerinit = ReaderFooter.init

ReaderFooter.init = function(self)
readerinit(self)

MODE.apm_status = 21 -- unused value, but high enough updates to the real MODE shouldn't get here

    if not Device:hasFastWifiStatusQuery() then
        MODE.apm_status = nil
    end
end



--[[local function symbol_sorter(symbol)
    local t = {}
    t.letters = symbol.letters
    t.icons = symbol.letters
    t.compact_items = symbol.compact_items
    return t
end]]
logger.info("MIKE starting")

--local footerTextGeneratorMap = userpatch.getUpValue(ReaderFooter.applyFooterMode, "footerTextGeneratorMap")
local footerTextGeneratorMap = userpatch.getUpValue(ReaderFooter.addToMainMenu, "footerTextGeneratorMap")
local symbol_prefix = userpatch.getUpValue(footerTextGeneratorMap.wifi_status, "symbol_prefix")
logger.info("MIKE adding to symbol_prefix")

symbol_prefix.letters.apm_status = C_("FooterLetterPrefix", "APM:")

symbol_prefix.icons.apm_status = "\u{F1D8}"
symbol_prefix.compact_items.apm_status = "꜌"
symbol_prefix.icons.apm_status_off = "\u{F1D9}"
symbol_prefix.compact_items.apm_status_off = "꜍"
logger.info("symbol prefix is",symbol_prefix)

for _, item in ipairs { "wifi_status", "apm_status" } do
    local orig = footerTextGeneratorMap[item] or nil
    logger.info("MIKE adding item to footertext",item)
    if item == "apm_status" then
        logger.info("MIKE adding apm status to footertext")
        local reader_settings = LuaSettings:open(DataStorage:getDataDir().."/settings.reader.lua")
        local ap_status = reader_settings:isTrue("airplanemode")
        footerTextGeneratorMap["apm_status"] = function(footer, ...)
            if footer.settings.item_prefix == "icons" or footer.settings.item_prefix == "compact_items" then
                if ap_status then
                    return symbol_prefix.icons.apm_status
                else
                    if footer.settings.all_at_once and footer.settings.hide_empty_generators then
                        return ""
                    else
                        return symbol_prefix.icons.apm_status_off
                    end
                end
            else
                local prefix = symbol_prefix[footer.settings.item_prefix].apm_status
                if ap_status then
                    return T(_("%1 On"), prefix)
                else
                    if footer.settings.all_at_once and footer.settings.hide_empty_generators then
                        return ""
                    else
                        return T(_("%1 Off"), prefix)
                    end
                end
            end
        end
    end
    if item == "wifi_status" then
        footerTextGeneratorMap[item] = function(...) return orig end
    end
end

local orig_textOptionTitles = ReaderFooter.textOptionTitles
ReaderFooter.textOptionTitles = function(self,option)
    -- sadly another whole lift to be able to override the return. i think this is how this works?
    if option == "apm_status" then
        local symbol = self.settings.item_prefix
        logger.info("MIKE text option",symbol)

        local option_titles = {
            apm_status = T(_("AirPlane Mode status (%1)"), symbol_prefix[symbol].apm_status),
        }
        return option_titles[option]
    end
    orig_textOptionTitles(self,option)
end

-- addtomainmenu block here
local getMinibarOption = userpatch.getUpValue(ReaderFooter.addToMainMenu, "getMinibarOption")
local orig_addToMainMenu = ReaderFooter.addToMainMenu
--local footer_items = userpatch.getUpvalue(ReaderFooter.addToMainMenu, "footer_items")
ReaderFooter.addToMainMenu = function(self, menu_items)
    local footer_items = userpatch.getUpvalue(ReaderFooter.addToMainMenu, "footer_items")
    orig_addToMainMenu(self, menu_items, footer_items)
    if Device:hasFastWifiStatusQuery() then
        table.insert(footer_items, getMinibarOption("apm_status"))
    end
end

local orig_onNetworkConnected = ReaderFooter.onNetworkConnected
ReaderFooter.onNetworkConnected = function(self)
    if self.settings.apm_status then
        self:maybeUpdateFooter()
    end
    orig_onNetworkConnected()
end