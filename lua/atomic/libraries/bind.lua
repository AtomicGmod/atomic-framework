atomic.bind = atomic.bind or {
  ---@type table<number, table<number, fun(player: Player)>>
  _storage = {},
  ---@type table<number, number> -- [registrationId] = key
  _map = {},
  _lastBindId = 0
}

---@param key number Index of the key
---@param callback fun(player: Player)
---@return number registerationId
function atomic.bind.bind(key, callback)
  if (type(atomic.bind._storage[key]) ~= "table") then
    atomic.bind._storage[key] = {}
  end

  atomic.bind._lastBindId = atomic.bind._lastBindId + 1
  local id = atomic.bind._lastBindId

  atomic.bind._storage[key][id] = callback
  atomic.bind._map[id] = key

  return id
end

---@param registerationId number
function atomic.bind.unbind(registerationId)
  local key = atomic.bind._map[registerationId]
  if (type(key) ~= "number") then
    return
  end

  local tab = atomic.bind._storage[key]

  if (type(tab) ~= "table") then
    return
  end

  tab[registerationId] = nil
  atomic.bind._map[registerationId] = nil
end

---@param player Player
---@param key number
local function keybind_handler(player, key)
  if (not IsFirstTimePredicted()) then
    return
  end

  local tab = atomic.bind._storage[key]
  if (not tab) then return end

  for _, callback in pairs(tab) do
    callback(player)
  end
end

hook.Add("PlayerButtonDown", "atomic.bind", keybind_handler)