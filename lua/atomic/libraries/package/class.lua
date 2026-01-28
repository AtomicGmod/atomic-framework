---@class Atomic.Package.Metadata
---@field id string
---@field title string
---@field description? string
---@field version string
---@field documentation? string
---@field configuration? table<string, Atomic.Package.Configuration.Raw>
---@field files table<"client" | "shared" | "server", string[]>
---@field dependencies? table<"client" | "shared" | "server", table<"atomic" | string, string>>
---@field kind? "system" | "library"
---@field icon? string Url to the icon of a package
---@field language? table<string, table<string, string>>
---@field private _path string? `Internal` field

---@class Atomic.Package: Atomic.Class
---@field private _state? table<string, any>
---@field private _metadata Atomic.Package.Metadata
---@field private _registry? Atomic.Package.Registry
---@field private _data? table<string, table>
-- @field private _configuration Atomic.Package.Configuration
---@field private _isEnabled boolean?
---@field logger Atomic.Logger
local Package = atomic.class.create("Package")
atomic.class.register(Package, atomic.class.pseudo)

---@type Atomic.Package.Configuration
local Configuration = atomic.class.get("Configuration")
---@type Atomic.Package.Registry
local PackageRegistry = atomic.class.get("PackageRegistry")

---@param metadata Atomic.Package.Metadata
function Package:init(metadata)
  local splittedId = metadata.id:Split(".")
  local prefix = (splittedId[#splittedId] or metadata.id):lower()

  self._isEnabled = false
  self._metadata = metadata
  self._configuration = atomic.class.new(Configuration, metadata.configuration or {}, metadata.id, metadata.version)
  self.logger = atomic.logger.new(prefix)

  self:addRegistry()
  self:addLanguageFromMetadata()
end

---@private
function Package:addRegistry()
  self._registry = atomic.class.new(PackageRegistry)
  self._data = {
    classes = {}
  }

  self._registry:define("classes",
    function(self, _, class) atomic.class.register(class, self) end,
    function(self, className) atomic.class.unregister(className, self) end
  )

  if (self._metadata.kind ~= "library") then
    self._state = {}
    self._data["events"] = {}
    self._data["commands"] = {}
    self._data["binds"] = {}
    self._data["netschemas"] = {}
    self._data["netlisteners"] = {}
    self._data["webviews"] = {}
    self._registry:define("events",
      function(self, eventId, listener) hook.Add(eventId, self:formatUniversalId(eventId), function(...) return listener(self, ...) end) end,
      function(self, eventId) hook.Remove(eventId, self:formatUniversalId(eventId)) end
    )

    self._registry:define("binds",
      function(_, _, data)
        local regId = atomic.bind.bind(data.key, data.callback)
        data.registrationId = regId
      end,
      function(_, _, data) atomic.bind.unbind(data.registrationId) end
    )

    self._registry:define("commands",
      function(_, name, command) atomic.command.add(name, command) end,
      function(_, name) atomic.command.remove(name) end
    )

    self._registry:define("netschemas",
      function(_, _, schema) atomic.network.register(schema) end,
      function(_, _, schema) atomic.network.unregister(schema._name) end
    )

    self._registry:define("netlisteners",
      function(_, schemaName, schema) atomic.network.listen(self:formatUniversalId(schemaName), schema) end,
      function(_, schemaName) atomic.network.unlisten(self:formatUniversalId(schemaName)) end
    )

    self._registry:define("webviews",
      function(_, _, webview) atomic.webview.register(webview, self) end,
      function(_, name) atomic.webview.unregister(name, self) end
    )
  end
end

local addPhrase = atomic.i18n.addPhrase

---@private
function Package:addLanguageFromMetadata()
  local localization = self._metadata.language

  if (localization) then
    for language, tab in pairs(localization) do
      for phraseId, phrase in pairs(tab) do
        addPhrase(language, self:formatUniversalId(phraseId), phrase)
      end
    end
  end
end

---@private
---@param category "events" | "binds" | "classes"| "commands" | "netschemas" | "netlisteners" | "webviews"
---@param index string | integer
---@param value any
function Package:register(category, index, value)
  self._data[category][index] = value

  if (self._isEnabled) then
    self._registry:add(category, self, index, value)
  end
end

---@private
---@param category string
---@param index string | integer
function Package:unregister(category, index)
  local value = self._data[category][index]

  if (not value) then
    return
  end

  if (self._isEnabled) then
    self._registry:remove(category, self, index, value)
  end

  self._data[category][index] = nil
end

---@private
function Package:load()
  local instant = Instant()
  local files = self._metadata.files

  if (not files) then
    return self.logger:warn("no files to include")
  end

  self:include("shared", files.shared)
  self:include("server", files.server)
  self:include("client", files.client)

  self:enable()
  self.logger:trace("package `%s@%s` loaded successfully for %sms", self._metadata.id, self._metadata.version, instant:elapsed():as_millis())
end

---@private
function Package:include(side, files)
  if (not files) then
    return
  end

  local include = atomic.loader[side]

  if (not include) then
    atomic.log:err("unknown include side `%s`", side)
    return
  end

  for _, filename in ipairs(files) do
    include(self._metadata._path .. "/" .. filename)
  end
end

---@private
function Package:unload()
  self:disable()
  self.logger:trace("package `%s@%s` unloaded successfully", self._metadata.id, self._metadata.version)
end

--- Enable/Disable

---@private
function Package:enable()
  self:emitEvent("onEnable")

  if (self._data) then
    for category, entries in pairs(self._data) do
      for index, entry in pairs(entries) do
        self._registry:add(category, self, index, entry)
      end
    end
  end

  self._isEnabled = true
end

local removePhrase = atomic.i18n.removePhrase

---@private
function Package:disable()
  self:emitEvent("onDisable")

  if (self._data) then
    for category, entries in pairs(self._data) do
      for index, entry in pairs(entries) do
        self._registry:remove(category, self, index, entry)
      end
    end
  end

  local localization = self._metadata.language

  if (localization) then
    for language, tab in pairs(localization) do
      for phraseId in pairs(tab) do
        removePhrase(language, self:formatUniversalId(phraseId))
      end
    end
  end

  -- clearing state
  if (self._state) then
    self._state = {}
  end

  self._isEnabled = true
end

--- Metadata

---@return boolean
function Package:isEnabled()
  return self._isEnabled
end

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

---@param id string
---@return Atomic.Package?
function Package:getDependency(id)
  local dependecies = self._metadata.dependencies

  if (not dependecies) then
    return
  end

  local stateDeps = dependecies[SERVER and "server" or "client"]

  local version = stateDeps and stateDeps[id]

  if (not version) then
    local sharedDeps = dependecies.shared
    version = sharedDeps and sharedDeps[id]

    if (not version) then
      return self.logger:err("dependency `%s` is not specified in package.lua!", id)
    end
  end

  return atomic.package.get(id, version)
end

--- State

---@param key string
---@param value any
---@return any? @Old value
function Package:setState(key, value)
  local old = self._state[key]
  self._state[key] = value
  return old
end

---@param key string
---@return any? @Old value
function Package:clearState(key)
  local old = self._state[key]
  self._state[key] = nil
  return old
end

---@param key string
---@return any?
function Package:getState(key)
  return self._state[key]
end

--- Language

local getPhrase = atomic.i18n.getPhrase

---@param player Player | string
---@param phraseId string
---@param ...any?
---@return string
function Package:getPhrase(player, phraseId, ...)
  return getPhrase(player, self:formatUniversalId(phraseId), ...)
end

--- Binds

---@param callback fun(player: Player)
---@param key number
---@return integer registrationId
function Package:bind(callback, key)
  local id = #self._data.binds+1

  self:register("binds", id, {
    key = key,
    callback = callback,
    registrationId = 0
  })

  return id
end

---@param registrationId integer
function Package:unbind(registrationId)
  self:unregister("binds", registrationId)
end

--- Commands

--- Registers the command
---
--- ```lua
--- local package = atomic.package.current()
---
--- package:command("example", "atomic.example")
---   :argument("user", "player")
---   :onExecute(function(executor, user)
---     print(executor:Nick() .. " executes command `example` and mentioned player " .. user:Nick() .. " !")
---   end)
--- ```
---@param commandName string
---@param permission? string
---@param cooldown? number
---@return Atomic.Command
function Package:command(commandName, permission, cooldown)
  local command = atomic.command.new(commandName, permission, cooldown)
  self:register("commands", commandName, command)

  return command
end

--- Events

---@alias Atomic.Package.Events "onEnable" | "onDisable" | "onDatabaseConnected" | "CouldPlayerExecuteCommand"

---@private
function Package:formatUniversalId(eventName)
  return ("atomic:%s:%s:%s"):format(self._metadata.id, self._metadata.version, eventName)
end

--- Adds an event for listening
---
--- ```lua
--- local package = current()
---
--- package:listen(function(player)
---   print(player:Nick() .. " has been died!")
--- end, "PlayerDeath")
--- ```
---@generic T: Atomic.Package
---@param self T
---@param callback fun(self: T, ...: any): ...: any
---@param eventName string | Atomic.Package.Events Name of the event
function Package:listen(callback, eventName)
  --- todo remove diagnostic disable
  --- ebuchi lualsp >:(
  ---@diagnostic disable-next-line undefined-field
  self:register("events", eventName, callback)
end

--- Removes the event from listening
---
--- ```lua
--- local package = current()
---
--- package:unlisten("PlayerDeath")
--- ```
---@param eventName string
function Package:unlisten(eventName)
  self:unregister("events", eventName)
end

--- Starts a local event that is only associated with the current package.
---@private
---@param name Atomic.Package.Events
---@vararg any
function Package:emitEvent(name, ...)
  if (not self._data.events) then
    return
  end

  local listener = self._data.events[name]

  if (not listener) then
    return
  end

  listener(self, ...)
end

--- Classes

--- Creates new class and automatically registeres it
---@param name string
---@param parent? Atomic.Class
---@generic T
---@return T: Atomic.Class
function Package:class(name, parent)
  local class = atomic.class.create(name, parent)

  self:register("classes", class:__classname(), class)

  return class
end

--- Return package's registered class
---@param name string
function Package:getClass(name)
  return self._data.classes[name]
end

--- Network

---@param schemaName string
---@return Atomic.Network.Schema
function Package:networkSchema(schemaName)
  local schema = atomic.network.new(self, self:formatUniversalId(schemaName))

  self:register("netschemas", schemaName, schema)

  return schema
end

---@generic T: Atomic.Package
---@param self T
---@param callback fun(self: T, message: Atomic.Network.Message)
---@param schemaName string
function Package:onNetworkMessage(callback, schemaName)
  --- todo remove diagnostic disable
  --- ebuchi lualsp >:(
  ---@diagnostic disable-next-line undefined-field
  self:register("netlisteners", schemaName, callback)
end

---@param name string
---@param data table<string, any>
---@param player? Player | table | Vector
---@param sendFunction? "Send" | "SendOmit" | "SendPAS" | "SendPVS" | "Broadcast"
---@return string Message id
function Package:sendNetworkMessage(name, data, player, sendFunction)
  local schema = self._data.netschemas[name]

  return atomic.network.send(schema._name, data, player, sendFunction)
end

---@param name string
---@param data table<string, any>
function Package:broadcastNetworkMessage(name, data)
  self:sendNetworkMessage(name, data, player.GetHumans(), "Broadcast")
end

---@async
---@param name string
---@param data table<string, any>
---@param player Player?
---@return Atomic.Network.Message | string
function Package:sendNetworkMessageAsync(name, data, player)
  local schema = self._data.netschemas[name]

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

  self:register("webviews", webview._name, webview)

  return webview
end

--- Return package's registered webview
---@param name string
---@return Atomic.WebView
function Package:getWebview(name)
  return self._data.webviews[name]
end