atomic.package = atomic.package or {
  ---@type table<string, table<string, Atomic.Package>>
  _storage = {},
  ---@type table<string, { [1]: string, [2]: string }> table<Path, Package>
  _pathMap = {},
}

---@include
atomic.loader.shared("config.lua")
atomic.loader.shared("registry.lua")
atomic.loader.shared("class.lua")

---@type Atomic.Package
local packageClass = atomic.class.get("Package")

---@private
---@param metadata Atomic.Package.Metadata
---@return Atomic.Package
function atomic.package.new(metadata)
  local package = atomic.class.new(packageClass, metadata)
  ---@cast package Atomic.Package
  local id, version = metadata.id, metadata.version
  local storage = atomic.package._storage

  if (not storage[id]) then
    storage[id] = {}
  end

  storage[id][version] = package

  return package
end

atomic.class.pseudo = atomic.package.new(atomic.class.pseudo._metadata)

---@param id string
---@param version string
function atomic.package.get(id, version)
  local packages = atomic.package._storage[id]

  if (not packages) then
    return
  end

  for ver, package in pairs(packages) do
    if (util.IsVersionSuitable(ver, version)) then
      return package
    end
  end
end

--- Reads metadata from `package.lua`, and returns it, making `package.lua` visible on client
---
--- ```lua
--- local metadata = atomic.package.readPackageMetadata("atomic/packages/zen/package.lua")
--- table.debug(metadata)
--- ```
---
---@param path string
---@return Atomic.Package.Metadata?
function atomic.package.readPackageMetadata(path)
  if (not file.Exists(path, "LUA")) then
    return nil
  end

  local metadata = SERVER and atomic.loader.server(path) or atomic.loader.client(path)
  ---@cast metadata Atomic.Package.Metadata

  if (type(metadata) ~= "table") then
    return nil
  end

  metadata._path = path:GetPathFromFilename():sub(1, -2) -- removing last "/" from string

  if (SERVER) then
    local files = metadata.files

    -- make server-only packages hidden from clients
    if (type(files) == "table" and type(files.client) == "table" or type(files.shared) == "table") then
      atomic.loader.csluafile(path)
    end
  end

  return metadata
end

--- Searches for packages along the specified path
---
--- ```lua
--- local packages = atomic.package.find("atomic/packages")
--- local packages = atomic.package.find(GM.FolderName .. "/gamemode/packages")
---
--- table.debug(packages)
--- ```
---@param path string
---@return Atomic.Package.Metadata[]?
function atomic.package.find(path)
  local packageMeta = atomic.package.readPackageMetadata(path .. "/package.lua")

  if (packageMeta) then
    return { packageMeta }
  end

  local result = {}
  local _, packages = file.Find(path .. "/*", "LUA")

  for _, dirName in ipairs(packages) do
    local packageMeta = atomic.package.readPackageMetadata(path .. "/" .. dirName .. "/package.lua")

    if (packageMeta) then
      table.insert(result, packageMeta)
    end
  end

  return #result > 0 and result or nil
end

--- Loades an package
---@param metadata Atomic.Package.Metadata
function atomic.package.load(metadata)
  if type(metadata) ~= "table" or not metadata.id or not metadata.version or not metadata._path then
    atomic.log:warn("invalid package to load")
    return
  end

  if (atomic.package.get(metadata.id, metadata.version)) then
    return atomic.log:trace("package %s@%s is already loaded", metadata.id, metadata.version)
  end

  local package = atomic.package.new(metadata)
  local id, version = metadata.id, metadata.version

  atomic.package._pathMap[metadata._path] = { id, version }

  -- dependencies check
  local deps = metadata.dependencies
  if (deps) then
    for depId, depVersion in pairs(deps) do
      local dep = atomic.package.get(depId, depVersion)

      if (not dep) then
        return package.logger:err("dependency %s@%s not satisfied for package %s@%s", depId, depVersion, id, version)
      end
    end
  end

  local isOk, err = pcall(function()
    package:load()
  end)

  if (not isOk) then
    atomic.log:err("failed to load package `%s@%s`: %s", id, version, err)
  end
end

---@param packages Atomic.Package.Metadata[]
function atomic.package.loadMany(packages)
  if type(packages) ~= "table" or #packages == 0 then
    atomic.log:warn("no packages to load")
    return
  end

  local loadingSort = {}
  local visited = {}

  local getKey = function(package)
    return package.id .. "@" .. package.version
  end

  local findDependency = function(depId, depVersion)
    for _, package in ipairs(packages) do
      if package.id == depId and util.IsVersionSuitable(depVersion, package.version) then
        return package
      end
    end

    local cached = atomic.package.get(depId, depVersion)

    if (cached) then
      packages[#packages+1] = cached._metadata
      return cached._metadata
    end
  end

  local visit
  visit = function(package)
    local key = getKey(package)

    if visited[key] == "temp" then
      atomic.log:err("dependency cycle detected on %s@%s", package.id, package.version)
      return
    end

    if visited[key] then
      return
    end

    visited[key] = "temp"

    local deps = package.dependencies or {}

    for depId, depVersion in pairs(deps) do
      if (depId == "atomic") then
        continue
      end

      local depPkg = findDependency(depId, depVersion)

      if not depPkg then
        atomic.log:err("dependency `%s@%s` is required for `%s@%s`, but was not found", depId, depVersion, package.id, package.version)
      else
        visit(depPkg)
      end
    end

    visited[key] = true
    loadingSort[#loadingSort+1] = package
  end

  for _, package in ipairs(packages) do
    visit(package)
  end

  local keys = {}
  for _, package in ipairs(loadingSort) do
    keys[#keys+1] = getKey(package)
  end

  atomic.log:trace("package loading order: %s", table.concat(keys, ", "))

  for _, package in ipairs(loadingSort) do
    atomic.package.load(package)
  end
end

local cache = {}
local pathMap = atomic.package._pathMap

function atomic.package.current()
  -- 2 'cause 0 its lua engine, 1 its this function, and 2 is the caller
  local info = debug.getinfo(2, "S")
  if (not info) then
    return
  end

  local src = info.short_src or info.source
  if (not src) then
    return
  end

  local cached = cache[src]
  if (cached) then
    return cached
  end

  local clean = src:gsub("^@", "")

  clean = clean:gsub("^addons/[^/]+/lua/", "")
    :gsub("^gamemodes/([^/]+)/", "%1/")

  local bestVal, bestLen = nil, 0

  for k, v in pairs(pathMap) do
    local s = clean:find(k, 1, true)
    if s then
      if s == 1 and #k > bestLen then
        bestVal, bestLen = v, #k
      end
    end
  end

  if (not bestVal) then
    return
  end

  local package = atomic.package.get(bestVal[1], bestVal[2])

  cache[src] = package

  return package
end