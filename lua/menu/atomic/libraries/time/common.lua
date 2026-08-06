atomic.time = atomic.time or {}

---@include
atomic.loader.include("duration.lua")
atomic.loader.include("instant.lua")
atomic.loader.include("naivedatetime.lua")

local class = atomic.class
local new = class.new

local Instant = class.get("Instant")
local Duration = class.get("Duration")
local NaiveDateTime = class.get("NaiveDateTime")

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

atomic.time.naiveDateTime = {}

---@param secs integer
---@return Atomic.Time.NaiveDateTime
function atomic.time.naiveDateTime.fromTimestamp(secs)
  local dateData = os.date("!*t", secs)
  return new(NaiveDateTime, dateData.year, dateData.month, dateData.day, dateData.hour, dateData.min, dateData.sec)
end

---@param str string ISO 8601 formatted
---@return Atomic.Time.NaiveDateTime
function atomic.time.naiveDateTime.fromIso8601(str)
  local year, month, day, hour, min, sec = str:match("(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)")
  return new(NaiveDateTime,  tonumber(year), tonumber(month), tonumber(day), tonumber(hour), tonumber(min), tonumber(sec))
end