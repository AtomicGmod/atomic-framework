---@param fun function
---@return boolean
function coroutine.start(fun)
  return coroutine.resume(coroutine.create(fun))
end

--- Checks whether the current function is within a coroutine or not, and if not, throws an error.
---
--- ```lua
--- ```
---@return thread
function coroutine.get()
  local co = coroutine.running()

  if (not co) then
    error("attempt to use an asynchronous function outside of a coroutine")
  end

  return co
end