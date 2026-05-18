---@class SettingsConfig
---@field koreader string
---@field backup string
---@field airplanemode string
---@field airplanemode_old string
---@field prev_config string
---@field koreader_plugins string
---@field airplane_plugins string
---@field icon_on string
---@field icon_off string
---@field version string

---@class APMConfig
---@field show_info boolean
---@field enabled_plugins table|nil
---@field disabled_plugins table|nil
---@field loaded_plugins table|nil
---@field all_plugins table|nil

local DataStorage = require("datastorage")
local meta = require("_meta")

local APMConfig = {
  show_info = true,
  enabled_plugins = nil,
  disabled_plugins = nil,
  loaded_plugins = nil,
  all_plugins = nil,
}

---Return base config file locations
---@return SettingsConfig
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
    airplane_plugins = "disabled_plugins", -- deprecated
    icon_on = "\u{F1D8}",
    icon_off = "\u{F1D9}",
    version = meta.version,
  }
end

return APMConfig
