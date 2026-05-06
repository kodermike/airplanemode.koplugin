local lfs = require("libs/libkoreader-lfs")

local H = {}

function H.isFile(path)
    return lfs.attributes(path, "mode") == "file"
end

function H.isDir(path)
    return lfs.attributes(path, "mode") == "directory"
end

function H.removeFile(self, path)
    if H.isFile(path) then
        os.remove(path)
        return true
    else
        return false
    end
end

return H
