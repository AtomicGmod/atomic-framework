if (not util.IsBinaryModuleInstalled("mysqloo")) then
	return
end

if (not mysqloo) then
  require("mysqloo")
end

atomic.mysql = atomic.mysql or {
  logger = atomic.logger.new("mysql")
}

local logger = atomic.mysql.logger

file.CreateDir("atomic/mysql")

if (file.Size("data/atomic/mysql/credentials.json", "GAME") <= 0) then
  local defaultJson = [[{
    "host": "127.0.0.1",
    "user": "root",
    "password": "root",
    "table": "gmod",
    "port": 3306
}]];

  file.Write("atomic/mysql/credentials.json", defaultJson)
	logger:warn("the `credentials.json` file has just been created in `data/atomic/mysql/` folder. to work with MySQL, fill in the database connection credentials in this file.")
end

---@class Atomic.MySQL.Credentials
---@field host string
---@field user string
---@field password string
---@field table string
---@field port? integer
local credentials = util.JSONToTable(file.Read("atomic/mysql/credentials.json"))
local autoconnect = CreateConVar("atomic_mysql_autoconnect", "1", {FCVAR_PROTECTED, FCVAR_ARCHIVE}, "Should the connection to MySQL be automatic?")

if (autoconnect:GetBool() and not atomic.mysql._database) then
  atomic.mysql._database = mysqloo.connect(
    credentials.host,
    credentials.user,
    credentials.password,
    credentials.table,
    credentials.port or 3306
  )

  atomic.mysql._database.onConnected = function(_)
    logger:info("successfully connected to the MySQL database")
  end

  atomic.mysql._database.onConnectionFailed = function(_, err)
    logger:err("error while connecting to database: %s", err)
  end

  atomic.mysql._database.onError = function(_, err, sql)
    logger:debug("error executing query `%s`: %s", sql, err)
  end

  atomic.mysql._database:connect()
end

local prepareTypes = {
  string = "setString",
  boolean = "setBoolean",
  number = "setNumber"
}

--- Returns a raw database object
---@see https://github.com/FredyH/MySQLOO/
function atomic.mysql.getDatabase()
  return atomic.mysql._database
end

--- Checks whether the connection to the database is active.
---@return boolean
function atomic.mysql.isConnected()
  return atomic.mysql._database and atomic.mysql._database:ping()
end

--- Executes a query to the database, and escaping the arguments
---
--- ```lua
--- local data = atomic.mysqlo.query("SELECT * from users WHERE steamid=?;", Player(1):SteamID())
--- ```
---@async
---@param query string
---@vararg ...?
---@return table, string?
function atomic.mysql.query(query, ...)
  local co = coroutine.get()

  local prepared = atomic.mysql._database:prepare(query)
  prepared.onSuccess = function(_, data)
    coroutine.resume(co, data)
  end

  prepared.onError = function(_, err)
    coroutine.resume(co, nil, err)
  end

  for index, value in ipairs({...}) do
    local method = prepareTypes[type(value)] or prepareTypes.string
    prepared[method](prepared, index, value)
  end

  prepared:start()

  return coroutine.yield()
end