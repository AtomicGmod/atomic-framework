---@class Atomic.Package: Atomic.Class
---@field id string
---@field nicename string
---@field description string?
---@field version string
---@field documentation string?
-- @field configuration Atomic.Package.Configuration?
---@field files table<"client" | "shared" | "server", string[]>
---@field dependencies table<string, string>?
---@field atomic { version: string }?
---@field kind? "system" | "library"
---@field private _path string? `Internal` variable
---@field private _isLoaded boolean? `Internal` variable
---@field private _events table<string, function>? `Internal` variable
---@field private _commands table<string, Atomic.Command>? `Internal` variable
---@field private _binds { key: integer, callback: fun(player: Player), registrationId: integer }[]? `Internal` variable
---@field private _classes table<string, Atomic.Class>?
---@field private _netschemas table<string, Atomic.Network.Schema>?
---@field private _netlisteners table<string, fun(message: Atomic.Network.Message)>?
---@field logger Atomic.Logger? `Internal` variable
local package = atomic.class.create("Package")
atomic.class.register(package, atomic.class.pseudo)

local configClass = atomic.class.get("Configuration")
---@cast configClass Atomic.Package

function package:init()
  local prefix = (self.id:Split(".")[3] or "n/a"):lower()

  local config = self.configuration or {}

  self.logger = atomic.logger.new(prefix)
  self.configuration = atomic.class.new(configClass, nil, config, self)
  self._isLoaded = false
  self._events = {}
  self._commands = {}
  self._binds = {}
  self._classes = {}
  self._netschemas = {}
  self._netlisteners = {}
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
      include(self._path .. "/" .. filename)
    end
  end

  self:setup()
end

---@private
function package:unload()
  self:cleanup()

  self.logger:debug("package `%s@%s` unloaded successfully", self.id, self.version)
end

--- Setup/Cleanup

---@private
function package:setup()
  for name, command in pairs(self._commands) do
    atomic.command.add(name, command)
  end

  for name, callback in pairs(self._events) do
    hook.Add(name, self:formatUniversalId(name), callback)
  end

  for _, data in ipairs(self._binds) do
    local regId = atomic.bind.bind(data.key, data.callback)
    data.registrationId = regId
  end

  for _, class in pairs(self._classes) do
    atomic.class.register(class, self)
  end

  for _, schema in pairs(self._netschemas) do
    atomic.network.register(schema)
  end

  for schemaName, schema in pairs(self._netlisteners) do
    atomic.network.listen(self:formatUniversalId(schemaName), schema)
  end
end

---@private
function package:cleanup()
  for name in pairs(self._commands) do
    atomic.command.remove(name)
  end

  for name in pairs(self._events) do
    hook.Remove(name, self:formatUniversalId(name))
  end

  for _, data in ipairs(self._binds) do
    atomic.bind.unbind(data.registrationId)
  end

  for className in pairs(self._classes) do
    atomic.class.unregister(className, self)
  end

  for _, schema in pairs(self._netschemas) do
    ---@diagnostic disable-next-line
    atomic.network.unregister(schema._name)
  end

  for schemaName in pairs(self._netlisteners) do
    atomic.network.unlisten(self:formatUniversalId(schemaName))
  end
end

--- Binds

---@param key number
---@param callback fun(player: Player)
---@return integer registrationId
function package:bind(key, callback)
  local id = #self._binds+1

  self._binds[id] = {
    key = key,
    callback = callback,
    registrationId = 0
  }

  return id
end

--- Commands
--- todo: make it so that they attach/detach without reloading the package

--- Registers the command
---
--- ```lua
--- local package = atomic.package.current()
---
--- package:command(
---   atomic.command.new("example", "atomic.example")
---     :argument("user", "player")
---     :onExecute(function(executor, user)
---       print(executor:Nick() .. " executes command `example` and mentioned player " .. user:Nick() .. " !")
---     end)
--- )
--- ```
---@param command Atomic.Command
function package:command(command)
  self._commands[command.name] = command
end

--- Unregisters the command
---
--- ```lua
--- local package = atomic.package.current()
---
--- package:dettachCommand("example")
--- ```
---@param commandName string
function package:dettachCommand(commandName)
  self._commands[commandName] = nil
end

--- Events

---@private
function package:formatUniversalId(eventName)
  return ("atomic:%s:%s"):format(self.id, eventName)
end

--- Adds an event for listening
---
--- ```lua
--- local package = atomic.package.current()
---
--- package:listen(function(player)
---   print(player:Nick() .. " has been died!")
--- end, "PlayerDeath")
--- ```
---@param eventName string Name of the event
---@param callback fun()
function package:listen(eventName, callback)
  self._events[eventName] = callback
end

--- Removes the event from listening
---
--- ```lua
--- local package = atomic.package.current()
---
--- package:unlisten("PlayerDeath")
--- ```
---@param eventName string
function package:unlisten(eventName)
  self._events[eventName] = nil
end

--- Classes

--- Creates new class and automatically registeres it
---@param name string
---@generic T
---@return T: Atomic.Class
function package:class(name)
  local class = atomic.class.create(name)

  ---@diagnostic disable-next-line
  self._classes[class._name] = class

  return class
end

--- Return package's registered class
---@param class Atomic.Class
function package:registerClass(class)
  return atomic.class.register(class, self)
end

---@param className string
function package:unregisterClass(className)
  return atomic.class.unregister(self._classes[className], self)
end

--- Return package's registered class
---@param name string
function package:getClass(name)
  return self._classes[name]
end

--- Network

---@param schemaName string
---@return Atomic.Network.Schema
function package:networkSchema(schemaName)
  local schema = atomic.network.new(self:formatUniversalId(schemaName))
  ---@diagnostic disable-next-line
  self._netschemas[schemaName] = schema

  return schema
end

---@param callback fun(message: Atomic.Network.Message)
---@param schemaName string
function package:onNetworkMessage(callback, schemaName)
  self._netlisteners[schemaName] = callback
end

---@param name string
---@param data table<string, any>
---@param player Player?
---@return string Message id
function package:sendNetworkMessage(name, data, player)
  local schema = self._netschemas[name]

  ---@diagnostic disable-next-line
  return atomic.network.send(schema._name, data, player)
end

---@async
---@param name string
---@param data table<string, any>
---@param player Player?
---@return table | string
function package:sendNetworkMessageAsync(name, data, player)
  local schema = self._netschemas[name]

  ---@diagnostic disable-next-line
  return atomic.network.sendAsync(schema._name, data, player)
end