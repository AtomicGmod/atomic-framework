atomic.command = {
	logger = atomic.logger.new("command"),
	---@type table<string, Atomic.Command>
	_storage = {}
}

---@include
atomic.loader.server("class.lua")

---@type Atomic.Command
local commandClass = atomic.class.get("Command", atomic.class.pseudo)

---@param name string
---@param permission string
---@return Atomic.Command
function atomic.command.new(name, permission)
  return atomic.class.new(commandClass, name, permission)
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

---@diagnostic disable-next-line TODO
---@param command string
---@vararg any
---@return table<string, any>
-- function atomic.command.toArgumentsTable(command, ...)
--   local cmd = atomic.command.get(command)
--   local args = cmd._arguments

--   for _, type in ipairs(args) do

--   end
-- end