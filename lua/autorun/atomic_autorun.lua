atomic = {
  meta = {
    author = "smokingplaya",
    version_name = "Ackee",
    version = "0.3.0",
  }
}

local start = SysTime()

local function includeSh(path)
  if (SERVER) then
    AddCSLuaFile(path)
  end

  include(path)
end

---@include
includeSh("atomic/libraries/class.lua")
includeSh("atomic/libraries/logger.lua")
includeSh("atomic/libraries/loader.lua")

local loader = atomic.loader
local client, shared, server = loader.client, loader.shared, loader.server
-- utils
shared("atomic/utils/table.lua")
shared("atomic/utils/coroutine.lua")
shared("atomic/utils/semver.lua")
-- libraries
shared("atomic/libraries/bind.lua")
client("atomic/libraries/web.lua")
server("atomic/libraries/command.lua")
server("atomic/libraries/mysql.lua")
server("atomic/libraries/git.lua")
-- package loading should be latest
shared("atomic/libraries/package/class.lua")
shared("atomic/libraries/package/common.lua")

atomic.log = atomic.logger.new("atomic")

local package = atomic.package
local packages = package.find("atomic/packages")

---@cast packages Atomic.Package

package.loadMany(packages)

atomic.log:info("Atomic Framework %s has been loaded for %sms", atomic.meta.version_name, math.floor((SysTime() - start) * 1000 + 0.5))