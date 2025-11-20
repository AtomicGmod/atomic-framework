atomic = {
  meta = {
    author = "smokingplaya",
    version_name = "Peach",
    version = "0.6.0",
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
---@include
-- utils
shared("atomic/utils/table.lua")
shared("atomic/utils/debug.lua")
shared("atomic/utils/coroutine.lua")
shared("atomic/utils/semver.lua")
shared("atomic/utils/global.lua")
-- libraries
shared("atomic/libraries/i18n.lua")
shared("atomic/libraries/bind.lua")
shared("atomic/libraries/network/common.lua")
shared("atomic/libraries/time/common.lua")
shared("atomic/libraries/benchmark.lua")
client("atomic/libraries/webview/class.lua")
client("atomic/libraries/webview/common.lua")
client("atomic/libraries/webview/basicfuncs.lua")
server("atomic/libraries/command/common.lua")
server("atomic/libraries/mysql.lua")
server("atomic/libraries/git.lua")
-- package loading should be latest
shared("atomic/libraries/package/common.lua")
shared("atomic/utils/aliases.lua")

atomic.log = atomic.logger.new("atomic")

local package = atomic.package
local packages = package.find("atomic/packages")
---@cast packages Atomic.Package[]

package.loadMany(packages)

atomic.log:info("Atomic Framework %s has been loaded for %sms", atomic.meta.version_name, math.floor((SysTime() - start) * 1000 + 0.5))