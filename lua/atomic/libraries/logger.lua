atomic.logger = atomic.logger or {
  ---@private
  ---@type table<string, Atomic.STD.Logger>
  storage = {},
}

---@class Atomic.STD.Logger
---@field prefix string
local logger = {}
logger.__index = logger

RegisterMetaTable("Atomic.STD.Logger", logger)

--- Creates new instance of Logger
---@param prefix string
---@return Atomic.STD.Logger
function atomic.logger.new(prefix)
  local cache = atomic.logger.storage[prefix]

  if (cache) then
    return cache
  end

  local lggr = setmetatable({ prefix = prefix }, logger)

  atomic.logger.storage[prefix] = lggr

  return lggr
end

local function getcurrenttime()
  return os.date("%H:%M:%S %d.%m")
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

local logvar = CreateConVar("atomic_log", "INFO", FCVAR_ARCHIVE, "Minimum log level (INFO, DEBUG, WARN, ERR)")

---@protected
---@param color Color | string
---@param level string
---@param message string
---@param ... any
function logger:log(color, level, message, ...)
  local currentLevel = logvar:GetString():upper()
  local currentIdx = levels[currentLevel] or 1
  local msgIdx = levels[level] or 1

  if msgIdx < currentIdx then return end

  MsgC(white, "[", getcurrenttime(), " ", color, level, " ", white, self.prefix, "]", " ", string.format(message, ...))
  MsgN()
end

function logger:info(message, ...)
  self:log(info, "INFO", message, ...)
end

function logger:debug(message, ...)
  self:log(debug, "DEBUG", message, ...)
end

function logger:warn(message, ...)
  self:log(warn, "WARN", message, ...)
end

function logger:err(message, ...)
  self:log(err, "ERR", message, ...)
end
