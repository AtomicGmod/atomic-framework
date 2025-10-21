---@class Atomic.Network.Message: Atomic.Class
---@field private _scheme string
---@field private _sender Player
---@field private _id string
---@field private _isReplied boolean
local message = atomic.class.create("NetworkMessage")
atomic.class.register(message, atomic.class.pseudo)

---@param schemeName string
---@param sender Player
---@param id string
function message:init(schemeName, sender, id)
  self._scheme = schemeName
  self._sender = sender
  self._id = id
  self._isReplied = false
end

---@return Player
function message:getSender()
  return self._sender
end

---@return boolean
function message:isReplied()
  return self._isReplied
end

---@param data table<string, any>
function message:reply(data)
  if (self._isReplied) then
    error("message `" .. self._id .. "` of scheme `" .. self._scheme .. "` is already replied!")
  end

  atomic.network.send(self._scheme, data, self._sender, self._id)

  self._isReplied = true
end