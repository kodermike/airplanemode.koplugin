---@class H

local lfs = require("libs/libkoreader-lfs")

local H = {}

local function first_non_empty(...)
  for i = 1, select("#", ...) do
    local v = select(i, ...)
    if type(v) == "string" and v ~= "" then
      return v
    end
  end
  return nil
end

local function normalize_value(v)
  if type(v) == "number" then
    v = tostring(v)
  end
  if type(v) ~= "string" then
    return nil
  end
  v = v:match("^%s*(.-)%s*$")
  if v == "" then
    return nil
  end
  return v
end

---Check if path is a file
---@param path string
---@return boolean
function H.isFile(path)
  if type(path) ~= "string" then
    return false
  end
  if not H.isDir(path) then
    return os.rename(path, path) and true or false
    -- note that the short evaluation is to
    -- return false instead of a possible nil
  end
  return false
end

---Check if path is a directory
---@param path string
---@return boolean
function H.isDir(path)
  if type(path) ~= "string" then
    return false
  end
  -- Prefer using attributes to detect directories so tests can provide
  -- minimal lfs mocks that only implement attributes. This avoids
  -- relying on currentdir/chdir being present.
  local mode = nil
  if type(lfs.attributes) == "function" then
    -- ask for mode first (some mocks return a string when passed "mode")
    local ok, m = pcall(lfs.attributes, path, "mode")
    if ok then
      mode = m
    else
      -- fallback: try without "mode"
      local ok2, t = pcall(lfs.attributes, path)
      if ok2 and type(t) == "table" then
        mode = t.mode
      end
    end
  end
  if mode == "directory" then
    return true
  elseif mode == "file" then
    return false
  end
  return false
end

---Remove file if it exists
---This function signature intentionally matches existing usage: it may be called as `H.removeFile(path)`.
---@param path string
---@return boolean
function H.removeFile(path)
  if H.isFile(path) then
    os.remove(path)
    return true
  else
    return false
  end
end

--TODO:
-- - move the version stuff to utilities, leave only the helpers in helpers
-- - break out debugging!!! Then record the firmware, hardware, etc in debugging
-- - add "enable debug" somewhere useful
--FIX: pop up window looks like shit

---Retrieve KOReader version
---@return string
function H.getKOReaderVersion()
  local ok, v_info = pcall(require, "version")
  if ok then
    if type(v_info) == "string" and v_info ~= "" then
      return v_info
    end
    if type(v_info) == "table" then
      local value = first_non_empty(v_info.version, v_info.short, v_info.git, v_info.git_rev, v_info.build, v_info.tag)
      if value then
        return value
      end
    end
  end

  local value = first_non_empty(rawget(_G, "KOREADER_VERSION"), rawget(_G, "KO_VERSION"), rawget(_G, "GIT_REV"))
  return value or "unknown"
end

function H.get_device_model_name()
  local function call_device_method(name)
    print("\n\ndevicename might be:", name)
    if not (Device and type(Device[name]) == "function") then
      return nil
    end
    local ok, value = pcall(Device[name], Device)
    value = ok and normalize_value(value) or nil
    if value then
      return value
    end
    ok, value = pcall(Device[name])
    return ok and normalize_value(value) or nil
  end

  local value = normalize_value(
    first_non_empty(
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
      return normalize_value(out)
    end)
    local ok_mfr, mfr = pcall(function()
      local pipe = io.popen("getprop ro.product.manufacturer 2>/dev/null")
      if not pipe then
        return nil
      end
      local out = pipe:read("*l")
      pipe:close()
      return normalize_value(out)
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

function H.get_device_firmware_info()
  if not Device then
    return "n/a", nil, nil
  end

  local function normalize_fw_value(v)
    return normalize_value(v)
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
  local value = first_non_empty(
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

return H
