local helper = require("tests/spec_helper")
local tmp_dir = helper.tmp_dir

describe("modules/helpers - stringto", function()
  setup(function()
    helper.reset()
  end)

  it("parses string 'true' and 'false' correctly", function()
    -- Force loading the real helpers module (spec_helper stubs it), and provide a dummy lfs
    package.loaded["modules/helpers"] = nil
    package.loaded["libs/libkoreader-lfs"] = {}
    local H = require("modules/helpers")

    assert.is_true(H.stringto(true))
    assert.is_false(H.stringto(false))
    -- assert.is_false(H.stringto("something else"))
  end)
end)
