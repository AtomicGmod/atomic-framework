atomic.network = atomic.network or {
  logger = atomic.logger.new("atomic.network"),
  _storage = {
    ---@type table<string, fun(message: Atomic.Network.Message)>
    listeners = {},
    ---@type table<string, Atomic.Network.Schema>
    schemas = {}
  },
  ---@alias Atomic.Network.Schema.Types "bool" | "i8" | "i16" | "i32" | "u8" | "u16" | "u32" | "u64" | "string" | "data" | "data_uncomp" | "entity" | "player" | "table"
  _types = {
    bool = {function() return net.ReadBool() end, function(n) net.WriteBool(n) end},
    i8 = {function() return net.ReadInt(8) end, function(n) net.WriteInt(n, 8) end},
    i16 = {function() return net.ReadInt(16) end, function(n) net.WriteInt(n, 16) end},
    i32 = {function() return net.ReadInt(32) end, function(n) net.WriteInt(n, 32) end},
    u8 = {function() return net.ReadUInt(8) end, function(n) net.WriteUInt(n, 8) end},
    u16 = {function() return net.ReadUInt(16) end, function(n) net.WriteUInt(n, 16) end},
    u32 = {function() return net.ReadUInt(32) end, function(n) net.WriteUInt(n, 32) end},
    u64 = {function() return net.ReadUInt64() end, function(n) net.WriteUInt64(n) end},
    string = {function() return net.ReadString() end, function(n) net.WriteString(n) end},
    data = {function() return util.Decompress(net.ReadData(net.ReadUInt(32))) end, function(n) local c = util.Compress(n) net.WriteUInt(#c, 32) net.WriteData(c) end},
    data_uncomp = {function() return net.ReadData(net.ReadUInt(32)) end, function(n) net.WriteUInt(#n, 32) net.WriteData(n) end},
    entity = {function() return net.ReadEntity() end, function(n) net.WriteEntity(n) end},
    player = {function() return net.ReadPlayer() end, function(n) net.WritePlayer(n) end},
    table = {function() return net.ReadTable() end, function(n) net.WriteTable(n) end}
  }
}

if (SERVER) then
	util.AddNetworkString("atomic.framework")
end

---@include
atomic.loader.shared("message.lua")
atomic.loader.shared("schema.lua")

local logger = atomic.network.logger
local schemas = atomic.network._storage.schemas
local listeners = atomic.network._storage.listeners
---@type Atomic.Network.Schema
local schemaClass = atomic.class.get("NetworkSchema")

--- Creates new schema
-- @param name string
-- @return Atomic.Network.Schema
function atomic.network.new(name)
  return atomic.class.new(schemaClass, name)
end

---@param schema Atomic.Network.Schema
function atomic.network.register(schema)
  schemas[schema._name] = schema
end

---@param name string
function atomic.network.unregister(name)
  schemas[name] = nil
end

---@param name string
---@param callback fun(message: Atomic.Network.Message)
function atomic.network.listen(name, callback)
  listeners[name] = callback
end

---@param name string
function atomic.network.unlisten(name)
  listeners[name] = nil
end

---@return string
local function generateMessageId()
  return util.MD5("atomic.network:" .. os.time() .. ":" .. math.random(1, 99999))
end

---@param schemaName string
---@param data table<string, any>
---@param player? Player
---@param id? string Overrides message id
---@return string Id of the message
function atomic.network.send(schemaName, data, player, id)
  id = id or generateMessageId()

  local schema = schemas[schemaName]

  if (not schema) then
    error("network schema " .. tostring(schemaName) .. " not found")
  end

  net.Start("atomic.framework")
  net.WriteString(schemaName)
  net.WriteString(id)

  schema:writePackage(data)

  if (SERVER and IsValid(player)) then
    ---@cast player Player
    net.Send(player)
  elseif (CLIENT) then
    net.SendToServer()
  end

  return id
end

---@type table<string, { sendedTo?: Player, callback: fun(message: Atomic.Network.Message) }>
local responseAwaiters = {}

---@async
---@param schemaName string
---@param data table<string, any>
---@param player? Player
---@return table | string
function atomic.network.sendAsync(schemaName, data, player)
  local co = coroutine.get()

  local id = atomic.network.send(schemaName, data, player)

  local callback = function(message)
    coroutine.resume(co, message)
  end

  responseAwaiters[id] = { sendedTo = player, callback = callback }

  -- timeout handler
  timer.Simple(5, function()
    responseAwaiters[id] = nil

    coroutine.resume(co, "timeout")
  end)

  return coroutine.yield()
end

---@private
function atomic.network.receiver(len, player)
  local schemaName = net.ReadString()
  local messageId = net.ReadString()
  local schema = schemas[schemaName]
  local message = schema and schema:readPackage(player, messageId)

  if (not schema or not message) then
    logger:warn("an unknown net packet was received from player `%s` with %s length without a valid schema.\n\tcheck the packet in Atomic Bandwidth!", player:SteamID64(), len)
    return
  end

  local awaited = responseAwaiters[messageId]

  if (awaited) then
    if (awaited.sendedTo ~= nil and awaited.sendedTo ~= player) then
      return logger:warn(
        "the awaited message `%s` was sent by player `%s`, but the response was received from player `%s`.",
        messageId, awaited.sendedTo, player
      )
    end

    awaited.callback(message)

    return
  end

  local listener = listeners[schemaName]

  if (not listener) then
    logger:err("no listener for schema `%s`", schemaName)

    return
  end

  listener(message)
end

net.Receive("atomic.framework", atomic.network.receiver)