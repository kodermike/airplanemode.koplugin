-- Busted / busted assertion stubs for LSP
-- This file provides noop definitions for busted globals so the language server
-- doesn't emit undefined-field / undefined-global diagnostics while editing tests.
---@diagnostic disable

-- Test declaration helpers
function describe(...) end
function it(...) end
function setup(...) end
function teardown(...) end
function before_each(...) end
function after_each(...) end
function pending(...) end
function spy(...)
  return nil
end

-- Minimal 'assert' table with commonly used helpers in specs
---@class BustedAssert
---@field is_table fun(v: any)
---@field is_true fun(v: any)
---@field is_false fun(v: any)
---@field is_not_nil fun(v: any)
---@field is_string fun(v: any)
---@field is_not_equal fun(a: any, b: any)
---@field is_equal fun(a: any, b: any)
---@field is_truthy fun(v: any)
---@field are BustedAssertAre
---
---@class BustedAssertAre
---@field equal fun(a: any, b: any)
---@field same fun(a: any, b: any)

---@class assert
---@field is_table fun(v: any)
---@field is_true fun(v: any)
---@field is_false fun(v: any)
---@field is_not_nil fun(v: any)
---@field is_string fun(v: any)
---@field is_not_equal fun(a: any, b: any)
---@field is_equal fun(a: any, b: any)
---@field is_truthy fun(v: any)
---@field are BustedAssertAre

---@type assert
assert = assert or {}
assert.is_table = function(v) end
assert.is_true = function(v) end
assert.is_false = function(v) end
assert.is_not_nil = function(v) end
assert.is_nil = function(v) end
assert.is_string = function(v) end
assert.is_not_equal = function(a, b) end
-- Common aliases used in specs
assert.is_equal = function(a, b) end
assert.is_truthy = function(v) end

assert.are = assert.are or {}
assert.are.equal = function(a, b) end
assert.are.same = function(a, b) end

-- 'assert' may also be used as a function; keep original behavior if present
local _orig_assert = _G._orig_assert
if not _orig_assert and type(assert) == "function" then
  _orig_assert = assert
  _G._orig_assert = _orig_assert
end

-- Provide 'describe' as a safe global to avoid diagnostics
_G.describe = _G.describe or function() end
_G.it = _G.it or function() end
_G.setup = _G.setup or function() end
_G.teardown = _G.teardown or function() end
_G.before_each = _G.before_each or function() end
_G.after_each = _G.after_each or function() end
_G.pending = _G.pending or function() end
_G.spy = _G.spy or function() end
_G.KEEP_TEST_TMP = _G.KEEP_TEST_TMP or function() end

-- Ensure we export something so requiring this file doesn't error
return {}
