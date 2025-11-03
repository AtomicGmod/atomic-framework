atomic.time = atomic.time or {}

---@include
atomic.loader.shared("duration.lua")
atomic.loader.shared("instant.lua")

local class = atomic.class
local new = class.new

local Instant = class.get("Instant")
local Duration = class.get("Duration")

---@param time? number
---@return Atomic.Time.Instant
function atomic.time.newInstant(time)
  return new(Instant, time)
end

---@param secs integer
---@param nanos integer
---@return Atomic.Time.Duration
function atomic.time.newDuration(secs, nanos)
  return new(Duration, secs, nanos)
end