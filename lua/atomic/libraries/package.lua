atomic.package = {
  ---@private
  storage = {
    ---@type table<string, Atomic.STD.Package[]>
    packages = {},
    ---@type { id: string, version: string }[]
    map = {}
  }
}

---@class Atomic.STD.AtomicMeta
---@field version? string

---@class Atomic.STD.Package
---@field kind "library" | "system"
---@field id string Package ID form of %s.author.packagename
---@field atomic? Atomic.STD.AtomicMeta
---@field nicename string Formatted name of the package (or language key)
---@field description string? Description of the package
---@field version string Version of a package form of %d.%d.%d
---@field documentation string? URL to documentation of the package
---@field configuration table<string, any>
---@field files table<"client" | "server" | "shared", string[]>
---@field dependencies table<string, string>?
---@field private _dir string? Internal
---@field private _isLoaded boolean? Internal
---@field private _isEnabled boolean? Internal
---@field private logger Atomic.STD.Logger? Internal
---@field private _events table<string, function> Internal
---@field private _commands table<string, Atomic.STD.Command> Internal
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

  ---@diagnostic disable
  payload._dir = dir
  payload._isLoaded = false
  payload._isEnabled = false
  payload._events = {}
  payload._commands = {}
  payload.logger = atomic.logger.new(dir)

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

---@param dirname string
---@return Atomic.STD.Package?
function atomic.package.getByDir(dirname)
  local pkgMeta = atomic.package.storage.map[dirname]

  if (not pkgMeta) then
    return
  end

  return atomic.package.get(pkgMeta.id, pkgMeta.version)
end

--- Returns current package, with context saving
---@return Atomic.STD.Package | nil Package Could return nil if the package wasn't registered
function atomic.package.current()
  -- 2 'cause 0 its lua engine, 1 its this function, and 2 is the caller
  local data = debug.getinfo(2)
  local pkgname = data.short_src:match("lua/atomic/packages/([^/]+)/")

  return atomic.package.getByDir(pkgname)
end

---@return boolean
function package:isLoaded()
  return self._isLoaded
end

---@return boolean
function package:isEnabled()
  return self._isEnabled
end

---@private
function package:load()
  local files = self.files

  if (not files) then
    return self.logger:warn("no files to include")
  end

  for side, filelist in pairs(files) do
    local include = atomic.loader[side]

    if (not include) then
      atomic.log:err("unknown include side `%s`", side)
      continue
    end

    for _, filename in ipairs(filelist) do
      include("atomic/packages/" .. self._dir .. "/" .. filename)
    end
  end

  self:enable()
end

---@private
function package:unload()
  if (not self._isLoaded) then
    return self.logger:debug("trying to unload not loaded package")
  end

  self.logger:debug("package `%s@%s` unloaded successfully", self.id, self.version)
end

---@private
function package:formatEventId(eventName)
  return ("atomic:%s:%s"):format(self.id, eventName)
end

---@private
function package:enable()
  for name, command in pairs(self._commands) do
    atomic.command.add(name, command)
  end

  for eventName, callback in pairs(self._events) do
    hook.Add(eventName, self:formatEventId(eventName), callback)
  end

  self._isEnabled = true
end

---@private
function package:disable()
  for name in pairs(self._commands) do
    atomic.command.remove(name) -- detach команды
  end

  for eventName in pairs(self._events) do
    hook.Remove(eventName, self:formatEventId(eventName))
  end

  self._isEnabled = false
end

function package:getName()
  return self.nicename
end

function package:getId()
  return self.id
end

---@param eventName string
---@param callback function
function package:on(eventName, callback)
  self._events[eventName] = callback
end

---@param name string
---@param permission string
---@return Atomic.STD.Command
function package:command(name, permission)
  local cmd = atomic.command.register(name, permission)

  self._commands[name] = cmd

  return cmd
end