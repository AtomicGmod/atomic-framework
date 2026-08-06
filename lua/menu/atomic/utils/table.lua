local white = Color(255, 255, 255)
local blue = Color(0, 255, 255)

local typeAliases = {
  string = "str",
  number = "int",
  boolean = "bool",
  table = "tbl",
  thread = "thrd",
  userdata = "user",
  ["function"] = "func",
  ["nil"] = "nil"
}

---@param  d any
---@return string
local function getTypeAlias(d)
  local t = type(d)
  return t == "table" and (d.__classname and d:__classname()) or typeAliases[t] or t
end

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
    MsgC(white, indentStr, tostring(key), " ", blue, getTypeAlias(key), white, " = ", blue, getTypeAlias(value), white, " ", tostring(value))
    MsgN()

    if istable(value) and not done[value] then
      table.debug(value, indent + 1, done)
    end
  end

  if (i == 0) then
    MsgC(indentStr, blue, "<empty table>")
    MsgN()
  end
end

---@diagnostic disable-next-line
td = table.debug