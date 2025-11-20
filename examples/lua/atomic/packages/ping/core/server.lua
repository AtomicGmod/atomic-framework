---@class ExamplePackagePing: Atomic.Package
local package = current()

package:onNetworkMessage(function(message)
  local sender = message:getSender()

  sender:ChatPrint("Pong!")

  message:reply({
    content = "Hello from server!"
  })
end, "Ping")