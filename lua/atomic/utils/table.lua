local iswin = jit.os == "Windows"
local white = iswin and Color(255, 255, 255) or "\27[37m"
local blue = iswin and Color(0, 255, 255) or "\27[36m"

local typeAliases = {
  string = "str",
  number = "int",
  boolean = "bool",
  table = "tbl",
  thread = "thr",
  userdata = "ud",
  ["function"] = "fn",
  ["nil"] = "nil"
}

---@param tab table
---@param indent number?
---@param done table?
function table.debug(tab, indent, done)
  indent = indent or 0
  done = done or {}

  done[tab] = true

  local indentStr = ("\t"):rep(indent)

  local i = 0;
  for key, value in pairs(tab) do
    i = i + 1
    MsgC(indentStr, blue, typeAliases[type(key)], " ", white, tostring(key), white, " = ", blue, (typeAliases[type(value)] or type(value)), white, " ", tostring(value))
    MsgN()

    if istable(value) and not done[value] then
      table.debug(value, indent + 1, done)
    end
  end

  if (i == 0) then
    MsgC(indentStr, blue, "empty table")
    MsgN()
  end
end

---@diagnostic disable-next-line
td = table.debug