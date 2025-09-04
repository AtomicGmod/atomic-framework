return {
  id = "dev.smokingplaya.character",
  nicename = "Character System",
  -- documentation = "",
  -- description = "",
  version = "1.0.0",
  dependencies = {
    ["dev.timschumi.chttp"] = "1.10.2"
  },
  configuration = {
    maxcharacters = {
      default = 1,
      vip = 2,
    }
  },
  files = {
    client = {""},
    server = {""},
    shared = {""}
  }
}