local BD = require("ui/bidi")
local Device = require("device")
local ReaderFooter = require("apps/reader/modules/readerfooter")
local UIManager = require("ui/uimanager")

local logger = require("logger")
local userpatch = require("userpatch")
local T = require("ffi/util").template
local _ = require("gettext")
local C_ = _.pgettext


local MODE, MODE_idx = userpatch.getUpValue(ReaderFooter.init, "MODE")
MODE.apm_status = 21
userpatch.replaceUpValue(ReaderFooter.init, MODE_idx, MODE)

local symbol_prefix = userpatch.getUpValue(ReaderFooter.textOptionTitles, "symbol_prefix")
symbol_prefix.letters.apm_status = C_("FooterLetterPrefix", "AP:")
symbol_prefix.icons.apm_status = "\u{F1D8}"
symbol_prefix.icons.apm_status_off = "\u{F1D9}"

for _, item in ipairs { "apm_status", "apm_status_off" } do
    symbol_prefix.compact_items[item] = symbol_prefix.icons[item]
end

local footerTextGeneratorMap = userpatch.getUpValue(ReaderFooter.applyFooterMode, "footerTextGeneratorMap")

-- MPC - when this is working, see if you can just set the apm part without the loop
for _, item in ipairs { "wifi_status" } do
    local orig = footerTextGeneratorMap[item]
    footerTextGeneratorMap[item] = function(footer, ...)
        local text = orig(footer, ...)
        return text
    end
    footerTextGeneratorMap["apm_status"] = function(footer)
        local LuaSettings = require("luasettings")
        local DataStorage = require("datastorage")
        local reader_settings = LuaSettings:open(DataStorage:getDataDir().."/settings.reader.lua")
        local ap_status = reader_settings:isTrue("airplanemode")
        local symbol_type = footer.settings.item_prefix
        if symbol_type == "icons" or symbol_type == "compact_items" then
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
            local prefix = symbol_prefix[symbol_type].apm_status
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


-- Couldn't think of a way to insert the needed addition without just replacing the original
function ReaderFooter:rescheduleFooterAutoRefreshIfNeeded()
    if not self.autoRefreshFooter then
        -- Create this function the first time we're called
        self.autoRefreshFooter = function()
            -- Only actually repaint the footer if nothing's being shown over ReaderUI (#6616)
            -- (We want to avoid the footer to be painted over a widget covering it - we would
            -- be fine refreshing it if the widget is not covering it, but this is hard to
            -- guess from here.)
            self:onUpdateFooter(self:shouldBeRepainted())

            self:rescheduleFooterAutoRefreshIfNeeded() -- schedule (or not) next refresh
        end
    end
    local unscheduled = UIManager:unschedule(self.autoRefreshFooter) -- unschedule if already scheduled
    -- Only schedule an update if the footer has items that may change
    -- As self.view.footer_visible may be temporarily toggled off by other modules,
    -- we can't trust it for not scheduling auto refresh
    local schedule = false
    if self.settings.auto_refresh_time then
        if self.settings.all_at_once then
            if self.settings.time or self.settings.battery or self.settings.wifi_status
            or self.settings.mem_usage or self.settings.apm_status then
                schedule = true
            end
        else
            if self.mode == self.mode_list.time or self.mode == self.mode_list.battery
                    or self.mode == self.mode_list.wifi_status or self.mode == self.mode_list.mem_usage
                    or self.mode == self.mode_list.apm_status then
                schedule = true
            end
        end
    end

    if schedule then
        UIManager:scheduleIn(61 - tonumber(os.date("%S")), self.autoRefreshFooter)
        if not unscheduled then
            logger.dbg("ReaderFooter: scheduled autoRefreshFooter")
        else
            logger.dbg("ReaderFooter: rescheduled autoRefreshFooter")
        end
    elseif unscheduled then
        logger.dbg("ReaderFooter: unscheduled autoRefreshFooter")
    end
end

function ReaderFooter:textOptionTitles(option)
    local symbol = self.settings.item_prefix
    local option_titles = {
        all_at_once = _("Show all selected items at once"),
        reclaim_height = _("Overlap status bar"),
        bookmark_count = T(_("Bookmark count (%1)"), symbol_prefix[symbol].bookmark_count),
        page_progress = T(_("Current page (%1)"), "/"),
        pages_left_book = T(_("Pages left in book (%1)"), symbol_prefix[symbol].pages_left_book),
        time = symbol_prefix[symbol].time
            and T(_("Current time (%1)"), symbol_prefix[symbol].time) or _("Current time"),
        chapter_progress = T(_("Current page in chapter (%1)"), " ⁄⁄ "),
        pages_left = T(_("Pages left in chapter (%1)"), symbol_prefix[symbol].pages_left),
        battery = T(_("Battery percentage (%1)"), symbol_prefix[symbol].battery),
        percentage = symbol_prefix[symbol].percentage
            and T(_("Progress percentage (%1)"), symbol_prefix[symbol].percentage) or _("Progress percentage"),
        book_time_to_read = symbol_prefix[symbol].book_time_to_read
            and T(_("Time left to finish book (%1)"),symbol_prefix[symbol].book_time_to_read) or _("Time left to finish book"),
        chapter_time_to_read = T(_("Time left to finish chapter (%1)"), symbol_prefix[symbol].chapter_time_to_read),
        frontlight = T(_("Brightness level (%1)"), symbol_prefix[symbol].frontlight),
        frontlight_warmth = T(_("Warmth level (%1)"), symbol_prefix[symbol].frontlight_warmth),
        mem_usage = T(_("KOReader memory usage (%1)"), symbol_prefix[symbol].mem_usage),
        wifi_status = T(_("Wi-Fi status (%1)"), symbol_prefix[symbol].wifi_status),
        page_turning_inverted = T(_("Page turning inverted (%1)"), symbol_prefix[symbol].page_turning_inverted),
        book_author = _("Book author"),
        book_title = _("Book title"),
        book_chapter = _("Chapter title"),
        custom_text = T(_("Custom text (long-press to edit): \'%1\'%2"), self.custom_text,
            self.custom_text_repetitions > 1 and
            string.format(" × %d", self.custom_text_repetitions) or ""),
        dynamic_filler = _("Dynamic filler"),
        apm_status = T(_("AirPlane Mode status (%1)"), symbol_prefix[symbol].apm_status),
    }
    return option_titles[option]
end

function ReaderFooter:onNetworkConnected()
    if self.settings.wifi_status or self.settings.apm_status then
        self:maybeUpdateFooter()
    end
end
ReaderFooter.onNetworkDisconnected = ReaderFooter.onNetworkConnected
