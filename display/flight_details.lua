-- local FocusManager = require("ui/widget/focusmanager")
-- local TextWidget = require("ui/widget/textwidget")

local BD = require("ui/bidi")
local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")

local ffiutil = require("ffi/util")
local T = ffiutil.template
local _ = require("gettext")

local FlightConfig = require("flight_config")
local settings = FlightConfig:init()
local H = require("utils/flight_helpers")
local U = require("utils/flight_utilities")

local FlightDetails = {}

---Retrieve KOReader version
---@return string
function FlightDetails.getKOReaderVersion()
  local ok, v_info = pcall(require, "version")
  if ok then
    if type(v_info) == "string" and v_info ~= "" then
      return v_info
    end
    if type(v_info) == "table" then
      local value = H.first_non_empty(v_info.version, v_info.short, v_info.git, v_info.git_rev, v_info.build, v_info.tag)
      if value then
        return value
      end
    end
  end

  local value = H.first_non_empty(rawget(_G, "KOREADER_VERSION"), rawget(_G, "KO_VERSION"), rawget(_G, "GIT_REV"))
  return value or "unknown"
end

function FlightDetails.get_device_model_name()
  local function call_device_method(name)
    print("\n\ndevicename might be:", name)
    if not (Device and type(Device[name]) == "function") then
      return nil
    end
    local ok, value = pcall(Device[name], Device)
    value = ok and H.normalize_value(value) or nil
    if value then
      return value
    end
    ok, value = pcall(Device[name])
    return ok and H.normalize_value(value) or nil
  end

  local value = H.normalize_value(
    H.first_non_empty(
      Device and Device.model,
      Device and Device.model_name,
      Device and Device.device_model,
      Device and Device.product,
      Device and Device.name,
      Device and Device.friendly_name,
      Device and Device.id,
      rawget(_G, "DEVICE_MODEL")
    )
  )
  if value then
    return value
  end

  value = call_device_method("getModel")
    or call_device_method("getModelName")
    or call_device_method("getDeviceModel")
    or call_device_method("getFriendlyName")
    or call_device_method("getDeviceName")
  if value then
    return value
  end

  if Device and Device.isAndroid and Device:isAndroid() then
    local ok_model, model = pcall(function()
      local pipe = io.popen("getprop ro.product.model 2>/dev/null")
      if not pipe then
        return nil
      end
      local out = pipe:read("*l")
      pipe:close()
      return H.normalize_value(out)
    end)
    local ok_mfr, mfr = pcall(function()
      local pipe = io.popen("getprop ro.product.manufacturer 2>/dev/null")
      if not pipe then
        return nil
      end
      local out = pipe:read("*l")
      pipe:close()
      return H.normalize_value(out)
    end)
    if ok_model and model then
      if ok_mfr and mfr and not model:lower():find(mfr:lower(), 1, true) then
        return mfr .. " " .. model
      end
      return model
    end
  end

  return "Device"
end

function FlightDetails.get_device_firmware_info()
  if not Device then
    return "n/a", nil, nil
  end

  local function normalize_fw_value(v)
    return H.normalize_value(v)
  end

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
        return value, "Device FW", "Device FW"
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
    return value, "Device FW", "Device FW"
  end

  -- Kindle-specific files
  if Device.isKindle and Device:isKindle() then
    value = read_first_line("/etc/prettyversion.txt")
    if value then
      return value, "prettyversion", "prettyversion"
    end
    value = read_first_line("/etc/version.txt")
    if value then
      return value, "version", "version"
    end
  end

  -- Kobo-specific file: "N/A,N/A,4.38.21908" -> last field is FW version
  if Device.isKobo and Device:isKobo() then
    local raw = read_first_line("/mnt/onboard/.kobo/version")
    if raw then
      value = raw:match("([^,]+)$") or raw
      value = normalize_fw_value(value)
      if value then
        return value, "version", "version"
      end
    end
  end

  return "n/a", nil, nil
end

local function generic_entry(t)
  local icon = U:getStatus() and settings.icon_on or settings.icon_off
  return {
    text = _(t),
    keep_menu_open = true,
    callback = function()
      UIManager:show(InfoMessage:new({
        text = T(_("%1  %2 v%3\n\n%4\n\nLicensed under Affero GPL v3."), icon, BD.ltr(settings.fullname), BD.ltr(settings.version), BD.ltr(settings.description)),
      }))
    end,
  }
end

function FlightDetails:menu()
  local airplane_specs = {}
  -- Generate information buttons - all use the same popup for displaying About
  local button_list = {
    T(_("%1: v%2"), settings.fullname, settings.version),
    T(_("KOReader Version: %s"):format(BD.ltr(self:getKOReaderVersion()))),
    --TODO: alt if there is no firmware info
    T(_("Firmware: %s"):format(BD.ltr(self:get_device_firmware_info()))),
    --TODO: Alt if there is no device model info
    T(_("Device: %s"):format(BD.ltr(self:get_device_model_name()))),
  }
  for _, text in ipairs(button_list) do
    table.insert(airplane_specs, generic_entry(text))
  end

  -- Updater management
  --TODO: Disable if airplane mode is enabled
  --TODO: show popup if not enabled
  table.insert(airplane_specs, {
    text = _("Update management"),
    sub_item_table_func = function()
      local updater_menu = require("display/flight_plan_menu")
      return updater_menu:showMenu()
    end,
  })

  --Debug Manager
  --TODO: add debug menu
  -- enable data dumps
  -- enable debug mode
  -- bug report?
  -- bug report from qr code...?
  --
  return airplane_specs
end

return FlightDetails
