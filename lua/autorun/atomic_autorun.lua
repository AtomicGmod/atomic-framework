atomic = atomic or {
  meta = {
    author = "smokingplaya",
    versionName = "Cherry",
    version = "1.0.0-rc.2",
  },
  _config = {},
  _isGamemodeLoaded = false
}

file.CreateDir("atomic")

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
shared("atomic/libraries/primitives/common.lua")
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

local package = atomic.package
local packages = package.find("atomic/packages")
---@type Atomic.Time.Instant
local packageLoadingTime

local function loadPackages()
  package.loadMany(packages)
  atomic.log:info("Atomic Framework %s %s has loaded %s packages for %sms", atomic.meta.version, atomic.meta.versionName, #packages, packageLoadingTime:elapsed():as_millis())
end

local function appendGamemodePackages()
	local gamemode = gmod.GetGamemode()
	local dir = gamemode and gamemode.packageDir
	local gamemodePackages = dir and package.find(dir)

	if (not gamemodePackages) then
		return
	end

	for _, gamemodePackage in ipairs(gamemodePackages) do
		packages[#packages + 1] = gamemodePackage
	end
end

local function onGamemodeLoaded()
	atomic._isGamemodeLoaded = true
	packageLoadingTime = Instant()

	appendGamemodePackages()
	loadPackages()
end

local function init()
	if (atomic._isGamemodeLoaded) then
		onGamemodeLoaded()
	else
		hook.Add("OnGamemodeLoaded", "atomic:" .. atomic.meta.version, onGamemodeLoaded)
	end
end

init()