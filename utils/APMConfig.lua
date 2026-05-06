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

  return {
    koreader = settings_file,
    settings_backup = settings_bk,
    airplanemode = airplanemode_config,
  }
end

return APMConfig
