atomic.logger = atomic.logger or {
  ---@private
  ---@type table<string, Atomic.Logger>
  _storage = {},
}

---@class Atomic.Logger: Atomic.Class
---@field prefix string
local loggerClass = atomic.class.create("Logger")
atomic.class.register(loggerClass, atomic.class.pseudo)

--- Creates new instance of Logger
---@param prefix string
---@return Atomic.Logger
function atomic.logger.new(prefix)
  local cache = atomic.logger._storage[prefix]

  if (cache) then
    return cache
  end

  local logger = atomic.class.new(loggerClass, {}, prefix)
  ---@cast logger Atomic.Logger

  atomic.logger._storage[prefix] = logger

  return logger
end

local function getcurrenttime()
  return os.date("%H:%M:%S")
end

local iswin = jit.os == "Windows"

-- colors
local white = iswin and Color(255, 255, 255) or "\27[37m"
local info = iswin and Color(0, 255, 0) or "\27[32m"
local debug = iswin and Color(0, 255, 255) or "\27[36m"
local warn = iswin and Color(255, 255, 0) or "\27[33m"
local err = iswin and Color(255, 0, 0) or "\27[31m"

local levels = {
  DEBUG = 1,
  INFO = 2,
  WARN = 3,
  ERR = 4,
}

local logvar = CreateConVar("atomic_log", "INFO", FCVAR_ARCHIVE + FCVAR_PROTECTED, "Minimum log level (INFO, DEBUG, WARN, ERR)")

---@param prefix string
function loggerClass:init(prefix)
  self.prefix = prefix
end

---@protected
---@param color Color | string
---@param level string
---@param message string
---@param ... any
function loggerClass:log(color, level, message, ...)
  local currentLevel = logvar:GetString():upper()
  local currentIdx = levels[currentLevel] or 1
  local msgIdx = levels[level] or 1

  if msgIdx < currentIdx then return end

  MsgC(white, "[", getcurrenttime(), " ", color, level, " ", white, self.prefix, "]", " ", string.format(message, ...))
  MsgN()
end

function loggerClass:info(message, ...)
  self:log(info, "INFO", message, ...)
end

function loggerClass:debug(message, ...)
  self:log(debug, "DEBUG", message, ...)
end

function loggerClass:warn(message, ...)
  self:log(warn, "WARN", message, ...)
end

function loggerClass:err(message, ...)
  self:log(err, "ERR", message, ...)
end