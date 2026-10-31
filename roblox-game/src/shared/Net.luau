--!strict
-- Every RemoteEvent in one place. The server creates them; clients wait for them.
--
--   Action   client -> server  combat and menu intents, checked by Rules/Protocol
--   Settings both ways         client sends changes; server sends the saved settings on join
--   Notify   server -> client  level ups, loot, cooldowns, assist offers, knockback
--   Fx       server -> clients visual-only events (unreliable: a lost one only skips an effect)
--   Dev      both ways         Roblox Studio only; never created in a live game

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

local RELIABLE = { Action = true, Settings = true, Notify = true, Dev = true }
local FOLDER_NAME = "Remotes"

local function folder(): Instance
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if existing then
			return existing
		end
		local created = Instance.new("Folder")
		created.Name = FOLDER_NAME
		created.Parent = ReplicatedStorage
		return created
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

function Net.event(name: string): RemoteEvent
	assert(RELIABLE[name], `unknown remote {name}`)
	local parent = folder()
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing :: RemoteEvent
	end
	if RunService:IsServer() then
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = parent
		return remote
	end
	return parent:WaitForChild(name) :: RemoteEvent
end

function Net.fx(): UnreliableRemoteEvent
	local parent = folder()
	local existing = parent:FindFirstChild("Fx")
	if existing then
		return existing :: UnreliableRemoteEvent
	end
	if RunService:IsServer() then
		local remote = Instance.new("UnreliableRemoteEvent")
		remote.Name = "Fx"
		remote.Parent = parent
		return remote
	end
	return parent:WaitForChild("Fx") :: UnreliableRemoteEvent
end

-- Clients use this for the Studio-only Dev remote, which may not exist.
function Net.findEvent(name: string): RemoteEvent?
	local parent = if RunService:IsServer() then folder() else ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if parent == nil then
		return nil
	end
	local found = parent:FindFirstChild(name)
	return if found and found:IsA("RemoteEvent") then found else nil
end

-- Shared server/client clock (seconds) for cooldowns shown on screen.
function Net.now(): number
	return workspace:GetServerTimeNow()
end

return Net
