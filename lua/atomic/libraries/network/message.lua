---@class Atomic.Network.Message: Atomic.Class
---@field private _scheme string
---@field private _sender Player
---@field private _id string
---@field private _isReplied boolean
local NetworkMessage = atomic.class.create("NetworkMessage")
atomic.class.register(NetworkMessage, atomic.class.pseudo)

---@param msg table
---@param schemeName string
---@param sender Player
---@param id string
function NetworkMessage:init(msg, schemeName, sender, id)
  for k, v in pairs(msg) do
    self[k] = v
  end

  self._scheme = schemeName
  self._sender = sender
  self._id = id
  self._isReplied = false
end

---@return Player
function NetworkMessage:getSender()
  return self._sender
end

---@return boolean
function NetworkMessage:isReplied()
  return self._isReplied
end

---@param data table<string, any>
function NetworkMessage:reply(data)
  if (self._isReplied) then
    error("message `" .. self._id .. "` of scheme `" .. self._scheme .. "` is already replied!")
  end

  atomic.network.send(self._scheme, data, self._sender, "Send", self._id)

  self._isReplied = true
end