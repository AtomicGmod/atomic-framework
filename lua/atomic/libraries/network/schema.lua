---@type Atomic.Network.Message
local NetworkMessage = atomic.class.get("NetworkMessage")

---@class Atomic.Network.Schema: Atomic.Class
---@field private _package Atomic.Package
---@field private _name string
---@field private _arguments table<("client" | "server"), { fieldName: string, type: Atomic.Network.Schema.Types, isOptional?: boolean }[]>
local NetworkSchema = atomic.class.create("NetworkSchema")
atomic.class.register(NetworkSchema, atomic.class.pseudo)

---@param name string
function NetworkSchema:init(package, name)
  self._package = package
  self._name = name
  self._arguments = {
    client = {},
    server = {}
  }
end

--- Adds an argument to the schema that will be in the payload on the **client**.
---@param name string
---@param type Atomic.Network.Schema.Types
---@param isOptional? boolean @default = false
function NetworkSchema:client(name, type, isOptional)
  self._arguments.client[#self._arguments.client+1] = { fieldName = name, type = type, isOptional = isOptional }

  return self
end

--- Adds an argument to the schema that will be in the payload on the **server**.
---@param name string
---@param type Atomic.Network.Schema.Types
---@param isOptional? boolean @default = false
function NetworkSchema:server(name, type, isOptional)
  self._arguments.server[#self._arguments.server+1] = { fieldName = name, type = type, isOptional = isOptional }

  return self
end

---@param sender Player
---@param messageId string
---@return Atomic.Network.Message
function NetworkSchema:readNetPacket(sender, messageId)
  local msg = {}
  local side = SERVER and "server" or "client"

  for _, field in ipairs(self._arguments[side]) do
    local readFn = atomic.network._types[field.type][1]
		local canRead = not field.isOptional and true or net.ReadBool()

		if (canRead) then
      msg[field.fieldName] = readFn()
    end
  end

  return atomic.class.new(NetworkMessage, msg, self._name, sender, messageId)
end

---@param data table<string, any>
function NetworkSchema:writeNetPacket(data)
  local side = SERVER and "client" or "server"

  for _, field in ipairs(self._arguments[side]) do
    local writeFn = atomic.network._types[field.type][2]
		local value = data[field.fieldName]
		local canWrite = not field.isOptional and true or value ~= nil

		if (field.isOptional) then
			-- is value provided
			net.WriteBool(value ~= nil)
		end

		if (canWrite) then
      writeFn(value)
		end
  end
end

---@return string
function NetworkSchema:getName()
  return self._name
end

---@return Atomic.Package
function NetworkSchema:getParentPackage()
  return self._package
end