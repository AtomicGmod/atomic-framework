atomic.loader = atomic.loader or {
  logger = atomic.logger.new("atomic.loader")
}

---@param path string
function atomic.loader.client(path)
  if (SERVER) then
    return AddCSLuaFile(path)
  end

  atomic.loader.logger:debug("including client file `%s`", path)

  include(path)
end

---@param path string
function atomic.loader.shared(path)
  if (SERVER) then
    AddCSLuaFile(path)
  end

  atomic.loader.logger:debug("including shared file `%s`", path)

  include(path)
end

---@param path string
function atomic.loader.server(path)
  if (SERVER) then
    atomic.loader.logger:debug("including server file `%s`", path)
    include(path)
  end
end