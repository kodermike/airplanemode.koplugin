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

    local menu = FPM:showMenu()
    -- test text_func for available update = nil (installed version)
    local second = menu[1]
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
