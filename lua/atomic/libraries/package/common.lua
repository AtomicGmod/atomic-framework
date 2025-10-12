atomic.package = atomic.package or {
  ---@type table<string, table<string, Atomic.Package>>
  _storage = {},
  ---@type table<string, { [1]: string, [2]: string }> table<Path, Package>
  _pathMap = {}
}

local packageClass = atomic.class.get("Package")

---@cast packageClass Atomic.Package

---@private
---@param metadata Atomic.Package
---@return Atomic.Package
function atomic.package.new(metadata)
  local package = atomic.class.new(packageClass, metadata)
  ---@cast package Atomic.Package
  local id, version = package.id, package.version
  local storage = atomic.package._storage

  if (not storage[id]) then
    storage[id] = {}
  end

  storage[id][version] = package

  return package
end

---@param id string
---@param version string
function atomic.package.get(id, version)
  return (atomic.package._storage[id] or {})[version]
end

--- Searches for packages along the specified path
---
--- Supports searching within the ``garrysmod/lua/`` directory, as well as relative to ``garrysmod/gamemodes/``
---
--- ```lua
--- --- gamemodes/exaample/gamemode/shared.lua
--- --- When searching for packages in gamemode, it is important to specify the second argument = true.
--- local packages = atomic.package.find(GM.FolderName .. "/gamemode/packages", true)
---
--- td(packages) -- table.debug alias, see atomic/utils/table.lua
--- --- admin, base, character, logs
--- ```
---@param path string
---@param isInGamemode boolean?
---@return Atomic.Package[]?
function atomic.package.find(path, isInGamemode)
  local gameRelativePath = (isInGamemode and "gamemodes/" or "") .. path
  local pkg = gameRelativePath .. "/package.lua"
  local gameDir = isInGamemode and "GAME" or "LUA"

  if file.Exists(pkg, gameDir) then
    local package = include(path .. "/package.lua")

    if (type(package) ~= "table") then
      return
    end

    package._path = path

    return { package }
  end

  local _, packages = file.Find(gameRelativePath .. "/*", gameDir)
  local result = {}

  for _, package in ipairs(packages) do
    local pkgPath = gameRelativePath .. "/" .. package .. "/package.lua"
    if file.Exists(pkgPath, gameDir) then
      local packageData = include(path .. "/" .. package .. "/package.lua")
      packageData._path = path .. "/" .. package
      if type(packageData) == "table" then
        table.insert(result, packageData)
      end
    end
  end

  return #result > 0 and result or nil
end

--- Loading an package
---@param package Atomic.Package
function atomic.package.load(package)
  ---@diagnostic disable-next-line
  if type(package) ~= "table" or not package.id or not package.version or not package._path then
    atomic.log:warn("invalid package, skipping.")
    return
  end

  local packageInstance = atomic.package.new(package)

  atomic.package._pathMap[package._path] = { package.id, package.version }

  ---@cast packageInstance Atomic.Package
  if packageInstance.atomic and not util.IsVersionSuitable(packageInstance.atomic.version, atomic.meta.version) then
    atomic.log:err(
      "package `%s` requires atomic %s, but current is %s",
      packageInstance.id, tostring(packageInstance.atomic.version), tostring(atomic.meta.version)
    )
    return
  end

  if type(packageInstance.load) ~= "function" then
    atomic.log:err("package `%s`: load() is not a function", packageInstance.id)
    return
  end

  local ok, err = pcall(function()
    packageInstance:load()
  end)

  if not ok then
    atomic.log:err("failed to load package `%s`: %s", packageInstance.id, err)
  end
end

--- Loading packages, sorting them according to dependencies.
---@param packages Atomic.Package[]
function atomic.package.loadMany(packages)
  if type(packages) ~= "table" or #packages == 0 then
    atomic.log:warn("no packages to load, skipping.")
    return
  end

  local packagesCache = {}

  for _, pkg in ipairs(packages) do
    if not pkg.id or not pkg.version then
      atomic.log:err("invalid package detected (missing id/version), skipping.")
      continue
    end

    local key = pkg.id .. "@" .. pkg.version
    if packagesCache[key] then
      atomic.log:warn("duplicate package `%s@%s` ignored.", pkg.id, pkg.version)
    else
      packagesCache[key] = pkg
    end
  end

  local toRemove = {}

  for id, pkg in pairs(packagesCache) do
    local deps = pkg.dependencies
    if type(deps) == "table" then
      for depId, depVersion in pairs(deps) do
        if not packagesCache[depId .. "@" .. depVersion] then
          atomic.log:err("dependency `%s` version %s is required for `%s`, but was not found.", depId, depVersion, pkg.id)
          table.insert(toRemove, id)
          break
        end
      end
    end
  end

  for _, id in ipairs(toRemove) do
    packagesCache[id] = nil
  end

  if table.Count(packagesCache) == 0 then
    return
  end

  local indegree = {}
  for _, pkg in pairs(packagesCache) do
    indegree[pkg.id] = 0
  end

  for _, pkg in pairs(packagesCache) do
    if type(pkg.dependencies) == "table" then
      for depId, depVersion in pairs(pkg.dependencies) do
        local depKey = depId .. "@" .. depVersion
        if packagesCache[depKey] then
          indegree[pkg.id] = (indegree[pkg.id] or 0) + 1
        end
      end
    end
  end

  local queue = {}
  for id, degree in pairs(indegree) do
    if degree == 0 then table.insert(queue, id) end
  end

  local loadOrder = {}
  while #queue > 0 do
    local id = table.remove(queue, 1)
    for _, pkg in pairs(packagesCache) do
      if type(pkg.dependencies) == "table" then
        for depId, depVersion in pairs(pkg.dependencies) do
          local depKey = depId .. "@" .. depVersion
          if packagesCache[depKey] and depId == id then
            indegree[pkg.id] = indegree[pkg.id] - 1
            if indegree[pkg.id] == 0 then table.insert(queue, pkg.id) end
          end
        end
      end
    end
    table.insert(loadOrder, id)
  end

  if #loadOrder ~= table.Count(packagesCache) then
    atomic.log:err("dependency cycle detected! unable to resolve load order.")
    return
  end

  for _, id in ipairs(loadOrder) do
    for _, pkg in pairs(packagesCache) do
      if pkg.id == id then
        atomic.package.load(pkg)
      end
    end
  end
end

local cache = {}
local pathMap = atomic.package._pathMap

function atomic.package.current()
  -- 2 'cause 0 its lua engine, 1 its this function, and 2 is the caller
  local info = debug.getinfo(2, "S")

  if not info then
    return
  end

  local src = info.short_src or info.source
  if not src then
    return
  end

  local cached = cache[src]
  if cached ~= nil then
    return cached ~= false and cached or nil
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