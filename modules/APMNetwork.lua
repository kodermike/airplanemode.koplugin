---@class APMNetwork

local logger = require("logger")
local Device = require("device")
local LuaSettings = require("luasettings")
local NetworkMgr = require("ui/network/manager")

local APMConfig = require("modules/APMConfig")
local settings = APMConfig:init()
local U = require("modules/utilities")

local APMNetwork = {}

---Re-enable WiFi and restore related settings from backup
---@return nil
function APMNetwork:reenableWifi()
  if Device:hasWifiRestore() and U:readAPMsetting("auto_restore_wifi", settings.koreader) then
    logger.dbg("AIRPLANEMODE: Reverting auto_restore_wifi to true")
    U:APMmakeTrue("auto_restore_wifi", settings.koreader)
  end

  if U:APMnilOrFalse("auto_disable_wifi", settings.backup) then
    logger.dbg("AIRPLANEMODE: Reverting auto_disable_wifi to false")
    -- flip the real config
    U:APMflipNilOrFalse("auto_disable_wifi", settings.koreader)
  end

  -- According to network manager, this setting always has a value and defaults to prompt
  if U:APMhasNot("wifi_enable_action", settings.backup) then
    logger.dbg("AIRPLANEMODE: Deleting wifi_enable_action setting")
    U:delAPMsetting("wifi_enable_action", settings.koreader)
  else
    local bk_wifi_enable_action_setting = U:readAPMsetting("wifi_enable_action", settings.backup) or "prompt"
    logger.dbg("AIRPLANEMODE: Saving wifi_enable_action setting: ", bk_wifi_enable_action_setting)
    U:saveAPMsetting("wifi_enable_action", bk_wifi_enable_action_setting, settings.koreader)
  end

  -- According to network manager, this setting always has a value and defaults to prompt
  if U:APMhasNot("wifi_disable_action", settings.backup) then
    logger.dbg("AIRPLANEMODE: Deleting wifi_disable_action setting")
    U:delAPMsetting("wifi_disable_action", settings.koreader)
  else
    local bk_wifi_disable_action_setting = U:readAPMsetting("wifi_disable_action", settings.backup) or "prompt"
    logger.dbg("AIRPLANEMODE: Saving wifi_disable_action setting: ", bk_wifi_disable_action_setting)
    U:saveAPMsetting("wifi_disable_action", bk_wifi_disable_action_setting, settings.koreader)
  end

  -- got to watch out for our emulator friends :) (ie, me, testing)
  if Device:isEmulator() and U:APMhas("emulator_fake_wifi_connected", settings.backup) then
    logger.dbg("AIRPLANEMODE: Saving emulator_fake_wifi_connected setting: ", U:readAPMsetting("emulator_fake_wifi_connected", settings.backup))
    local old_emulator_fake_wifi_connected = U:readAPMsetting("emulator_fake_wifi_connected", settings.backup) or nil
    -- flip the real config
    if not old_emulator_fake_wifi_connected == nil then
      U:saveAPMsetting("emulator_fake_wifi_connected", old_emulator_fake_wifi_connected, settings.koreader)
    end
  end

  if U:APMisTrue("http_proxy_enabled", settings.backup) then
    logger.dbg("AIRPLANEMODE: Saving http_proxy_enabled setting: true")
    -- flip the real config
    U:APMmakeTrue("http_proxy_enabled", settings.koreader)
  end

  --if NetworkMgr:getWifiState() == false and backup_config:isTrue("wifi_was_on") then
  if U:APMhasNot("wifi_was_on", settings.backup) then
    logger.dbg("AIRPLANEMODE: Deleting wifi_was_on setting")
    U:delAPMsetting("wifi_was_on", settings.koreader)
  elseif U:APMisTrue("wifi_was_on", settings.backup) then
    logger.dbg("AIRPLANEMODE: Saving wifi_was_on setting: true")
    U:APMmakeTrue("wifi_was_on", settings.koreader)
    NetworkMgr:enableWifi(nil, true)
  end
end

---Disable WiFi and adjust related settings for airplane mode
---@return nil
function APMNetwork:disableWifi()
  --set this regardless of original setting to ensure no resumes
  if Device:hasWifiRestore() then
    logger.dbg("AIRPLANEMODE: hasWifiRestore, flipping auto_restore_wifi")
    U:APMflipNilOrFalse("auto_restore_wifi", settings.koreader)
  end

  if U:APMnilOrFalse("auto_disable_wifi", settings.koreader) then
    logger.dbg("AIRPLANEMODE: auto_disable_wifi is true, flipping")
    U:APMflipNilOrFalse("auto_disable_wifi", settings.koreader)
  end

  -- According to network manager, this setting always has a value and defaults to prompt
  local wifi_enable_action_setting = U:readAPMsetting("wifi_enable_action", settings.koreader) or "prompt"
  if wifi_enable_action_setting == "turn_on" then
    logger.dbg("AIRPLANEMODE: wifi_enable_action is turn_on, setting to prompt")
    U:saveAPMsetting("wifi_enable_action", "prompt", settings.koreader)
  end

  -- According to network manager, this setting always has a value and defaults to prompt
  local wifi_disable_action_setting = U:readAPMsetting("wifi_disable_action", settings.koreader) or "prompt"
  if wifi_disable_action_setting ~= "turn_off" then
    logger.dbg("AIRPLANEMODE: wifi_disable_action is not turn_off, setting to turn_off")
    U:saveAPMsetting("wifi_disable_action", "turn_off", settings.koreader)
  end

  if Device:isEmulator() and U:APMhas("emulator_fake_wifi_connected", settings.koreader) and U:APMisTrue("emulator_fake_wifi_connected", settings.koreader) then
    logger.dbg("AIRPLANEMODE: emulator_fake_wifi_connected is true, flipping")
    U:APMmakeFalse("emulator_fake_wifi_connected", settings.koreader)
  end

  if U:APMisTrue("http_proxy_enabled", settings.koreader) then --t
    logger.dbg("AIRPLANEMODE: http_proxy_enabled is true, flipping")
    U:APMflipNilOrFalse("http_proxy_enabled", settings.koreader)
  end

  if NetworkMgr:isWifiOn() then
    logger.dbg("AIRPLANEMODE: wifi is on, disabling")
    NetworkMgr:disableWifi(nil, true)
  end
end

return APMNetwork
