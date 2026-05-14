local DataStorage = require("datastorage")

local APMConfig = {
  show_info = true,
  enabled_plugins = nil,
  disabled_plugins = nil,
  loaded_plugins = nil,
  all_plugins = nil,
}

-- return base config file locations
function APMConfig:init()
  local settings_file = DataStorage:getDataDir() .. "/settings.reader.lua"
  local settings_bk = DataStorage:getDataDir() .. "/settings.reader.lua.airplane"
  local airplanemode_config = DataStorage:getDataDir() .. "/settings/airplanemode.lua"
  local airplanemode_old = airplanemode_config .. ".old"
  local prev_config = DataStorage:getDataDir() .. "/settings/airplane_plugins.lua"

  return {
    koreader = settings_file,
    backup = settings_bk,
    airplanemode = airplanemode_config,
    airplanemode_old = airplanemode_old,
    prev_config = prev_config,
    koreader_plugins = "plugins_disabled",
    airplane_plugins = "disabled_plugins",
  }
end

return APMConfig
