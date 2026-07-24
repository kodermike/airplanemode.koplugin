---@class FlightLog

local logger = require("logger")

local FlightConfig = require("flight_config")
local serpent = require("ffi/serpent")

local FlightLog = {}

local DEFAULT_DUMP_LVL = 15

local serpent_opts = {
  maxlevel = DEFAULT_DUMP_LVL,
  indent = "  ",
  nocode = true,
}

-- Robust table serializer that adapts to available serpent API or falls back
local function serialize_table(t)
  if type(serpent) == "table" then
    if type(serpent.block) == "function" then
      return serpent.block(t, serpent_opts)
    end
    if type(serpent.dump) == "function" then
      return serpent.dump(t)
    end
    if type(serpent.new) == "function" then
      -- some test mocks expose a simple 'new' that returns the table
      local ok, out = pcall(serpent.new, t)
      if ok and type(out) == "string" then
        return out
      elseif ok and type(out) == "table" then
        -- best-effort tostring of table-like mock
        return "<table>"
      end
    end
  end
  -- fallback: shallow representation
  local parts = {}
  for k, v in pairs(t) do
    table.insert(parts, tostring(k) .. "=" .. tostring(v))
    if #parts >= 10 then
      break
    end
  end
  return "{" .. table.concat(parts, ", ") .. (next(t) and "..." or "") .. "}"
end

local function make_entry(...)
  local parts = {}
  for i = 1, select("#", ...) do
    local v = select(i, ...)
    if type(v) == "table" then
      table.insert(parts, serialize_table(v))
    else
      table.insert(parts, tostring(v))
    end
  end
  return table.concat(parts, " ")
end

local function safe_call_logger(method, msg)
  -- if type(logger[method]) == "function" then
  --   logger[method](msg)
  -- else
  --   -- fallback to info if specific level not available
  --   if type(logger.info) == "function" then
  logger.info(msg)
  --   end
  -- end
end

-- log info messages
---@param function_name string
---@param ... any
function FlightLog.info(function_name, ...)
  local settings = FlightConfig:init()
  local FlightName = string.upper(settings.fullname)
  function_name = function_name or "?"
  local entry = make_entry(...)
  safe_call_logger("info", FlightName .. " [" .. function_name .. "] " .. entry)
end

-- log warn messages
---@param function_name string
---@param ... any
function FlightLog.warn(function_name, ...)
  local settings = FlightConfig:init()
  local FlightName = string.upper(settings.fullname)
  function_name = function_name or "?"
  local entry = make_entry(...)
  safe_call_logger("warn", FlightName .. " [" .. function_name .. "] " .. entry)
end

-- log debug messages
---@param function_name string
---@param ... any
function FlightLog.dbg(function_name, ...)
  local settings = FlightConfig:init()
  local FlightName = string.upper(settings.fullname)
  function_name = function_name or "?"
  local entry = make_entry(...)
  safe_call_logger("dbg", FlightName .. " [" .. function_name .. "] " .. entry)
end

-- log error messages
---@param function_name string
---@param ... any
function FlightLog.err(function_name, ...)
  local settings = FlightConfig:init()
  local FlightName = string.upper(settings.fullname)
  function_name = function_name or "?"
  local entry = make_entry(...)
  safe_call_logger("err", FlightName .. " [" .. function_name .. "] " .. entry)
end

return FlightLog
