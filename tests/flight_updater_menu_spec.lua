local helper = require("tests/spec_helper")
local U = helper.U

describe("display/flight_updater_menu - updater menu and toggles", function()
  setup(function()
    helper.reset()
  end)

  it("showMenu toggles check_updates and reports available/installed text", function()
    -- stub Updater
    package.loaded["utils/flight_updater"] = {
      getAvailableUpdate = function()
        return nil
      end,
      checkForUpdates = function() end,
      editDevBranch = function() end,
      resetToStableRelease = function() end,
    }

    local FPM = require("display/flight_updater_menu")
    local settings = require("flight_config"):init()

    -- ensure check_updates default false
    U:delFlightSetting("check_updates")

    local menu = FPM:showMenu()
    assert.is_table(menu)
    assert(menu)
    local first = menu[1]
    assert(type(first.checked_func) == "function")
    assert.is_false(first.checked_func())

    -- invoke callback to toggle and ensure saved
    first.callback()
    assert.is_true(U:FlightHas("check_updates"))

    -- test text_func for available update = nil (installed version)
    local second = menu[2]
    assert(second)
    local txt = second.text_func()
    assert.is_string(txt)

    -- stub available update
    package.loaded["utils/flight_updater"].getAvailableUpdate = function()
      return "9.9"
    end
    local txt2 = second.text_func()
    assert.is_string(txt2)
    assert.is_not_equal(txt, txt2)
  end)
end)
