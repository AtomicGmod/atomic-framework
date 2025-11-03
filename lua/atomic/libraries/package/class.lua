---@class Atomic.Package.Metadata
---@field id string
---@field title string
---@field description? string
---@field version string
---@field documentation? string
---@field configuration? table<string, Atomic.Package.Configuration.Raw>
---@field files table<"client" | "shared" | "server", string[]>
---@field dependencies? table<"atomic" | string, string>
---@field kind? "system" | "library"
---@field icon? string Url to the icon of a package
---@field private _path string? `Internal` field

---@class Atomic.Package: Atomic.Class
---@field private _metadata Atomic.Package.Metadata
-- @field private _configuration Atomic.Package.Configuration
---@field private _isLoaded boolean?
---@field private _events table<string, function>?
---@field private _commands table<string, Atomic.Command>?
---@field private _binds { key: integer, callback: fun(player: Player), registrationId: integer }[]?
---@field private _classes table<string, Atomic.Class>?
---@field private _netschemas table<string, Atomic.Network.Schema>?
---@field private _netlisteners table<string, fun(message: Atomic.Network.Message)>?
---@field private _webviews table<string, Atomic.WebView>?
---@field logger Atomic.Logger
local Package = atomic.class.create("Package")
atomic.class.register(Package, atomic.class.pseudo)

---@type Atomic.Package.Configuration
local Configuration = atomic.class.get("Configuration")

---@param metadata Atomic.Package.Metadata
function Package:init(metadata)
  local prefix = (metadata.id:Split(".")[3] or metadata.id):lower()

  self._metadata = metadata
  self._configuration = atomic.class.new(Configuration, metadata.configuration or {}, metadata.id, metadata.version)
  self._isLoaded = false
  self._events = {}
  self._commands = {}
  self._binds = {}
  self._classes = {}
  self._netschemas = {}
  self._netlisteners = {}
  self._webviews = {}
  self.logger = atomic.logger.new(prefix)
end

---@private
function Package:load()
  local files = self._metadata.files

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
      ---@diagnostic disable-next-line
      include(self._metadata._path .. "/" .. filename)
    end
  end

  self:setup()

  self:runLocalEvent("loaded")
end

---@private
function Package:unload()
  self:runLocalEvent("unloading")

  self:cleanup()

  self.logger:debug("package `%s@%s` unloaded successfully", self._metadata.id, self._metadata.version)
end

--- Setup/Cleanup

---@private
function Package:setup()
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

  for _, webview in pairs(self._webviews) do
    atomic.webview.register(webview, self)
  end
end

---@private
function Package:cleanup()
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

  for name in pairs(self._webviews) do
    atomic.webview.unregister(name, self)
  end
end

--- Metadata

---@return string
function Package:getId()
  return self._metadata.id
end

---@return string
function Package:getVersion()
  return self._metadata.version
end

---@return string
function Package:getTitle()
  return self._metadata.title
end

---@return string?
function Package:getDocumentation()
  return self._metadata.documentation
end

---@return string?
function Package:getDescription()
  return self._metadata.description
end

---@return string?
function Package:getIcon()
  return self._metadata.icon
end

---@return boolean
function Package:isSystem()
  return self._metadata.kind == "system"
end

---@return boolean
function Package:isLibrary()
  return self._metadata.kind == "library"
end

---@return "system" | "library"
function Package:getKind()
  return self._metadata.kind or "system"
end

--- ```lua
--- local config = package:getConfiguration()
--- assert(config:get("someKey"), "hello, world")
--- ```
---@return Atomic.Package.Configuration
function Package:getConfiguration()
  return self._configuration
end

--- Binds

---@param key number
---@param callback fun(player: Player)
---@return integer registrationId
function Package:bind(key, callback)
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
function Package:command(command)
  ---@diagnostic disable-next-line
  self._commands[command._name] = command
end

--- Events

---@alias Atomic.Package.LocalEvents "loaded" | "unloading"

---@private
function Package:formatUniversalId(eventName)
  return ("atomic:%s:%s:%s"):format(self._metadata.id, self._metadata.version, eventName)
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
---@param eventName string | Atomic.Package.LocalEvents Name of the event
---@param callback fun(...: any): ...: any
function Package:listen(eventName, callback)
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
function Package:unlisten(eventName)
  self._events[eventName] = nil
end

--- Starts a local event that is only associated with the current package.
---@private
---@param name Atomic.Package.LocalEvents
---@vararg any
function Package:runLocalEvent(name, ...)
  local listener = self._events[name]

  if (not listener) then
    return
  end

  listener(...)
end

--- Classes

--- Creates new class and automatically registeres it
---@param name string
---@generic T
---@return T: Atomic.Class
function Package:class(name)
  local class = atomic.class.create(name)

  ---@diagnostic disable-next-line
  self._classes[class._name] = class

  return class
end

--- Return package's registered class
---@param name string
function Package:getClass(name)
  return self._classes[name]
end

--- Network

---@param schemaName string
---@return Atomic.Network.Schema
function Package:networkSchema(schemaName)
  local schema = atomic.network.new(self:formatUniversalId(schemaName))
  ---@diagnostic disable-next-line
  self._netschemas[schemaName] = schema

  return schema
end

---@param callback fun(message: Atomic.Network.Message)
---@param schemaName string
function Package:onNetworkMessage(callback, schemaName)
  self._netlisteners[schemaName] = callback
end

---@param name string
---@param data table<string, any>
---@param player Player?
---@return string Message id
function Package:sendNetworkMessage(name, data, player)
  local schema = self._netschemas[name]

  ---@diagnostic disable-next-line
  return atomic.network.send(schema._name, data, player)
end

---@async
---@param name string
---@param data table<string, any>
---@param player Player?
---@return table | string
function Package:sendNetworkMessageAsync(name, data, player)
  local schema = self._netschemas[name]

  ---@diagnostic disable-next-line
  return atomic.network.sendAsync(schema._name, data, player)
end

--- Creates new webview and automatically registeres it
---@param name string
---@param autoSpawn? boolean = true
---@return Atomic.WebView
function Package:webview(name, autoSpawn)
  local folder = self._metadata.id .. "@" .. self._metadata.version
  local path = "asset://garrysmod/resource/webviews/" .. folder

  local webview = atomic.webview.new(name, path, autoSpawn)

  ---@diagnostic disable-next-line
  self._webviews[webview._name] = webview

  return webview
end

--- Return package's registered webview
---@param name string
---@return Atomic.WebView
function Package:getWebview(name)
  return self._webviews[name]
end