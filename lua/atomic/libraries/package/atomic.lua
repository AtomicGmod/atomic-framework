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

local package = atomic.package.new(metadata)
package:load()

atomic.class.pseudo = package

--- 1. setup configuration

local config = package:getConfiguration()

config:subscribe(atomic.logger.updateLevel, "logLevel")

atomic._config.mysqlAutoconnect = config:get("mysqlAutoconnect")
atomic._config.mysqlMultistatements = config:get("mysqlMultistatements")