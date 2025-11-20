---@class ExamplePackagePing: Atomic.Package
local package = current()

--- Registering new Network Schema
--- that will be visible on both sides - on client and server
package:networkSchema("Ping")
  -- server will send to client
  -- field "content" with type of string
  :clientField("content", "string")