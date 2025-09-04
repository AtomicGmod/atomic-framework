atomic.package = {
  ---@private
  storage = {
    ---@type table<string, Atomic.STD.Package[]>
    packages = {},
    ---@type { id: string, version: string }[]
    map = {}
  }
}

---@class Atomic.STD.Package
---@field dir string
---@field id string Package ID form of %s.author.packagename
---@field nicename string Formatted name of the package (or language key)
---@field description string? Description of the package
---@field version string Version of a package form of %d.%d.%d
---@field documentation string? URL to documentation of the package
---@field configuration table<string, any>
---@field files table<"client" | "server" | "shared", string[]>
---@field dependencies table<string, string>
---@field isloaded boolean
local package = {}
package.__index = package

RegisterMetaTable("Atomic.STD.Package", package)

---@param payload Atomic.STD.Package
---@param dir string Package location (dir) relative to lua/atomic/packages/
---@return Atomic.STD.Package
function atomic.package.new(payload, dir)
  local id = payload.id
  local cache = atomic.package.storage[id]

  if (cache) then
    return cache
  end

  payload.dir = dir
  payload.isloaded = false
  local pkg = setmetatable(payload, package)

  if (not istable(atomic.package.storage.packages[id])) then
    atomic.package.storage.packages[id] = {}
  end

  atomic.package.storage.packages[id][#atomic.package.storage.packages[id]+1] = pkg
  atomic.package.storage.map[dir] = { id = id, version = payload.version }

  return pkg
end

---@param name string Name of the package of dir
---@param version? string
---@return Atomic.STD.Package?
function atomic.package.get(name, version)
  local pkgs = atomic.package.storage.packages[name]

  if (not pkgs) then
    return
  end

  local result

  if (version) then
    for _, pkg in ipairs(pkgs) do
      if (util.IsVersionSuitable(pkg.version, version)) then -- exactly
        result = pkg
      end
    end
  else
    result = pkgs[1]
  end

  return result
end

--- Returns current package, with context saving
---@return Atomic.STD.Package | nil Package Could return nil if the package wasn't registered
function atomic.package.current()
  -- 2 'cause 0 its lua engine, 1 its this function, and 2 is the caller
  local data = debug.getinfo(2)
  local pkgname = data.short_src:match("lua/atomic/packages/([^/]+)/")

  return atomic.package.get(pkgname)
end

---@return boolean
function package:isLoaded()
  return self.isloaded
end

function package:load()
  -- todo
end

function package:getName()
  return self.nicename
end

function package:getId()
  return self.id
end