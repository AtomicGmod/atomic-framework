atomic = {
  meta = {
    author = "smokingplaya",
    versionName = "Cherry",
    version = "1.0.0-alpha.5",
  },
  _config = {}
}

file.CreateDir("atomic")

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

atomic.log = atomic.logger.new("atomic")

local loader = atomic.loader
local client, shared, server = loader.client, loader.shared, loader.server
---@include
-- utils
shared("atomic/utils/table.lua")
shared("atomic/utils/debug.lua")
shared("atomic/utils/coroutine.lua")
shared("atomic/utils/global.lua")
-- libraries
shared("atomic/libraries/semver.lua")
shared("atomic/libraries/i18n.lua")
shared("atomic/libraries/bind.lua")
shared("atomic/libraries/network/common.lua")
shared("atomic/libraries/time/common.lua")
shared("atomic/libraries/benchmark.lua")
client("atomic/libraries/webview/class.lua")
client("atomic/libraries/webview/common.lua")
client("atomic/libraries/webview/basicfuncs.lua")
server("atomic/libraries/command/common.lua")
-- package loading should be one of the latest
shared("atomic/libraries/package/common.lua")
server("atomic/libraries/mysql.lua")
shared("atomic/utils/aliases.lua")

local packageLoadingStart = SysTime()

local package = atomic.package
local packages = package.find("atomic/packages")

package.loadMany(packages)

atomic.log:info("Atomic Framework %s %s has been loaded for %sms (%s packages loaded for %sms)", atomic.meta.version, atomic.meta.versionName, math.floor((SysTime() - start) * 1000 + 0.5), #atomic.package._list, math.floor((SysTime() - packageLoadingStart) * 1000 + 0.5))