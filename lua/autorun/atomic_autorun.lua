atomic = {
  meta = {
    author = "smokingplaya",
    version = "0.1.2"
  }
}

local function includeSh(path)
  if (SERVER) then
    AddCSLuaFile(path)
  end

  include(path)
end

---@include
includeSh("atomic/utils/table.lua")
includeSh("atomic/utils/coroutine.lua")
includeSh("atomic/utils/semver.lua")
includeSh("atomic/libraries/logger.lua")
includeSh("atomic/libraries/loader.lua")
atomic.loader.shared("atomic/libraries/package.lua")
atomic.loader.client("atomic/libraries/web.lua")

atomic.log = atomic.logger.new("atomic")

-- step 1: Scaning for packages
local atomicVersion = atomic.meta.version
---@type table<string, Atomic.STD.Package>
local packagesCache = {}

local _, packages = file.Find("atomic/packages/*", "LUA")

for _, package in ipairs(packages) do
  local path = "atomic/packages/" .. package .. "/package.lua"

  if (not file.Exists(path, "LUA")) then
    atomic.log:warn("package `%s` doesn't contains package.lua!", package)
    continue
  end

  ---@type Atomic.STD.Package
  local payload = include(path)

  if (not istable(payload)) then
    atomic.log:err("package `%s` contains wrong payload! (%s instead table)", package, type(payload))
    continue
  end

  if (payload.atomic) then
    local version = payload.atomic.version

    if (version) then
      if (not util.IsVersionSuitable(atomic.meta.version, version)) then
        atomic.log:err("package `%s` requires atomic's version `%s`, current is `%s`", package, version, atomicVersion)
        continue
      end
    end
  end

  -- all package.lua's are shared files
  if (SERVER) then
    AddCSLuaFile(path)
  end

  packagesCache[payload.id .. "@" .. payload.version] = atomic.package.new(payload, package)
end

-- step 2: Dependencies/required atomic version check

local toRemove = {}

for id, package in pairs(packagesCache) do
  local deps = package.dependencies

  if not istable(deps) or not deps then
    continue
  end

  for depId, depVersion in pairs(deps) do
    local dep = packagesCache[depId .. "@" .. depVersion]

    if not dep then
      atomic.log:err("dependency `%s` version %s is required for `%s`, but was not found.", depId, depVersion, package.id)
      toRemove[#toRemove+1] = id
      break
    end
  end
end

for _, id in ipairs(toRemove) do
  packagesCache[id] = nil
end

-- step 3: Loading packages

local loadOrder = {}
local indegree = {}

-- считаем входящие зависимости
for _, package in pairs(packagesCache) do
  indegree[package.id] = 0
end

for _, package in pairs(packagesCache) do
  if istable(package.dependencies) then
    for depId, depVersion in pairs(package.dependencies) do
      local depKey = depId .. "@" .. depVersion
      local dep = packagesCache[depKey]

      if dep then
        indegree[package.id] = (indegree[package.id] or 0) + 1
      end
    end
  end
end

-- очередь с нулями (готовые к загрузке)
local queue = {}
for id, degree in pairs(indegree) do
  if degree == 0 then
    table.insert(queue, id)
  end
end

-- топологическая сортировка
while #queue > 0 do
  local id = table.remove(queue, 1)

  for _, package in pairs(packagesCache) do
    if istable(package.dependencies) then
      for depId, depVersion in pairs(package.dependencies) do
        local depKey = depId .. "@" .. depVersion
        local dep = packagesCache[depKey]

        if dep and dep.id == id then
          indegree[package.id] = indegree[package.id] - 1
          if indegree[package.id] == 0 then
            table.insert(queue, package.id)
          end
        end
      end
    end
  end

  table.insert(loadOrder, id)
end

-- проверка на циклы
if #loadOrder ~= table.Count(packagesCache) then
  atomic.log:err("dependency cycle detected! Unable to resolve load order.")
else
  -- загружаем в порядке
  for _, id in ipairs(loadOrder) do
    for _, package in pairs(packagesCache) do
      if package.id == id then
        local ok, err = pcall(package.load, package)

        if not ok then
          atomic.log:err("failed to load package `%s`: %s", id, err)
        else
          atomic.log:debug("package `%s` loaded successfully!", id)
        end
      end
    end
  end
end