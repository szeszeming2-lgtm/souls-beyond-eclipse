--!strict
-- The one way game code reads shared data: typed lookups, built once.
--     local Data = require(ReplicatedStorage.Shared.Data)
--     local weapon = Data.weapons["wpn_hearthwick"]

local CatalogBuilder = require(script.Parent.Rules.CatalogBuilder)

return CatalogBuilder.build(require(script.Parent.GameData))
