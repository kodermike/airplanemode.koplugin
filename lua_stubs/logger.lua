-- Logger stubs for LSP
-- Provides the common logger functions used by the plugin so the language server
-- doesn't emit diagnostics for undefined fields.

---@class Logger
---@field info fun(...: any)
---@field warn fun(...: any)
---@field dbg fun(...: any)
---@field err fun(...: any)

local M = {}

function M.info(...) end
function M.warn(...) end
function M.dbg(...) end
function M.err(...) end

return M
