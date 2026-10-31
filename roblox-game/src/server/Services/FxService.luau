--!strict
-- Sends visual-only combat events to clients (swings, hits, attack tells). Unreliable on
-- purpose: a lost message only skips one effect, never changes a result.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local FxService = {}

local remote: UnreliableRemoteEvent? = nil

function FxService.all(event: { [string]: any })
	if remote then
		remote:FireAllClients(event)
	end
end

function FxService.to(player: Player, event: { [string]: any })
	if remote then
		remote:FireClient(player, event)
	end
end

function FxService.start()
	remote = Net.fx()
end

return FxService
