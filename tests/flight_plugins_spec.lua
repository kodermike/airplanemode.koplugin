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

   -- Clear flight_plugins from cache so it reloads with the new pluginloader
   package.loaded["utils/flight_plugins"] = nil
    
   -- ensure check_plugins has some entries
   local settings = require("flight_config"):init()
   U:saveFlightPlugins({ newsdownloader = true }, settings.airplanemode)

   -- load the flight_plugins module with the stubbed pluginloader
   local FlightPlugins = require("utils/flight_plugins")
    
   -- call getPlugins for builtin = true
   local lst = FlightPlugins:getPlugins(true, settings)
   assert.is_table(lst)
   -- ensure at least one entry (should have calibre)
   assert.is_true(#lst >= 1)
  end)
end)
