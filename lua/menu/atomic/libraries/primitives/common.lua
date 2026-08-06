atomic.primitives = atomic.primitives or {}

---@include
atomic.loader.include("cachedarray.lua")

---@type Atomic.CachedArray
local CachedArray = atomic.class.get("CachedArray")

---@param primaryKey string
---@param content? table[]
function atomic.primitives.newCachedArray(primaryKey, content)
  return new(CachedArray, primaryKey, content)
end