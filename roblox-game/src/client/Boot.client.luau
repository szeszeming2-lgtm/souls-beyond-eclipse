--!strict
-- Phase 0 smoke test. NOT gameplay code.
-- It only proves that the client can read the shared GameData modules.
-- Phase 1 replaces this with the real client bootstrap.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameData")) :: any

local actionCount = #GameData.InputActions.actions
assert(actionCount > 0, "input actions should not be empty")

print(string.format("[SBE] Phase 0 smoke test PASSED on the client: %d input actions loaded.", actionCount))
