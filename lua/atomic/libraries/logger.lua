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

function logger:info(message, ...)
  MsgC(white, "[", getcurrenttime(), " ", info, "INFO", " ", white, self.prefix, "]", " ", string.format(message, ...))
  MsgN()
end

function logger:debug(message, ...)
  MsgC(white, "[", getcurrenttime(), " ", debug, "DEBUG", " ", white, self.prefix, "]", " ", string.format(message, ...))
  MsgN()
end

function logger:warn(message, ...)
  MsgC(white, "[", getcurrenttime(), " ", warn, "WARN", " ", white, self.prefix, "]", " ", string.format(message, ...))
  MsgN()
end

function logger:err(message, ...)
  MsgC(white, "[", getcurrenttime(), " ", err, "ERR", " ", white, self.prefix, "]", " ", string.format(message, ...))
  MsgN()
end