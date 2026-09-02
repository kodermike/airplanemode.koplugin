local helper = require("tests/spec_helper")
local U = helper.U

local function find_item_by_text(tbl, text)
  for _, it in ipairs(tbl) do
    if it.text and it.text == text then
      return it
    end
    if it.text_func and it.text_func() == text then
      return it
    end
  end
  return nil
end

describe("display/flight_advanced_menu - KOReader version and menu entries", function()
  setup(function()
    helper.reset()
  end)

  it("getKOReaderVersion returns version from require('version') as string/table or globals", function()
    -- Ensure we have the real helpers implementation (spec_helper provides a minimal stub)
    package.loaded["utils/flight_helpers"] = nil
    -- ensure bidi.ltr returns its argument so format calls get a value
    package.loaded["ui/bidi"] = {
      ltr = function(s)
        return s
      end,
      rtl = function(s)
        return s
      end,
    }
    -- ensure ffi util template returns the formatted string for clarity
    package.loaded["ffi/util"] = {
      template = function(s, ...)
        return s
      end,
    }
    -- ensure device mock exposes boolean checks expected by flight_deviceinfo
    package.loaded["device"] = package.loaded["device"] or {}
    package.loaded["device"].isSDL = function()
      return false
    end
    package.loaded["device"].isDesktop = function()
      return false
    end
    package.loaded["device"].isAndroid = function()
      return false
    end
    package.loaded["device"].isCervantes = function()
      return false
    end
    package.loaded["device"].isKindle = function()
      return false
    end
    package.loaded["device"].isKobo = function()
      return false
    end
    package.loaded["device"].isPocketBook = function()
      return false
    end
    package.loaded["device"].isRemarkable = function()
      return false
    end
    package.loaded["device"].isSonyPRSTUX = function()
      return false
    end

    local FD = require("display.flight_advanced_menu")

    -- string version
    package.loaded["version"] = "1.2.3-string"
    assert.are.equal("1.2.3-string", FD.getKOReaderVersion())
    package.loaded["version"] = nil

    -- table version
    package.loaded["version"] = { version = "2.3.4" }
    assert.are.equal("2.3.4", FD.getKOReaderVersion())
    package.loaded["version"] = nil

    -- fallback to globals
    rawset(_G, "KOREADER_VERSION", "g-5.6.7")
    assert.are.equal("g-5.6.7", FD.getKOReaderVersion())
    rawset(_G, "KOREADER_VERSION", nil)
  end)

  it("getMenuItems includes builtin plugin submenu when airmode false", function()
    local FD = require("display.flight_advanced_menu")
    local settings = require("flight_config"):init()

    -- ensure airmode inactive
    U:FlightMakeFalse("airplanemode_enabled", settings.airplanemode)

    -- provide apm with getPlugins returning non-empty builtin list
    local apm = {
      name = "airplanemode",
      getPlugins = function(builtin)
        return { { name = "p_builtin", fullname = "PBuilt", description = "d" } }
      end,
      plugin_list = function()
        return { p_builtin = true }
      end,
      addAdditionalFooterContent = function()
        helper.UIManager.footer_added = true
      end,
      removeAdditionalFooterContent = function()
        helper.UIManager.footer_removed = true
      end,
    }
    FD.apm = apm

    local items = FD:menu(apm)
    assert.is_table(items)

    -- there should be an entry with a sub_item_table_func for builtin plugins
    local found = false
    for _, it in ipairs(items) do
      if type(it.sub_item_table_func) == "function" then
        found = true
        break
      end
    end
    assert.is_true(found)

    -- test the footer toggle item: find it and call callback to toggle
    local footer_item = find_item_by_text(items, "Show AirPlaneMode in reader footer")
    assert(footer_item)
    -- initial show_value_in_footer may be nil; set to false
    FD.show_value_in_footer = false
    U:delFlightSetting("airplanemode_in_footer", settings.airplanemode)

    -- call callback to toggle on
    footer_item.callback()
    assert.is_true(U:FlightIsTrue("airplanemode_in_footer"))
    assert.is_true(FD.show_value_in_footer)
    -- ensure apm:addAdditionalFooterContent was called (our apm writes to helper.UIManager)
    assert.is_true(helper.UIManager.footer_added)

    -- call callback again to toggle off
    footer_item.callback()
    assert.is_false(U:FlightIsTrue("airplanemode_in_footer"))
    assert.is_false(FD.show_value_in_footer)
  end)
end)
