---@class Atomic.WebView: Atomic.Class
---@field private _name string
---@field private _parentDir string
---@field private _dhtml DHTML
---@field private _eventsQueue string[]
---@field private _funcs table<string, fun()>
---@field private _attachedVgui table<string, Panel>
---@field private _autoSpawn boolean
local WebView = atomic.class.create("WebView")
atomic.class.register(WebView, atomic.class.pseudo)

---@param name string
---@param parentDir string Path or url
---@param autoSpawn boolean
function WebView:init(name, parentDir, autoSpawn)
  self._name = name
  self._parentDir = parentDir or "asset://garrysmod/resource/webviews"
  self._dhtml = NULL
  self._eventsQueue = {}
  self._funcs = {}
  self._attachedVgui = {}
  self._isPopup = false
  self._autoSpawn = autoSpawn
end

---@param isPopup boolean
function WebView:setPopup(isPopup)
  self._isPopup = isPopup

  if (not IsValid(self._dhtml)) then
    return
  end

  if (isPopup) then
    self._dhtml:MakePopup()
  else
    self._dhtml:SetMouseInputEnabled(false)
    self._dhtml:SetKeyboardInputEnabled(false)
  end
end

---@return boolean
function WebView:isValid()
  return IsValid(self._dhtml)
end

---@param url string
function WebView:setCustomUrl(url)
  self._customUrl = url
end

---@return string
function WebView:getPathToHtml()
  return self._customUrl or self._parentDir .. "/" .. self._name .. ".html.dat"
end

function WebView:isAutoSpawnEnabled()
  return self._autoSpawn
end

WebView.IsValid = WebView.isValid

function WebView:event(payload, eventName)
  local event = atomic.webview.formatEvent({ payload = payload, eventName = eventName })

  if (IsValid(self)) then
    self:queueJs(event)
  else
    self._eventsQueue[#self._eventsQueue+1] = event
  end
end

---@private
---@param code string
function WebView:queueJs(code)
  self._dhtml:QueueJavascript(code)
end

---@return DHTML
function WebView:getPanel()
  return self._dhtml
end

---@param element Panel
---@param htmlElementId string
function WebView:attachVgui(element, htmlElementId)
  -- automatic hiding is necessary
  -- so that the element is not displayed
  -- until the target web element appears
  element:Hide()

  if (IsValid(self)) then
    element:SetParent(self._dhtml)
  end

  self._attachedVgui[htmlElementId] = element
end

---@private
---@param id string
---@return Panel?
function WebView:getAttachedVgui(id)
  return self._attachedVgui[id]
end

---@param fname string
---@vararg ...
---@return "__ok__" | "__err__", ...: Atomic.Webview.SafeJSTypes
function WebView:callLuaFunction(fname, ...)
  local callback = atomic.webview._jsFuncs[fname]

  if (!callback) then
    return "__err__", "unknown function `" .. tostring(fname) .. "`"
  end

  local isOk, result = pcall(callback, self, ...)

  if (isOk) then
    return "__ok__", result
  end

  return "__err__", "runtime error: " .. tostring(result)
end

function WebView:spawn()
  if (IsValid(self)) then
    return
  end

  self._dhtml = vgui.Create("DHTML")
  self._dhtml:Dock(FILL)
  self._dhtml:OpenURL(self:getPathToHtml())
  self._dhtml:AddFunction("lua", "call", function(fname, ...)
    return self:callLuaFunction(fname, ...)
  end)

  if (self._isPopup) then
    self._dhtml:MakePopup()
  end

  for _, panel in pairs(self._attachedVgui) do
    panel:SetParent(self._dhtml)
  end

  local events = self._eventsQueue

  if (#events > 0) then
    for _, event in ipairs(events) do
      self:queueJs(event)
    end
  end
end