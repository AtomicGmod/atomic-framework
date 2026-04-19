atomic.network = atomic.network or {
  logger = atomic.logger.new("atomic.network"),
  _storage = {
    ---@type table<string, fun(self: Atomic.Package, message: Atomic.Network.Message)>
    listeners = {},
    ---@type table<string, Atomic.Network.Schema>
    schemas = {}
  },
  ---@alias Atomic.Network.Schema.Types "bool" | "i8" | "i16" | "i32" | "u8" | "u16" | "u32" | "u64" | "string" | "data" | "data_uncomp" | "entity" | "player" | "table"
  _types = {
    bool = {net.ReadBool, net.WriteBool},
    i8 = {function() return net.ReadInt(8) end, function(n) net.WriteInt(n, 8) end},
    i16 = {function() return net.ReadInt(16) end, function(n) net.WriteInt(n, 16) end},
    i32 = {function() return net.ReadInt(32) end, function(n) net.WriteInt(n, 32) end},
    u8 = {function() return net.ReadUInt(8) end, function(n) net.WriteUInt(n, 8) end},
    u16 = {function() return net.ReadUInt(16) end, function(n) net.WriteUInt(n, 16) end},
    u32 = {function() return net.ReadUInt(32) end, function(n) net.WriteUInt(n, 32) end},
    u64 = {net.ReadUInt64, net.WriteUInt64},
    string = {net.ReadString, net.WriteString},
    data = {function() return util.Decompress(net.ReadData(net.ReadUInt(32))) end, function(n) local c = util.Compress(n) net.WriteUInt(#c, 32) net.WriteData(c) end},
    data_uncomp = {function() return net.ReadData(net.ReadUInt(32)) end, function(n) net.WriteUInt(#n, 32) net.WriteData(n) end},
    entity = {net.ReadEntity, net.WriteEntity},
    player = {net.ReadPlayer, net.WritePlayer},
    table = {net.ReadTable, net.WriteTable}
  }
}

local netChannelName = "atomic:" .. atomic.meta.version

if (SERVER) then
	util.AddNetworkString(netChannelName)
end

---@include
atomic.loader.shared("message.lua")
atomic.loader.shared("schema.lua")

local logger = atomic.network.logger
local schemas = atomic.network._storage.schemas
local listeners = atomic.network._storage.listeners
---@type Atomic.Network.Schema
local NetworkSchema = atomic.class.get("NetworkSchema")

--- Creates new schema
---@param package Atomic.Package
---@param name string
---@return Atomic.Network.Schema
function atomic.network.new(package, name)
  return atomic.class.new(NetworkSchema, package, name)
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
---@param player? Player | table | Vector
---@param sendFunction? "Send" | "SendOmit" | "SendPAS" | "SendPVS" | "Broadcast" Serverside only
---@param id? string Overrides message id
---@return string? Id of the message
function atomic.network.send(schemaName, data, player, sendFunction, id)
  id = id or generateMessageId()

  local schema = schemas[schemaName]

  if (not schema) then
    error("network schema " .. tostring(schemaName) .. " not found")
  end

  net.Start(netChannelName)
  -- todo md5ing schemaName for get a little a few bytes
  net.WriteString(schemaName)
  -- todo id is needed if only message will await for a response, right?
  -- so we can make it optional (net.WriteBool(true) -> id is exists, false -> not exists) and win +-31 bytes
  net.WriteString(id)

  schema:writeNetPacket(data)

  if (SERVER) then
    local sendFn = sendFunction or "Send"
    local isOk, err = pcall(net[sendFn], player)

    if (not isOk) then
      return logger:err("failed to send message `%s` with net.%s(%s): %s", schemaName, sendFn, player or "", err)
    end
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
---@param shouldIgnoreError? boolean
---@return table | "timeout" | "err"
function atomic.network.sendAsync(schemaName, data, player, shouldIgnoreError)
  local co = coroutine.get()

  local id = atomic.network.send(schemaName, data, player)

  if (not id) then
    return "err"
  end

  local callback = function(message)
    coroutine.resume(co, message)
  end

  responseAwaiters[id] = { sendedTo = player, callback = callback }

  -- timeout handler
  timer.Simple(5, function()
    if (responseAwaiters[id] ~= nil) then
      responseAwaiters[id] = nil

      if (not shouldIgnoreError) then
        atomic.network.logger:err("message `%s` (`%s`) did not receive a response!", schemaName, id)
      end

      coroutine.resume(co, "timeout")
    end
  end)

  return coroutine.yield()
end

---@private
function atomic.network.receiver(len, player)
  local schemaName = net.ReadString()
  local messageId = net.ReadString()

  local schema = schemas[schemaName]
  local message = schema and schema:readNetPacket(player, messageId)

  if (not schema or not message) then
    return logger:warn("an unknown net packet was received from `%s` with %sbits length without a valid schema.", IsValid(player) and player:SteamID64() or "<console>", len)
  end

  local awaited = responseAwaiters[messageId]

  if (awaited) then
    if (awaited.sendedTo ~= nil and awaited.sendedTo ~= player) then
      return logger:warn(
        "the awaited message `%s` was sent by player `%s`, but the response was received from player `%s`",
        messageId, awaited.sendedTo, player
      )
    end

    responseAwaiters[messageId] = nil

    return awaited.callback(message)
  end

  local listener = listeners[schemaName]

  if (not listener) then
    return logger:err("no listener for schema `%s`", schemaName)
  end

  listener(schema:getParentPackage(), message)
end

net.Receive(netChannelName, atomic.network.receiver)