local helper = require("tests/spec_helper")
local U = helper.U

describe("display/flight_plan_menu - updater menu and toggles", function()
  setup(function()
    helper.reset()
  end)

  it("showMenu toggles check_updates and reports available/installed text", function()
    -- stub Updater
    package.loaded["utils/flight_plan"] = {
      getAvailableUpdate = function()
        return nil
      end,
      checkForUpdates = function() end,
      editDevBranch = function() end,
      resetToStableRelease = function() end,
    }

    local FPM = require("display/flight_plan_menu")
    local settings = require("flight_config"):init()

    -- ensure check_updates default false
    U:delFlightSetting("check_updates", settings.airplanemode)

    local menu = FPM:showMenu()
    assert.is_table(menu)
    local first = menu[1]
    assert.is_function(first.checked_func)
    assert.is_false(first.checked_func())

    -- invoke callback to toggle and ensure saved
    first.callback()
    assert.is_true(U:FlightHas("check_updates", settings.airplanemode))

    -- test text_func for available update = nil (installed version)
    local second = menu[2]
    local txt = second.text_func()
    assert.is_string(txt)

    -- stub available update
    package.loaded["utils/flight_plan"].getAvailableUpdate = function()
      return "9.9"
    end
    local txt2 = second.text_func()
    assert.is_string(txt2)
    assert.is_not_equal(txt, txt2)
  end)
end)
