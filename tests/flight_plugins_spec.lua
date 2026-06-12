local helper = require("tests/spec_helper")
local U = helper.U

describe("flight_plugins:getPlugins and helpers", function()
  setup(function()
    helper.reset()
  end)

  it("getPlugins handles enabled and disabled plugin lists from PluginLoader", function()
    -- stub PluginLoader:loadPlugins by injecting into package.loaded
    package.loaded["pluginloader"] = {
      loadPlugins = function()
        return {
          { name = "calibre", fullname = "Calibre", description = "x" },
          { name = "userplugin", fullname = "User", description = "y" },
        }, {
          { name = "newsdownloader", fullname = "News", description = "z" },
        }
      end,
    }

    -- ensure check_plugins has some entries
    local settings = require("flight_config"):init()
    U:saveFlightPlugins({ newsdownloader = true }, settings.airplanemode)

    -- load the flight_plugins module as a fresh chunk to avoid prior side-effects
    local fp_chunk = assert(loadfile("./flight_plugins.lua"))
    local fp_fn = fp_chunk()
    local dummyAPM = { ui = {} }
    fp_fn(dummyAPM)
    local AP = dummyAPM

    -- call getPlugins for builtin = true
    local lst = AP:getPlugins(true, settings)
    assert.is_table(lst)
    -- ensure at least one entry
    assert.is_true(#lst >= 1)
  end)
end)
