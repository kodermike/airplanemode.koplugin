local helper = require("tests/spec_helper")

describe("utils/flight_log - serialization and logger fallbacks", function()
  setup(function()
    helper.reset()
  end)

  it("serializes tables and calls logger methods without error", function()
    -- prepare a deterministic serpent implementation for this test
    local old_serpent = package.loaded["ffi/serpent"]
    package.loaded["ffi/serpent"] = {
      block = function(t, opts)
        return "SERPENT(" .. tostring(opts and opts.maxlevel or "") .. ")"
      end,
    }

    -- spy logger that records calls
    local calls = {}
    local spy_logger = {
      info = function(msg)
        table.insert(calls, { level = "info", msg = msg })
      end,
      dbg = function(msg)
        table.insert(calls, { level = "dbg", msg = msg })
      end,
      err = function(msg)
        table.insert(calls, { level = "err", msg = msg })
      end,
      -- intentionally omit warn here to test fallback separately
    }

    local old_logger = package.loaded["logger"]
    package.loaded["logger"] = spy_logger

    -- Ensure fresh load
    package.loaded["utils/flight_log"] = nil
    local FlightLog = require("utils/flight_log")

    -- call different log levels with table and scalar args
    FlightLog.info("testfn", "hello", { a = 1 })
    FlightLog.dbg("dbgfn", { 1, 2, 3 })
    FlightLog.err("errfn", "oops")

    -- basic assertions: calls were recorded and match exact serialized output
    assert.is_equal(3, #calls)
    -- FlightName is uppercased fullname from FlightConfig:init() -> "TESTINGMODE"
    assert.is_equal("TESTINGMODE [testfn] hello SERPENT(15)", calls[1].msg)
    assert.is_equal("TESTINGMODE [dbgfn] SERPENT(15)", calls[2].msg)
    assert.is_equal("TESTINGMODE [errfn] oops", calls[3].msg)

    -- restore
    package.loaded["ffi/serpent"] = old_serpent
    package.loaded["logger"] = old_logger
  end)

  it("falls back to logger.info when warn is missing and uses warn when present", function()
    -- case 1: warn missing -> should call info
    local calls = {}
    local spy_logger = {
      info = function(msg)
        table.insert(calls, { level = "info", msg = msg })
      end,
      dbg = function(msg)
        table.insert(calls, { level = "dbg", msg = msg })
      end,
      err = function(msg)
        table.insert(calls, { level = "err", msg = msg })
      end,
      -- warn intentionally missing
    }
    local old_logger = package.loaded["logger"]
    package.loaded["logger"] = spy_logger
    package.loaded["utils/flight_log"] = nil
    local FlightLog = require("utils/flight_log")

    FlightLog.warn("warnfn", "be careful")
    assert.is_equal(1, #calls)
    assert.is_equal("info", calls[1].level)
    assert.is_truthy(string.find(calls[1].msg, "%[warnfn%]") ~= nil)

    -- case 2: warn present -> should call warn
    calls = {}
    spy_logger.warn = function(msg)
      table.insert(calls, { level = "warn", msg = msg })
    end
    package.loaded["logger"] = spy_logger
    package.loaded["utils/flight_log"] = nil
    FlightLog = require("utils/flight_log")

    FlightLog.warn("warnfn2", "watch out")
    assert.is_equal(1, #calls)
    assert.is_equal("warn", calls[1].level)
    assert.is_truthy(string.find(calls[1].msg, "%[warnfn2%]") ~= nil)

    package.loaded["logger"] = old_logger
  end)
end)
