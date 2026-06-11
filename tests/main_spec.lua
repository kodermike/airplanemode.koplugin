local helper = require("tests/spec_helper")
local U = helper.U

describe("AirPlaneMode plugin - basic specs", function()
  setup(function()
    helper.reset()
  end)

  it("loads the module and registers dispatcher actions", function()
    local AP = require("main")
    assert.is_table(AP)
    -- call the registration function
    AP.onDispatcherRegisterActions()
    -- expect actions registered
    local actions = helper.Dispatcher._actions
    assert.is_table(actions)
    assert.is_not_nil(actions["airplanemode_enable"]) -- at least one
    assert.is_not_nil(actions["airplanemode_disable"]) -- at least one
    assert.is_not_nil(actions["airplanemode_toggle"]) -- toggle
  end)

  it("initSettingsFile writes default settings when absent", function()
    local AP = require("main")
    -- ensure no preexisting file
    local settings_path = helper.tmp_dir .. "/airplanemode.lua"
    if os.remove(settings_path) then
    end
    -- call initSettingsFile (class-level function)
    AP.initSettingsFile()

    -- check that version was saved into utils storage under the airplanemode file
    local ver = U:readFlightSetting("version", settings_path)
    assert.are.equal("0.0-test", ver)

    -- check plugins_disabled saved
    local plugins = U:readFlightSetting("plugins_disabled", settings_path)
    assert.is_table(plugins)
    assert.is_true(plugins["newsdownloader"]) -- default list contains newsdownloader
  end)
end)
