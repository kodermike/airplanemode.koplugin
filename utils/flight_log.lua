---@class FlightLog

local logger = require("logger")

local FlightConfig = require("flight_config")
local settings = FlightConfig:init()
local FlightName = string.upper(settings.fullname)

local FlightLog = {}

-- log info messages
---@param function_name string
---@param ... any
function FlightLog.info(function_name, ...)
  function_name = function_name or "?"
  logger.info(FlightName .. " [" .. function_name .. "] " .. ...)
end

-- log warn messages
---@param function_name string
---@param ... any
function FlightLog.warn(function_name, ...)
  function_name = function_name or "?"
  logger.warn(FlightName .. " [" .. function_name .. "] " .. ...)
end

-- log debug messages
---@param function_name string
---@param ... any
function FlightLog.dbg(function_name, ...)
  function_name = function_name or "?"
  logger.dbg(FlightName .. " [" .. function_name .. "] " .. ...)
end

-- log error messages
---@param function_name string
---@param ... any
function FlightLog.err(function_name, ...)
  function_name = function_name or "?"
  logger.err(FlightName .. " [" .. function_name .. "] " .. ...)
end

return FlightLog
