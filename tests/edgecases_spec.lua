local helper = require("tests/spec_helper")
local U = helper.U

describe("Edge cases for helpers and main flows", function()
  setup(function()
    helper.reset()
  end)

  it("helpers.isFile/isDir/removeFile handle nil and missing paths safely", function()
    -- load real helpers module for file checks
    package.loaded["utils/flight_helpers"] = nil
    package.loaded["libs/libkoreader-lfs"] = {
      attributes = function(path, mode)
        if not path then
          return nil
        end
        local fh = io.open(path, "r")
        if fh then
          fh:close()
          if mode == "mode" then
            return "file"
          else
            return { mode = "file" }
          end
        end
        if string.sub(path, -1) == "/" then
          if mode == "mode" then
            return "directory"
          else
            return { mode = "directory" }
          end
        end
        return nil
      end,
    }
    local H = require("utils/flight_helpers")

    -- nil path
    ---@diagnostic disable-next-line: param-type-mismatch
    assert.is_false(H.isFile(nil))
    ---@diagnostic disable-next-line: param-type-mismatch
    assert.is_false(H.isDir(nil))
    -- remove nonexistent file should return false
    ---@diagnostic disable-next-line: param-type-mismatch
    assert.is_false(H.removeFile(nil))
    assert.is_false(H.removeFile("/tmp/file-that-does-not-exist-12345"))
  end)

  it("initSettingsFile does not overwrite when settings file already exists", function()
    local AP = require("main")
    local settings = require("flight_config"):init()

    -- create a preexisting file and a preexisting version value in storage
    local fh = io.open(settings.airplanemode, "w")
    assert(fh)
    fh:write("preexisting")
    fh:close()
    U:saveFlightSetting("version", "existing-version", settings.airplanemode)

    -- Also set a plugins_disabled at koreader level so initSettingsFile would skip writing defaults
    U:saveFlightPlugins({ someplugin = true }, settings.koreader)

    -- Call initSettingsFile; since file exists, it should skip and preserve our version
    AP.initSettingsFile()

    local ver = U:readFlightSetting("version", settings.airplanemode)
    assert.are.equal("existing-version", ver)
  end)

  it("deletePluginSettings is safe when no files or settings exist", function()
    local AP = require("main")
    local settings = require("flight_config"):init()

    -- Ensure no file exists and no settings present
    if package.loaded["utils/flight_helpers"].isFile(settings.airplanemode) then
      package.loaded["utils/flight_helpers"].removeFile(settings.airplanemode)
    end
    U:delFlightSetting("airplanemode", settings.airplanemode)
    U:delFlightSetting("airplanemode_in_footer", settings.airplanemode)

    -- Should not error
    AP.deletePluginSettings()

    -- Still no settings
    assert.is_false(U:FlightHas("airplanemode", settings.airplanemode))
    assert.is_false(U:FlightHas("airplanemode_in_footer", settings.airplanemode))
  end)
end)
