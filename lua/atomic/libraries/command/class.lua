---@alias Atomic.Command.ArgumentKind "number" | "string" | "boolean" | "time" | "player"
---@alias Atomic.Command.ExecuteFunc function(executor: Player, arguments: table<string, Atomic.Command.ArgumentKind): string?

---@class Atomic.Command: Atomic.Class
---@field private _name string
---@field private _permission string
---@field private _arguments {[1]: string, [2]: Atomic.Command.ArgumentKind}[]
---@field private _execute Atomic.Command.ExecuteFunc
---@field private _enabled boolean Internal
local command = atomic.class.create("Command")
atomic.class.register(command, atomic.class.pseudo)

---@param name string
---@param permission string
function command:init(name, permission)
  self._name = name
  self._permission = permission
  self._arguments = {}
  self._enabled = true
end

---@param name string
---@param kind Atomic.Command.ArgumentKind
---@return self
function command:argument(name, kind)
	self._arguments[#self._arguments + 1] = { name, kind }

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
		player:ChatPrint(language.GetPhrase(msg))
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
function command:doExecute(executor, arguments)
  if (not self._enabled) then
    return
  end

  coroutine.start(function()
		local couldExecute = hook.Run("CouldPlayerExecuteCommand", executor, self)

		if (!couldExecute or hasRightToExecute(executor, self._permission)) then
			return sayToPlayer(executor, "#atomic.no_perms")
		end

		local err = self._execute(executor, arguments)

		sayToPlayer(executor, err)
	end)
end

---@param b boolean
function command:setEnabled(b)
	self._enabled = b

	return self
end