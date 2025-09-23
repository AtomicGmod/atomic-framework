---@alias Atomic.Command.ArgumentKind "number" | "string" | "time" | "player"
---@alias Atomic.Command.ExecuteFunc function(executor: Player, arguments: table<string, Atomic.Command.ArgumentKind): string?

---@class Atomic.Command
---@field name string
---@field permission string
---@field arguments table<[1]: string, [2]: Atomic.Command.ArgumentKind>[]
---@field execute Atomic.Command.ExecuteFunc

atomic.command = {
	---@type table<string, Atomic.Command>
	logger = atomic.logger.new("atomic.command"),
	_storage = {}
}

---@class Atomic.Command
local command = {}
command.__index = command

---@param name string
---@param permission string
function atomic.command.register(name, permission)
  local cache = atomic.command._storage[name]

	if (cache) then
	  return cache
	end

	local cmd = setmetatable({ name = name, permission = permission, arguments = {} }, command)

	atomic.command._storage[name] = cmd

	return cmd
end

---@return Atomic.Command?
function atomic.command.get(name)
	return atomic.command._storage[name]
end

---@param name string
---@param kind Atomic.Command.ArgumentKind
---@return self
function command:argument(name, kind)
	self.arguments[#self.arguments + 1] = { name, kind }

	return self
end

---@param executable Atomic.Command.ExecuteFunc
---@return self
function command:onExecute(executable)
	self.execute = executable

	return self
end

---@param player Player
---@param msg string
local function sayToPlayer(player, msg)
	if (err) then
		if (IsValid(executor)) then
			executor:ChatPrint(err)
		end
	else
		atomic.command.logger:error("Failed to execute command `%s` due to: %s", self.name, err)
	end
end

---@param player Player
---@param permission string
local function hasRightToExecute(player, permission)
	if (IsValid(player)) then
		CAMI.PlayerHasAccess(player, permission, function(allow)
			coroutine.resume(allow)
		end)

		return coroutine.yield()
	else -- console
		return true
	end
end

---@private
---@param executor Player
---@param arguments table<string, Atomic.Command.ArgumentKind>
---@return thread
function command:doExecute(executor, arguments)
	local thread = coroutine.create(function()
		local couldExecute = hook.Run("CouldPlayerExecuteCommand", executor, self)

		if (!couldExecute or hasRightToExecute(executor, self.permission)) then
			return sayToPlayer(executor, "#atomic.no_perms")
		end

		local err = self.execute(executor, arguments)

		sayToPlayer(executor, err)
	end)

	return thread
end