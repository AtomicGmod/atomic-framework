atomic.command = atomic.command or {
	logger = atomic.logger.new("command"),
	---@type table<string, Atomic.Command>
	_storage = {}
}

---@include
atomic.loader.include("class.lua")

---@type Atomic.Command
local commandClass = atomic.class.get("Command", atomic.class.pseudo)

---@param name string
---@param permission? string
---@param cooldown? integer Cooldown in seconds, before player can again use this command
---@return Atomic.Command
function atomic.command.new(name, permission, cooldown)
  return atomic.class.new(commandClass, name, permission, cooldown)
end

---@param name string
---@param command Atomic.Command
function atomic.command.add(name, command)
 	atomic.command._storage[name] = command
end

---@param name string
---@return Atomic.Command
function atomic.command.get(name)
	return atomic.command._storage[name]
end

---@param name string
function atomic.command.remove(name)
	atomic.command._storage[name] = nil
end