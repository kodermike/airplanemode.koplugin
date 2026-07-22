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
---@field dev_mode boolean

local DataStorage = require("datastorage")
local meta = require("_meta")
local H = require("utils/flight_helpers")

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
  dev_mode = nil,
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

  if not H.isFile(self.airplanemode) then
    self.initSettingsFile(self.airplanemode, self.version)
  end
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
      if cfg:has("dev_mode") then
        self.dev_mode = cfg:readSetting("dev_mode")
      else
        self.dev_mode = false
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
    dev_mode = self.dev_mode,
  }
end

---Settings initialized
---@return nil
function FlightConfig.initSettingsFile(airplanemode_file, version)
  -- If the file already exists, bail out early
  if H.isFile(airplanemode_file) == true then
    return
  else
    -- Only write defaults if the setting is not already present (avoid clobbering)
    local default_disable = {}
    local default_disable_list = { "newsdownloader", "wallabag", "kosync", "opds", "SSH", "timesync", "httpinspector" }
    for __, plugin in ipairs(default_disable_list) do
      default_disable[plugin] = true
    end
    local ok, LuaSettings = pcall(require, "luasettings")
    if ok and LuaSettings then
      local status, cfg = pcall(function()
        return LuaSettings:open(airplanemode_file)
      end)
      if status and cfg then
        cfg:saveSetting("version", version)
        cfg:saveSetting("plugins_disabled", default_disable)
        cfg:close()
      end
    end
  end
end
return FlightConfig
