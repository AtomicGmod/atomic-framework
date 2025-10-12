---@class Atomic.Package: Atomic.Class
---@field id string
---@field nicename string
---@field description string?
---@field version string
---@field documentation string?
-- @field configuration table<string, any>?
---@field files table<"client" | "shared" | "server", string[]>
---@field dependencies table<string, string>?
---@field atomic { version: string }?
---@field kind? "system" | "library"
---@field private _path string? `Internal` variable
---@field private _isLoaded boolean? `Internal` variable
---@field private _events table<string, function>? `Internal` variable
---@field private _commands table<string, Atomic.Command>? `Internal` variable
---@field private _binds { key: integer, callback: fun(player: Player), registrationId: integer }[]? `Internal` variable
---@field logger Atomic.Logger? `Internal` variable
local package = atomic.class.create("Package")
atomic.class.register(package, atomic.class.pseudo)

local logger = atomic.class.get("Logger")

---@cast logger Atomic.Logger

function package:init()
  local prefix = (self.id:Split(".")[3] or ""):lower()

  self.configuration = self.configuration or {}
  self._isLoaded = false
  self._events = {}
  self._commands = {}
  self._binds = {}
  self.logger = atomic.logger.new(prefix)
end

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
    hook.Add(name, self:formatEventId(name), callback)
  end

  for _, data in ipairs(self._binds) do
    local regId = atomic.bind.bind(data.key, data.callback)
    data.registrationId = regId
  end
end

---@private
function package:cleanup()
  for name in pairs(self._commands) do
    atomic.command.remove(name)
  end

  for name in pairs(self._events) do
    hook.Remove(name, self:formatEventId(name))
  end

  for _, data in ipairs(self._binds) do
    atomic.bind.unbind(data.registrationId)
  end
end

--- Binds

---@param key number
---@param callback fun(player: Player)
---@return integer registrationId
function package:bind(key, callback)
  self._binds[#self._binds+1] = {
    key = key,
    callback = callback,
    registrationId = 0
  }
end

--- Commands
--- todo: make it so that they attach/detach without reloading the package

--- Registers the command
---
--- ```lua
--- local package = atomic.package.current()
---
--- package:attachCommand(
---   atomic.command.new("example", "atomic.example")
---     :argument("user", "player")
---     :onExecute(function(executor, user)
---       print(executor:Nick() .. " executes command `example` and mentioned player " .. user:Nick() .. " !")
---     end)
--- )
--- ```
---@param command Atomic.Command
function package:attachCommand(command)
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
function package:formatEventId(eventName)
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