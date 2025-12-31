---@param current string
---@param constraint string
---@return boolean
function util.IsVersionSuitable(current, constraint)
  if (constraint == "*") then
    return true
  end

  local function splitver(v)
    local t = {}
    for num in string.gmatch(v, "%d+") do
      t[#t+1] = tonumber(num)
    end
    return t
  end

  local function cmp(a, b)
    local len = math.max(#a, #b)
    for i = 1, len do
      local x, y = a[i] or 0, b[i] or 0
      if x < y then return -1 end
      if x > y then return 1 end
    end
    return 0
  end

  local ver = splitver(current)
  local sym, base = string.match(constraint, "^([~^]?)([%d%.]+)$")
  if not base then return false end
  local basever = splitver(base)

  if sym == "" then
    return cmp(ver, basever) == 0
  elseif sym == "~" then
    if cmp(ver, basever) < 0 then return false end
    local limit = { basever[1], (basever[2] or 0) + 1, 0 }
    return cmp(ver, limit) < 0
  elseif sym == "^" then
    if cmp(ver, basever) < 0 then return false end
    if basever[1] > 0 then
      local limit = { basever[1] + 1, 0, 0 }
      return cmp(ver, limit) < 0
    elseif (basever[2] or 0) > 0 then
      local limit = { 0, basever[2] + 1, 0 }
      return cmp(ver, limit) < 0
    else
      local limit = { 0, 0, (basever[3] or 0) + 1 }
      return cmp(ver, limit) < 0
    end
  end

  return false
end