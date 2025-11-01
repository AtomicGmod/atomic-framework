---@class Atomic.WebView: Atomic.Class
---@field private _name string
---@field private _parentDir string
---@field private _dhtml DHTML
---@field private _eventsQueue { payload: table<string, any>, eventName: string }[]
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
  self._autoSpawn = autoSpawn
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
  local event = { payload = payload, eventName = eventName }

  if (not IsValid(self)) then
    self._eventsQueue[#self._eventsQueue+1] = event
  else
    self._dhtml:QueueJavascript(atomic.webview.formatEvent(event))
  end
end

---@generic T
---@param element T: Panel
---@param htmlElementId string
function WebView:attachVgui(element, htmlElementId)
  -- todo
  self._attachedVgui[htmlElementId] = element
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

  local format = atomic.webview.formatEvent
  local queue = self._eventsQueue

  if (#queue > 0) then
    for _, payload in ipairs(queue) do
      -- todo DRY in :event method
      self._dhtml:QueueJavascript(format(payload))
    end
  end
end