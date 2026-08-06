--- *important note
---
--- the package configuration is stored locally
--- in SQLite because it works synchronously,
--- and the configuration can be loaded
--- when the package is initialized,
--- which cannot be realized properly
--- when working asynchronously with other databases.
---
--- update: in fact, it actually can be realized.
--- the idea is to move package initialization into a coroutine, but
--- before initializing packages, we can load all configurations
--- from a remote database, and then, once we get configurations
--- from the remote database, we can initialize all packages.
---
--- another update: how the fuck are you gonna block the Lua thread
--- while waiting for a response from the database? with an infinite loop?
atomic.package.config = atomic.package.config or {}

---@alias ConfigurationContentType "string" | "integer" | "float" | "boolean" | "json" | "color" | "vector" | "angle"

---@class Atomic.Package.Configuration.Raw
---@field default any
---@field type ConfigurationContentType
---@field description? string
---@field sync? boolean @Default = true

---@alias Atomic.Package.Configuration.InternalEntry { type: ConfigurationContentType, value: any, sync: boolean }

---@class Atomic.Package.Configuration: Atomic.Class
---@field private _storage table<string, Atomic.Package.Configuration.InternalEntry>
---@field private _memorized { length: integer, configuration: table<string, Atomic.Package.Configuration.Raw> }
---@field private _package Atomic.Package
---@field private _subscribedCallbacks table<string, fun(value: any): false?>
local Configuration = atomic.class.create("Configuration")
atomic.class.register(Configuration, atomic.class.pseudo)

if (not sql.TableExists("atomic_config")) then
  sql.Query([[CREATE TABLE IF NOT EXISTS atomic_config(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    package_id TEXT NOT NULL,
    name TEXT NOT NULL UNIQUE,
    value TEXT NOT NULL
  );]])
end

local types = {
  string = {
    is = isstring,
    serialize = tostring,
    deserialize = tostring
  },
  integer = {
    is = isnumber,
    serialize = tonumber,
    deserialize = function(v) return math.floor(tonumber(v) or 0) end
  },
  float = {
    is = isnumber,
    serialize = tonumber,
    deserialize = tonumber
  },
  boolean = {
    is = isbool,
    serialize = tostring,
    deserialize = tobool
  },
  json = {
    is = istable,
    serialize = util.TableToJSON,
    deserialize = util.JSONToTable
  },
  color = {
    is = IsColor,
    serialize = string.FromColor,
    deserialize = string.ToColor
  },
  vector = {
    is = isvector,
    serialize = tostring,
    deserialize = Vector
  },
  angle = {
    is = isangle,
    serialize = tostring,
    deserialize = Angle
  }
}

---@param configuration table<"menu", table<string, Atomic.Package.Configuration.Raw>>
---@param package Atomic.Package
---@return table<string, Atomic.Package.Configuration.Raw>, integer
local function flatConfig(configuration, package)
  local result = {}
  local length = 0

  for _, config in pairs(configuration) do
    for variable, data in pairs(config) do
      if (result[variable]) then
        package.logger:warn("%s configuration variable `%s` for has been overridden due to a conflict", package, variable)
      else
        length = length + 1
      end

      result[variable] = data
    end
  end

  return result, length
end

---@param configuration table<"menu", table<string, Atomic.Package.Configuration.Raw>>
---@param package Atomic.Package
function Configuration:init(configuration, package)
  local configuration, length = flatConfig(configuration, package)

  local packageId = package:getId()
  self._memorized = { length = length, configuration = configuration }
  self._package = package
  self._storage = {}
  self._subscribedCallbacks = {}

  local data = sql.QueryTyped("SELECT name, value FROM atomic_config WHERE package_id=?", packageId)
  ---@cast data { name: string, value: string }[]

  if (istable(data) and #data > 0) then
    for _, row in ipairs(data) do
      local raw = configuration[row.name]

      if (not raw) then
        package.logger:warn("unknown configuration field `%s` with value `%s`", tostring(row.name), tostring(row.value))
        continue
      end

      local handler = types[raw.type]

      if (not handler) then
        package.logger:err("unknown config variable type '%s' for key '%s'", tostring(raw.type), row.name)
        continue
      end

      self._storage[row.name] = {
        type = raw.type,
        value = handler.deserialize(row.value),
        sync = raw.sync
      }
    end
  end

  -- if the server has package version X installed and the developer decides
  -- to update the package to a new version that includes a new configuration parameter,
  -- that parameter will not be in the database and therefore cannot be
  -- obtained using the get method or set using the set method.
  sql.Begin()
  for name, raw in pairs(configuration) do
    if (not self._storage[name]) then
      local handler = types[raw.type]
      local defaultValue = handler and handler.serialize(raw.default) or tostring(raw.default)
      sql.QueryTyped("INSERT OR IGNORE INTO atomic_config(package_id, name, value) VALUES(?, ?, ?)", packageId, name, defaultValue)
      self._storage[name] = { type = raw.type, value = raw.default, sync = raw.sync }
    end
  end
  sql.Commit()
end

function Configuration:__tostring()
  return "Configuration of " .. tostring(self._package:__tostring())
end

--- Returns current value of a field
---
--- ```lua
--- local value = package:getConfiguration():get("somePackageConfigurationField")
--- print(value) -- "This is value from databases"
--- ```
---
---@param key string
---@return any?
function Configuration:get(key)
  local entry = self._storage[key]
  return entry and entry.value
end

--- Returns default value of a field
---
--- ```lua
--- local value = package:getConfiguration():getDefault("somePackageConfigurationField")
--- print(value) -- "Change me"
--- ```
---
---@param key string
---@return any?
function Configuration:getDefault(key)
  local entry = self._memorized.configuration[key]
  return entry and entry.default
end

---@param variable string
---@return Atomic.Package.Configuration.InternalEntry?
function Configuration:getEntry(variable)
  return self._storage[variable]
end

function Configuration:getEntries()
  return self._storage
end

---@return integer
function Configuration:getEntriesCount()
  return self._memorized.length
end

---
---
--- ```lua
--- local value
--- package:getConfiguration():subscribe(function(fromDatabase)
---   value = fromDatabase
--- end, "somePackageConfigurationField")
---
--- print(value) -- "This is value from databases"
--- ```
---
---@param callback fun(value: any): false?
---@param key string
function Configuration:subscribe(callback, key)
  local value = self:get(key)

  if (value ~= nil) then
    callback(value)
  end

  self._subscribedCallbacks[key] = callback
end

---@param key string
---@param value any
function Configuration:set(key, value)
  local entry = self._storage[key]
  if (not entry) then
    return atomic.log:err("attempt to set unknown key `%s` to config\n\tcalled from %s", key, debug.getcaller())
  end

  local handler = types[entry.type]
  if (not handler) then
    return atomic.log:err("unknown type '%s' on config:set(%s)\n\tcalled from %s", entry.type, key, debug.getcaller())
  end

  value = handler.deserialize(value)

  sql.QueryTyped("UPDATE atomic_config SET value=? WHERE name=? AND package_id=?", handler.serialize(value), key, self._package:getId())

  local isSuccessful = true
  local subscribedCallback = self._subscribedCallbacks[key]

  if (subscribedCallback) then
    local result = subscribedCallback(value)

    if (result == false) then
      isSuccessful = false
    end
  end

  if (isSuccessful) then
    entry.value = value

    hook.Run("onAtomicPackageConfigChanged", self._package, key, entry)
  end
end