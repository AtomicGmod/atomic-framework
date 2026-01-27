-- Rust-like Duration class

local class = atomic.class
local new = class.new

---@class Atomic.Time.Duration: Atomic.Class
---@field private _secs integer
---@field private _nanos integer
local Duration = class.create("Duration")
class.register(Duration, atomic.class.pseudo)

---@param secs integer
---@param nanos number
function Duration:init(secs, nanos)
  -- normalize nanoseconds so they're always in [0, 1e9)
  -- convert overflow into extra seconds or borrow from seconds if negative
  if nanos >= 1e9 then
    local extra = math.floor(nanos / 1e9)
    secs = secs + extra
    nanos = nanos - extra * 1e9
  elseif nanos < 0 then
    local borrow = math.ceil(-nanos / 1e9)
    secs = secs - borrow
    nanos = nanos + borrow * 1e9
  end

  self._secs = secs or 0
  self._nanos = nanos or 0
end

---@return number
function Duration:as_secs()
  return self._secs
end

---@return number
function Duration:as_millis()
  return self._secs * 1000 + math.floor(self._nanos / 1e6)
end

---@return number
function Duration:as_micros()
  return self._secs * 1e6 + math.floor(self._nanos / 1e3)
end

---@return number
function Duration:as_nanos()
  return self._secs * 1e9 + math.floor(self._nanos)
end

---@private
---@param other Atomic.Time.Duration
---@return Atomic.Time.Duration
function Duration:__add(other)
  return new(Duration, 0, self:as_nanos() + (istable(other) and other:as_nanos() or other))
end

---@private
---@param other Atomic.Time.Duration
---@return Atomic.Time.Duration
function Duration:__sub(other)
  return new(Duration, 0, self:as_nanos() - (istable(other) and other:as_nanos() or other))
end

---@private
---@param other Atomic.Time.Duration
---@return Atomic.Time.Duration
function Duration:__mul(other)
  return new(Duration, 0, self:as_nanos() * (istable(other) and other:as_nanos() or other))
end

---@private
---@param other Atomic.Time.Duration
---@return Atomic.Time.Duration
function Duration:__div(other)
  return new(Duration, 0, self:as_nanos() / (istable(other) and other:as_nanos() or other))
end

---@private
---@param other Atomic.Time.Duration
---@return boolean
function Duration:__lt(other)
  return self:as_nanos() < (istable(other) and other:as_nanos() or other)
end

---@private
---@param other Atomic.Time.Duration
---@return boolean
function Duration:__le(other)
  return self:as_nanos() <= (istable(other) and other:as_nanos() or other)
end

---@private
---@param other Atomic.Time.Duration
---@return boolean
function Duration:__eq(other)
  return self:as_nanos() == other:as_nanos()
end