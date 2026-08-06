---@param overhead? integer
---@return string short_src
function debug.getcaller(overhead)
  -- 0 - lua state
  -- 1 - debug.getinfo
  -- 2 - getcaller
  -- 3 - caller of 2
  local caller = debug.getinfo(3 + (overhead or 0))

  return (caller.short_src or "n/a") .. ":" .. (caller.currentline or "-1")
end