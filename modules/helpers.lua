local lfs = require("libs/libkoreader-lfs")

local H = {}

function H.isFile(path)
  if path and lfs.attributes(path, "mode") == "file" then
    return true
  else
    return false
  end
end

function H.isDir(path)
  if path and lfs.attributes(path, "mode") == "directory" then
    return true
  else
    return false
  end
end

function H.removeFile(self, path)
  if H.isFile(path) then
    os.remove(path)
    return true
  else
    return false
  end
end

function H.stringto(v)
  if type(v) == "string" and v == "true" then
    return true
  end
  if type(v) == "string" and v == "false" then
    return false
  end
  return nil
end

return H
