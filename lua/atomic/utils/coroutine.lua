---@param fun function
---@return boolean
function coroutine.start(fun)
  return coroutine.resume(coroutine.create(fun))
end