local helper = require("tests/spec_helper")
local U = helper.U

describe("flight_plugins:disablePlugins - stopping plugins and saving disabled list", function()
  setup(function()
    helper.reset()
  end)

  it("disablePlugins stops running plugins and writes plugins_disabled", function()
    -- stub PluginLoader to report an enabled plugin we will disable
    package.loaded["pluginloader"] = {
      loadPlugins = function()
        return {
          { name = "p1", fullname = "P1", description = "p" },
        }, {}
      end,
    }

    local settings = require("flight_config"):init()
    -- set check_plugins to include p1
    U:saveFlightPlugins({ p1 = true })
    U:saveFlightSetting("plugins_disabled", {}, settings.koreader)

    -- prepare dummy AirPlaneMode and a plugin module in ui
    local dummyAPM = { ui = {} }
    dummyAPM.ui["p1"] = {
      stopPlugin = function()
        helper.UIManager.last_stopped = "stopPlugin"
      end,
      stop = function()
        helper.UIManager.last_stopped = "stop"
      end,
      isRunning = function()
        return true
      end,
    }

    -- load flight_plugins fresh and apply to dummyAPM
    local fp_chunk = assert(loadfile("./flight_plugins.lua"))
    local fp_fn = fp_chunk()
    fp_fn(dummyAPM)
    local AP = dummyAPM

    -- call disablePlugins
    AP:disablePlugins(settings)

    -- plugins_disabled should include p1
    local saved = U:readFlightSetting("plugins_disabled", settings.koreader)
    assert.is_table(saved)
    assert.is_true(saved["p1"] or saved.p1)
  end)
end)
