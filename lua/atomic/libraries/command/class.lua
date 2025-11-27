---@alias Atomic.Command.ArgumentKind "number" | "string" | "boolean" | "time" | "player"
---@alias Atomic.Command.ExecuteFunc function(executor: Player, arguments: table<string, Atomic.Command.ArgumentKind): string?

---@class Atomic.Command: Atomic.Class
---@field private _name string
---@field private _permission? string
---@field private _cooldown? integer
---@field private _arguments {[1]: string, [2]: Atomic.Command.ArgumentKind}[]
---@field private _execute Atomic.Command.ExecuteFunc
---@field private _enabled boolean Internal
local Command = atomic.class.create("Command")
atomic.class.register(Command, atomic.class.pseudo)

---@param name string
---@param permission? string
---@param cooldown? integer
function Command:init(name, permission, cooldown)
  self._name = name
  self._permission = permission
	self._cooldown = cooldown
  self._arguments = {}
  self._enabled = true
end

---@return integer?
function Command:getCooldown()
	return self._cooldown
end

---@param name string
---@param kind Atomic.Command.ArgumentKind
---@param isOptional? boolean = false
---@return self
function Command:argument(name, kind, isOptional)
	self._arguments[#self._arguments + 1] = { name = name, kind = kind, isOptional = isOptional or false }

	return self
end

---@param executable Atomic.Command.ExecuteFunc
---@return self
function Command:onExecute(executable)
	self._execute = executable

	return self
end

-- why it on atomic framework, not in admin system?
---@param player Player
---@param permission string
local function hasRightToExecute(player, permission)
	if (not permission) then
		return true
	end

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

---@param executor Player
---@param arguments table<string, Atomic.Command.ArgumentKind>
---@return async fun(): (boolean, string?) | nil
function Command:execute(executor, arguments)
  if (not self._enabled) then
    return
  end

	return function()
		local couldExecute = hook.Run("CouldPlayerExecuteCommand", executor, self)

		if (couldExecute == false or (self._permission and not hasRightToExecute(executor, self._permission))) then
			return false, "no_perms"
		end

		local err = self._execute(executor, arguments)

		return err == nil, err
	end
end

---@param b boolean
function Command:setEnabled(b)
	self._enabled = b

	return self
end