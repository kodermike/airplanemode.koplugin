local helper = require("tests/spec_helper")
local U = helper.U

describe("Migration flows: migrateconfig and migratesettings", function()
  setup(function()
    helper.reset()
  end)

  it("migrateconfig moves disabled_plugins from prev_config to airplanemode and removes prev_config file", function()
    local AP = require("main")
    local settings = require("flight_config"):init()

    -- create a prev_config file and populate previous disabled_plugins
    local fh = io.open(settings.prev_config, "w")
    fh:write("old")
    fh:close()
    U:saveFlightsetting("disabled_plugins", { calibre = true, newsdownloader = true }, settings.prev_config)

    -- run migration
    AP.migrateconfig()

    -- version should be set in new file
    local ver = U:readFlightsetting("version", settings.airplanemode)
    assert.are.equal(settings.version, ver)

    -- plugins_disabled should have moved, and calibre removed
    local moved = U:readFlightsetting(settings.koreader_plugins, settings.airplanemode)
    assert.is_table(moved)
    assert.is_nil(moved["calibre"]) -- calibre should be removed
    assert.is_true(moved["newsdownloader"])

    -- prev_config file should be removed
    assert.is_false(package.loaded["utils/flight_helpers"].isFile(settings.prev_config))
  end)

  it("migratesettings moves 'airplanemode' boolean and footer setting, and cleans old keys", function()
    local AP = require("main")
    local settings = require("flight_config"):init()

    -- set old koreader settings
    U:saveFlightsetting("airplanemode", true, settings.koreader)
    U:saveFlightsetting("plugins_disabled", { a = true }, settings.airplanemode)
    U:saveFlightsetting("airplanemode_in_footer", true, settings.koreader)

    -- call migratesettings on an instance
    local inst = AP:new({ name = "airplanemode" })
    inst:migratesettings()

    -- airplanemode should now be under settings.airplanemode as airplanemode_enabled
    assert.is_true(U:FlightisTrue("airplanemode_enabled", settings.airplanemode))
    -- old koreader key should be removed
    assert.is_false(U:Flighthas("airplanemode", settings.koreader))
    -- footer moved
    assert.is_true(U:Flighthas("airplanemode_in_footer", settings.airplanemode))
    assert.is_false(U:Flighthas("airplanemode_in_footer", settings.koreader))
  end)
end)
