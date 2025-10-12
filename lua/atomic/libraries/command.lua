---@alias Atomic.Command.ArgumentKind "number" | "string" | "time" | "player"
---@alias Atomic.Command.ExecuteFunc function(executor: Player, arguments: table<string, Atomic.Command.ArgumentKind): string?

---@class Atomic.Command
---@field name string
---@field permission string
---@field arguments {[1]: string, [2]: Atomic.Command.ArgumentKind}[]
---@field private _execute Atomic.Command.ExecuteFunc
---@field private _enabled boolean Internal

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
function atomic.command.new(name, permission)
	return setmetatable({ name = name, permission = permission, arguments = {}, enabled = true }, command)
end

---@param name string
---@param command Atomic.Command
function atomic.command.add(name, command)
 	atomic.command._storage[name] = command
end

---@param name string
---@return Atomic.Command?
function atomic.command.get(name)
	return atomic.command._storage[name]
end

---@param name string
function atomic.command.remove(name)
	atomic.command._storage[name] = nil
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
	self._execute = executable

	return self
end

---@param player Player
---@param msg string
local function sayToPlayer(player, msg)
	if (IsValid(player)) then
		player:ChatPrint(msg)
	else
		atomic.command.logger:error("Failed to execute command due to: %s", msg)
	end
end

---@param player Player
---@param permission string
local function hasRightToExecute(player, permission)
	if (IsValid(player)) then
		---@diagnostic disable-next-line
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

		local err = self._execute(executor, arguments)

		sayToPlayer(executor, err)
	end)

	coroutine.resume(thread)

	return thread
end

---@param b boolean
function command:setEnabled(b)
	self._enabled = b

	return self
end