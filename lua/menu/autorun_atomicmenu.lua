atomic = atomic or {
  meta = {
    author = "smokingplaya",
    versionName = "Cherry",
    version = "1.0.0-rc.4+menu-build",
  },
  _config = {},
}

file.CreateDir("atomic")

---@include
include("atomic/libraries/class.lua")
include("atomic/libraries/logger.lua")
include("atomic/libraries/loader.lua")

atomic.log = atomic.logger.new("atomic")

local includeMenu = atomic.loader.include
---@include
-- utils
includeMenu("atomic/utils/table.lua")
includeMenu("atomic/utils/debug.lua")
includeMenu("atomic/utils/coroutine.lua")
includeMenu("atomic/utils/global.lua")
-- libraries
includeMenu("atomic/libraries/semver.lua")
includeMenu("atomic/libraries/i18n.lua")
includeMenu("atomic/libraries/primitives/common.lua")
includeMenu("atomic/libraries/time/common.lua")
includeMenu("atomic/libraries/benchmark.lua")
includeMenu("atomic/libraries/webview/class.lua")
includeMenu("atomic/libraries/webview/common.lua")
includeMenu("atomic/libraries/webview/basicfuncs.lua")
includeMenu("atomic/libraries/command/common.lua")
-- package loading should be one of the latest
includeMenu("atomic/libraries/package/common.lua")
includeMenu("atomic/utils/aliases.lua")

hook.Run("onAtomicPrePackageLoading")

local package = atomic.package
local packages = package.find("lua/menu/atomic/packages")
---@type Atomic.Time.Instant
local packageLoadingTime = Instant()

package.loadMany(packages)
atomic.log:info("Atomic Framework %s %s has loaded %s packages for %sms", atomic.meta.version, atomic.meta.versionName, #packages, packageLoadingTime:elapsed():as_millis())