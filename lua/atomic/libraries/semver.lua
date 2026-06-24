atomic.semver = {}

---@alias Atomic.SemanticVersion.PreRelease "rc" | "beta" | "alpha"

---@class Atomic.SemanticVersion: Atomic.Class
---@field private base string
---@field private major number
---@field private minor number
---@field private patch number
---@field private prerelease? { [1]: Atomic.SemanticVersion.PreRelease, [2]?: number }
---@field private build? { [1]: string, [2]?: string }
local SemanticVersion = atomic.class.create("SemanticVersion")
atomic.class.register(SemanticVersion, atomic.class.pseudo)

--- * 1.0.0
--- * 1.3.0-rc.1
--- * 1.3.0-alpha
--- * 1.3.0-rc.1+build.4
---@param version string
function SemanticVersion:init(version)
  -- that is not really cleanest solution, but that works and works pretty good
  local core, pre, build = version:match("^(%d+%.%d+%.%d+)%-(%w+%.?%d*)%+?([%w%.%-]*)$")

  if (not core) then
    core, pre = version:match("^(%d+%.%d+%.%d+)%-(%w+%.?%d*)$")
  end

  if (not core) then
    core, build = version:match("^(%d+%.%d+%.%d+)%+([%w%.%-]+)$")
  end

  if (not core) then
    core = version:match("^(%d+%.%d+%.%d+)$")
  end

  local major, minor, patch = core:match("(%d+)%.(%d+)%.(%d+)")

  if (not major or not minor or not patch) then
    error("no major/minor/patch found!")
  end

  self.base = version
  self.major = tonumber(major) or 0
  self.minor = tonumber(minor) or 0
  self.patch = tonumber(patch) or 0

  if (pre) then
    local tag, num = pre:match("^(%a+)%.?(%d*)$")

    if (tag) then
      self.prerelease = { tag, num ~= "" and tonumber(num) or nil }
    end
  end

  if (build and build ~= "") then
    local a, b = build:match("^([%w%-]+)%.?([%w%-]*)$")
    self.build = { a, b ~= "" and b or nil }
  end
end

---@return boolean
function SemanticVersion:isStableRelease()
  return self.prerelease == nil and self.major > 0
end

---@return number
function SemanticVersion:getMajor()
  return self.major
end

---@return number
function SemanticVersion:getMinor()
  return self.minor
end

---@return number
function SemanticVersion:getPatch()
  return self.patch
end

--- ```lua
--- print(version:getPreRelease()) -- rc 3
--- ```
---@return Atomic.SemanticVersion.PreRelease?, number?
function SemanticVersion:getPreRelease()
  local prerelease = self.prerelease

  if (not prerelease) then
    return
  end

  return prerelease[1], prerelease[2]
end

---@return string
function SemanticVersion:getString()
  return self.base
end

--- "1.0.0-rc.1+build.18"
---@return string
function SemanticVersion:toString()
  local result = ("%d.%d.%d"):format(self.major, self.minor, self.patch)

  local prerelease = self.prerelease
  if (prerelease) then
    result = result .. "-" .. self.prerelease[1]

    local num = prerelease[2]
    if (num) then
      result = result .. "." .. num
    end
  end

  local build = self.build
  if (build) then
    result = result .. "+" .. build[1]

    local b = self.build[2] -- not really know how to name it
    if (b) then
      result = result .. "." .. b
    end
  end

  return result
end

--- Returns core version
---@return string
function SemanticVersion:getCore()
  return tostring(self.major) .. "." .. tostring(self.minor) .. "." .. tostring(self.patch)
end

---@private
function SemanticVersion:__tostring()
  return ("SemanticVersion %s"):format(self:toString())
end

local prereleasesOrder = {
  alpha = 1,
  beta = 2,
  rc = 3
}

---@param a number
---@param b number
---@return -1 | 1 | 0
local function compare(a, b)
  if (a < b) then
    return -1
  end

  if (a > b) then
    return 1
  end

  return 0
end

---@param a Atomic.SemanticVersion
---@param b Atomic.SemanticVersion
---@return -1 | 1 | 0
local function comparePreRelease(a, b)
  if (not a and not b) then
    return 0
  end

  if (not a) then
    return 1
  end

  if (not b) then
    return -1
  end

  local tagA = prereleasesOrder[a[1]] or 0
  local tagB = prereleasesOrder[b[1]] or 0

  if (tagA ~= tagB) then
    return compare(tagA, tagB)
  end

  local numA = a[2] or 0
  local numB = b[2] or 0

  return compare(numA, numB)
end

---@private
---@param other Atomic.SemanticVersion | string
---@return boolean
function SemanticVersion:__lt(other)
  other = isstring(other) and atomic.class.new(SemanticVersion, other) or other

  local result = compare(self.major, other.major)
  if (result ~= 0) then
    return result < 0
  end

  result = compare(self.minor, other.minor)
  if (result ~= 0) then
    return result < 0
  end

  result = compare(self.patch, other.patch)
  if (result ~= 0) then
    return result < 0
  end

  result = comparePreRelease(self.prerelease, other.prerelease)

  return result < 0
end

---@private
---@param other Atomic.SemanticVersion | string
---@return boolean
function SemanticVersion:__eq(other)
  other = isstring(other) and atomic.class.new(SemanticVersion, other) or other

  return self.major == other.major
    and self.minor == other.minor
    and self.patch == other.patch
    and comparePreRelease(self.prerelease, other.prerelease) == 0
end

---@private
---@param other Atomic.SemanticVersion | string
---@return boolean
function SemanticVersion:__le(other)
  other = isstring(other) and atomic.class.new(SemanticVersion, other) or other
  return self == other or self < other
end

---@param version string
---@return Atomic.SemanticVersion
function atomic.semver.new(version)
  return atomic.class.new(SemanticVersion, version)
end

local metadataVersion = atomic.class.pseudo._metadata.version
if (type(metadataVersion) == "string") then
  atomic.class.pseudo._metadata.version = atomic.semver.new(metadataVersion)
end

---@type table<string, fun(version: Atomic.SemanticVersion, base: Atomic.SemanticVersion): boolean>
local prefixActions = {
  [""] = function(version, base) return version == base end,
  ["~"] = function(version, base)
    if (version:getMajor() ~= base:getMajor()) then
      return false
    end

    if (version:getMinor() ~= base:getMinor()) then
      return false
    end

    return version >= base
  end,
  ["^"] = function(version, base)
    local major = base:getMajor()
    local minor = base:getMinor()
    local patch = base:getPatch()

    if (major > 0) then
      if (version:getMajor() ~= major) then
        return false
      end

      return version >= base
    end

    if (minor > 0) then
      if (version:getMajor() ~= 0) then
        return false
      end

      if (version:getMinor() ~= minor) then
        return false
      end

      return version >= base
    end

    if (version:getMajor() ~= 0) then
      return false
    end

    if (version:getMinor() ~= 0) then
      return false
    end

    if (version:getPatch() ~= patch) then
      return false
    end

    return version >= base
  end
}

---@param versionInstance Atomic.SemanticVersion | string
---@param constraint string
---@return boolean
function atomic.semver.isSuitable(versionInstance, constraint)
  if (constraint == "*") then
    return true
  end

  local prefix, version = constraint:match("^([~^]?)(.+)$")

  if (not version) then
    return false
  end

  local action = prefixActions[prefix]
  local base = atomic.class.new(SemanticVersion, version)

  ---@diagnostic disable-next-line
  return action and action(isstring(versionInstance) and atomic.semver.new(versionInstance) or versionInstance, base) or false
end