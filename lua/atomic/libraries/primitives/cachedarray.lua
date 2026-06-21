---@class Atomic.CachedArray<T>: Atomic.Class
---@field private primaryKey string
---@field private storage table[]
---@field private storageMap table<(string | integer), integer>
---@field private onChange? fun(self: self)
local CachedArray = atomic.class.create("CachedArray")
atomic.class.register(CachedArray, atomic.class.pseudo)

---@alias CachedArray Atomic.CachedArray

---@generic T
---@param primaryKey string
---@param content? T[]
function CachedArray:init(primaryKey, content)
  self.primaryKey = primaryKey
  self.storage = {}
  self.storageMap = {}

  if (content) then
    for _, table in ipairs(content or {}) do
      self:insert(table)
    end
  end
end

--- Allows to indexing instance as an regular array
function CachedArray:__index(index)
  if (type(index) == "number") then
    return self.storage[index]
  end

  return CachedArray[index] or rawget(self, index)
end

--- Allows to indexing instance as an regular array
function CachedArray:__newindex(index, value)
  if (type(index) == "number") then
    self.storage[index] = value
    return
  end

  rawset(self, index, value)
end

function CachedArray:getLength()
  return #self.storage
end

---@param callback fun(self: self)
function CachedArray:setOnChange(callback)
  self.onChange = callback
end

---@private
function CachedArray:notifyChange()
  local callback = self.onChange

  if (not callback) then
    return
  end

  callback(self)
end

---@generic T
---@generic V
---@return (fun(table: V[], i: integer?): integer, V), T, integer
function CachedArray:iter()
  return ipairs(self.storage)
end

--- `O(1)`
---@generic T
---@param data T
function CachedArray:insert(data)
  local primaryKeyValue = data[self.primaryKey]

  if (not primaryKeyValue) then
    error("no field `" .. tostring(self.primaryKey) .. "` in insertable table!")
  end

  local index = self.storageMap[primaryKeyValue]

  if (index) then
    self.storage[index] = data
    self:notifyChange()
    return
  end

  local newIndex = #self.storage + 1
  self.storage[newIndex] = data
  self.storageMap[primaryKeyValue] = newIndex

  self:notifyChange()

  return newIndex
end

---@generic T
---@param primaryKey string | integer
---@return T?
function CachedArray:get(primaryKey)
  local cacheIndex = self:getIndex(primaryKey)

  if (not cacheIndex) then
    return
  end

  return self.storage[cacheIndex]
end

---@param primaryKey string | integer
---@return integer?
function CachedArray:getIndex(primaryKey)
  return self.storageMap[primaryKey]
end

---@generic T
---@return T[]
function CachedArray:getStorage()
  return self.storage
end

--- `O(1)`
---@generic T
---@param primaryKey string | integer
---@return T
function CachedArray:remove(primaryKey)
  local index = self.storageMap[primaryKey]

  if (not index) then
    return nil
  end

  local lastIndex = #self.storage
  local removed = self.storage[index]

  if (index ~= lastIndex) then
    local lastItem = self.storage[lastIndex]
    self.storage[index] = lastItem
    self.storageMap[lastItem[self.primaryKey]] = index
  end

  self.storage[lastIndex] = nil
  self.storageMap[primaryKey] = nil

  self:notifyChange()

  return removed
end

---@param callback? fun(a: any, b: any): boolean
function CachedArray:sort(callback)
  table.sort(self.storage, callback)

  for index, item in ipairs(self.storage) do
    self.storageMap[item[self.primaryKey]] = index
  end

  self:notifyChange()
end