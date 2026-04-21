---@type PackageMeta
return {
  id = "org.example.ping",
  title = "Ping",
  version = "1.0.0",
  kind = "system",
  files = {
    dir = "core",
    client = { "client" },
    shared = { "shared" },
    server = { "server" }
  },
  dependencies = {
    shared = {
      atomic = "^1.0.0-alpha.1"
    }
  }
}