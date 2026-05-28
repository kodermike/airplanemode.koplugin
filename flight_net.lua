---@class FlightNetwork

local logger = require("logger")
local Device = require("device")
local NetworkMgr = require("ui/network/manager")

local FlightConfig = require("flight_config")
local settings = FlightConfig:init()
local U = require("utils/flight_utilities")

local FlightNetwork = {}

---Re-enable WiFi and restore related settings from backup
---@return nil
function FlightNetwork:reenableWifi()
  if Device:hasWifiRestore() and U:readFlightsetting("auto_restore_wifi", settings.koreader) then
    logger.dbg("AIRPLANEMODE: Reverting auto_restore_wifi to true")
    U:FlightmakeTrue("auto_restore_wifi", settings.koreader)
  end

  if U:FlightnilOrFalse("auto_disable_wifi", settings.backup) then
    logger.dbg("AIRPLANEMODE: Reverting auto_disable_wifi to false")
    -- flip the real config
    U:FlightflipNilOrFalse("auto_disable_wifi", settings.koreader)
  end

  -- According to network manager, this setting always has a value and defaults to prompt
  if U:FlighthasNot("wifi_enable_action", settings.backup) then
    logger.dbg("AIRPLANEMODE: Deleting wifi_enable_action setting")
    U:delFlightsetting("wifi_enable_action", settings.koreader)
  else
    local bk_wifi_enable_action_setting = U:readFlightsetting("wifi_enable_action", settings.backup) or "prompt"
    logger.dbg("AIRPLANEMODE: Saving wifi_enable_action setting: ", bk_wifi_enable_action_setting)
    U:saveFlightsetting("wifi_enable_action", bk_wifi_enable_action_setting, settings.koreader)
  end

  -- According to network manager, this setting always has a value and defaults to prompt
  if U:FlighthasNot("wifi_disable_action", settings.backup) then
    logger.dbg("AIRPLANEMODE: Deleting wifi_disable_action setting")
    U:delFlightsetting("wifi_disable_action", settings.koreader)
  else
    local bk_wifi_disable_action_setting = U:readFlightsetting("wifi_disable_action", settings.backup) or "prompt"
    logger.dbg("AIRPLANEMODE: Saving wifi_disable_action setting: ", bk_wifi_disable_action_setting)
    U:saveFlightsetting("wifi_disable_action", bk_wifi_disable_action_setting, settings.koreader)
  end

  -- got to watch out for our emulator friends :) (ie, me, testing)
  if Device:isEmulator() and U:Flighthas("emulator_fake_wifi_connected", settings.backup) then
    logger.dbg("AIRPLANEMODE: Saving emulator_fake_wifi_connected setting: ", U:readFlightsetting("emulator_fake_wifi_connected", settings.backup))
    local old_emulator_fake_wifi_connected = U:readFlightsetting("emulator_fake_wifi_connected", settings.backup) or nil
    -- flip the real config
    if old_emulator_fake_wifi_connected ~= nil then
      U:saveFlightsetting("emulator_fake_wifi_connected", old_emulator_fake_wifi_connected, settings.koreader)
    end
  end

  if U:FlightisTrue("http_proxy_enabled", settings.backup) then
    logger.dbg("AIRPLANEMODE: Saving http_proxy_enabled setting: true")
    -- flip the real config
    U:FlightmakeTrue("http_proxy_enabled", settings.koreader)
  end

  --if NetworkMgr:getWifiState() == false and backup_config:isTrue("wifi_was_on") then
  if U:FlighthasNot("wifi_was_on", settings.backup) then
    logger.dbg("AIRPLANEMODE: Deleting wifi_was_on setting")
    U:delFlightsetting("wifi_was_on", settings.koreader)
  elseif U:FlightisTrue("wifi_was_on", settings.backup) then
    logger.dbg("AIRPLANEMODE: Saving wifi_was_on setting: true")
    U:FlightmakeTrue("wifi_was_on", settings.koreader)
    NetworkMgr:enableWifi(nil, true)
  end
end

---Disable WiFi and adjust related settings for airplane mode
---@return nil
function FlightNetwork:disableWifi()
  --set this regardless of original setting to ensure no resumes
  if Device:hasWifiRestore() then
    logger.dbg("AIRPLANEMODE: hasWifiRestore, flipping auto_restore_wifi")
    U:FlightflipNilOrFalse("auto_restore_wifi", settings.koreader)
  end

  -- https://github.com/koreader/koreader/issues/15397
  -- Emulator can't have autodisable set to true or it crashes koreader
  if U:FlightnilOrFalse("auto_disable_wifi", settings.koreader) and not Device:isEmulator() then
    logger.dbg("AIRPLANEMODE: auto_disable_wifi is true, flipping")
    U:FlightflipNilOrFalse("auto_disable_wifi", settings.koreader)
  end

  -- According to network manager, this setting always has a value and defaults to prompt
  local wifi_enable_action_setting = U:readFlightsetting("wifi_enable_action", settings.koreader) or "prompt"
  if wifi_enable_action_setting == "turn_on" then
    logger.dbg("AIRPLANEMODE: wifi_enable_action is turn_on, setting to prompt")
    U:saveFlightsetting("wifi_enable_action", "prompt", settings.koreader)
  end

  -- According to network manager, this setting always has a value and defaults to prompt
  local wifi_disable_action_setting = U:readFlightsetting("wifi_disable_action", settings.koreader) or "prompt"
  if wifi_disable_action_setting ~= "turn_off" then
    logger.dbg("AIRPLANEMODE: wifi_disable_action is not turn_off, setting to turn_off")
    U:saveFlightsetting("wifi_disable_action", "turn_off", settings.koreader)
  end

  if Device:isEmulator() and U:Flighthas("emulator_fake_wifi_connected", settings.koreader) and U:FlightisTrue("emulator_fake_wifi_connected", settings.koreader) then
    logger.dbg("AIRPLANEMODE: emulator_fake_wifi_connected is true, flipping")
    U:FlightmakeFalse("emulator_fake_wifi_connected", settings.koreader)
  end

  if U:FlightisTrue("http_proxy_enabled", settings.koreader) then --t
    logger.dbg("AIRPLANEMODE: http_proxy_enabled is true, flipping")
    U:FlightflipNilOrFalse("http_proxy_enabled", settings.koreader)
  end

  if NetworkMgr:isWifiOn() then
    logger.dbg("AIRPLANEMODE: wifi is on, disabling")
    NetworkMgr:disableWifi(nil, true)
  end
end

return FlightNetwork
