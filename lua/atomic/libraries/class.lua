atomic.class = atomic.class or {
  ---@type table<string, table<string, Atomic.Class[]>>
  _storage = {
    atomic = {
      [atomic.meta.version] = {}
    }
  },

  ---@type Atomic.Package
  ---@diagnostic disable-next-line
  pseudo = { id = "atomic", version = atomic.meta.version };
}

---@class Atomic.Class
---@field init fun(self: Atomic.Class, ...: any)?
---@field private _name string?
local classMt = {}
classMt.__index = classMt

function classMt:__tostring()
  return "class " .. tostring(self._name)
end

--- Creates new class
---@param name string
---@param parent Atomic.Class?
---@return Atomic.Class
function atomic.class.create(name, parent)
  -- new class inherited from classMt or parent (if provided)
  local class = setmetatable({ _name = name }, { __index = parent or classMt })
  class.__index = class
  class.__tostring = function(self)
    ---@diagnostic disable-next-line
    return "instance of " .. tostring(self._name)
  end

  class.__classname = function(self)
    return name
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
  local pkgName = type(packageOrId) == "table" and packageOrId.id
      or type(packageOrId) == "string" and packageOrId
      or not packageOrId and "atomic"

  local pkgVersion = type(packageOrId) == "table" and packageOrId.version
      or type(packageVersion) == "string" and packageVersion
      or pkgName == "atomic" and atomic.meta.version

  return ((atomic.class._storage[pkgName] or {})[pkgVersion] or {})[name]
end

--- Creates a new class instance
---
--- ```lua
--- local animal = atomic.class.new(animalClass)
--- ```
---
---@generic T
---@param class Atomic.Class
---@param tab T? Content of the instance
---@vararg any
---@return T: Atomic.Class
function atomic.class.new(class, tab, ...)
  local instance = setmetatable(tab or {}, class)

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

--- Registers the class in the storage, allowing it to be get via ``atomic.class.get``
---@param class Atomic.Class
---@param package Atomic.Package
function atomic.class.register(class, package)
  local storage = atomic.class._storage
  local id, version = package.id, package.version

  if (type(storage[id]) ~= "table") then
    storage[id] = {}
  end

  if (type(storage[id][version]) ~= "table") then
    storage[id][version] = {}
  end

  ---@diagnostic disable-next-line
  storage[id][version][class._name] = class

  atomic.class._storage = storage
end

function atomic.class.unregister(class, package)
  local storage = atomic.class._storage
  local id, version = package.id, package.version

  ---@diagnostic disable-next-line
  storage[id][version][class._name] = nil

  atomic.class._storage = storage
end