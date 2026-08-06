---@alias Atomic.Command.ArgumentKind "number" | "string" | "boolean" | "time" | "player"
---@alias Atomic.Command.ArgumentTypes number | string | boolean | Player
---@alias Atomic.Command.ExecuteFunc fun(executor: Player, arguments: table<string, Atomic.Command.ArgumentTypes>): string?
---@alias Atomic.Command.Argument { name: string, kind: Atomic.Command.ArgumentKind, isOptional: boolean }

---@class Atomic.Command: Atomic.Class
---@field private _name string
---@field private _permission? string
---@field private _cooldown? integer
---@field private _arguments Atomic.Command.Argument[]
---@field private _execute Atomic.Command.ExecuteFunc
---@field private _enabled boolean Internal
---@field private _hasOptional boolean Internal
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
	self._hasOptional = false
end

---@return integer?
function Command:getCooldown()
	return self._cooldown
end

---@return string?
function Command:getPermission()
  return self._permission
end

---@return string
function Command:getName()
	return self._name
end

---@return Atomic.Command.Argument[]
function Command:getArguments()
	return self._arguments
end

---@param name string
---@param kind Atomic.Command.ArgumentKind
---@param isOptional? boolean = false
---@return self
function Command:argument(name, kind, isOptional)
	if (not self._hasOptional and isOptional) then
		self._hasOptional = true
	end

	if (self._hasOptional and not isOptional) then
		error("in an argument chain a required argument cannot be after an optional argument")
	end

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
	if (not permission or not IsValid(player)) then
		return true
	end

	---@diagnostic disable

	local co = coroutine.running()
	local result
	local isYielded = false

	CAMI.PlayerHasAccess(player, permission, function(hasAccess)
		if (not result) then
			result = hasAccess
			if (isYielded) then
				coroutine.resume(co, hasAccess)
			end
		end
	end)

	if (not result) then
		isYielded = true
		result = coroutine.yield()
		isYielded = false
	end

	return result
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

---@return boolean
function Command:isEnabled()
  return self._enabled
end