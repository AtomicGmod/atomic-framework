atomic.i18n = atomic.i18n or {
  ---@table
  _storage = {},
  _defaultLanguage = "en",
  _logger = atomic.logger.new("i18n")
}

local logger = atomic.i18n._logger

---@param language string
---@return table<string, string>
function atomic.i18n.getTable(language)
  return atomic.i18n._storage[language]
end

---@param languageName string
---@param languageTable table<string, string>
function atomic.i18n.register(languageName, languageTable)
  languageName = languageName:Trim():lower()

  if (not atomic.i18n._storage[languageName]) then
    atomic.i18n._storage[languageName] = languageTable
    logger:debug("language %s has been registered", languageName)
  else
    for k, v in pairs(languageTable) do
      atomic.i18n._storage[languageName][k] = v
    end
  end

end

--- Adds a phrase to an existing language table
---
--- ```lua
--- atomic.i18n.addPhrase("en", "boughtDoor", "You have bought a door!")
--- ```
---@param language string
---@param phraseIndex string
---@param phrase string
function atomic.i18n.addPhrase(language, phraseIndex, phrase)
  if (not atomic.i18n._storage[language]) then
    atomic.i18n._storage[language] = {}
  end

  atomic.i18n._storage[language][phraseIndex] = phrase
end

--- Adds a phrases to an existing languages
----
--- ```lua
--- atomic.i18n.addPhrases({
---   en = {
---     boughtDoor = "You have bought a door!"
---   },
---   ru = {
---     boughtDoor = "Вы купили дверь!"
---   }
--- })
--- ```
---@param tab table<string, table<string, string>>
function atomic.i18n.addPhrases(tab)
  local storage = atomic.i18n._storage

  -- mixing
  for lang, langTable in pairs(tab) do
    if (not storage[lang]) then
      storage[lang] = {}
    end

    for phraseIndex, phrase in pairs(langTable) do
      storage[lang][phraseIndex] = phrase
    end
  end
end

---@param language string
---@param phraseIndex string
function atomic.i18n.removePhrase(language, phraseIndex)
  local storage = atomic.i18n._storage

  if (not storage[language]) then
    return
  end

  storage[language][phraseIndex] = nil
end

--- Returns the player's current language, for example “en”
---
--- ```lua
--- hook.Add("PlayerSpawn", "example", function(player)
---   local lang = atomic.i18n.getPlayerLanguage(player)
---   local phrase = atomic.i18n.getPhrase(lang, "playerSpawned")
---
---   player:ChatPrint(phrase)
--- end)
--- ```
---@return string
function atomic.i18n.getLanguage()
  return GetConVar("gmod_language"):GetString() or atomic.i18n._defaultLanguage
end

atomic.i18n.getPlayerLanguage = atomic.i18n.getLanguage

--- Finds language phrase and formats it
---
--- ```lua
--- atomic.i18n.addPhrase("en", "boughtManyDoors", "You have bought %s doors!")
--- local phrase = atomic.i18n.getPhrase("en", "boughtManyDoors", 3) -- will be "You have bought 3 doors!"
---
--- atomic.i18n.getPhrase("ru", "boughtManyDoors", 3) -- also will be "You have bought 3 doors!", because of function has fallback to the default language (english)
--- atomic.i18n.getPhrase("en", "someNonExistsPhrase") -- will be "someNonExistsPhrase", because of the phrase is not registered
---
--- if (CLIENT) then
---   -- client only!
---   atomic.i18n.getPhrase(NULL, "boughtManyDoors")
--- end
---
--- if (SERVER) then
---   atomic.i18n.getPhrase(Player(2), "boughtManyDoors")
--- end
--- ```
---@param language string
---@param phraseIndex string
---@vararg string | number
---@return string
function atomic.i18n.getPhrase(language, phraseIndex, ...)
  if (isentity(language)) then
    ---@diagnostic disable-next-line
    language = atomic.i18n.getPlayerLanguage(language)
  end

  local langTable = atomic.i18n._storage[language]
  local phrase = langTable and langTable[phraseIndex]

  if (not langTable or not phrase) then
    -- fallback on phrase/language not found
    local default = atomic.i18n._defaultLanguage
    return language ~= default and atomic.i18n.getPhrase(default, phraseIndex, ...) or phraseIndex
  end

  return phrase:format(...)
end