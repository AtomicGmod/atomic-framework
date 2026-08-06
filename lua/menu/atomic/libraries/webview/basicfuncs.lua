local function add(name, func)
  atomic.webview._jsFuncs[name] = func
end

--- internal function, that called for
--- set attached VGUI panel new position
---@param webview Atomic.WebView
---@param id string ID of the Web element, that some VGUI element attached on
---@param visible boolean
---@param x integer
---@param y integer
---@param w integer
---@param h integer
add("__vgui__handle__", function(webview, id, visible, x, y, w, h)
  local element = webview:getAttachedVgui(id)
  ---@cast element Panel

  if (not element) then
    return
  end

  if (not visible) then
    element:Hide()
  elseif (not element:IsVisible()) then
    element:Show()
  end

  element:SetX(x)
  element:SetY(y)
  element:SetWide(w)
  element:SetTall(h)
end)

-- todo
add("getNick", function()
  return LocalPlayer():Nick()
end)

add("getSteamId", function()
  return LocalPlayer():SteamID()
end)

add("getSteamId64", function()
  return LocalPlayer():SteamID64()
end)