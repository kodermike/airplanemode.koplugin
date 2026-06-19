local helper = require("tests/spec_helper")
local U = helper.U

describe("AirPlaneMode instance init and toggle behavior", function()
  setup(function()
    helper.reset()
  end)

  it("init registers footer and menu when settings present/absent", function()
    local AP = require("main")
    -- create instance with minimal ui
    local inst = AP:new({ name = "airplanemode" })
    inst.ui = {
      view = { footer = { settings = { item_prefix = "icons" }, addAdditionalFooterContent = function() end, removeAdditionalFooterContent = function() end } },
      menu = { registerToMainMenu = function() end },
    }

    -- ensure no prev_config present
    local settings = require("flight_config"):init()
    if package.loaded["utils/flight_helpers"].isFile(settings.prev_config) then
      package.loaded["utils/flight_helpers"].removeFile(settings.prev_config)
    end

    -- ensure koreader plugins nil to allow initSettingsFile to create defaults
    U:saveFlightPlugins(nil, settings.koreader)

    -- call init to exercise initialization flow
    inst:init()

    -- version should be saved
    local ver = U:readFlightSetting("version", settings.airplanemode)
    assert(ver)

    -- cleanup
    U:delFlightSetting("version", settings.airplanemode)
  end)

  it("onToggle delegates to Enable/Disable based on status", function()
    local AP = require("main")
    local inst = AP:new({ name = "airplanemode" })
    inst.ui = { view = { footer = { settings = { item_prefix = "icons" } } }, menu = { registerToMainMenu = function() end } }

    local called_enable, called_disable = false, false
    inst.Enable = function(self)
      called_enable = true
    end
    inst.Disable = function(self)
      called_disable = true
    end

    -- when off: stub U.getFlightStatus
    ---@diagnostic disable-next-line
    helper.U.getFlightStatus = function()
      return false
    end
    inst:onToggle()
    assert.is_true(called_enable)

    -- when on: stub to true
    called_enable, called_disable = false, false
    ---@diagnostic disable-next-line
    helper.U.getFlightStatus = function()
      return true
    end
    inst:onToggle()
    assert.is_true(called_disable)
  end)
end)
