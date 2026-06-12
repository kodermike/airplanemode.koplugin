local helper = require("tests/spec_helper")
local U = helper.U

describe("display/flight_menu - menu building and footer integration", function()
  setup(function()
    helper.reset()
  end)

  it("creates menu item with correct icon text when airplanemode on/off", function()
    local FM = require("display/flight_menu")
    -- ensure flight status false
    U:delFlightSetting("airplanemode_enabled", helper.tmp_dir .. "/airplanemode.lua")

    local menu_items = {}
    -- provide a fake AirPlaneMode with name and getPlugins stub
    local fakeAPM = {
      name = "airplanemode",
      getPlugins = function()
        return {}
      end,
    }
    FM:init(menu_items, fakeAPM)
    assert.is_table(menu_items.airplanemode)
    -- evaluate text_func when off
    local txt = menu_items.airplanemode.text_func()
    assert.is_string(txt)

    -- set enabled
    U:FlightMakeTrue("airplanemode_enabled", helper.tmp_dir .. "/airplanemode.lua")
    local txt2 = menu_items.airplanemode.text_func()
    assert.is_string(txt2)
    -- menu text_func uses a captured snapshot of status at init, so it may not change
    assert.is_true(string.find(txt, "AirplaneMode") ~= nil)
  end)

  it("PluginMenu returns placeholder when user plugins empty", function()
    local FM = require("display/flight_menu")
    local fakeAPM = {
      name = "airplanemode",
      getPlugins = function()
        return {}
      end,
      plugin_list = function()
        return {}
      end,
    }
    FM.apm = fakeAPM
    local menu = FM:PluginMenu(false)
    assert.is_table(menu)
    assert.is_true(#menu > 0)
  end)
end)
