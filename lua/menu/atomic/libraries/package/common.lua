atomic.package = atomic.package or {
  ---@type table<string, table<string, Atomic.Package>>
  _storage = {},
  ---@type table<string, { [1]: string, [2]: string }> table<Path, Package>
  _pathMap = {},
}

---@type Atomic.Package[]
atomic.package._list = {}

---@include
atomic.loader.include("config.lua")
atomic.loader.include("registry.lua")
atomic.loader.include("class.lua")

local packageList = atomic.package._list

---@type Atomic.Package
local Package = atomic.class.get("Package")

---@private
---@param metadata Atomic.Package.InternalMetadata
---@return Atomic.Package
function atomic.package.new(metadata)
  local package = atomic.class.new(Package, metadata)
  local id, version = metadata.id, metadata.version:getString()
  local storage = atomic.package._storage

  if (not storage[id]) then
    storage[id] = {}
  end

  packageList[#packageList+1] = package
  storage[id][version] = package

  return package
end

--- Alias for `ipairs(atomic.package._list)`
function atomic.package.list()
  return ipairs(packageList)
end

--- should be right after `atomic.package.new` definition!!!
---@include
atomic.loader.include("atomic.lua")

local isSuitable = atomic.semver.isSuitable

---@param id string
---@param version string
function atomic.package.get(id, version)
  local packages = atomic.package._storage[id]

  if (not packages) then
    return
  end

  for _, package in pairs(packages) do
    if (isSuitable(package:getVersion(), version)) then
      return package
    end
  end
end

---@type Atomic.SemanticVersion
local SemanticVersion = atomic.class.get("SemanticVersion")

--- Reads metadata from `package.lua`, and returns it, making `package.lua` visible on client
---
--- ```lua
--- local metadata = atomic.package.readPackageMetadata("atomic/packages/zen/package.lua")
--- table.debug(metadata)
--- ```
---
---@param path string
---@return Atomic.Package.InternalMetadata?
function atomic.package.readPackageMetadata(path)
  if (not file.Exists(path, "GAME")) then
    return nil
  end

  local metadata = atomic.loader.include(path)
  ---@cast metadata Atomic.Package.InternalMetadata

  if (type(metadata) ~= "table") then
    return nil
  end

  local path = path:GetPathFromFilename():sub(1, -2) -- removing last "/" from string

  metadata._path = path:sub(5)
  metadata.version = atomic.class.new(SemanticVersion, metadata.version)

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
---@return Atomic.Package.InternalMetadata[]?
function atomic.package.find(path)
  local packageMeta = atomic.package.readPackageMetadata(path .. "/package.lua")

  if (packageMeta) then
    return { packageMeta }
  end

  local result = {}
  local _, packages = file.Find(path .. "/*", "GAME")

  for _, dirName in ipairs(packages) do
    local packageMeta = atomic.package.readPackageMetadata(path .. "/" .. dirName .. "/package.lua")

    if (packageMeta) then
      table.insert(result, packageMeta)
    end
  end

  return #result > 0 and result or nil
end

--- Loades an package
---@param metadata Atomic.Package.InternalMetadata
function atomic.package.load(metadata)
  local id, version, path = metadata.id, metadata.version:getString(), metadata._path

  if (type(metadata) ~= "table" or not id or not version or not path) then
    return atomic.log:warn("package %s@%s have is invalid!", id or path or "N/A (see TRACE logs)", version or "N/A")
  end

  if ((atomic.package._storage[id] or {})[version]) then
    return atomic.log:trace("package %s@%s is already loaded", id, version)
  end

  local isOk, package = pcall(atomic.package.new, metadata)

  if (not isOk) then
    return atomic.log:err("package %s@%s failed to load: %s", id, version, package)
  end

  atomic.package._pathMap[path] = { id, version }

  -- dependencies check
  local deps = metadata.dependencies
  if (deps) then
    for depId, depVersionData in pairs(deps.menu or {}) do
      local isDependencyOptional = istable(depVersionData) and depVersionData.optional
      local depVersion = istable(depVersionData) and depVersionData.version or depVersionData
      ---@cast depVersion string
      local dep = atomic.package.get(depId, depVersion)

      if (not dep and not isDependencyOptional) then
        return package.logger:err("dependency %s@%s not satisfied for package %s@%s", depId, depVersion, id, version)
      end
    end
  end

  local isOk, err = pcall(package.load, package)

  if (not isOk) then
    atomic.log:err("failed to load package `%s@%s`: %s", id, version, err)
  end
end

---@param packages Atomic.Package.InternalMetadata[]?
function atomic.package.loadMany(packages)
  if (type(packages) ~= "table" or #packages == 0) then
    return atomic.log:warn("no packages to load")
  end

  local loadingSort = {}
  local visited = {}

  ---@param package Atomic.Package.InternalMetadata
  local getKey = function(package)
    return package.id .. "@" .. package.version:getString()
  end

  local findDependency = function(depId, depVersion)
    for _, package in ipairs(packages) do
      if (package.id == depId and isSuitable(package.version, depVersion)) then
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
  ---@param package Atomic.Package.InternalMetadata
  visit = function(package)
    local key = getKey(package)

    local id, version = package.id, package.version:getString()
    if (visited[key] == "temp") then
      return atomic.log:err("dependency cycle detected on %s@%s", id, version)
    end

    if (visited[key]) then
      return
    end

    visited[key] = "temp"

    local deps = package.dependencies or {}

    for depId, depVersionData in pairs(deps.menu or {}) do
      local isDependencyOptional = istable(depVersionData) and depVersionData.optional
      local depVersion = istable(depVersionData) and depVersionData.version or depVersionData

      if (depId == "atomic") then
        continue
      end

      local depPkg = findDependency(depId, depVersion)

      if (not depPkg) then
        if (not isDependencyOptional) then
          atomic.log:err("dependency `%s@%s` is required for `%s@%s`, but was not found", depId, depVersion, id, version)
        end

        continue
      end

      visit(depPkg)
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

-- todo push cache[path] in atomic.package.new
local cache = {}
local pathMap = atomic.package._pathMap

--- 0   Lua
--- 1   Current function
--- 2   Function caller
--- (overhead)
local baseStackIndex = 2

---@param overhead? integer
function atomic.package.current(overhead)
  local info = debug.getinfo(2 + (overhead or 0), "S")
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
  clean = clean:gsub("^.-lua/", "")

  local bestVal, bestLen = nil, 0

  for k, v in pairs(pathMap) do
    local s = clean:find(k, 1, true)

    if (s) then
      if (s) == 1 and #k > bestLen then
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