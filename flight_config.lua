---@class FlightConfig
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
---@field description string
---@field fullname string
---@field debug_is_on boolean

local DataStorage = require("datastorage")
local meta = require("_meta")

local FlightConfig = {
  koreader = nil,
  backup = nil,
  airplanemode = nil,
  airplanemode_old = nil,
  prev_config = nil,
  koreader_plugins = nil,
  airplane_plugins = nil,
  icon_on = nil,
  icon_off = nil,
  version = nil,
  description = nil,
  fullname = nil,
  debug_is_on = nil,
}

---Return base config file locations
---@return FlightConfig table
function FlightConfig:init()
  self.koreader = DataStorage:getDataDir() .. "/settings.reader.lua"
  self.backup = DataStorage:getDataDir() .. "/settings.reader.lua.airplane"
  self.airplanemode = DataStorage:getDataDir() .. "/settings/airplanemode.lua"
  self.airplanemode_old = self.airplanemode .. ".old"
  self.prev_config = DataStorage:getDataDir() .. "/settings/airplane_plugins.lua"
  self.koreader_plugins = "plugins_disabled"
  ---@deprecated Use koreader_plugins instead
  self.airplane_plugins = "disabled_plugins"
  self.description = meta.description or "Toggleing all your networking apps at once"
  self.fullname = meta.fullname or "AirPlaneMode"
  self.version = meta.version or "9.9.9"
  self.icon_on = "\u{F1D8}"
  self.icon_off = "\u{F1D9}"

  -- Read optional debug flag from the AirPlaneMode settings file if present
  -- Can't use existing config handler because it would create a depenency loop
  self.debug_is_on = false
  local ok, LuaSettings = pcall(require, "luasettings")
  if ok and LuaSettings then
    local status, cfg = pcall(function()
      return LuaSettings:open(self.airplanemode)
    end)
    if status and cfg then
      if cfg:has("debug_is_on") then
        self.debug_is_on = cfg:readSetting("debug_is_on")
      else
        self.debug_is_on = false
      end
      cfg:close()
    end
  end

  return {
    koreader = self.koreader,
    backup = self.backup,
    airplanemode = self.airplanemode,
    airplanemode_old = self.airplanemode_old,
    prev_config = self.prev_config,
    koreader_plugins = self.koreader_plugins,
    airplane_plugins = self.airplane_plugins,
    icon_on = self.icon_on,
    icon_off = self.icon_off,
    version = self.version,
    description = self.description,
    fullname = self.fullname,
    debug_is_on = self.debug_is_on,
  }
end

return FlightConfig
