atomic.loader = atomic.loader or {
  logger = atomic.logger.new("loader")
}

---@param path string
---@return ...?
function atomic.loader.include(path)
  atomic.loader.logger:trace("including file `%s`", path)

  return include(path)
end

atomic.loader.client = atomic.loader.include
atomic.loader.shared = atomic.loader.include
atomic.loader.server = atomic.loader.include