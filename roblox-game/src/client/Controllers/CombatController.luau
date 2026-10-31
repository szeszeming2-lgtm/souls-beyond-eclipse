--!strict
-- Turns combat actions into requests to the server, and plays the local effect at once so
-- attacks feel instant. The server still decides every hit.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Data = require(Shared:WaitForChild("Data"))
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local InputController = require(script.Parent.InputController)
local MovementController = require(script.Parent.MovementController)
local CameraController = require(script.Parent.CameraController)
local FxController = require(script.Parent.FxController)

local player = Players.LocalPlayer
local LOCAL_THROTTLE_S = 0.12 -- the server queues inputs; this only avoids flooding it

local CombatController = {}
CombatController.notAvailable = Signal.new() -- (actionLabel) for actions not in this build yet

local lastSent: { [string]: number } = {}

local function send(payload: { [string]: any })
	Net.event("Action"):FireServer(payload)
end

local function aim()
	local target = CameraController.lockedTarget()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root == nil then
		return
	end
	if target and target.PrimaryPart then
		MovementController.face(target.PrimaryPart.Position - root.Position)
	else
		MovementController.face(CameraController.forward())
	end
end

local function throttled(key: string): boolean
	local now = os.clock()
	if now - (lastSent[key] or 0) < LOCAL_THROTTLE_S then
		return true
	end
	lastSent[key] = now
	return false
end

local function weaponSpecial(): any
	local hearthwick = Data.weapons["wpn_hearthwick"]
	return Data.abilities[hearthwick.special_ability_id]
end

function CombatController.start()
	InputController.pressed:Connect(function(actionId: string)
		if InputController.context() ~= "gameplay" then
			return
		end
		if actionId == "light_attack" or actionId == "heavy_attack" then
			local heavy = actionId == "heavy_attack"
			if throttled(actionId) then
				return
			end
			aim()
			FxController.swing(player.Character, heavy)
			send({ a = if heavy then "heavy" else "light" })
		elseif actionId == "ability_1" then
			if throttled(actionId) then
				return
			end
			aim()
			local ability = weaponSpecial()
			FxController.wickflare(player.Character, ability.timing.windup_s, ability.timing.active_s)
			send({ a = "special" })
		elseif actionId == "guard" then
			MovementController.setGuarding(true)
			send({ a = "guard_start" })
		elseif
			actionId == "ability_2"
			or actionId == "ability_3"
			or actionId == "ultimate"
			or actionId == "interact"
		then
			local action = Data.inputActions.actions
			for _, a in action do
				if a.id == actionId then
					CombatController.notAvailable:Fire(a.label)
				end
			end
		end
	end)
	InputController.released:Connect(function(actionId: string)
		if actionId == "guard" then
			MovementController.setGuarding(false)
			send({ a = "guard_end" })
		end
	end)
end

return CombatController
