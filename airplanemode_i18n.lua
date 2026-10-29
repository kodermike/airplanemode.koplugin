--[[
Per-plugin locale catalog.

KOReader only localizes its own tree (l10n/<lang>.mo), so this plugin reads
locales/<lang>.po next to main.lua and serves those msgids through KOReader's
gettext; anything the catalog lacks still falls through to KOReader's own
translations.

install() replaces the gettext module with a thin wrapper before any plugin
module captures it, so the plugin's existing _() call sites resolve without
being touched. The wrapper delegates every other key to the real module, so
pgettext/ngettext/changeLang keep working for code loaded afterwards.

Usage:
    require("airplanemode_i18n").install()
    local _ = require("gettext")
    _("AirPlaneMode Enable") --> "AirPlaneMode: Ativar" (pt_BR)
]]

local logger = require("logger")

local M = {}

local translations = {}

-- Directory holding this file. KOReader's loader yields the path it found the
-- module at (absolute, or relative to the working directory); io.open resolves
-- a relative one the same way.
local function resolveDir(source)
  local dir = source:match("^@(.*)/")
  return dir and dir .. "/" or "./"
end

local plugin_dir = resolveDir(debug.getinfo(1, "S").source or "")

local function unescape(text)
  return (text:gsub("\\(.)", function(c)
    if c == "n" then
      return "\n"
    elseif c == "t" then
      return "\t"
    elseif c == '"' then
      return '"'
    elseif c == "\\" then
      return "\\"
    else
      return "\\" .. c
    end
  end))
end

--- Minimal .po reader: msgid/msgstr plus continuation lines. Contextual,
--- plural, fuzzy and obsolete entries are dropped rather than served: this
--- plugin has no context- or number-dependent strings, and a plural would need
--- ngettext to be wrapped as well.
---@param path string
---@return table? catalog msgid -> msgstr, nil if unreadable or empty
function M.parse_po(path)
  local handle = io.open(path, "r")
  if not handle then
    return nil
  end

  local catalog = {}
  local msgid, msgstr, in_id, in_str
  local drop_next, drop_entry

  local function flush()
    if not drop_entry and msgid and msgid ~= "" and msgstr and msgstr ~= "" then
      catalog[msgid] = msgstr
    end
    msgid, msgstr, in_id, in_str, drop_entry = nil, nil, false, false, false
  end

  for line in handle:lines() do
    line = line:match("^%s*(.-)%s*$")
    if line == "" then
      flush()
    elseif line:sub(1, 1) == "#" then
      -- "#, fuzzy" marks the following entry as unreviewed by msgfmt rules
      drop_next = drop_next or line:match("^#,.*fuzzy") ~= nil
    elseif line:match("^msgctxt%s") then
      flush()
      drop_next = true
    elseif line:match("^msgid_plural%s") or line:match("^msgstr%s*%[") then
      -- plural block: drop it whole so its continuations cannot corrupt msgid
      flush()
    elseif line:match('^msgid%s+"') then
      flush()
      drop_entry = drop_next
      drop_next = nil
      msgid = unescape(line:match('^msgid%s+"(.*)"') or "")
      in_id, in_str = true, false
    elseif line:match('^msgstr%s+"') then
      msgstr = unescape(line:match('^msgstr%s+"(.*)"') or "")
      in_str, in_id = true, false
    elseif line:sub(1, 1) == '"' then
      local continuation = unescape(line:match('^"(.*)"') or "")
      if in_id and msgid then
        msgid = msgid .. continuation
      elseif in_str and msgstr then
        msgstr = msgstr .. continuation
      end
    end
  end
  flush()
  handle:close()

  if next(catalog) == nil then
    return nil
  end
  return catalog
end

--- Language detection: KOReader's "language" setting first, then the POSIX
--- locale, mirroring the priority order of KOReader's gettext module.
---@return string? lang e.g. "pt_BR", nil if nothing usable
function M.getLang()
  local lang
  if type(G_reader_settings) == "table" and type(G_reader_settings.readSetting) == "function" then
    lang = G_reader_settings:readSetting("language")
  end
  if type(lang) ~= "string" or lang == "" then
    local posix = os.getenv("LANGUAGE") or os.getenv("LC_ALL") or os.getenv("LC_MESSAGES") or os.getenv("LANG") or ""
    lang = posix:match("^([%a_]+)")
  end
  if type(lang) == "string" then
    -- strip an encoding suffix such as ".UTF-8"
    local dot = lang:find("%.")
    if dot then
      lang = lang:sub(1, dot - 1)
    end
  end
  if lang == "" then
    return nil
  end
  return lang
end

local function uses_english(lang)
  return lang == "C" or lang == "POSIX" or lang == "en" or lang:match("^en_") ~= nil
end

local function load_catalog(lang)
  local candidates = { lang }
  local prefix = lang:match("^([%a]+)")
  if prefix and prefix ~= lang then
    candidates[#candidates + 1] = prefix
  end

  for _, candidate in ipairs(candidates) do
    local path = plugin_dir .. "locales/" .. candidate .. ".po"
    local parsed = M.parse_po(path)
    if parsed then
      local count = 0
      for _ in pairs(parsed) do
        count = count + 1
      end
      logger.info("AirPlaneMode: loaded " .. path .. " — " .. count .. " entries")
      return parsed
    end
  end
  return nil
end

--- Install the plugin catalog over the loaded gettext module.
--- Safe to call more than once; later calls keep the wrapper already in place.
---@return boolean ok true when a catalog was installed
function M.install()
  local gettext = package.loaded["gettext"]
  if type(gettext) == "table" and rawget(gettext, "_apm_i18n") then
    return true
  end

  local lang = M.getLang()
  if not lang or uses_english(lang) then
    logger.info("AirPlaneMode: staying in English (lang=" .. tostring(lang) .. ")")
    return false
  end

  local catalog = load_catalog(lang)
  if not catalog then
    logger.info("AirPlaneMode: no locale file for language " .. lang .. ", staying in English")
    return false
  end
  translations = catalog

  if not gettext then
    local ok, module = pcall(require, "gettext")
    if ok then
      gettext = module
    end
  end
  if type(gettext) ~= "table" and type(gettext) ~= "function" then
    logger.warn("AirPlaneMode: cannot wrap gettext, translations disabled")
    return false
  end

  local mt = {
    __call = function(_, msgid)
      return translations[msgid] or gettext(msgid)
    end,
  }
  if type(gettext) == "table" then
    -- Delegate unknown keys to the real module, so pgettext/ngettext/changeLang
    -- work and other plugins can still patch that table.
    mt.__index = gettext
    mt.__newindex = gettext
  end

  -- Only modules that require gettext after this point (i.e. this plugin's own
  -- modules) see the catalog; KOReader's gettext state stays untouched.
  package.loaded["gettext"] = setmetatable({ _apm_i18n = true }, mt)
  return true
end

return M
