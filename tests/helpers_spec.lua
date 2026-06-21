local helper = require("tests/spec_helper")
local tmp_dir = helper.tmp_dir

describe("utils/flight_helpers - helper functionality", function()
  -- Generate random strings for use in file/dir testing
  setup(function()
    helper.reset()
    package.loaded["utils/flight_helpers"] = nil
    H = require("utils/flight_helpers")
  end)

  function randomString(length)
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local result = {}
    for i = 1, length do
      local index = math.random(1, #chars)
      result[i] = chars:sub(index, index)
    end

    return table.concat(result)
  end

  local tst_dir = tmp_dir .. "/" .. randomString(5)

  it("return false for dir existing", function()
    -- Force loading the real helpers module (spec_helper stubs it), and provide a dummy lfs
    -- package.loaded["utils/flight_helpers"] = nil
    -- local H = require("utils/flight_helpers")
    assert.is_false(H.isDir(tst_dir))
    os.execute("mkdir -p " .. tst_dir)
  end)

  it("return true for dir existing", function()
    -- Force loading the real helpers module (spec_helper stubs it), and provide a dummy lfs
    -- package.loaded["utils/flight_helpers"] = nil
    -- local H = require("utils/flight_helpers")
    assert.is_true(H.isDir(tst_dir))
  end)

  it("return file exists 'true' and 'false' correctly", function()
    -- Force loading the real helpers module (spec_helper stubs it), and provide a dummy lfs
    -- package.loaded["utils/flight_helpers"] = nil
    -- local H = require("utils/flight_helpers")
    local tmp_file = tst_dir .. "/" .. randomString(10)
    local f, err = io.open(tmp_file, "w")
    assert(f)
    f:write("test")
    f:close()

    assert.is_true(H.isFile(tmp_file))
    os.remove(tmp_file)
    assert.is_false(H.isFile(tmp_file))
  end)

  it("verify tmp dir is removed", function()
    os.execute("rm -rf " .. tst_dir)
    assert.is_false(H.isDir(tst_dir))
  end)
end)
