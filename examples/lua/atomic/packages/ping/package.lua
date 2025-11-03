---@type Atomic.Package.Metadata
return {
  id = "team.meadows.example_ping",
  title = "Example package - Ping",
  version = "1.0.0",
  files = {
    client = { "core/client.lua" },
    shared = { "core/shared.lua" },
    server = { "core/server.lua" }
  }
}