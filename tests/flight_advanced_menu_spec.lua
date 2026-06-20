local helper = require("tests/spec_helper")
local U = helper.U

describe("display/flight_advanced_menu - KOReader version and menu entries", function()
  setup(function()
    helper.reset()
  end)

  it("getKOReaderVersion returns version from require('version') as string/table or globals", function()
    -- Ensure we have the real helpers implementation (spec_helper provides a minimal stub)
    package.loaded["utils/flight_helpers"] = nil
    -- ensure bidi.ltr returns its argument so format calls get a value
    package.loaded["ui/bidi"] = {
      ltr = function(s)
        return s
      end,
      rtl = function(s)
        return s
      end,
    }
    -- ensure ffi util template returns the formatted string for clarity
    package.loaded["ffi/util"] = {
      template = function(s, ...)
        return s
      end,
    }
    -- ensure device mock exposes boolean checks expected by flight_deviceinfo
    package.loaded["device"] = package.loaded["device"] or {}
    package.loaded["device"].isSDL = function()
      return false
    end
    package.loaded["device"].isDesktop = function()
      return false
    end
    package.loaded["device"].isAndroid = function()
      return false
    end
    package.loaded["device"].isCervantes = function()
      return false
    end
    package.loaded["device"].isKindle = function()
      return false
    end
    package.loaded["device"].isKobo = function()
      return false
    end
    package.loaded["device"].isPocketBook = function()
      return false
    end
    package.loaded["device"].isRemarkable = function()
      return false
    end
    package.loaded["device"].isSonyPRSTUX = function()
      return false
    end

    local FD = require("display/flight_advanced_menu")

    -- string version
    package.loaded["version"] = "1.2.3-string"
    assert.are.equal("1.2.3-string", FD.getKOReaderVersion())
    package.loaded["version"] = nil

    -- table version
    package.loaded["version"] = { version = "2.3.4" }
    assert.are.equal("2.3.4", FD.getKOReaderVersion())
    package.loaded["version"] = nil

    -- fallback to globals
    rawset(_G, "KOREADER_VERSION", "g-5.6.7")
    assert.are.equal("g-5.6.7", FD.getKOReaderVersion())
    rawset(_G, "KOREADER_VERSION", nil)
  end)

  it("menu generic entries show an InfoMessage via UIManager when invoked", function()
    -- ensure FM provides device info used in menu
    package.loaded["utils/flight_deviceinfo"] = {
      get_device_model_name = function()
        return "ModelX"
      end,
      get_device_firmware_info = function()
        return "FW1"
      end,
    }
    local FD = require("display/flight_advanced_menu")
    local menu = FD:menu()
    assert.is_table(menu)
    -- pick first entry and invoke callback which should call UIManager:show
    local first = menu[1]
    assert.is_table(first)
    -- spy on UIManager.show (mock records shown table)
    local UIManager = helper.UIManager
    UIManager.shown = UIManager.shown or {}
    first.callback()
    assert.is_true(#UIManager.shown > 0)
  end)
end)
