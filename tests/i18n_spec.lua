local helper = require("tests/spec_helper")
local i18n = require("airplanemode_i18n")

-- gettext and G_reader_settings are process-wide; every test installs its own
-- fakes and restores the shared slots afterwards.
local shared_gettext = package.loaded["gettext"]
local saved_greader

--- A gettext module shaped like KOReader's frontend/gettext.lua: a table whose
--- __call translates and whose methods live on the metatable __index.
local function fake_gettext(translation)
  local GetText = { translation = translation or {}, context = {}, current_lang = "en" }
  local methods = {}
  function methods.changeLang(lang)
    GetText.current_lang = lang
    return true
  end
  function methods.pgettext(msgctxt, msgid)
    return GetText.context[msgctxt] and GetText.context[msgctxt][msgid] or msgid
  end
  function methods.ngettext(single, plural, count)
    return count == 1 and single or plural
  end
  setmetatable(GetText, {
    __index = methods,
    __newindex = GetText,
    __call = function(gettext, msgid)
      return gettext.translation[msgid] or msgid
    end,
  })
  return GetText
end

local function set_reader_language(lang)
  if lang == nil then
    _G.G_reader_settings = nil
    return
  end
  _G.G_reader_settings = {
    readSetting = function(_, key)
      if key == "language" then
        return lang
      end
    end,
  }
end

local function write_file(path, body)
  local fh = assert(io.open(path, "w"))
  fh:write(body)
  fh:close()
end

local function count_entries(tbl)
  local count = 0
  for _ in pairs(tbl) do
    count = count + 1
  end
  return count
end

describe("airplanemode_i18n - locale loading", function()
  setup(function()
    helper.reset()
  end)

  before_each(function()
    saved_greader = _G.G_reader_settings
    _G.G_reader_settings = nil
    package.loaded["gettext"] = fake_gettext()
  end)

  after_each(function()
    package.loaded["gettext"] = shared_gettext
    _G.G_reader_settings = saved_greader
  end)

  describe("parse_po", function()
    it("parses the bundled pt_BR catalog", function()
      local catalog = i18n.parse_po("locales/pt_BR.po")
      assert.is_table(catalog)
      assert.are.equal("Cancelar", catalog["Cancel"])
      assert.are.equal("AirPlaneMode: Ativar", catalog["AirPlaneMode Enable"])
      -- joins continuation lines and keeps %1 placeholders intact
      assert.are.equal("%1  Gerenciamento de plugins suspenso durante o voo",
        catalog["%1  Plugin management suspended while in flight"])
    end)

    it("decodes escaped newlines in msgids and msgstrs", function()
      local catalog = i18n.parse_po("locales/pt_BR.po")
      local msgid = "A simple plugin that helps you when you're on the go.\n\n\nv.%1"
      assert.are.equal(
        "Um plugin simples que ajuda quando você está a caminho.\n\n\nv.%1",
        catalog[msgid])
    end)

    it("returns nil for a missing file", function()
      assert.is_nil(i18n.parse_po("locales/does_not_exist.po"))
    end)

    it("ignores entries with an empty msgstr", function()
      local path = helper.tmp_dir .. "/empty_msgstr.po"
      write_file(path, 'msgid "abc"\nmsgstr ""\n\nmsgid "def"\nmsgstr "ghi"\n')
      local catalog = i18n.parse_po(path)
      assert.are.equal(1, count_entries(catalog))
      assert.are.equal("ghi", catalog["def"])
    end)

    it("drops plural entries without corrupting their neighbours", function()
      local path = helper.tmp_dir .. "/plural.po"
      write_file(path, table.concat({
        'msgid "one file"',
        'msgid_plural "%1 files"',
        'msgstr[0] "um arquivo"',
        'msgstr[1] "%1 arquivos"',
        "",
        'msgid "kept"',
        'msgstr "mantido"',
        "",
      }, "\n"))
      local catalog = i18n.parse_po(path)
      assert.are.equal(1, count_entries(catalog))
      assert.are.equal("mantido", catalog["kept"])
      assert.is_nil(catalog["one file"])
    end)

    it("skips fuzzy entries", function()
      local path = helper.tmp_dir .. "/fuzzy.po"
      write_file(path, table.concat({
        "#, fuzzy",
        'msgid "draft"',
        'msgstr "rascunho"',
        "",
        'msgid "kept"',
        'msgstr "mantido"',
        "",
      }, "\n"))
      local catalog = i18n.parse_po(path)
      assert.is_nil(catalog["draft"])
      assert.are.equal("mantido", catalog["kept"])
    end)

    it("does not serve contextual entries as plain msgids", function()
      local path = helper.tmp_dir .. "/context.po"
      write_file(path, table.concat({
        'msgctxt "File"',
        'msgid "Copy"',
        'msgstr "Copiar"',
        "",
        'msgid "Cancel"',
        'msgstr "Cancelar"',
        "",
      }, "\n"))
      local catalog = i18n.parse_po(path)
      assert.is_nil(catalog["Copy"])
      assert.are.equal("Cancelar", catalog["Cancel"])
    end)
  end)

  describe("getLang", function()
    it("prefers the KOReader language setting", function()
      set_reader_language("fr_FR")
      assert.are.equal("fr_FR", i18n.getLang())
    end)

    it("strips an encoding suffix", function()
      set_reader_language("pt_BR.UTF-8")
      assert.are.equal("pt_BR", i18n.getLang())
    end)

    -- os.setenv is unavailable on some interpreters (e.g. plain LuaJIT);
    -- the POSIX fallback is only exercised where it can be set.
    if type(os.setenv) == "function" then
      local env_vars = { "LANGUAGE", "LC_ALL", "LC_MESSAGES", "LANG" }
      local function clear_locale_env()
        for _, v in ipairs(env_vars) do
          os.setenv(v, "")
        end
      end
      local function restore_locale_env(saved)
        for k, v in pairs(saved) do
          os.setenv(k, v or "")
        end
      end

      it("falls back to the LANG env var", function()
        local saved = {}
        for _, v in ipairs(env_vars) do
          saved[v] = os.getenv(v)
        end
        clear_locale_env()
        os.setenv("LANG", "de_DE.UTF-8")
        assert.are.equal("de_DE", i18n.getLang())
        restore_locale_env(saved)
      end)

      it("returns nil when nothing is set", function()
        local saved = {}
        for _, v in ipairs(env_vars) do
          saved[v] = os.getenv(v)
        end
        clear_locale_env()
        assert.is_nil(i18n.getLang())
        restore_locale_env(saved)
      end)
    end
  end)

  describe("install", function()
    it("stays in English for en locales", function()
      set_reader_language("en_US")
      local gettext = package.loaded["gettext"]
      assert.is_false(i18n.install())
      assert.are.equal(gettext, package.loaded["gettext"])
    end)

    it("stays in English when no catalog exists for the language", function()
      set_reader_language("fr_FR")
      local gettext = package.loaded["gettext"]
      assert.is_false(i18n.install())
      assert.are.equal(gettext, package.loaded["gettext"])
    end)

    it("serves translations over a table gettext and keeps its API", function()
      local real = fake_gettext({ ["A string only KOReader knows"] = "Uma string do KOReader" })
      package.loaded["gettext"] = real
      set_reader_language("pt_BR")
      assert.is_true(i18n.install())

      local _ = require("gettext")
      assert.are.equal("Cancelar", _("Cancel"))
      -- unknown msgids fall through to KOReader's own catalog
      assert.are.equal("Uma string do KOReader", _("A string only KOReader knows"))

      -- methods keep resolving through the wrapper
      assert.are.equal("function", type(_.pgettext))
      assert.are.equal("function", type(_.ngettext))
      assert.is_true(_.changeLang("de_DE"))
      assert.are.equal("de_DE", real.current_lang)

      -- writes land in the real module, not in the wrapper
      _["translation"]["injected"] = "ok"
      assert.are.equal("ok", real.translation.injected)
      assert.is_nil(rawget(package.loaded["gettext"], "translation"))

      -- the real catalog is left alone: only the wrapper translates
      assert.is_nil(real.translation["Cancel"])
    end)

    it("serves translations over a function gettext", function()
      local real = function(s)
        return "EN:" .. s
      end
      package.loaded["gettext"] = real
      set_reader_language("pt_BR")
      assert.is_true(i18n.install())

      local _ = require("gettext")
      assert.are.equal("AirPlaneMode: Alternar", _("AirPlaneMode Toggle"))
      assert.are.equal("EN:some untranslated string", _("some untranslated string"))
    end)

    it("is idempotent once installed", function()
      set_reader_language("pt_BR")
      assert.is_true(i18n.install())
      local wrapped = package.loaded["gettext"]
      assert.is_true(i18n.install())
      assert.are.equal(wrapped, package.loaded["gettext"])
    end)
  end)

  describe("source strings", function()
    it("keeps user-facing text behind _()", function()
      local cmd = "grep -rnE "
        .. "'(^|[^[:alnum:]_])(text|title|ok_text|cancel_text|help_text|input_hint|description)"
        .. '[[:space:]]*=[[:space:]]*"[^"]*[[:alpha:]]\' --include=*.lua '
        .. "display utils main.lua flight_config.lua flight_footer.lua flight_network.lua 2>/dev/null"
      local pipe = io.popen(cmd)
      local offenders = pipe:read("*a") or ""
      pipe:close()
      assert.are.equal("", offenders)
    end)
  end)
end)
