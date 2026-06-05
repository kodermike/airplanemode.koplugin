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

--- Show the about dialog for the plugin.
function FlightDetails:_about()
  --   local Device = require("device")
  --   local Screen = Device.screen
  --   local Font = require("ui/font")
  --   local Geom = require("ui/geometry")
  --   local Size = require("ui/size")
  --   local Blitbuffer = require("ffi/blitbuffer")
  --   local FrameContainer = require("ui/widget/container/framecontainer")
  --   local CenterContainer = require("ui/widget/container/centercontainer")
  --   local MovableContainer = require("ui/widget/container/movablecontainer")
  --   local InputContainer = require("ui/widget/container/inputcontainer")
  --   local VerticalGroup = require("ui/widget/verticalgroup")
  --   local VerticalSpan = require("ui/widget/verticalspan")
  --   local TextBoxWidget = require("ui/widget/textboxwidget")
  --   local TextWidget = require("ui/widget/textwidget")
  --   local GestureRange = require("ui/gesturerange")

  --   local sw, sh = Screen:getWidth(), Screen:getHeight()
  --   local frame_w = math.min(math.floor(sw * 0.8), Screen:scaleBySize(420))
  --   local FRAME_PAD = Screen:scaleBySize(24)
  --   local content_w = frame_w - FRAME_PAD * 2

  --   local column = VerticalGroup:new({ align = "center" })

  --   local ver_face, ver_bold = BFont:getFace("cfont", 16)
  --   column[#column + 1] = TextWidget:new({
  --     text = "v" .. version,
  --     face = ver_face,
  --     bold = ver_bold,
  --   })
  --   column[#column + 1] = VerticalSpan:new({ width = Size.padding.large })
  --   local desc_face, desc_bold = BFont:getFace("cfont", 16)
  --   column[#column + 1] = TextBoxWidget:new({
  --     text = description,
  --     face = desc_face,
  --     bold = desc_bold,
  --     width = content_w,
  --     alignment = "center",
  --   })
  --   column[#column + 1] = VerticalSpan:new({ width = Size.padding.large })
  --   -- Tappable URL: tries Device:openLink (works on SDL / Android), then
  --   -- falls back to copying to KOReader's internal clipboard + a brief
  --   -- Notification. On Kindle there's no native browser so the
  --   -- clipboard path is the user-meaningful one (paste into a Send-to-
  --   -- Kindle-style helper, or just read the URL clearly).
  --   local Button = require("ui/widget/button")
  --   local function open_github()
  --     local ok = false
  --     if Device.openLink then
  --       local _ok, ret = pcall(function()
  --         return Device:openLink(GITHUB_URL)
  --       end)
  --       if _ok and ret then
  --         ok = true
  --       end
  --     end
  --     if not ok and Device.input and Device.input.setClipboardText then
  --       pcall(function()
  --         Device.input.setClipboardText(GITHUB_URL)
  --       end)
  --       local Notification = require("ui/widget/notification")
  --       UIManager:show(Notification:new({
  --         text = _("Link copied to clipboard"),
  --       }))
  --     end
  --   end
  --   column[#column + 1] = Button:new({
  --     text = GITHUB_URL_DISPLAY,
  --     bordersize = 0,
  --     padding = 0,
  --     margin = 0,
  --     text_font_face = "cfont",
  --     text_font_size = 14,
  --     callback = open_github,
  --   })

  --   -- Frame styling matches the other Bookshelf modals (chip editor,
  --   -- hero line editor): default Size.border.window thickness (thicker
  --   -- than Size.border.thin) and Size.radius.window for rounded
  --   -- corners. Earlier the popup used thin + square, which read as
  --   -- subtly out-of-family next to the rest of the plugin's dialogs.
  --   -- Per-side padding: tighter at the top because the BOOKSHELF logo's
  --   -- bold glyphs carry their own visual mass and don't need as much
  --   -- breathing room above them. Equal padding made the popup read as
  --   -- top-heavy in the screenshot. Bottom keeps the full FRAME_PAD so
  --   -- the URL has the same air the description gets.
  --   local frame = FrameContainer:new({
  --     radius = Size.radius.window,
  --     padding = FRAME_PAD,
  --     padding_top = math.floor(FRAME_PAD * 0.5),
  --     margin = 0,
  --     background = Blitbuffer.COLOR_WHITE,
  --     column,
  --   })

  --   local dialog
  --   dialog = InputContainer:new({
  --     align = "center",
  --     dimen = Geom:new({ x = 0, y = 0, w = sw, h = sh }),
  --     CenterContainer:new({
  --       dimen = Geom:new({ w = sw, h = sh }),
  --       MovableContainer:new({ frame }),
  --     }),
  --   })
  --   if Device:isTouchDevice() then
  --     dialog.ges_events = {
  --       TapClose = { GestureRange:new({
  --         ges = "tap",
  --         range = Geom:new({ x = 0, y = 0, w = sw, h = sh }),
  --       }) },
  --     }
  --     dialog.onTapClose = function(self_d, _arg, ges_ev)
  --       if not frame.dimen or ges_ev.pos:notIntersectWith(frame.dimen) then
  --         UIManager:close(self_d)
  --       end
  --       return true
  --     end
  --   end
  --   if Device:hasKeys() then
  --     dialog.key_events = { Close = { { Device.input.group.Back } } }
  --     dialog.onClose = function(self_d)
  --       UIManager:close(self_d)
  --       return true
  --     end
  --   end

  --   UIManager:show(dialog)
end

function FlightDetails:menu()
  local airplane_specs = {}
  table.insert(airplane_specs, {
    text = T(_("%1: v%2"), settings.fullname, settings.version),
    keep_menu_open = true,
    callback = function()
      UIManager:show(InfoMessage:new({
        text = T(_("%1  %2 v%3\n\n%4\n\nLicensed under Affero GPL v3."), settings.icon_on, BD.ltr(settings.fullname), BD.ltr(settings.version), BD.ltr(settings.description)),
      }))
    end,
  })
  table.insert(airplane_specs, {
    text = T(_("KOReader Version: %s"):format(BD.ltr(self:getKOReaderVersion()))),
  })
  table.insert(airplane_specs, {
    text = T(_("Device: %s"):format(BD.ltr(self:get_device_model_name()))),
  })
  table.insert(airplane_specs, {
    text = T(_("Firmware: %s"):format(BD.ltr(self:get_device_firmware_info()))),
  })

  return airplane_specs
end

return FlightDetails
