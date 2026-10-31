--!strict
-- Server entry point: starts every service in dependency order.

local Services = script.Parent:WaitForChild("Services")

local order: { any } = {
	require(Services:WaitForChild("FxService")),
	require(Services:WaitForChild("WorldService")),
	require(Services:WaitForChild("PlayerDataService")),
	require(Services:WaitForChild("SettingsService")),
	require(Services:WaitForChild("ProgressionService")),
	require(Services:WaitForChild("ItemService")),
	require(Services:WaitForChild("CharacterService")),
	require(Services:WaitForChild("CombatService")),
	require(Services:WaitForChild("EnemyService")),
	require(Services:WaitForChild("BossService")),
	require(Services:WaitForChild("DevService")),
}

for _, service in order do
	(service :: any).start()
end
require(Services:WaitForChild("PlayerDataService")).beginLoading()

print("[SBE] Server started: Phase 1 prototype (placeholder art)")
