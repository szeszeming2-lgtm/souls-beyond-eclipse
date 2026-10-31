--!strict
-- Studio-only test buttons (add XP, reset the save). Never shown in a live game: the server
-- does not even create the Dev remote outside Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Theme = require(script.Parent.Theme)

local player = Players.LocalPlayer

local DevPanel = {}

function DevPanel.start()
	if not RunService:IsStudio() then
		return
	end
	local remote: RemoteEvent? = nil
	for _ = 1, 50 do
		remote = Net.findEvent("Dev")
		if remote then
			break
		end
		task.wait(0.1)
	end
	if remote == nil then
		return
	end
	local devRemote = remote :: RemoteEvent
	local gui = Theme.make(
		"ScreenGui",
		{ Name = "SBE_DevPanel", ResetOnSpawn = false, DisplayOrder = 30, Parent = player:WaitForChild("PlayerGui") }
	)
	local frame = Theme.make("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -36),
		Size = UDim2.fromOffset(190, 170),
		BackgroundColor3 = Color3.fromRGB(60, 20, 20),
		BackgroundTransparency = 0.2,
		Parent = gui,
	})
	Theme.corner(frame)
	Theme.label({
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -20, 0, 22),
		Text = "DEV (Studio only)",
		Font = Theme.fontBold,
		TextSize = 15,
		Parent = frame,
	})
	local function button(text: string, y: number, payload: { [string]: any })
		local b = Theme.button({
			Position = UDim2.fromOffset(10, y),
			Size = UDim2.new(1, -20, 0, 34),
			Text = text,
			TextSize = 15,
			Parent = frame,
		})
		b.Activated:Connect(function()
			devRemote:FireServer(payload)
		end)
	end
	button("+1,000 XP", 30, { cmd = "add_xp", amount = 1000 })
	button("+100,000 XP", 76, { cmd = "add_xp", amount = 100000 })
	button("Reset save", 122, { cmd = "reset" })
end

return DevPanel
