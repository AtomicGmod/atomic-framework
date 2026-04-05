---@type Atomic.Package.InternalMetadata
local metadata = atomic.class.pseudo._metadata
metadata.title = "Atomic Framework"
metadata.kind = "system"
metadata.documentation = "https://deepwiki.com/TeamMeadows/atomic-framework"
metadata.icon = "https://github.com/TeamMeadows/atomic-framework/raw/production/assets/logo.png"
metadata.files = {}
metadata.configuration = {
  logLevel = {
    type = "string",
    default = "info"
  },
  mysqlAutoconnect = {
    type = "boolean",
    default = true
  },
  mysqlMultistatements = {
    type = "boolean",
    default = false
  }
}

local package = atomic.package.new(metadata)

--- 1. setup configuration

local config = package:getConfiguration()

config:subscribe(atomic.logger.updateLevel, "logLevel")

atomic._config.mysqlAutoconnect = config:get("mysqlAutoconnect")
atomic._config.mysqlMultistatements = config:get("mysqlMultistatements")

atomic.class.pseudo = package