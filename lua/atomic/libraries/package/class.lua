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
  local prefix = (metadata.id:Split(".")[3] or metadata.id):lower()

  self._metadata = metadata
  self._configuration = atomic.class.new(Configuration, metadata.configuration or {}, metadata.id, metadata.version)
  self._isEnabled = false
  self.logger = atomic.logger.new(prefix)

  if (self._metadata.kind ~= "library") then
    self:addRegistry()
  end
end

---@private
function Package:addRegistry()
  self._registry = atomic.class.new(PackageRegistry)
  self._data = {
    events = {},
    commands = {},
    binds = {},
    classes = {},
    netschemas = {},
    netlisteners = {},
    webviews = {}
  }

  self._registry:define("events",
    function(self, eventId, listener) hook.Add(eventId, self:formatUniversalId(eventId), listener) end,
    function(self, eventId) hook.Remove(eventId, self:formatUniversalId(eventId)) end
  )

  self._registry:define("binds",
    function(_, _, data)
      local regId = atomic.bind.bind(data.key, data.callback)
      data.registrationId = regId
    end,
    function(self, _, data) atomic.bind.unbind(data.registrationId) end
  )

  self._registry:define("classes",
    function(self, _, class) atomic.class.register(class, self) end,
    function(self, className) atomic.class.unregister(className, self) end
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

---@private
---@param category "events" | "binds" | "classes"| "commands" | "netschemas" | "netlisteners" | "webviews"
---@param index string | integer
---@param value any
function Package:register(category, index, value)
  self._data[category][index] = value

  if self._isEnabled then
    self._registry[category].add(index, value, self)
  end
end

---@private
---@param category string
---@param index string | integer
function Package:unregister(category, index)
  local value = self._data[category][index]

  if not value then
    return
  end

  if self._isEnabled then
    self._registry[category].remove(index, value, self)
  end

  self._data[category][index] = nil
end

---@private
function Package:load()
  local instant = atomic.time.newInstant()

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
      include(self._metadata._path .. "/" .. filename)
    end
  end

  self:enable()
  self:emitEvent("onEnable")
  self.logger:trace("package `%s@%s` loaded successfully for %sms", self._metadata.id, self._metadata.version, instant:elapsed():as_millis())
end

---@private
function Package:unload()
  self:emitEvent("onDisable")
  self:disable()
  self.logger:trace("package `%s@%s` unloaded successfully", self._metadata.id, self._metadata.version)
end

--- Enable/Disable

---@private
function Package:enable()
  for category, entries in pairs(self._data) do
    for index, entry in pairs(entries) do
      self._registry:add(category, self, index, entry)
    end
  end

  self._isEnabled = true
end

---@private
function Package:disable()
  for category, entries in pairs(self._data) do
    for index, entry in pairs(entries) do
      self._registry:remove(category, self, index, entry)
    end
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

--- Binds

---@param key number
---@param callback fun(player: Player)
---@return integer registrationId
function Package:bind(key, callback)
  local id = #self._data.binds+1

  self:register("binds", id, {
    key = key,
    callback = callback,
    registrationId = 0
  })

  return id
end

--- Commands

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
  self:register("commands", command._name, command)
end

--- Events

---@alias Atomic.Package.LocalEvents "onEnable" | "onDisable"

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
  self:register("events", eventName, callback)
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
  self:unregister("events", eventName)
end

--- Starts a local event that is only associated with the current package.
---@private
---@param name Atomic.Package.LocalEvents
---@vararg any
function Package:emitEvent(name, ...)
  local listener = self._data.events[name]

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

  self:register("classes", class._name, class)

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
  local schema = atomic.network.new(self:formatUniversalId(schemaName))
  self:register("netschemas", schemaName, schema)

  return schema
end

---@param callback fun(message: Atomic.Network.Message)
---@param schemaName string
function Package:onNetworkMessage(callback, schemaName)
  self:register("netlisteners", schemaName, callback)
end

---@param name string
---@param data table<string, any>
---@param player Player?
---@return string Message id
function Package:sendNetworkMessage(name, data, player)
  local schema = self._data.netschemas[name]

  return atomic.network.send(schema._name, data, player)
end

---@async
---@param name string
---@param data table<string, any>
---@param player Player?
---@return table | string
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