atomic.webview = {
  ---@type table<string, table<string, table<string, Atomic.WebView>>>
  _storage = {
    atomic = {
      [atomic.meta.version] = {}
    }
  },
  ---@type table<string, fun(webview: Atomic.WebView, ...)>
  _jsFuncs = {},
}

---@type Atomic.WebView
local WebView = atomic.class.get("WebView")

---@param name string
---@param parentDir string Path or url
---@param autoSpawn? boolean = true
---@return Atomic.WebView
function atomic.webview.new(name, parentDir, autoSpawn)
  return atomic.class.new(WebView, name, parentDir, autoSpawn ~= false)
end

--- Finds menu from a package
---
--- Usecases
--- ```lua
--- -- 1. Get Atomic std's menu
--- local hud = atomic.webview.get("hud")
--- -- 2. Get menu from a package
--- local hud = atomic.webview.get("hud", package)
--- -- 3. Get menu from a package name and version
--- local hud = atomic.webview.get("hud", "some.package.hud", "0.1.3")
--- ```
---@param name string
---@param packageOrId? Atomic.Package | string
---@param packageVersion? string
---@return Atomic.WebView?
function atomic.webview.get(name, packageOrId, packageVersion)
  local pkgName = type(packageOrId) == "table" and packageOrId._metadata.id
    or type(packageOrId) == "string" and packageOrId
    or not packageOrId and "atomic"

  local pkgVersion = type(packageOrId) == "table" and packageOrId._metadata.version
    or type(packageVersion) == "string" and packageVersion
    or pkgName == "atomic" and atomic.meta.version

  return ((atomic.webview._storage[pkgName] or {})[pkgVersion] or {})[name]
end

--- Registers the menu in the storage, allowing it to be get via ``atomic.menu.get``
---@param webview Atomic.WebView
---@param package Atomic.Package
function atomic.webview.register(webview, package)
  local storage = atomic.webview._storage
  local id, version = package._metadata.id, package._metadata.version

  if (type(storage[id]) ~= "table") then
    storage[id] = {}
  end

  if (type(storage[id][version]) ~= "table") then
    storage[id][version] = {}
  end

  storage[id][version][webview._name] = webview
end

---@param name string
---@param package Atomic.Package
function atomic.webview.unregister(name, package)
  local storage = atomic.webview._storage
  local id, version = package._metadata.id, package._metadata.version

  storage[id][version][name] = nil

  atomic.webview._storage = storage
end

---@return Atomic.WebView[]
function atomic.webview.getRegistered()
  local result = {}

  for _, packages in pairs(atomic.webview._storage) do
    for _, webviews in pairs(packages) do
      for _, webview in pairs(webviews) do
        result[#result+1] = webview
      end
    end
  end

  return result
end

---@param event { eventName: string, payload: table }
---@return string JS Code
function atomic.webview.formatEvent(event)
  local jsoned = util.TableToJSON(event.payload)

  -- hardcoded but tbh idc
  local eventCode = ("new CustomEvent('" .. event.eventName .. "', { detail: " .. jsoned .. " })")

  return ("window.dispatchEvent(" .. eventCode .. ")")
end

hook.Add("InitPostEntity", "atomic.webview", function()
  hook.Remove("InitPostEntity", "atomic.webview")

  local webviews = atomic.webview.getRegistered()

  for _, webview in ipairs(webviews) do
    if (not webview:isAutoSpawnEnabled()) then
      continue
    end

    webview:spawn()
  end
end)