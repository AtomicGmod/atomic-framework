atomic.logger = atomic.logger or {
  ---@private
  ---@type table<string, Atomic.Logger>
  _storage = {},
}

---@class Atomic.Logger: Atomic.Class
---@field prefix string
local Logger = atomic.class.create("Logger")
atomic.class.register(Logger, atomic.class.pseudo)

--- Creates new instance of Logger
---@param prefix string
---@return Atomic.Logger
function atomic.logger.new(prefix)
  local cache = atomic.logger._storage[prefix]

  if (cache) then
    return cache
  end

  local logger = atomic.class.new(Logger, prefix)
  ---@cast logger Atomic.Logger

  atomic.logger._storage[prefix] = logger

  return logger
end

local function getcurrenttime()
  return os.date("%H:%M:%S")
end

-- colors
-- *client game console doesn't support the ANSI escape codes
local white = MENU_DLL and Color(255, 255, 255) or "\27[37m"
local trace = MENU_DLL and Color(128, 128, 128) or "\27[90m"
local debug = MENU_DLL and Color(0, 255, 255) or "\27[36m"
local info = MENU_DLL and Color(0, 255, 0) or "\27[32m"
local warn = MENU_DLL and Color(255, 255, 0) or "\27[33m"
local err = MENU_DLL and Color(255, 0, 0) or "\27[31m"

local levels = {
  TRACE = 1,
  DEBUG = 2,
  INFO = 3,
  WARN = 4,
  ERR = 5,
}

local logLevelFile = "atomic/loglevel.dat"
function atomic.logger.getCurrentLevel()
  return atomic._config.logLevel or file.Read(logLevelFile) or "info"
end

--- `Internal` function, you `probably` shouldn't use it
---@param levelName string
---@return boolean
function atomic.logger.isLevelExists(levelName)
  return levels[levelName:upper()] ~= nil
end

--- `Internal` function, you shouldn't use it
---@param level string
function atomic.logger.updateLevel(level)
  if (not atomic.logger.isLevelExists(level)) then
    return false
  end

  atomic._config.logLevel = level

  file.Write(logLevelFile, level)
end

atomic._config.logLevel = atomic.logger.getCurrentLevel()

---@private
function Logger:__tostring()
  return "Logger [" .. tostring(self.prefix) .. "]"
end

---@param prefix string
function Logger:init(prefix)
  self.prefix = prefix
end

-- not a magic number
local MAX_LEVEL_LENGTH = 5

---@protected
---@param color Color | string
---@param level string
---@param message string
---@param ... any
function Logger:log(color, level, message, ...)
  local currentLevel = atomic._config.logLevel:upper()
  local currentIdx = levels[currentLevel] or 1
  local msgIdx = levels[level] or 1

  if (msgIdx < currentIdx) then
    return
  end

  MsgC(white, "[", getcurrenttime(), " ", color, level .. (" "):rep(MAX_LEVEL_LENGTH - #level), " ", white, self.prefix, "]", " ", string.format(message, ...))
  MsgN()
end

function Logger:trace(message, ...)
  self:log(trace, "TRACE", message, ...)
end

function Logger:debug(message, ...)
  self:log(debug, "DEBUG", message, ...)
end


function Logger:info(message, ...)
  self:log(info, "INFO", message, ...)
end

function Logger:warn(message, ...)
  self:log(warn, "WARN", message, ...)
end

function Logger:err(message, ...)
  self:log(err, "ERR", message, ...)
  _G["debug"].Trace()
end