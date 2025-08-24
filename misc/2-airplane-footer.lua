local Device = require("device")
local Presets = require("ui/presets")
local ReaderFooter = require("apps/reader/modules/readerfooter")
local Size = require("ui/size")
local SpinWidget = require("ui/widget/spinwidget")
local UIManager = require("ui/uimanager")

local logger = require("logger")
local userpatch = require("userpatch")
local T = require("ffi/util").template
local _ = require("gettext")
local C_ = _.pgettext
local Screen = Device.screen

local MODE, MODE_idx = userpatch.getUpValue(ReaderFooter.init, "MODE")
MODE.apm_status = 21
userpatch.replaceUpValue(ReaderFooter.init, MODE_idx, MODE)

local symbol_prefix = userpatch.getUpValue(ReaderFooter.textOptionTitles, "symbol_prefix")
symbol_prefix.letters.apm_status = C_("FooterLetterPrefix", "AP:")
symbol_prefix.icons.apm_status = "\u{F1D8}"
symbol_prefix.icons.apm_status_off = "\u{F1D9}"

for _, item in ipairs({ "apm_status", "apm_status_off" }) do
	symbol_prefix.compact_items[item] = symbol_prefix.icons[item]
end

local footerTextGeneratorMap = userpatch.getUpValue(ReaderFooter.applyFooterMode, "footerTextGeneratorMap")

-- Add the airplane mode status to the footer
footerTextGeneratorMap["apm_status"] = function(footer)
	local LuaSettings = require("luasettings")
	local DataStorage = require("datastorage")
	local reader_settings = LuaSettings:open(DataStorage:getDataDir() .. "/settings.reader.lua")
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

local option_help_text = userpatch.getUpValue(ReaderFooter.addToMainMenu, "option_help_text")

function ReaderFooter:addToMainMenu(menu_items)
	local sub_items = {}
	menu_items.status_bar = {
		text = _("Status bar"),
		sub_item_table = sub_items,
	}

	-- If using crengine, add Alt status bar items at top
	if self.ui.crelistener then
		table.insert(sub_items, self.ui.crelistener:getAltStatusBarMenu())
	end

	-- menu item to fake footer tapping when touch area is disabled
	local DTAP_ZONE_MINIBAR = G_defaults:readSetting("DTAP_ZONE_MINIBAR")
	if DTAP_ZONE_MINIBAR.h == 0 or DTAP_ZONE_MINIBAR.w == 0 then
		table.insert(sub_items, {
			text = _("Toggle mode"),
			enabled_func = function()
				return not self.view.flipping_visible
			end,
			callback = function()
				self:onToggleFooterMode()
			end,
		})
	end

	local getMinibarOption = function(option, callback)
		return {
			text_func = function()
				return self:textOptionTitles(option)
			end,
			help_text = type(option_help_text[option]) == "string" and option_help_text[option],
			help_text_func = type(option_help_text[option]) == "function" and function(touchmenu_instance)
				option_help_text[option](self, touchmenu_instance)
			end,
			checked_func = function()
				return self.settings[option] == true
			end,
			callback = function()
				self.settings[option] = not self.settings[option]
				-- We only need to send a SetPageBottomMargin event when we truly affect the margin
				local should_signal = false
				-- only case that we don't need a UI update is enable/disable
				-- non-current mode when all_at_once is disabled.
				local should_update = false
				local first_enabled_mode_num
				local prev_has_no_mode = self.has_no_mode
				local prev_reclaim_height = self.reclaim_height
				self.has_no_mode = true
				for mode_num, m in pairs(self.mode_index) do
					if self.settings[m] then
						first_enabled_mode_num = mode_num
						self.has_no_mode = false
						break
					end
				end
				self.reclaim_height = self.settings.reclaim_height
				-- refresh margins position
				if self.has_no_mode then
					self.footer_text.height = 0
					should_signal = true
					self.genFooterText = footerTextGeneratorMap.empty
					self.mode = self.mode_list.off
				elseif prev_has_no_mode then
					if self.settings.all_at_once then
						self.mode = self.mode_list.page_progress
						self:applyFooterMode()
						G_reader_settings:saveSetting("reader_footer_mode", self.mode)
					else
						G_reader_settings:saveSetting("reader_footer_mode", first_enabled_mode_num)
					end
					should_signal = true
				elseif self.reclaim_height ~= prev_reclaim_height then
					should_signal = true
					should_update = true
				end
				if callback then
					should_update = callback(self)
				elseif self.settings.all_at_once then
					should_update = self:updateFooterTextGenerator()
				elseif
					(self.mode_list[option] == self.mode and self.settings[option] == false)
					or (prev_has_no_mode ~= self.has_no_mode)
				then
					-- current mode got disabled, redraw footer with other
					-- enabled modes. if all modes are disabled, then only show
					-- progress bar
					if not self.has_no_mode then
						self.mode = first_enabled_mode_num
					else
						-- If we've just disabled our last mode, first_enabled_mode_num is nil
						-- If the progress bar is enabled,
						-- fake an innocuous mode so that we switch to showing the progress bar alone, instead of nothing,
						-- This is exactly what the "Show progress bar" toggle does.
						self.mode = self.settings.disable_progress_bar and self.mode_list.off
							or self.mode_list.page_progress
					end
					should_update = true
					self:applyFooterMode()
					G_reader_settings:saveSetting("reader_footer_mode", self.mode)
				end
				if should_update or should_signal then
					self:refreshFooter(should_update, should_signal)
				end
				-- The absence or presence of some items may change whether auto-refresh should be ensured
				self:rescheduleFooterAutoRefreshIfNeeded()
			end,
		}
	end

	table.insert(sub_items, {
		text = _("Progress bar"),
		separator = true,
		sub_item_table = {
			{
				text = _("Show progress bar"),
				checked_func = function()
					return not self.settings.disable_progress_bar
				end,
				callback = function()
					self.settings.disable_progress_bar = not self.settings.disable_progress_bar
					if not self.settings.disable_progress_bar then
						self:setTocMarkers()
					end
					-- If the status bar is currently disabled, switch to an innocuous mode to display it
					if not self.view.footer_visible then
						self.mode = self.mode_list.page_progress
						self:applyFooterMode()
						G_reader_settings:saveSetting("reader_footer_mode", self.mode)
					end
					self:refreshFooter(true, true)
				end,
			},
			{
				text = _("Show chapter-progress bar instead"),
				help_text = _("Show progress bar for the current chapter, instead of the whole book."),
				enabled_func = function()
					return not self.settings.disable_progress_bar
				end,
				checked_func = function()
					return self.settings.chapter_progress_bar
				end,
				callback = function()
					self:onToggleChapterProgressBar()
				end,
			},
			{
				text_func = function()
					return T(_("Position: %1"), self:genProgressBarPositionMenuItems())
				end,
				enabled_func = function()
					return not self.settings.disable_progress_bar
				end,
				sub_item_table = {
					self:genProgressBarPositionMenuItems("above"),
					self:genProgressBarPositionMenuItems("alongside"),
					self:genProgressBarPositionMenuItems("below"),
				},
				separator = true,
			},
			{
				text_func = function()
					if self.settings.progress_style_thin then
						return _("Thickness and height: thin")
					else
						return _("Thickness and height: thick")
					end
				end,
				enabled_func = function()
					return not self.settings.disable_progress_bar
				end,
				sub_item_table = {
					{
						text = _("Thick"),
						checked_func = function()
							return not self.settings.progress_style_thin
						end,
						callback = function()
							self.settings.progress_style_thin = nil
							local bar_height = self.settings.progress_style_thick_height
							self.progress_bar:updateStyle(true, bar_height)
							self:setTocMarkers()
							self:refreshFooter(true, true)
						end,
					},
					{
						text = _("Thin"),
						checked_func = function()
							return self.settings.progress_style_thin
						end,
						callback = function()
							self.settings.progress_style_thin = true
							local bar_height = self.settings.progress_style_thin_height
							self.progress_bar:updateStyle(false, bar_height)
							self:refreshFooter(true, true)
						end,
						separator = true,
					},
					{
						text_func = function()
							local height = self.settings.progress_style_thin
									and self.settings.progress_style_thin_height
								or self.settings.progress_style_thick_height
							return T(_("Height: %1"), height)
						end,
						callback = function(touchmenu_instance)
							local value, value_min, value_max, default_value
							if self.settings.progress_style_thin then
								default_value = self.default_settings.progress_style_thin_height
								value = self.settings.progress_style_thin_height
								value_min = 1
								value_max = 12
							else
								default_value = self.default_settings.progress_style_thick_height
								value = self.settings.progress_style_thick_height
								value_min = 5
								value_max = 28
							end
							local items = SpinWidget:new({
								value = value,
								value_min = value_min,
								value_step = 1,
								value_hold_step = 2,
								value_max = value_max,
								default_value = default_value,
								title_text = _("Progress bar height"),
								keep_shown_on_apply = true,
								callback = function(spin)
									if self.settings.progress_style_thin then
										self.settings.progress_style_thin_height = spin.value
									else
										self.settings.progress_style_thick_height = spin.value
									end
									self:refreshFooter(true, true)
									touchmenu_instance:updateItems()
								end,
							})
							UIManager:show(items)
						end,
						keep_menu_open = true,
					},
				},
			},
			{
				text_func = function()
					local value = self.settings.progress_margin and _("same as book margins")
						or self.settings.progress_margin_width
					return T(_("Margins: %1"), value)
				end,
				enabled_func = function()
					return not self.settings.disable_progress_bar
				end,
				keep_menu_open = true,
				callback = function(touchmenu_instance)
					local spin_widget
					spin_widget = SpinWidget:new({
						title_text = _("Progress bar margins"),
						value = self.settings.progress_margin_width,
						value_min = 0,
						value_max = 140, -- max creoptions h_page_margins
						value_hold_step = 5,
						default_value = self.default_settings.progress_margin_width,
						keep_shown_on_apply = true,
						callback = function(spin)
							self.settings.progress_margin_width = spin.value
							self.settings.progress_margin = false
							self:refreshFooter(true)
							touchmenu_instance:updateItems()
						end,
						extra_text = not self.ui.document.info.has_pages and _("Same as book margins"),
						extra_callback = function()
							local h_margins = self.ui.document.configurable.h_page_margins
							local value = math.floor((h_margins[1] + h_margins[2]) / 2)
							self.settings.progress_margin_width = value
							self.settings.progress_margin = true
							self:refreshFooter(true)
							touchmenu_instance:updateItems()
							spin_widget.value = value
							spin_widget.original_value = value
							spin_widget:update()
						end,
					})
					UIManager:show(spin_widget)
				end,
			},
			{
				text_func = function()
					return T(_("Minimum progress bar width: %1\xE2\x80\xAF%"), self.settings.progress_bar_min_width_pct) -- U+202F NARROW NO-BREAK SPACE
				end,
				enabled_func = function()
					return self.settings.progress_bar_position == "alongside"
						and not self.settings.disable_progress_bar
						and self.settings.all_at_once
				end,
				callback = function(touchmenu_instance)
					local items = SpinWidget:new({
						value = self.settings.progress_bar_min_width_pct,
						value_min = 5,
						value_step = 5,
						value_hold_step = 20,
						value_max = 50,
						unit = "%",
						title_text = _("Minimum progress bar width"),
						text = _("Minimum percentage of screen width assigned to progress bar"),
						keep_shown_on_apply = true,
						callback = function(spin)
							self.settings.progress_bar_min_width_pct = spin.value
							self:refreshFooter(true, true)
							if touchmenu_instance then
								touchmenu_instance:updateItems()
							end
						end,
					})
					UIManager:show(items)
				end,
				keep_menu_open = true,
				separator = true,
			},
			{
				text = _("Show initial-position marker"),
				checked_func = function()
					return self.settings.initial_marker == true
				end,
				enabled_func = function()
					return not self.settings.disable_progress_bar
				end,
				callback = function()
					self.settings.initial_marker = not self.settings.initial_marker
					self.progress_bar.initial_pos_marker = self.settings.initial_marker
					self:refreshFooter(true)
				end,
			},
			{
				text = _("Show chapter markers"),
				checked_func = function()
					return self.settings.toc_markers == true and not self.settings.chapter_progress_bar
				end,
				enabled_func = function()
					return not self.settings.progress_style_thin
						and not self.settings.chapter_progress_bar
						and not self.settings.disable_progress_bar
				end,
				callback = function()
					self.settings.toc_markers = not self.settings.toc_markers
					self:setTocMarkers()
					self:refreshFooter(true)
				end,
			},
			{
				text_func = function()
					return T(_("Chapter marker width: %1"), self:genProgressBarChapterMarkerWidthMenuItems())
				end,
				enabled_func = function()
					return not self.settings.progress_style_thin
						and not self.settings.chapter_progress_bar
						and self.settings.toc_markers
						and not self.settings.disable_progress_bar
				end,
				sub_item_table = {
					self:genProgressBarChapterMarkerWidthMenuItems(1),
					self:genProgressBarChapterMarkerWidthMenuItems(2),
					self:genProgressBarChapterMarkerWidthMenuItems(3),
				},
			},
		},
	})
	-- footer_items
	local footer_items = {}
	table.insert(sub_items, {
		text = _("Status bar items"),
		sub_item_table = footer_items,
	})
	table.insert(footer_items, getMinibarOption("page_progress"))
	table.insert(footer_items, getMinibarOption("pages_left_book"))
	table.insert(footer_items, getMinibarOption("time"))
	table.insert(footer_items, getMinibarOption("chapter_progress"))
	table.insert(footer_items, getMinibarOption("pages_left"))
	if Device:hasBattery() then
		table.insert(footer_items, getMinibarOption("battery"))
	end
	table.insert(footer_items, getMinibarOption("bookmark_count"))
	table.insert(footer_items, getMinibarOption("percentage"))
	table.insert(footer_items, getMinibarOption("book_time_to_read"))
	table.insert(footer_items, getMinibarOption("chapter_time_to_read"))
	if Device:hasFrontlight() then
		table.insert(footer_items, getMinibarOption("frontlight"))
	end
	if Device:hasNaturalLight() then
		table.insert(footer_items, getMinibarOption("frontlight_warmth"))
	end
	table.insert(footer_items, getMinibarOption("mem_usage"))
	if Device:hasFastWifiStatusQuery() then
		table.insert(footer_items, getMinibarOption("wifi_status"))
	end
	table.insert(footer_items, getMinibarOption("apm_status"))
	table.insert(footer_items, getMinibarOption("page_turning_inverted"))
	table.insert(footer_items, getMinibarOption("book_author"))
	table.insert(footer_items, getMinibarOption("book_title"))
	table.insert(footer_items, getMinibarOption("book_chapter"))
	table.insert(footer_items, getMinibarOption("custom_text"))
	table.insert(footer_items, getMinibarOption("dynamic_filler"))

	-- configure footer_items
	table.insert(sub_items, {
		text = _("Configure items"),
		separator = true,
		sub_item_table = {
			{
				text = _("Arrange items in status bar"),
				separator = true,
				keep_menu_open = true,
				enabled_func = function()
					local enabled_count = 0
					for _, m in ipairs(self.mode_index) do
						if self.settings[m] then
							if enabled_count == 1 then
								return true
							end
							enabled_count = enabled_count + 1
						end
					end
					return false
				end,
				callback = function()
					local item_table = {}
					for i, item in ipairs(self.mode_index) do
						item_table[i] =
							{ text = self:textOptionTitles(item), label = item, dim = not self.settings[item] }
					end
					local SortWidget = require("ui/widget/sortwidget")
					UIManager:show(SortWidget:new({
						title = _("Arrange items"),
						height = Screen:getHeight() - self:getHeight() - Size.padding.large,
						item_table = item_table,
						callback = function()
							for i, item in ipairs(item_table) do
								self.mode_index[i] = item.label
							end
							self.settings.order = self.mode_index
							self:updateFooterTextGenerator()
							self:onUpdateFooter(true)
							UIManager:setDirty(nil, "ui")
						end,
					}))
				end,
			},
			getMinibarOption("all_at_once", self.updateFooterTextGenerator),
			{
				text = _("Auto refresh items"),
				help_text = _(
					"This option allows certain items to update without needing user interaction (i.e page refresh). For example, the time item will update every minute regardless of user input."
				),
				checked_func = function()
					return self.settings.auto_refresh_time == true
				end,
				callback = function()
					self.settings.auto_refresh_time = not self.settings.auto_refresh_time
					self:rescheduleFooterAutoRefreshIfNeeded()
				end,
			},
			{
				text = _("Hide inactive items"),
				help_text = _(
					[[This option will hide inactive items from appearing on the status bar. For example, if the frontlight is 'off' (i.e 0 brightness), no symbols or values will be displayed until the brightness is set to a value >= 1.]]
				),
				enabled_func = function()
					return self.settings.all_at_once == true
				end,
				checked_func = function()
					return self.settings.hide_empty_generators == true
				end,
				callback = function()
					self.settings.hide_empty_generators = not self.settings.hide_empty_generators
					self:refreshFooter(true, true)
				end,
			},
			{
				text = _("Include current page in pages left"),
				help_text = _(
					[[By default, KOReader does not include the current page when calculating pages left. For example, in a book or chapter with n pages the 'pages left' item will range from 'n−1' to 0 (last page).With this feature enabled, the current page is factored in, resulting in the count going from n to 1 instead.]]
				),
				enabled_func = function()
					return self.settings.pages_left or self.settings.pages_left_book
				end,
				checked_func = function()
					return self.settings.pages_left_includes_current_page == true
				end,
				callback = function()
					self.settings.pages_left_includes_current_page = not self.settings.pages_left_includes_current_page
					self:refreshFooter(true)
				end,
			},
			{
				text_func = function()
					return T(_("Progress percentage format: %1"), self:genProgressPercentageFormatMenuItems())
				end,
				sub_item_table = {
					self:genProgressPercentageFormatMenuItems("0"),
					self:genProgressPercentageFormatMenuItems("1"),
					self:genProgressPercentageFormatMenuItems("2"),
				},
				separator = true,
			},
			{
				text_func = function()
					local font_weight = ""
					if self.settings.text_font_bold == true then
						font_weight = ", " .. _("bold")
					end
					return T(_("Item font: %1%2"), self.settings.text_font_size, font_weight)
				end,
				sub_item_table = {
					{
						text_func = function()
							return T(_("Item font size: %1"), self.settings.text_font_size)
						end,
						callback = function(touchmenu_instance)
							local items_font = SpinWidget:new({
								title_text = _("Item font size"),
								value = self.settings.text_font_size,
								value_min = 8,
								value_max = 36,
								default_value = self.default_settings.text_font_size,
								keep_shown_on_apply = true,
								callback = function(spin)
									self.settings.text_font_size = spin.value
									self:updateFooterFont()
									self:refreshFooter(true, true)
									touchmenu_instance:updateItems()
								end,
							})
							UIManager:show(items_font)
						end,
						keep_menu_open = true,
					},
					{
						text = _("Items in bold"),
						checked_func = function()
							return self.settings.text_font_bold == true
						end,
						callback = function()
							self.settings.text_font_bold = not self.settings.text_font_bold
							self:updateFooterFont()
							self:refreshFooter(true, true)
						end,
					},
				},
			},
			{
				text_func = function()
					return T(_("Item symbols: %1"), self:genItemSymbolsMenuItems())
				end,
				sub_item_table = {
					self:genItemSymbolsMenuItems("icons"),
					self:genItemSymbolsMenuItems("letters"),
					self:genItemSymbolsMenuItems("compact_items"),
				},
			},
			{
				text_func = function()
					return T(_("Item separator: %1"), self:genItemSeparatorMenuItems())
				end,
				sub_item_table = {
					self:genItemSeparatorMenuItems("bar"),
					self:genItemSeparatorMenuItems("bullet"),
					self:genItemSeparatorMenuItems("dot"),
					self:genItemSeparatorMenuItems("none"),
				},
			},
			{
				text = _("Item max width"),
				sub_item_table = {
					self:genItemMaxWidthMenuItems(
						_("Book-author item"),
						_("Book-author item: %1\xE2\x80\xAF%"),
						"book_author_max_width_pct"
					), -- U+202F NARROW NO-BREAK SPACE
					self:genItemMaxWidthMenuItems(
						_("Book-title item"),
						_("Book-title item: %1\xE2\x80\xAF%"),
						"book_title_max_width_pct"
					),
					self:genItemMaxWidthMenuItems(
						_("Chapter-title item"),
						_("Chapter-title item: %1\xE2\x80\xAF%"),
						"book_chapter_max_width_pct"
					),
				},
			},
			{
				text_func = function()
					return T(_("Alignment: %1"), self:genAlignmentMenuItems())
				end,
				enabled_func = function()
					return self.settings.disable_progress_bar or self.settings.progress_bar_position ~= "alongside"
				end,
				sub_item_table = {
					self:genAlignmentMenuItems("left"),
					self:genAlignmentMenuItems("center"),
					self:genAlignmentMenuItems("right"),
				},
			},
			{
				text_func = function()
					return T(_("Height: %1"), self.settings.container_height)
				end,
				callback = function(touchmenu_instance)
					local spin_widget = SpinWidget:new({
						value = self.settings.container_height,
						value_min = 7,
						value_max = 98,
						default_value = self.default_settings.container_height,
						title_text = _("Items container height"),
						keep_shown_on_apply = true,
						callback = function(spin)
							self.settings.container_height = spin.value
							self.height = Screen:scaleBySize(self.settings.container_height)
							self:refreshFooter(true, true)
							if touchmenu_instance then
								touchmenu_instance:updateItems()
							end
						end,
					})
					UIManager:show(spin_widget)
				end,
				keep_menu_open = true,
			},
			{
				text_func = function()
					return T(_("Bottom margin: %1"), self.settings.container_bottom_padding)
				end,
				callback = function(touchmenu_instance)
					local spin_widget = SpinWidget:new({
						value = self.settings.container_bottom_padding,
						value_min = 0,
						value_max = 49,
						default_value = self.default_settings.container_bottom_padding,
						title_text = _("Container bottom margin"),
						keep_shown_on_apply = true,
						callback = function(spin)
							self.settings.container_bottom_padding = spin.value
							self.bottom_padding = Screen:scaleBySize(self.settings.container_bottom_padding)
							self:refreshFooter(true, true)
							if touchmenu_instance then
								touchmenu_instance:updateItems()
							end
						end,
					})
					UIManager:show(spin_widget)
				end,
				keep_menu_open = true,
			},
		},
	})
	local configure_items_sub_table = sub_items[#sub_items].sub_item_table -- will pick the last item of sub_items
	if Device:hasBattery() then
		table.insert(configure_items_sub_table, 5, {
			text_func = function()
				if self.settings.battery_hide_threshold <= self.default_settings.battery_hide_threshold then
					return T(
						_("Hide battery item when higher than: %1\xE2\x80\xAF%"),
						self.settings.battery_hide_threshold
					) -- U+202F NARROW NO-BREAK SPACE
				else
					return _("Hide battery item at custom threshold")
				end
			end,
			checked_func = function()
				return self.settings.battery_hide_threshold <= self.default_settings.battery_hide_threshold
			end,
			enabled_func = function()
				return self.settings.all_at_once == true
			end,
			callback = function(touchmenu_instance)
				local max_pct = self.default_settings.battery_hide_threshold
				local battery_threshold = SpinWidget:new({
					value = math.min(self.settings.battery_hide_threshold, max_pct),
					value_min = 0,
					value_max = max_pct,
					default_value = max_pct,
					unit = "%",
					value_hold_step = 10,
					title_text = _("Minimum threshold to hide battery item"),
					callback = function(spin)
						self.settings.battery_hide_threshold = spin.value
						self:refreshFooter(true, true)
						if touchmenu_instance then
							touchmenu_instance:updateItems()
						end
					end,
					extra_text = _("Disable"),
					extra_callback = function()
						self.settings.battery_hide_threshold = max_pct + 1
						self:refreshFooter(true, true)
						if touchmenu_instance then
							touchmenu_instance:updateItems()
						end
					end,
					ok_always_enabled = true,
				})
				UIManager:show(battery_threshold)
			end,
			keep_menu_open = true,
			separator = true,
		})
	end
	table.insert(sub_items, {
		text = _("Status bar presets"),
		separator = true,
		sub_item_table_func = function()
			return Presets.genPresetMenuItemTable(self.preset_obj, nil, nil)
		end,
	})
	table.insert(sub_items, {
		text = _("Show status bar separator"),
		checked_func = function()
			return self.settings.bottom_horizontal_separator == true
		end,
		callback = function()
			self.settings.bottom_horizontal_separator = not self.settings.bottom_horizontal_separator
			self:refreshFooter(true, true)
		end,
	})
	if Device:isTouchDevice() then
		table.insert(sub_items, getMinibarOption("reclaim_height"))
		table.insert(sub_items, {
			text = _("Lock status bar"),
			checked_func = function()
				return self.settings.lock_tap == true
			end,
			callback = function()
				self.settings.lock_tap = not self.settings.lock_tap
			end,
		})
		table.insert(sub_items, {
			text = _("Long-press on status bar to skim"),
			checked_func = function()
				return self.settings.skim_widget_on_hold == true
			end,
			callback = function()
				self.settings.skim_widget_on_hold = not self.settings.skim_widget_on_hold
			end,
		})
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
			if
				self.settings.time
				or self.settings.battery
				or self.settings.wifi_status
				or self.settings.mem_usage
				or self.settings.apm_status
			then
				schedule = true
			end
		else
			if
				self.mode == self.mode_list.time
				or self.mode == self.mode_list.battery
				or self.mode == self.mode_list.wifi_status
				or self.mode == self.mode_list.mem_usage
				or self.mode == self.mode_list.apm_status
			then
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
		time = symbol_prefix[symbol].time and T(_("Current time (%1)"), symbol_prefix[symbol].time)
			or _("Current time"),
		chapter_progress = T(_("Current page in chapter (%1)"), " ⁄⁄ "),
		pages_left = T(_("Pages left in chapter (%1)"), symbol_prefix[symbol].pages_left),
		battery = T(_("Battery percentage (%1)"), symbol_prefix[symbol].battery),
		percentage = symbol_prefix[symbol].percentage
				and T(_("Progress percentage (%1)"), symbol_prefix[symbol].percentage)
			or _("Progress percentage"),
		book_time_to_read = symbol_prefix[symbol].book_time_to_read
				and T(_("Time left to finish book (%1)"), symbol_prefix[symbol].book_time_to_read)
			or _("Time left to finish book"),
		chapter_time_to_read = T(_("Time left to finish chapter (%1)"), symbol_prefix[symbol].chapter_time_to_read),
		frontlight = T(_("Brightness level (%1)"), symbol_prefix[symbol].frontlight),
		frontlight_warmth = T(_("Warmth level (%1)"), symbol_prefix[symbol].frontlight_warmth),
		mem_usage = T(_("KOReader memory usage (%1)"), symbol_prefix[symbol].mem_usage),
		wifi_status = T(_("Wi-Fi status (%1)"), symbol_prefix[symbol].wifi_status),
		page_turning_inverted = T(_("Page turning inverted (%1)"), symbol_prefix[symbol].page_turning_inverted),
		book_author = _("Book author"),
		book_title = _("Book title"),
		book_chapter = _("Chapter title"),
		custom_text = T(
			_("Custom text (long-press to edit): '%1'%2"),
			self.custom_text,
			self.custom_text_repetitions > 1 and string.format(" × %d", self.custom_text_repetitions) or ""
		),
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
