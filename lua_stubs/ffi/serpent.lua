-- Serpent stubs for LSP
-- Provide a minimal interface for the serializer used by flight_log so the language server
-- doesn't emit undefined-field diagnostics.

---@class Serpent
---@field block fun(t: table, opts: table): string
---@field dump fun(t: table): string
---@field new fun(t: table): string

local M = {}

function M.block(t, opts)
  return "<serpent>"
end
function M.dump(t)
  return "<serpent>"
end
function M.new(t)
  return "<serpent>"
end

return M
