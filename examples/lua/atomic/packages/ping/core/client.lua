---@class ExamplePackagePing: Atomic.Package
local package = current()

-- Asynchronous variant

--- this function will send
--- an asynchronous network message to the server
--- and wait for a response
function package:pingAsync()
  local instant = Instant()

  async(function()
    local message = self:sendNetworkMessageAsync("Ping", {})

    local ms = instant:elapsed():as_millis()

    self.logger:debug("Server ping took %sms", ms)
    self.logger:debug("Server response: %s", message.content)
  end)
end

concommand.Add("ping_async", function()
	package:pingAsync()
end)

-- Synchronous variant

---@type table<string, Atomic.Time.Instant>
package.syncMessagesId = {}

function package:ping()
  local instant = Instant()

  -- every network message have id
  local messageId = self:sendNetworkMessage("Ping", {})

  -- saving network packet sending time
  self.syncMessagesId[messageId] = instant
end

package:onNetworkMessage(function(self, message)
  local response = message.content

  local time = self.syncMessagesId[message:getId()]

  if (time) then
    self.logger:debug("Server ping took %sms", time:elapsed():as_millis())
  end

  self.logger:debug("Server response: %s", response)
end, "Ping")

concommand.Add("ping", function()
  package:ping()
end)