local helper = require("tests/spec_helper")
local tmp = helper.tmp_dir

describe("utils/flight_utilities - full behavior with mocked LuaSettings", function()
  setup(function()
    helper.reset()

    -- provide datastorage stub
    package.loaded["datastorage"] = {}

    -- storage per file
    local store = {}

    -- LuaSettings mock
    package.loaded["luasettings"] = {
      open = function(file)
        store[file] = store[file] or {}
        local self = {}
        self._file = file
        self.readSetting = function(_, k)
          return store[file][k]
        end
        self.saveSetting = function(_, k, v)
          store[file][k] = v
          return true
        end
        self.delSetting = function(_, k)
          store[file][k] = nil
          return true
        end
        self.flush = function() end
        self.close = function() end
        self.has = function(_, k)
          return store[file][k] ~= nil
        end
        self.hasNot = function(_, k)
          return store[file][k] == nil
        end
        self.toggle = function(_, k)
          if store[file][k] == nil then
            store[file][k] = true
          else
            store[file][k] = not store[file][k]
          end
          return store[file][k]
        end
        self.isTrue = function(_, k)
          return store[file][k] == true
        end
        self.isFalse = function(_, k)
          return store[file][k] == false
        end
        self.makeTrue = function(_, k)
          store[file][k] = true
          return true
        end
        self.makeFalse = function(_, k)
          store[file][k] = false
          return true
        end
        self.nilOrFalse = function(_, k)
          local v = store[file][k]
          return v == nil or v == false
        end
        self.nilOrTrue = function(_, k)
          local v = store[file][k]
          return v == nil or v == true
        end
        self.flipNilOrFalse = function(_, k)
          local v = store[file][k]
          if v == nil or v == false then
            store[file][k] = true
          else
            store[file][k] = false
          end
          return store[file][k]
        end
        return self
      end,
    }

    -- ensure ffi util has copyFile
    package.loaded["ffi/util"].copyFile = function(src, dst)
      local inf = io.open(src, "r")
      if not inf then
        return false
      end
      local data = inf:read("*a")
      inf:close()
      local outf = io.open(dst, "w")
      if not outf then
        return false
      end
      -- ensure LSP knows we checked for nil
      assert(outf)
      outf:write(data)
      outf:close()
      return true
    end

    -- ensure helpers lfs is available
    package.loaded["libs/libkoreader-lfs"] = package.loaded["libs/libkoreader-lfs"] or {}
  end)

  it("saveFlightSetting/readFlightSetting handle nil inputs and normal flows", function()
    package.loaded["utils/flight_utilities"] = nil
    local Utilities = require("utils/flight_utilities")
    local settings = require("flight_config"):init()

    -- nil object
    ---@diagnostic disable-next-line: param-type-mismatch
    assert.is_false(Utilities:saveFlightSetting(nil, "v", settings.airplanemode))
    -- nil value
    ---@diagnostic disable-next-line: param-type-mismatch
    assert.is_false(Utilities:saveFlightSetting("obj", nil, settings.airplanemode))

    -- normal save
    assert.is_true(Utilities:saveFlightSetting("mykey", "myval", settings.airplanemode))
    assert.are.equal("myval", Utilities:readFlightSetting("mykey", settings.airplanemode))
  end)

  it("readFlightPlugins/saveFlightPlugins roundtrip", function()
    package.loaded["utils/flight_utilities"] = nil
    local Utilities = require("utils/flight_utilities")
    local settings = require("flight_config"):init()

    Utilities:saveFlightPlugins({ a = true }, settings.airplanemode)
    local got = Utilities:readFlightPlugins(settings.koreader_plugins, settings.airplanemode)
    assert.is_table(got)
    assert.is_true(got.a)
  end)

  it("FlightHas/FlightHasNot/FlightToggle and boolean helpers", function()
    package.loaded["utils/flight_utilities"] = nil
    local Utilities = require("utils/flight_utilities")
    local settings = require("flight_config"):init()

    -- ensure starts nil
    assert.is_false(Utilities:FlightHas("flag", settings.airplanemode))
    assert.is_true(Utilities:FlightHasNot("flag", settings.airplanemode))

    Utilities:FlightMakeTrue("flag", settings.airplanemode)
    assert.is_true(Utilities:FlightHas("flag", settings.airplanemode))
    assert.is_true(Utilities:FlightIsTrue("flag", settings.airplanemode))
    assert.is_false(Utilities:FlightIsFalse("flag", settings.airplanemode))

    Utilities:FlightMakeFalse("flag", settings.airplanemode)
    assert.is_true(Utilities:FlightIsFalse("flag", settings.airplanemode))

    Utilities:FlightMakeTrue("flag", settings.airplanemode)
    Utilities:FlightToggle("flag", settings.airplanemode)
    -- toggle flips
    assert.is_false(Utilities:FlightIsTrue("flag", settings.airplanemode))
  end)

  it("FlightNilOrFalse/FlightNilOrTrue/FlightFlipNilOrFalse behavior", function()
    package.loaded["utils/flight_utilities"] = nil
    local Utilities = require("utils/flight_utilities")
    local settings = require("flight_config"):init()

    -- nil case
    assert.is_true(Utilities:FlightNilOrFalse("x", settings.airplanemode))
    assert.is_true(Utilities:FlightNilOrTrue("x", settings.airplanemode))

    Utilities:FlightMakeFalse("x", settings.airplanemode)
    assert.is_true(Utilities:FlightNilOrFalse("x", settings.airplanemode))
    Utilities:FlightMakeTrue("x", settings.airplanemode)
    assert.is_true(Utilities:FlightNilOrTrue("x", settings.airplanemode))

    Utilities:FlightMakeFalse("y", settings.airplanemode)
    Utilities:FlightFlipNilOrFalse("y", settings.airplanemode)
    assert.is_true(Utilities:FlightIsTrue("y", settings.airplanemode))
  end)

  it("backup copies file when present and returns false when missing", function()
    package.loaded["utils/flight_utilities"] = nil
    local Utilities = require("utils/flight_utilities")
    local settings = require("flight_config"):init()

    -- ensure source exists
    local fh = io.open(settings.koreader, "w")
    assert(fh)
    fh:write("content")
    fh:close()

    -- ensure remove any prior backup
    if package.loaded["utils/flight_helpers"].isFile(settings.backup) then
      package.loaded["utils/flight_helpers"].removeFile(settings.backup)
    end

    assert.is_true(Utilities:backupFlight(settings.koreader, settings.backup))
    assert.is_true(package.loaded["utils/flight_helpers"].isFile(settings.backup))

    -- missing source
    if package.loaded["utils/flight_helpers"].isFile(settings.koreader) then
      package.loaded["utils/flight_helpers"].removeFile(settings.koreader)
    end
    assert.is_false(Utilities:backupFlight(settings.koreader, settings.backup))
  end)

  it("getFlightStatus reflects backup and airplanemode_enabled", function()
    package.loaded["utils/flight_utilities"] = nil
    local Utilities = require("utils/flight_utilities")
    local settings = require("flight_config"):init()

    -- create settings file and backup
    local fh = io.open(settings.airplanemode, "w")
    assert(fh)
    fh:write("x")
    fh:close()
    local bf = io.open(settings.backup, "w")
    assert(bf)
    bf:write("b")
    bf:close()

    Utilities:FlightMakeTrue("airplanemode_enabled", settings.airplanemode)
    assert.is_true(Utilities:getFlightStatus())

    Utilities:FlightMakeFalse("airplanemode_enabled", settings.airplanemode)
    assert.is_false(Utilities:getFlightStatus())
  end)

  it("toggleAirPlaneMode sets the airplanemode in koreader settings", function()
    package.loaded["utils/flight_utilities"] = nil
    local Utilities = require("utils/flight_utilities")
    local settings = require("flight_config"):init()

    Utilities:toggleAirPlaneMode(true)
    assert.is_true(Utilities:FlightIsTrue("airplanemode_enabled", settings.airplanemode))
    Utilities:toggleAirPlaneMode(false)
    assert.is_true(Utilities:FlightIsFalse("airplanemode_enabled", settings.airplanemode))
  end)
end)
