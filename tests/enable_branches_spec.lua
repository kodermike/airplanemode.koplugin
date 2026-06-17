local helper = require("tests/spec_helper")
local U = helper.U

describe("Enable/Disable branches and edge conditions", function()
  setup(function()
    helper.reset()
  end)

  it("Enable should restartKOReader when silentmode is true, otherwise show ConfirmBox", function()
    local AP = require("main")
    local settings = require("flight_config"):init()

    -- prepare instance
    local inst = AP:new({ name = "airplanemode" })
    inst.ui = {
      saveSettings = function() end,
      view = { footer = { addAdditionalFooterContent = function() end, removeAdditionalFooterContent = function() end } },
      menu = { registerToMainMenu = function() end },
    }

    -- spy on UIManager
    local ui = helper.UIManager
    local restarted = false
    ui.restartKOReader = function()
      restarted = true
    end
    ui.show = function(self, what)
      self.last_shown = what
    end

    -- case 1: silentmode = true -> restartKOReader called
    U:saveFlightSetting("silentmode", true)
    -- ensure backup will succeed
    if package.loaded["utils/flight_helpers"].isFile(settings.backup) then
      package.loaded["utils/flight_helpers"].removeFile(settings.backup)
    end
    inst:Enable()
    assert.is_true(restarted)

    -- case 2: silentmode = false -> UIManager.show called (ConfirmBox)
    restarted = false
    U:saveFlightSetting("silentmode", false)
    inst:Enable()
    assert(ui.last_shown)
  end)

  it("managewifi setting prevents disabling wifi when explicitly true", function()
    local AP = require("main")
    local settings = require("flight_config"):init()
    local inst = AP:new({ name = "airplanemode" })
    inst.ui = {
      saveSettings = function() end,
      view = { footer = { addAdditionalFooterContent = function() end, removeAdditionalFooterContent = function() end } },
      menu = { registerToMainMenu = function() end },
    }

    -- ensure managewifi true in airplanemode -> should prevent disableWifi
    U:saveFlightSetting("managewifi", true)
    -- reset network disabled flag
    package.loaded["flight_net"]._disabled = false
    inst:Enable()
    assert.is_false(package.loaded["flight_net"]._disabled)

    -- now unset managewifi -> should disable wifi
    U:delFlightSetting("managewifi")
    inst:Enable()
    assert.is_true(package.loaded["flight_net"]._disabled)
  end)

  it("handles device cannot restart branch when disabling/enabling", function()
    local AP = require("main")
    local settings = require("flight_config"):init()
    -- override device to not allow restart
    package.loaded["device"] = {
      isEmulator = function()
        return false
      end,
      canRestart = function()
        return false
      end,
    }
    -- reload main so it picks up the new device implementation
    package.loaded["main"] = nil
    AP = require("main")

    local inst = AP:new({ name = "airplanemode" })
    inst.ui = {
      saveSettings = function() end,
      view = { footer = { addAdditionalFooterContent = function() end, removeAdditionalFooterContent = function() end } },
      menu = { registerToMainMenu = function() end },
    }

    local ui = helper.UIManager
    ui.last_shown = nil
    ui.show = function(self, what)
      self.last_shown = what
    end

    -- ensure backup exists removal path
    if package.loaded["utils/flight_helpers"].isFile(settings.backup) then
      package.loaded["utils/flight_helpers"].removeFile(settings.backup)
    end

    inst:Enable()
    -- since device cannot restart, should have shown a ConfirmBox/InfoMessage
    assert(ui.last_shown)

    -- and Disable should similarly show a confirm
    ui.last_shown = nil
    inst:Disable()
    assert(ui.last_shown)
  end)

  it("does not enable airplane mode if backup fails", function()
    local AP = require("main")
    local settings = require("flight_config"):init()
    local inst = AP:new({ name = "airplanemode" })
    inst.ui = {
      saveSettings = function() end,
      view = { footer = { addAdditionalFooterContent = function() end, removeAdditionalFooterContent = function() end } },
      menu = { registerToMainMenu = function() end },
    }

    -- force backup to fail
    ---@diagnostic disable-next-line
    U.backupFlight = function()
      return false
    end
    -- ensure airplanemode not active
    U:delFlightSetting("airplanemode", nil)
    inst:Enable()
    assert.is_true(not U:getFlightStatus())
  end)
end)
