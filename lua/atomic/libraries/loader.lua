atomic.loader = atomic.loader or {
  logger = atomic.logger.new("atomic.loader")
}

---@param path string
function atomic.loader.client(path)
  atomic.loader.logger:debug("including client file `%s`", path)

  if (SERVER) then
    return AddCSLuaFile(path)
  end

  include(path)
end

---@param path string
function atomic.loader.shared(path)
  atomic.loader.logger:debug("including shared file `%s`", path)

  if (SERVER) then
    AddCSLuaFile(path)
  end

  include(path)
end

---@param path string
function atomic.loader.server(path)
  atomic.loader.logger:debug("including server file `%s`", path)

  if (SERVER) then
    include(path)
  end
end