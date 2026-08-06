-- A class for contain timestamp,
-- close to the Rust (chrono::NaiveDateTime) implementation

local class = atomic.class

---@class Atomic.Time.NaiveDateTime: Atomic.Class
---@field private year integer
---@field private month integer
---@field private day integer
---@field private hour integer
---@field private minute integer
---@field private second integer
local NaiveDateTime = class.create("NaiveDateTime")
class.register(NaiveDateTime, atomic.class.pseudo)

---@param year integer
---@param month integer
---@param day integer
---@param hour integer
---@param minute integer
---@param second integer
function NaiveDateTime:init(year, month, day, hour, minute, second)
  self.year = year
  self.month = month
  self.day = day
  self.hour = hour
  self.minute = minute
  self.second = second
end

---@private
function NaiveDateTime:__tostring()
  -- iso 8601
  return "NaiveDateTime [" .. tostring(self:format("%Y-%m-%dT%H:%M:%S")) .. "]"
end

--- Returns UNIX Timestamp without current timezone
---@return number
function NaiveDateTime:getTimestamp()
  return os.time({
    year = self.year,
    month = self.month,
    day = self.day,
    hour = self.hour,
    min = self.minute,
    sec = self.second
  })
end

---@see https://wiki.facepunch.com/gmod/os.date
---@return string
function NaiveDateTime:format(formatStr)
  ---@type string
  return os.date(formatStr, self:getTimestamp())
end

--- Formats the time string as ISO 8601
---
--- Output example `2026-03-12T14:25:30`
---@return string
function NaiveDateTime:getIso8601()
  return self:format("%Y-%m-%dT%H:%M:%S")
end

---@param year integer
function NaiveDateTime:setYear(year)
  self.year = year
end

---@param month integer
function NaiveDateTime:setMonth(month)
  self.month = math.Clamp(month, 1, 12)
end

---@param day integer
function NaiveDateTime:setDay(day)
  self.day = math.Clamp(day, 1, 31)
end

---@param hour integer
function NaiveDateTime:setHour(hour)
  self.hour = math.Clamp(hour, 0, 24)
end

---@param minute integer
function NaiveDateTime:setMinute(minute)
  self.minute = math.Clamp(minute, 0, 60)
end

---@param second integer
function NaiveDateTime:setSecond(second)
  self.second = math.Clamp(second, 0, 60)
end

---@return integer
function NaiveDateTime:getYear()
  return self.year
end

---@return integer
function NaiveDateTime:getMonth()
  return self.month
end

---@return integer
function NaiveDateTime:getDay()
  return self.day
end

---@return integer
function NaiveDateTime:getHour()
  return self.hour
end

---@return integer
function NaiveDateTime:getMinute()
  return self.minute
end

---@return integer
function NaiveDateTime:getSecond()
  return self.second
end