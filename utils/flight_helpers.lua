---@class H

local lfs = require("libs/libkoreader-lfs")

local H = {}

---Check if path is a file
---@param path string
---@return boolean
function H.isFile(path)
  if type(path) ~= "string" then
    return false
  end
  if not H.isDir(path) then
    return os.rename(path, path) and true or false
    -- note that the short evaluation is to
    -- return false instead of a possible nil
  end
  return false
end

---Check if path is a directory
---@param path string
---@return boolean
function H.isDir(path)
  if type(path) ~= "string" then
    return false
  end
  -- Prefer using attributes to detect directories so tests can provide
  -- minimal lfs mocks that only implement attributes. This avoids
  -- relying on currentdir/chdir being present.
  local mode = nil
  if type(lfs.attributes) == "function" then
    -- ask for mode first (some mocks return a string when passed "mode")
    local ok, m = pcall(lfs.attributes, path, "mode")
    if ok then
      mode = m
    else
      -- fallback: try without "mode"
      local ok2, t = pcall(lfs.attributes, path)
      if ok2 and type(t) == "table" then
        mode = t.mode
      end
    end
  end
  if mode == "directory" then
    return true
  elseif mode == "file" then
    return false
  end
  return false
end

---Remove file if it exists
---This function signature intentionally matches existing usage: it may be called as `H.removeFile(path)`.
---@param path string
---@return boolean
function H.removeFile(path)
  if H.isFile(path) then
    os.remove(path)
    return true
  else
    return false
  end
end

---Convert string "true"/"false" to boolean
--- @ return boolean
-- function H.stringto(v)
--   if type(v) == "string" and v == "true" then
--     return true
--   end
--   if type(v) == "string" and v == "false" then
--     return false
--   end
--   if type(v) == "bolean" then
--     return v
--   end
--   return false
-- end

return H
