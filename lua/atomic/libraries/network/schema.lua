local message = atomic.class.get("NetworkMessage")
---@cast message Atomic.Class

---@class Atomic.Network.Schema: Atomic.Class
---@field private _name string
---@field private _arguments table<"client" | "server", { fieldName: string, type: Atomic.Network.Schema.Types }[]>
local schema = atomic.class.create("NetworkSchema")
atomic.class.register(schema, atomic.class.pseudo)

---@param name string
function schema:init(name)
  self._name = name
  self._arguments = {
    client = {},
    server = {}
  }
end

--- Adds an argument to the schema that will be in the payload on the **client**.
---@param name string
---@param type Atomic.Network.Schema.Types
function schema:clientField(name, type)
  self._arguments.client[#self._arguments.client+1] = { fieldName = name, type = type }

  return self
end

--- Adds an argument to the schema that will be in the payload on the **server**.
---@param name string
---@param type Atomic.Network.Schema.Types
function schema:serverField(name, type)
  self._arguments.server[#self._arguments.server+1] = { fieldName = name, type = type }

  return self
end

---@param sender Player
---@param messageId string
---@return Atomic.Network.Message
function schema:readPackage(sender, messageId)
  local msg = {}
  local side = SERVER and "server" or "client"

  for _, field in ipairs(self._arguments[side]) do
    local read = atomic.network._types[field.type][1]

    msg[field.fieldName] = read()
  end

  return atomic.class.new(message, msg, self._name, sender, messageId)
end

---@param data table<string, any>
function schema:writePackage(data)
  local side = SERVER and "client" or "server"

  for _, field in ipairs(self._arguments[side]) do
    local write = atomic.network._types[field.type][2]

    write(data[field.fieldName])
  end
end