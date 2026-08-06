---@alias Atomic.Package.Metadata.Dependency string | { optional: true, version: string }

---@class Atomic.Package.Metadata
---@field id string
---@field title string
---@field description? string
---@field version string
---@field documentation? string
---@field homepageUrl? string
---@field configuration? table<"menu", table<string, Atomic.Package.Configuration.Raw>>
---@field files { dir?: string, ["menu"]: string[] }
---@field dependencies? table<"menu", table<("atomic" | string), Atomic.Package.Metadata.Dependency>>
---@field kind "system" | "library"
---@field icon? string Url to the icon of a package
---@field language? table<string, table<string, string>>

---@alias PackageMeta Atomic.Package.Metadata
---@alias Package Atomic.Package

---@class Atomic.Package.InternalMetadata: Atomic.Package.Metadata
---@field private version Atomic.SemanticVersion
---@field private _path string?

---@class Atomic.Package: Atomic.Class
---@field private _coreVersion string
---@field private _version string
---@field private _state? table<string, any>
---@field private _metadata Atomic.Package.InternalMetadata
---@field private _registry? Atomic.Package.Registry
---@field private _configuration Atomic.Package.Configuration
---@field private _isEnabled boolean?
---@field logger Atomic.Logger
local Package = atomic.class.create("Package")
atomic.class.register(Package, atomic.class.pseudo)

---@type Atomic.Package.Configuration
local Configuration = atomic.class.get("Configuration")
---@type Atomic.Package.Registry
local PackageRegistry = atomic.class.get("PackageRegistry")

---@param metadata Atomic.Package.InternalMetadata
function Package:init(metadata)
  local prefix = metadata.id:match("^[^.]+%.[^.]+%.(.+)$") or metadata.id
  prefix = prefix:lower()
  local version = metadata.version

  self._isEnabled = false
  self._metadata = metadata
  self._metadata.kind = self._metadata.kind or "library"
  self._coreVersion = version:getCore() -- 1.0.0 (only major.minor.patch)
  self._version = version:getString() -- 1.0.0-alpha.1 (full version string)
  self.logger = atomic.logger.new(prefix)
  self._configuration = atomic.class.new(Configuration, metadata.configuration or {}, self)

  self:addRegistry()
  self:addLanguageFromMetadata()
end

---@private
function Package:__tostring()
  return "Package [" .. tostring(self:getId()) ..  "][" .. tostring(self:getVersionFullString()) .. "]"
end

---@alias Atomic.Package.RegistryCategories "events" | "binds" | "classes" | "commands" | "netschemas" | "netlisteners" | "webviews"
---@type table<Atomic.Package.RegistryCategories, {[1]: fun(Atomic.Package, any, any), [2]: fun(Atomic.Package, any, any)}>
local systemRegistry = {
  events = {
    function(self, eventId, listener) hook.Add(eventId, self:formatUniversalId(eventId), function(...) return listener(self, ...) end) end,
    function(self, eventId) hook.Remove(eventId, self:formatUniversalId(eventId)) end
  },
  binds = {
    function(_, _, data)
      local regId = atomic.bind.bind(data.key, data.callback)
      data.registrationId = regId
    end,
    function(_, index, data) atomic.bind.unbind(data.registrationId) end
  },
  commands = {
    function(_, name, command) atomic.command.add(name, command) end,
    function(_, name) atomic.command.remove(name) end
  },
  netschemas = {
    function(_, _, schema) atomic.network.register(schema) end,
    function(_, _, schema) atomic.network.unregister(schema._name) end
  },
  netlisteners = {
    function(self, schemaName, schema) atomic.network.listen(self:formatUniversalId(schemaName), schema) end,
    function(self, schemaName) atomic.network.unlisten(self:formatUniversalId(schemaName)) end
  },
  webviews = {
    function(self, _, webview) atomic.webview.register(webview, self) end,
    function(self, name) atomic.webview.unregister(name, self) end
  }
}

---@private
function Package:addRegistry()
  self._registry = atomic.class.new(PackageRegistry, self)

  self._registry:addCategory("classes",
    function(self, _, class) atomic.class.register(class, self) end,
    function(self, className) atomic.class.unregister(className, self) end
  )

  if (self:isSystem()) then
    self._state = {}

    for name, tab in pairs(systemRegistry) do
      self._registry:addCategory(name, tab[1], tab[2])
    end
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
---@param category Atomic.Package.RegistryCategories
---@param index string | integer
---@param value any
function Package:register(category, index, value)
  self._registry:set(category, index, value)
end

---@private
---@param category Atomic.Package.RegistryCategories
---@param index string | integer
function Package:unregister(category, index)
  self._registry:set(category, index)
end

---@private
function Package:load()
  local instant = atomic.time.newInstant()
  local files = self._metadata.files

  if (not files) then
    return self.logger:err("no files to include")
  end

  self:include(files.menu)

  self:enable()
  self.logger:debug("%s loaded successfully for %sms", self, instant:elapsed():as_millis())
end

---@private
---@param files string[]
function Package:include(files)
  if (not files) then
    return
  end

  local include = atomic.loader.include

  local dir = self._metadata.files.dir
  dir = dir and dir .. "/" or ""

  for _, filename in ipairs(files) do
    filename = (filename:sub(-4) == ".lua" and filename or filename .. ".lua")
    include(self._metadata._path .. "/" .. dir .. filename)
  end
end

---@private
function Package:unload()
  self:disable()
  self.logger:debug("%s unloaded successfully", self)
end

--- Enable/Disable

---@private
function Package:enable()
  self._registry:enable()

  self:setEnabled(true)
  self:emitLocalEvent("onEnabled")
end

local removePhrase = atomic.i18n.removePhrase

---@private
function Package:disable()
  self:emitLocalEvent("onDisable")

  self._registry:disable()

  local localization = self._metadata.language

  -- todo why it is not in registry?
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

  self:setEnabled(false)
end

--- Metadata

---@private
function Package:setEnabled(boolean)
  self._isEnabled = boolean
end

---@return boolean
function Package:isEnabled()
  return self._isEnabled
end

---@return string
function Package:getId()
  return self._metadata.id
end

--- Example: 1.0.0
---@return string
function Package:getVersionString()
  return self._coreVersion
end

--- Example: 1.0.0-rc.1+build.18
---@return string
function Package:getVersionFullString()
  return self._version
end

---@return Atomic.SemanticVersion
function Package:getVersion()
  local version = self._metadata.version
  ---@cast version Atomic.SemanticVersion
  return version
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
function Package:getHomepageUrl()
  return self._metadata.homepageUrl
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

---@return Atomic.Logger
function Package:getLogger()
  return self.logger
end

---@private
function Package:getFiles()
  return self._metadata.files.menu or {}
end

--- ```lua
--- local config = package:getConfiguration()
--- assert(config:get("someKey"), "hello, world")
--- ```
---@return Atomic.Package.Configuration
function Package:getConfiguration()
  return self._configuration
end

---@protected
---@param id string
---@return string?
function Package:getDependencyVersionByState(id)
  local dependencies = self._metadata.dependencies
  local stateDependencies = dependencies and dependencies.menu
  local depVersionData = stateDependencies and stateDependencies[id]

  ---@diagnostic disable-next-line
  return istable(depVersionData) and depVersionData.version or depVersionData
end

---@param id string
---@generic T: Atomic.Package
---@return T?
function Package:getDependency(id)
  local version = self:getDependencyVersionByState(id)

  if (not version) then
    return self.logger:err("dependency `%s` is not specified in metadata file", id)
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
local addPhrase = atomic.i18n.addPhrase

---@param language string
---@param phraseId string
---@param ...any?
---@return string
function Package:getPhrase(language, phraseId, ...)
  return getPhrase(language, self:formatUniversalId(phraseId), ...)
end

---@param language string
---@param phrase string
---@param translate string
function Package:addPhrase(language, phrase, translate)
  addPhrase(language, self:formatUniversalId(phrase), translate)
end

--- Binds

---@param callback fun(player: Player)
---@param key number
---@return integer localId
function Package:bind(callback, key)
  local id = self._registry:length("binds") + 1

  self:register("binds", id, {
    key = key,
    callback = callback,
    registrationId = 0
  })

  return id
end

---@param localId integer
function Package:unbind(localId)
  self:unregister("binds", localId)
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

---@alias Atomic.Package.Events "onEnabled" | "onDisable" | "onDatabaseConnected" | "CouldPlayerExecuteCommand" | "onAtomicPackageConfigChanged" | "onAtomicLoaded"

---@param id string
---@return string
function Package:formatUniversalId(id)
  return ("atomic:%s:%s:%s"):format(self._metadata.id, self._version, id)
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
function Package:emitLocalEvent(name, ...)
  local listener = self._registry:lookup("events", name)

  if (not listener) then
    return
  end

  listener(self, ...)
end

Package.getEvent = Package.formatUniversalId

--- Starts a event that is associated with the current package.
---@protected
---@param name string
---@vararg any
---@return any
function Package:emitEvent(name, ...)
  return hook.Run(self:getEvent(name), ...)
end

--- Classes

--- Creates new class and automatically registeres it
---@param name string
---@param parent? Atomic.Class
---@generic T: Atomic.Class
---@return T
function Package:class(name, parent)
  local class = atomic.class.create(name, parent)

  self:register("classes", class:getClassName(), class)

  return class
end

--- Return package's registered class
---@param name string
function Package:getClass(name)
  return self._registry:lookup("classes", name)
end

--- Network

--- Creates new webview and automatically registeres it
---@param name string
---@param autoSpawn? boolean = true
---@return Atomic.WebView
function Package:webview(name, autoSpawn)
  local folder = self._metadata.id .. "@" .. self._version
  local path = "asset://garrysmod/resource/webviews/" .. folder

  local webview = atomic.webview.new(name, path, autoSpawn)

  self:register("webviews", webview._name, webview)

  return webview
end

--- Return package's registered webview
---@param name string
---@return Atomic.WebView
function Package:getWebview(name)
  return self._registry:lookup("webviews", name)
end