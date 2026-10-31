--!strict
-- Developer tools for testing in Roblox Studio ONLY: add XP, reset progress.
-- Outside Studio this service does nothing at all: the Dev remote is never even created.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local DevGate = require(Shared.Rules.DevGate)
local RateLimiter = require(Shared.Rules.RateLimiter)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ProgressionService = require(script.Parent.ProgressionService)

local DevService = {}

function DevService.start()
	if not DevGate.allowed(RunService:IsStudio()) then
		return
	end
	local limiters: { [Player]: RateLimiter.Bucket } = {}
	local remote = Net.event("Dev")
	remote.OnServerEvent:Connect(function(player: Player, payload: any)
		if not DevGate.allowed(RunService:IsStudio()) or type(payload) ~= "table" then
			return
		end
		local now = os.clock()
		limiters[player] = limiters[player] or RateLimiter.new(5, 2, now)
		if not RateLimiter.allow(limiters[player], now) then
			return
		end
		if payload.cmd == "add_xp" and type(payload.amount) == "number" then
			local added = ProgressionService.addRawXp(player, math.clamp(payload.amount, 0, 10_000_000))
			print(`[SBE dev] {player.Name}: +{added} XP`)
		elseif payload.cmd == "reset" then
			PlayerDataService.devReset(player)
			ProgressionService.publish(player)
			print(`[SBE dev] {player.Name}: progress reset`)
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		limiters[player] = nil
	end)
	print("[SBE] Studio dev tools enabled (never available in a live game)")
end

return DevService
