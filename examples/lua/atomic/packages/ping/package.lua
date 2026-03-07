---@type PackageMeta
return {
  id = "org.example.ping",
  title = "Ping",
  version = "1.0.0",
  files = {
    client = { "core/client.lua" },
    shared = { "core/shared.lua" },
    server = { "core/server.lua" }
  },
  dependencies = {
    shared = {
      atomic = "~0.8.0-rc.1"
    }
  }
}