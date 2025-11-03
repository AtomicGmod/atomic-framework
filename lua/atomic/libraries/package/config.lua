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

---@alias ConfigurationContentType "string" | "integer" | "float" | "boolean" | "string[]", "number[]" | "json"

---@class Atomic.Package.Configuration.Raw
---@field default any
---@field description string
---@field type ConfigurationContentType

---@class Atomic.Package.Configuration: Atomic.Class
---@field private _storage table<string, { type: ConfigurationContentType, value: any }>
---@field private _name string?
---@field private _memorized table<string, Atomic.Package.Configuration.Raw>
---@field private _package { id: string, version: string }
local Configuration = atomic.class.create("Configuration")
atomic.class.register(Configuration, atomic.class.pseudo)

if (not sql.TableExists("atomic_config")) then
  sql.Query([[CREATE TABLE IF NOT EXISTS atomic_config(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    package_id TEXT NOT NULL,
    package_version TEXT NOT NULL,
    name TEXT NOT NULL UNIQUE,
    value TEXT NOT NULL
  );]])
end

local types = {
  string = {
    is = isstring,
    to = tostring,
    from = tostring
  },
  integer = {
    is = isnumber,
    to = tonumber,
    from = function(v) return math.floor(tonumber(v) or 0) end
  },
  float = {
    is = isnumber,
    to = tonumber,
    from = tonumber
  },
  boolean = {
    is = isbool,
    to = tobool,
    from = tobool
  },
  ["string[]"] = {
    is = istable,
    to = util.TableToJSON,
    from = util.JSONToTable
  },
  ["number[]"] = {
    is = istable,
    to = util.TableToJSON,
    from = util.JSONToTable
  },
  json = {
    is = istable,
    to = util.TableToJSON,
    from = util.JSONToTable
  }
}

---@param configuration table<string, Atomic.Package.Configuration.Raw>
---@param packageId string
---@param packageVer string
function Configuration:init(configuration, packageId, packageVer)
  self._memorized = configuration
  self._package = { id = packageId, version = packageVer }
  self._storage = {}

  local data = sql.QueryTyped("SELECT name, value FROM atomic_config WHERE package_id=? AND package_version = ?", packageId, packageVer)
  ---@cast data { name: string, value: string }[]

  -- todo remove spaghetti code
  if istable(data) then
    for _, row in ipairs(data) do
      local raw = configuration[row.name]
      if raw then
        local handler = types[raw.type]
        if handler then
          self._storage[row.name] = {
            type = raw.type,
            value = handler.from(row.value)
          }
        else
          atomic.log:err("unknown config type '%s' for key '%s'", tostring(raw.type), row.name)
        end
      end
    end
  end

  -- if the server has package version X installed and the developer decides
  -- to update the package to a new version that includes a new configuration parameter,
  -- that parameter will not be in the database and therefore cannot be
  -- obtained using the get method or set using the set method.
  sql.Begin()
  for name, raw in pairs(configuration) do
    if not self._storage[name] then
      local handler = types[raw.type]
      local defaultValue = handler and handler.to(raw.default) or tostring(raw.default)
      sql.QueryTyped("INSERT OR IGNORE INTO atomic_config(package_id, package_version, name, value) VALUES(?, ?, ?, ?)", packageId, packageVer, name, defaultValue)
      self._storage[name] = { type = raw.type, value = raw.default }
    end
  end
  sql.Commit()
end

---@param key string
---@generic T
---@return T?
function Configuration:get(key)
  local entry = self._storage[key]
  return entry and entry.value or nil
end

---@param key string
---@param value any
function Configuration:set(key, value)
  local entry = self._storage[key]
  if not entry then
    atomic.log:debug("attempt to set unknown key `%s` to config\n\tcalled from %s", key, debug.getcaller())
    return
  end

  local handler = types[entry.type]
  if not handler then
    atomic.log:err("unknown type '%s' on config:set(%s)\n\tcalled from %s", entry.type, key, debug.getcaller())
    return
  end

  local data = handler.to(value)

  sql.QueryTyped("UPDATE atomic_config SET value=? WHERE name=? AND package_id=? AND package_version=?", data, key, self._package.id, self._package.version)

  entry.value = value
end