---@type Atomic.Package.InternalMetadata
local metadata = atomic.class.pseudo._metadata
metadata.title = "Atomic Framework"
metadata.kind = "system"
metadata.documentation = "https://deepwiki.com/TeamMeadows/atomic-framework"
metadata.icon = "https://github.com/TeamMeadows/atomic-framework/raw/production/assets/logo.png"
metadata.files = {}
metadata.configuration = {
  shared = {
    logLevel = {
      type = "string",
      default = "info"
    },
  },
  server = {
    mysqlAutoconnect = {
      type = "boolean",
      default = true
    },
    mysqlMultistatements = {
      type = "boolean",
      default = false
    }
  }
}

---@class InternalAtomic: Atomic.Package
local package = atomic.package.new(metadata)
local logger = package.logger
package:load()

atomic.class.pseudo = package
--- #1 Configuration setup
local config = package:getConfiguration()

config:subscribe(atomic.logger.updateLevel, "logLevel")

atomic._config.mysqlAutoconnect = config:get("mysqlAutoconnect")
atomic._config.mysqlMultistatements = config:get("mysqlMultistatements")

if (atomic.mysql) then
	atomic.mysql.setMultistatements(atomic._config.mysqlMultistatements)
end

-- #2 Configuration variables synchronization setup

---@class InternalAtomic.Network.ReqConSync.Server: Atomic.Network.Message
---@field id string
---@field version string
---@field variable string

---@class InternalAtomic.Network.ReqConSync.Client: Atomic.Network.Message
---@field value string

-- request config synchronization
-- pipeline:  client -> yo server i got some variable (*variable*) of package (*id*, *version*) set to default value, lemme know' if you changed it so i can apply changes
--            server -> yo mane look i changed the value of this variable to (new *value*)
package:networkSchema("ReqConSync")
  :server("id", "string")
  :server("version", "string")
  :server("variable", "string")
  :client("value", "string")

---@class InternalAtomic.Network.NotConChan.Client: Atomic.Network.Message
---@field id string
---@field version string
---@field variable string

-- notify config change
-- pipeline:  server -> yo mane i got some configuration variable change, check it out
--            client -> hmmmm looks like i should update this mf!! ReqConSync(id, version, variable)
package:networkSchema("NotConChan")
  :client("id", "string")
  :client("version", "string")
  :client("variable", "string")

if (CLIENT) then
  --- Sends `ReqConSync` to the server
  ---@async
  ---@param requestedPackage Atomic.Package
  ---@param variable string
  local function requestConfigSync(requestedPackage, variable)
    local response = package:sendNetworkMessageAsync("ReqConSync", {
      id = requestedPackage:getId(),
      version = requestedPackage:getVersionFullString(),
      variable = variable
    }, nil, true)

    logger:trace("configuration variable `%s` of a package %s synchronization", variable, requestedPackage)

    if (response == "timeout") then
      return logger:trace("%s configuration variable `%s` synchronization error: server did not response", requestedPackage, variable)
    end

    ---@cast response InternalAtomic.Network.ReqConSync.Client

    logger:debug("setting configuration variable `%s` of %s to `%s`", variable, requestedPackage, response.value)

    ---@cast response InternalAtomic.Network.ReqConSync.Client
    local config = requestedPackage:getConfiguration()
    config:set(variable, response.value)

    logger:trace("configuration variable `%s` of a package %s has been synchronized successfuly", variable, requestedPackage)
  end

  --- Checks an configuration variable, and sends `ReqConSync` if finds variables to synchronize
  ---@param package Atomic.Package
  ---@param variable string
  local function checkPackageVariable(package, variable)
    local config = package:getConfiguration()
    local default = config:getDefault(variable)
    local entry = config:getEntry(variable)

    -- if current value != default then we ask server of current value
    if (not entry or entry.value ~= default) then
      return
    end

    async(function()
      requestConfigSync(package, variable)
    end)
  end

  --- Checks all configuration variables of a package
  ---@param package Atomic.Package
  local function checkPackage(package)
    local config = package:getConfiguration()

    if (config:getEntriesCount() == 0) then
      return
    end

    local variables = config:getEntries()

    for variable in pairs(variables) do
      checkPackageVariable(package, variable)
    end
  end

  ---@param message InternalAtomic.Network.NotConChan.Client
  package:onNetworkMessage(function(self, message)
    local package = atomic.package.get(message.id, message.version)

    if (not package) then
      return
    end

    checkPackageVariable(package, message.variable)
  end, "NotConChan")

  package:listen(function(self)
    self.logger:trace("starting configuration synchronization process")

    for _, package in atomic.package.list() do
      checkPackage(package)
    end
  end, "InitPostEntity")
end

if (SERVER) then
  ---@param message InternalAtomic.Network.ReqConSync.Server
  package:onNetworkMessage(function(self, message)
    self.logger:trace("player %s want to synchronize configuration variable `%s` of Package [%s][%s]", message:getSender(), message.variable, message.id, message.version)

    local package = atomic.package.get(message.id, message.version)

    if (not package) then
      return
    end

    local config = package:getConfiguration()
    local variables = config:getEntries()
    local variable = message.variable
    local variableData = variables[variable]

    if (not variableData or variableData.sync == false or config:getDefault(variable) == variableData.value) then
      ---@diagnostic disable-next-line redundant-return-value
      return variableData and self.logger:trace("there is no need in synchronization: sync(%s) default(%s) current(%s)", variableData.sync, config:getDefault(variable), variableData.value)
        or self.logger:trace("there is no need in synchronization: variableData == nil")
    end

    message:reply({
      value = tostring(variableData.value)
    })
  end, "ReqConSync")

  ---@param affectedPackage Atomic.Package
  ---@param variable string
  ---@param entry Atomic.Package.Configuration.InternalEntry
  package:listen(function(self, affectedPackage, variable, entry)
    if (entry.sync == false or not affectedPackage:isEnabled() or affectedPackage:isServerOnly()) then
      return
    end

    self:broadcastNetworkMessage("NotConChan", {
      id = affectedPackage:getId(),
      version = affectedPackage:getVersionFullString(),
      variable = variable
    })
  end, "onAtomicPackageConfigChanged")
end