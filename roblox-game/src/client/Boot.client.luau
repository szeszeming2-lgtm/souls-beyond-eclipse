--!strict
-- Client entry point: starts every controller and screen in order.

local Controllers = script.Parent:WaitForChild("Controllers")
local UI = script.Parent:WaitForChild("UI")

local order: { any } = {
	require(Controllers:WaitForChild("SettingsController")),
	require(Controllers:WaitForChild("InputController")),
	require(Controllers:WaitForChild("Notifications")),
	require(Controllers:WaitForChild("MovementController")),
	require(Controllers:WaitForChild("CameraController")),
	require(Controllers:WaitForChild("FxController")),
	require(Controllers:WaitForChild("CombatController")),
	require(UI:WaitForChild("Toasts")),
	require(UI:WaitForChild("Hud")),
	require(UI:WaitForChild("Minimap")),
	require(UI:WaitForChild("EnemyBars")),
	require(UI:WaitForChild("PauseMenu")),
	require(UI:WaitForChild("TouchControls")),
	require(UI:WaitForChild("DevPanel")),
}

for _, module in order do
	module.start()
end

print("[SBE] Client started: Phase 1 prototype (placeholder art)")
