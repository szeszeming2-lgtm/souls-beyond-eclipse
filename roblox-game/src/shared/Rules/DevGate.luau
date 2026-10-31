--!strict
-- Decides whether developer-only tools (progress reset, grant XP) may run. Pure, so the
-- "never in a live game" rule is tested. The server passes RunService:IsStudio() in.

local DevGate = {}

-- Dev tools only ever work inside Roblox Studio. There is no list of players who can use them
-- in a live game, by design: admin cheats never ship.
function DevGate.allowed(isStudio: boolean): boolean
	return isStudio == true
end

return DevGate
