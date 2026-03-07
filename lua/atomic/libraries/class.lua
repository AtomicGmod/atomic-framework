atomic.class = atomic.class or {
  ---@type table<string, table<string, Atomic.Class[]>>
  _storage = {
    atomic = {
      [atomic.meta.version] = {}
    }
  },
  pseudo = {
    ---@type Atomic.Package.Metadata
    _metadata = {
      id = "atomic",
      title = "Atomic Framework",
      version = atomic.meta.version,
      documentation = "https://github.com/TeamMeadows/atomic-framework/wiki",
      icon = "https://github.com/TeamMeadows/atomic-framework/raw/production/assets/logo.png",
      files = {}
    }
  }
}

---@class Atomic.Class
---@field init fun(self: Atomic.Class, ...: any)?
---@field private _classname string?
local classMt = {}
classMt.__index = classMt

function classMt:__tostring()
    return "class " .. self:__classname()
end

---@return string
function classMt:__classname()
  return tostring(self._classname)
end

--- Creates new class
---@param name string
---@param parent Atomic.Class?
---@return Atomic.Class
function atomic.class.create(name, parent)
  -- new class inherited from classMt or parent (if provided)
  local class = setmetatable({ _classname = name }, { __index = parent or classMt })
  class.__index = class
  class.__tostring = function(self)
    return "instance of " .. tostring(self._classname)
  end

  return class
end

--- Finds class from a package
---
--- Usecases
--- ```lua
--- -- 1. Get Atomic std's package
--- local pkgMt = atomic.class.get("Package")
--- -- 2. Get class from a package
--- local rankMt = atomic.class.get("Rank", package)
--- -- 3. Get class from a package name and version
--- local rankMt = atomic.class.get("Rank", "org.atomicgmod.admin", "0.1.3")
--- ```
---@param name string
---@param packageOrId? Atomic.Package | string
---@param packageVersion? string
---@generic T
---@return T: Atomic.Class?
function atomic.class.get(name, packageOrId, packageVersion)
  local pkgName = type(packageOrId) == "table" and packageOrId._metadata.id
      or type(packageOrId) == "string" and packageOrId
      or not packageOrId and "atomic"

  local pkgVersion = type(packageOrId) == "table" and packageOrId._metadata.version
      or type(packageVersion) == "string" and packageVersion
      or pkgName == "atomic" and atomic.meta.version

  return ((atomic.class._storage[pkgName] or {})[istable(pkgVersion) and pkgVersion:getString() or pkgVersion] or {})[name]
end

--- Creates a new class instance
---
--- ```lua
--- local animal = atomic.class.new(animalClass)
--- ```
---
---@generic T
---@param class T: Atomic.Class
---@vararg any Arguments to be passed to the class constructor
---@return T: Atomic.Class
function atomic.class.new(class, ...)
  local instance = setmetatable({}, class)

  if (type(instance.init) == "function") then
    instance:init(...)
  end

  return instance
end

--- Adds accessor functions (getter/setter) to the class
---
--- ```lua
--- local animalClass = atomic.class.create("Animal")
--- atomic.class.accessors(animalClass, "age", "weight")
---
--- local animal = atomic.class.new(animalClass)
--- animal:setAge(16)
--- animal:setWeight(48.0)
---
--- print(animal:getAge(), animal:getWeight()) -- 16, 48
--- ```
---@param class Atomic.Class
---@vararg string
function atomic.class.accessors(class, ...)
  local vars = {...}

  for _, var in ipairs(vars) do
    local varCapped = var:sub(1,1):upper() .. var:sub(2)

    class["get" .. varCapped] = function(self)
      return self[var]
    end

    class["set" .. varCapped] = function(self, value)
      self[var] = value
    end
  end
end

---@param version Atomic.SemanticVersion | string
---@return string
local versionToString = function(version)
  ---@diagnostic disable-next-line
  return isstring(version) and version or version:getString()
end

--- Registers the class in the storage, allowing it to be get via ``atomic.class.get``
---@param class Atomic.Class
---@param package Atomic.Package
function atomic.class.register(class, package)
  local storage = atomic.class._storage
  local id, version = package._metadata.id, versionToString(package._metadata.version)

  if (type(storage[id]) ~= "table") then
    storage[id] = {}
  end

  if (type(storage[id][version]) ~= "table") then
    storage[id][version] = {}
  end

  storage[id][version][class._classname] = class

  atomic.class._storage = storage
end

---@param class Atomic.Class
---@param package Atomic.Package
function atomic.class.unregister(class, package)
  local storage = atomic.class._storage
  local id, version = package._metadata.id, versionToString(package._metadata.version)

  storage[id][version][class._classname] = nil

  atomic.class._storage = storage
end