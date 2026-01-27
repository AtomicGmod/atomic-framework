-- A class for measuring time,
-- close to the Rust (std::time::Instant) implementation

local class = atomic.class
local new = class.new

---@type Atomic.Time.Duration
local Duration = class.get("Duration")

---@class Atomic.Time.Instant: Atomic.Class
---@field private _time number
local Instant = class.create("Instant")
class.register(Instant, atomic.class.pseudo)

---@param time? number
function Instant:init(time)
  self._time = time or SysTime()
end

---@param earlier Atomic.Time.Instant
---@return Atomic.Time.Duration
function Instant:duration_since(earlier)
  local delta = self._time - earlier._time

  if delta < 0 then
    error("Instant:duration_since called with later Instant")
  end

  local secs = math.floor(delta)
  local nanos = (delta - secs) * 1e9

  return new(Duration, secs, nanos)
end

---@return Atomic.Time.Duration
function Instant:elapsed()
  return new(Instant):duration_since(self)
end

---@private
---@param dur Atomic.Time.Duration
---@return Atomic.Time.Instant
function Instant:__add(dur)
  return new(Instant, self._time + dur:as_secs() + dur:as_nanos() / 1e9)
end

---@private
---@param other Atomic.Time.Instant
---@return Atomic.Time.Duration
function Instant:__sub(other)
  return self:duration_since(other)
end