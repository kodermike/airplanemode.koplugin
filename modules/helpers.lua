---@class H

local lfs = require("libs/libkoreader-lfs")

local H = {}

---Check if path is a file
---@param path string
---@return boolean
function H.isFile(path)
  if path and lfs.attributes(path, "mode") == "file" then
    return true
  else
    return false
  end
end

---Check if path is a directory
---@param path string
---@return boolean
function H.isDir(path)
  if path and lfs.attributes(path, "mode") == "directory" then
    return true
  else
    return false
  end
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
