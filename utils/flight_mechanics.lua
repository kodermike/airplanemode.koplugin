---@class FlightMechanics
---@field get_device_model_name fun(): string
---@field get_device_firmware_info fun(): string

local Device = require("device")
local H = require("utils/flight_helpers")

local FlightMechanics = {}

---FlightMechanics.get_device_model_name()
---Retrieve device model name
---@return string
function FlightMechanics.get_device_model_name()
  local dev = "Unknown"
  if Device and Device.isEmulator() then
    return "Emulator"
  end
  if Device and Device.isSDL() then
    return "SDL"
  end
  if Device and Device.isDesktop() then
    return "Desktop"
  end
  if Device and Device.isAndroid() then
    dev = "Android"
  end
  if Device and Device.isCervantes() then
    dev = "Cervantes"
  end
  if Device and Device.isKindle() then
    dev = "Kindle"
  end
  if Device and Device.isKobo() then
    dev = "Kobo"
  end
  if Device and Device.isPocketBook() then
    dev = "PocketBook"
  end
  if Device and Device.isRemarkable() then
    dev = "Remarkable"
  end
  if Device and Device.isSonyPRSTUX() then
    dev = "SonyPRSTUX"
  end
  if Device.model and (dev ~= Device.model) then
    local dm = dev .. Device.model
    return dm
  else
    return dev
  end
end

---Retrieve firmware version
---@return string
function FlightMechanics.get_device_firmware_info()
  if not Device then
    return "n/a"
  end

  ---@private
  local function normalize_fw_value(v)
    return H.normalize_value(v)
  end

  ---@private
  local function read_first_line(path)
    local f = io.open(path, "r")
    if not f then
      return nil
    end
    local line = f:read("*l")
    f:close()
    return normalize_fw_value(line)
  end

  -- Try the generic KOReader API first (works on Kobo, Kindle, etc.)
  if type(Device.getFirmwareVersion) == "function" then
    local calls = {
      function()
        return Device:getFirmwareVersion()
      end,
      function()
        return Device.getFirmwareVersion(Device)
      end,
      function()
        return Device.getFirmwareVersion()
      end,
    }
    for _, get_fw in ipairs(calls) do
      local ok, value = pcall(get_fw)
      value = ok and normalize_fw_value(value) or nil
      if value then
        return value
      end
    end
  end

  -- Common device fields
  local value = H.first_non_empty(
    Device.firmware,
    Device.firmware_version,
    Device.firmware_rev,
    Device.fw_version,
    Device.fw,
    Device.softwareVersion,
    rawget(_G, "KINDLE_FIRMWARE_VERSION"),
    rawget(_G, "KINDLE_FW_VERSION")
  )
  value = normalize_fw_value(value)
  if value then
    return value
  end

  -- Kindle-specific files
  if Device.isKindle and Device:isKindle() then
    value = read_first_line("/etc/prettyversion.txt")
    if value then
      return value
    end
    value = read_first_line("/etc/version.txt")
    if value then
      return value
    end
  end

  -- Kobo-specific file: "N/A,N/A,4.38.21908" -> last field is FW version
  if Device.isKobo and Device:isKobo() then
    local raw = read_first_line("/mnt/onboard/.kobo/version")
    if raw then
      value = raw:match("([^,]+)$") or raw
      value = normalize_fw_value(value)
      if value then
        return value
      end
    end
  end

  return "n/a"
end

return FlightMechanics
