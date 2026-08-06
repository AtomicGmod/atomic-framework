---@alias Atomic.Package.Registry.Callback fun(_: Atomic.Package, _: any, _: any)

---@class Atomic.Package.Registry: Atomic.Class
---@field private _package Atomic.Package
---@field private _storage table<string, { add: Atomic.Package.Registry.Callback, remove: Atomic.Package.Registry.Callback, data: table }>
local PackageRegistry = atomic.class.create("PackageRegistry")
atomic.class.register(PackageRegistry, atomic.class.pseudo)

---@param package Atomic.Package
function PackageRegistry:init(package)
  self._package = package
  self._storage = {}
end

function PackageRegistry:__tostring()
  return "PackageRegistry of " .. tostring(self._package:__tostring())
end

---@param category string
---@param addFn Atomic.Package.Registry.Callback
---@param removeFn Atomic.Package.Registry.Callback
function PackageRegistry:addCategory(category, addFn, removeFn)
  self._storage[category] = { add = addFn, remove = removeFn, data = {} }
end

---@param category string
---@param key string | integer
---@param value any
function PackageRegistry:set(category, key, value)
  local category = self._storage[category]

  if (not category) then
    return
  end

  local currentValue = category.data[key]
  category.data[key] = value

  local package = self._package

  if (package:isEnabled()) then
    local fn = value == nil and category.remove or category.add
    fn(package, key, (value == nil and currentValue or value))
  end
end

function PackageRegistry:enable()
  local package = self._package

  for _, category in pairs(self._storage) do
    for key, value in pairs(category.data) do
      category.add(package, key, value)
    end
  end
end

---@generic T
---@param category string
---@param index string | integer
---@param default T?
---@return T
function PackageRegistry:lookup(category, index, default)
  local category = self._storage[category]

  return category and category.data[index] or default
end

--- Works only on arrays!
---@return integer
function PackageRegistry:length(category)
  local category = self._storage[category]

  return category and #category.data or 0
end

function PackageRegistry:disable()
  local package = self._package

  for _, category in pairs(self._storage) do
    for key, value in pairs(category.data) do
      category.remove(package, key, value)
    end

    -- there is no need to clean `category.data`, because after disable user could enable package
    -- and the logic of it would be removed
  end
end