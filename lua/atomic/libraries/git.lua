if (not util.IsBinaryModuleInstalled("atomic_git")) then
  atomic.log:warn("Binary module `atomic_git` isn't installed!")

  return
end

---@class Atomic.Git.Folder
---@field folder string

if (not atomic.git) then
  require("atomic_git")

  if (not atomic.git) then
  	return
  end
end


---@type table<string, fun(name: string): Atomic.Git.Folder>
local openers = {
  root = function()
    return atomic.git.open("garrysmod")
  end,

  gamemode = function(name)
    return atomic.git.open("garrysmod/gamemodes/" .. name)
  end,

  addon = function(name)
    return atomic.git.open("garrysmod/addons/" .. name)
  end
}

atomic.git._storage = atomic.git._storage or {
  root = {},
  gamemode = {},
  addon = {}
}

---@param kind "root" | "gamemode" | "addon"
---@param name string?
---@return Atomic.Git.Folder
function atomic.git.from(kind, name)
  name = name or ""

  local opener = openers[kind]

  if (not opener) then
    error("no opener with name `" .. tostring(kind) .. "`")
  end

  local cache = atomic.git._storage[kind][name]

  if (cache) then
    return cache
  end

  local folder, err = opener(name)

  if (not folder) then
    return atomic.git.logger:err("failed to open git repository: %s", tostring(err))
  end

  atomic.git._storage[kind][name] = folder

  return folder
end