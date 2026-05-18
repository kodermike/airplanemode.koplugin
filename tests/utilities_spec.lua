local helper = require("tests/spec_helper")
local tmp = helper.tmp_dir

describe("modules/utilities - full behavior with mocked LuaSettings", function()
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
      outf:write(data)
      outf:close()
      return true
    end

    -- ensure helpers lfs is available
    package.loaded["libs/libkoreader-lfs"] = package.loaded["libs/libkoreader-lfs"] or {}
  end)

  it("saveAPMsetting/readAPMsetting handle nil inputs and normal flows", function()
    package.loaded["modules/utilities"] = nil
    local Utilities = require("modules/utilities")
    local settings = require("modules/APMConfig"):init()

    -- nil object
    assert.is_false(Utilities:saveAPMsetting(nil, "v", settings.airplanemode))
    -- nil value
    assert.is_false(Utilities:saveAPMsetting("obj", nil, settings.airplanemode))

    -- normal save
    assert.is_true(Utilities:saveAPMsetting("mykey", "myval", settings.airplanemode))
    assert.are.equal("myval", Utilities:readAPMsetting("mykey", settings.airplanemode))
  end)

  it("readAPMplugins/saveAPMplugins roundtrip", function()
    package.loaded["modules/utilities"] = nil
    local Utilities = require("modules/utilities")
    local settings = require("modules/APMConfig"):init()

    Utilities:saveAPMplugins({ a = true }, settings.airplanemode)
    local got = Utilities:readAPMplugins(settings.koreader_plugins, settings.airplanemode)
    assert.is_table(got)
    assert.is_true(got.a)
  end)

  it("APMhas/APMhasNot/APMtoggle and boolean helpers", function()
    package.loaded["modules/utilities"] = nil
    local Utilities = require("modules/utilities")
    local settings = require("modules/APMConfig"):init()

    -- ensure starts nil
    assert.is_false(Utilities:APMhas("flag", settings.airplanemode))
    assert.is_true(Utilities:APMhasNot("flag", settings.airplanemode))

    Utilities:APMmakeTrue("flag", settings.airplanemode)
    assert.is_true(Utilities:APMhas("flag", settings.airplanemode))
    assert.is_true(Utilities:APMisTrue("flag", settings.airplanemode))
    assert.is_false(Utilities:APMisFalse("flag", settings.airplanemode))

    Utilities:APMmakeFalse("flag", settings.airplanemode)
    assert.is_true(Utilities:APMisFalse("flag", settings.airplanemode))

    Utilities:APMmakeTrue("flag", settings.airplanemode)
    Utilities:APMtoggle("flag", settings.airplanemode)
    -- toggle flips
    assert.is_false(Utilities:APMisTrue("flag", settings.airplanemode))
  end)

  it("APMnilOrFalse/APMnilOrTrue/APMflipNilOrFalse behavior", function()
    package.loaded["modules/utilities"] = nil
    local Utilities = require("modules/utilities")
    local settings = require("modules/APMConfig"):init()

    -- nil case
    assert.is_true(Utilities:APMnilOrFalse("x", settings.airplanemode))
    assert.is_true(Utilities:APMnilOrTrue("x", settings.airplanemode))

    Utilities:APMmakeFalse("x", settings.airplanemode)
    assert.is_true(Utilities:APMnilOrFalse("x", settings.airplanemode))
    Utilities:APMmakeTrue("x", settings.airplanemode)
    assert.is_true(Utilities:APMnilOrTrue("x", settings.airplanemode))

    Utilities:APMmakeFalse("y", settings.airplanemode)
    Utilities:APMflipNilOrFalse("y", settings.airplanemode)
    assert.is_true(Utilities:APMisTrue("y", settings.airplanemode))
  end)

  it("backup copies file when present and returns false when missing", function()
    package.loaded["modules/utilities"] = nil
    local Utilities = require("modules/utilities")
    local settings = require("modules/APMConfig"):init()

    -- ensure source exists
    local fh = io.open(settings.koreader, "w")
    fh:write("content")
    fh:close()

    -- ensure remove any prior backup
    if package.loaded["modules/helpers"].isFile(settings.backup) then
      package.loaded["modules/helpers"].removeFile(settings.backup)
    end

    assert.is_true(Utilities:backup(settings.koreader, settings.backup))
    assert.is_true(package.loaded["modules/helpers"].isFile(settings.backup))

    -- missing source
    if package.loaded["modules/helpers"].isFile(settings.koreader) then
      package.loaded["modules/helpers"].removeFile(settings.koreader)
    end
    assert.is_false(Utilities:backup(settings.koreader, settings.backup))
  end)

  it("getStatus reflects backup and airplanemode_enabled", function()
    package.loaded["modules/utilities"] = nil
    local Utilities = require("modules/utilities")
    local settings = require("modules/APMConfig"):init()

    -- create settings file and backup
    local fh = io.open(settings.airplanemode, "w")
    fh:write("x")
    fh:close()
    local bf = io.open(settings.backup, "w")
    bf:write("b")
    bf:close()

    Utilities:APMmakeTrue("airplanemode_enabled", settings.airplanemode)
    assert.is_true(Utilities:getStatus())

    Utilities:APMmakeFalse("airplanemode_enabled", settings.airplanemode)
    assert.is_false(Utilities:getStatus())
  end)

  it("toggleAirPlaneMode sets the airplanemode in koreader settings", function()
    package.loaded["modules/utilities"] = nil
    local Utilities = require("modules/utilities")
    local settings = require("modules/APMConfig"):init()

    Utilities:toggleAirPlaneMode(true)
    assert.is_true(Utilities:APMisTrue("airplanemode_enabled", settings.airplanemode))
    Utilities:toggleAirPlaneMode(false)
    assert.is_true(Utilities:APMisFalse("airplanemode_enabled", settings.airplanemode))
  end)
end)
