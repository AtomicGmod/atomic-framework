---@param fun function
---@return boolean, ...any
function coroutine.start(fun)
  local isOk, err = coroutine.resume(coroutine.create(fun))

  if (!isOk) then
    local stack = debug.getcaller()
    atomic.log:err("an error occured inside coroutine: " .. tostring(err) .. "\n\t" .. stack)
  end

  return isOk, err
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