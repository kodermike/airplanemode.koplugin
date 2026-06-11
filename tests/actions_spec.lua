local helper = require("tests/spec_helper")
local U = helper.U
local Dispatcher = helper.Dispatcher
local UIManager = helper.UIManager
local PluginManager = package.loaded["flight_plugins"]

describe("AirPlaneMode actions - stop, delete, enable/disable", function()
  setup(function()
    helper.reset()
  end)

  it("stopPlugin should restore plugin settings and toggle airplanemode off", function()
    local AP = require("main")
    local restored = false
    -- spy on PluginManager.restorePluginSettings
    package.loaded["flight_plugins"].restorePluginSettings = function()
      restored = true
    end

    -- set airplanemode to true in the in-memory utilities
    U:toggleAirPlaneMode(true)
    assert.is_true(U:getFlightStatus())

    -- call stopPlugin
    AP.stopPlugin()

    assert.is_true(restored)
    assert.is_false(U:getFlightStatus())
  end)

  it("deletePluginSettings should remove files and settings", function()
    local AP = require("main")
    local settings = require("flight_config"):init()
    -- create a dummy airplanemode file
    local fh = io.open(settings.airplanemode, "w")
    assert.is_not_nil(fh)
    fh:write("dummy")
    fh:close()

    -- set settings in storage to simulate running state
    U:saveFlightSetting("airplanemode", true, settings.airplanemode)
    U:saveFlightSetting("airplanemode_in_footer", true, settings.airplanemode)

    assert.is_true(package.loaded["utils/flight_helpers"].isFile(settings.airplanemode))

    AP.deletePluginSettings()

    -- file should be removed
    assert.is_false(package.loaded["utils/flight_helpers"].isFile(settings.airplanemode))
    -- settings should be deleted
    assert.is_false(U:FlightHas("airplanemode", settings.airplanemode))
    assert.is_false(U:FlightHas("airplanemode_in_footer", settings.airplanemode))
  end)

  it("Enable should set airplanemode and create a backup; Disable should clear it and remove backup", function()
    local AP = require("main")
    local settings = require("flight_config"):init()

    -- create an instance with minimal ui to satisfy calls
    local inst = AP:new({ name = "airplanemode" })
    inst.ui = {
      saveSettings = function() end,
      view = { footer = { addAdditionalFooterContent = function() end, removeAdditionalFooterContent = function() end } },
      menu = { registerToMainMenu = function() end },
    }

    -- ensure clean start
    U:delFlightSetting("airplanemode", nil)
    if package.loaded["utils/flight_helpers"].isFile(settings.backup) then
      package.loaded["utils/flight_helpers"].removeFile(settings.backup)
    end

    -- call Enable
    inst:Enable()
    -- airplane mode should be active
    assert.is_true(U:getFlightStatus())
    -- backup file should exist
    assert.is_true(package.loaded["utils/flight_helpers"].isFile(settings.backup))

    -- call Disable
    inst:Disable()
    assert.is_false(U:getFlightStatus())
    -- backup file should be removed
    assert.is_false(package.loaded["utils/flight_helpers"].isFile(settings.backup))
  end)
end)
