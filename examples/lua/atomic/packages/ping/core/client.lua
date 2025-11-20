---@class ExamplePackagePing: Atomic.Package
local package = current()

--- this function will send
--- an asynchronous network message to the server
--- and wait for a response
function package:ping()
  local instant = Instant()

  coroutine.start(function()
    local message = self:sendNetworkMessageAsync("Ping", {})

    local ms = instant:elapsed():as_millis()

    package.logger:debug("Server ping took %sms", ms)
    package.logger:debug("Server response: %s", message.content)
  end)
end

--- Removing console command
--- when package will disabled
package:listen("onDisable", function()
  concommand.Remove("do_ping")
end)

concommand.Add("do_ping", function()
	package:ping()
end)