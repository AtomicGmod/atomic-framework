---@alias Atomic.Package.Registry.Callback fun(_: Atomic.Package, _: any, _: any)

---@class Atomic.Package.Registry: Atomic.Class
---@field private _storage table<string, { add: Atomic.Package.Registry.Callback, remove: Atomic.Package.Registry.Callback }>
local PackageRegistry = atomic.class.create("PackageRegistry")
atomic.class.register(PackageRegistry, atomic.class.pseudo)

function PackageRegistry:init()
  self._storage = {}
end

---@param category string
---@param addFn Atomic.Package.Registry.Callback
---@param removeFn Atomic.Package.Registry.Callback
function PackageRegistry:define(category, addFn, removeFn)
  self._storage[category] = { add = addFn, remove = removeFn }
end

---@param category string
---@param package Atomic.Package
---@param key string
---@param value string
function PackageRegistry:add(category, package, key, value)
  local cat = self._storage[category]

  if (not cat) then
    return
  end

  cat.add(package, key, value)
end

---@param category string
---@param package Atomic.Package
---@param key string
---@param value string
function PackageRegistry:remove(category, package, key, value)
  local cat = self._storage[category]

  if (not cat) then
    return
  end

  cat.remove(package, key, value)
end