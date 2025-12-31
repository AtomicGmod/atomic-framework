atomic.loader = atomic.loader or {
  logger = atomic.logger.new("loader")
}

---@param path string
---@return ...?
function atomic.loader.client(path)
  if (SERVER) then
    return atomic.loader.csluafile(path)
  end

  atomic.loader.logger:trace("including client file `%s`", path)

  return include(path)
end

---@param path string
---@return ...?
function atomic.loader.shared(path)
  if (SERVER) then
    atomic.loader.csluafile(path)
  end

  atomic.loader.logger:trace("including shared file `%s`", path)

  return include(path)
end

---@param path string
---@return ...?
function atomic.loader.server(path)
  if (SERVER) then
    atomic.loader.logger:trace("including server file `%s`", path)
    return include(path)
  end
end

---@param path string
---@return ...?
function atomic.loader.csluafile(path)
  if (SERVER) then
    atomic.loader.logger:trace("making `%s` available to clients", path)
    AddCSLuaFile(path)
  end
end