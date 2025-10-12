atomic.web = {
  ---@private
  ---@type table<string, Atomic.WebView>
  storage = {}
}

---@class Atomic.WebView
---@field id string
---@field url string
---@field private panel DHTML
local webview = {}
webview.__index = webview

RegisterMetaTable("Atomic.WebView", webview)

---@param id string
---@param url string
---@return Atomic.WebView
function atomic.web.register(id, url)
  local ui = atomic.web.storage[id]

  if (ui) then
    return ui
  end

  ui = setmetatable({
    id = id,
    url = url
  }, webview);

  ---@diagnostic disable-next-line: invisible
  ui:init();

  atomic.web.storage[id] = ui

  return ui
end

function atomic.web.get(id)
  return atomic.web.storage[id]
end

---@private
function webview:init()
  if (IsValid(self.panel)) then
    self.panel:Remove()
  end

  self.panel = vgui.Create("DHTML")
  self.panel:Dock(FILL) -- fullscreen
  self.panel:OpenURL(self.url)
end