local helper = require("tests/spec_helper")
local U = helper.U

describe("Enable/Disable branches and edge conditions", function()
  setup(function()
    helper.reset()
  end)

  it("Enable should restartKOReader when silentmode is true, otherwise show ConfirmBox", function()
    local AP = require("main")
    local settings = require("modules/APMConfig"):init()

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
    U:saveAPMsetting("silentmode", true, settings.airplanemode)
    -- ensure backup will succeed
    if package.loaded["modules/helpers"].isFile(settings.backup) then
      package.loaded["modules/helpers"].removeFile(settings.backup)
    end
    inst:Enable()
    assert.is_true(restarted)

    -- case 2: silentmode = false -> UIManager.show called (ConfirmBox)
    restarted = false
    U:saveAPMsetting("silentmode", false, settings.airplanemode)
    inst:Enable()
    assert.is_not_nil(ui.last_shown)
  end)

  it("managewifi setting prevents disabling wifi when explicitly true", function()
    local AP = require("main")
    local settings = require("modules/APMConfig"):init()
    local inst = AP:new({ name = "airplanemode" })
    inst.ui = {
      saveSettings = function() end,
      view = { footer = { addAdditionalFooterContent = function() end, removeAdditionalFooterContent = function() end } },
      menu = { registerToMainMenu = function() end },
    }

    -- ensure managewifi true in airplanemode -> should prevent disableWifi
    U:saveAPMsetting("managewifi", true, settings.airplanemode)
    -- reset network disabled flag
    package.loaded["modules/APMNetwork"]._disabled = false
    inst:Enable()
    assert.is_false(package.loaded["modules/APMNetwork"]._disabled)

    -- now unset managewifi -> should disable wifi
    U:delAPMsetting("managewifi", settings.airplanemode)
    inst:Enable()
    assert.is_true(package.loaded["modules/APMNetwork"]._disabled)
  end)

  it("handles device cannot restart branch when disabling/enabling", function()
    local AP = require("main")
    local settings = require("modules/APMConfig"):init()
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
    if package.loaded["modules/helpers"].isFile(settings.backup) then
      package.loaded["modules/helpers"].removeFile(settings.backup)
    end

    inst:Enable()
    -- since device cannot restart, should have shown a ConfirmBox/InfoMessage
    assert.is_not_nil(ui.last_shown)

    -- and Disable should similarly show a confirm
    ui.last_shown = nil
    inst:Disable()
    assert.is_not_nil(ui.last_shown)
  end)

  it("does not enable airplane mode if backup fails", function()
    local AP = require("main")
    local settings = require("modules/APMConfig"):init()
    local inst = AP:new({ name = "airplanemode" })
    inst.ui = {
      saveSettings = function() end,
      view = { footer = { addAdditionalFooterContent = function() end, removeAdditionalFooterContent = function() end } },
      menu = { registerToMainMenu = function() end },
    }

    -- force backup to fail
    U.backup = function()
      return false
    end
    -- ensure airplanemode not active
    U:delAPMsetting("airplanemode", nil)
    inst:Enable()
    assert.is_true(not U:getStatus())
  end)
end)
