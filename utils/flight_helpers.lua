---@class H

local lfs = require("libs/libkoreader-lfs")

local H = {}

---first_non_empty - return the first non empty value in an array
---@param ... any
---@return string?
function H.first_non_empty(...)
  for i = 1, select("#", ...) do
    local v = select(i, ...)
    if type(v) == "string" and v ~= "" then
      return v
    end
  end
  return nil
end

---normalize_fw_value
---@param v any
---@return string?
function H.normalize_value(v)
  if type(v) == "number" then
    v = tostring(v)
  end
  if type(v) ~= "string" then
    return nil
  end
  v = v:match("^%s*(.-)%s*$")
  if v == "" then
    return nil
  end
  return v
end

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

return H
