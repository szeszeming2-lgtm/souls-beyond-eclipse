--!strict
-- Name, level and health over each regular enemy (bosses use the big bar at the top instead).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Theme = require(script.Parent.Theme)

local player = Players.LocalPlayer
local TAG = "SBE_Enemy"

local EnemyBars = {}

local function attach(model: Instance)
	if
		not model:IsA("Model")
		or model:GetAttribute("Rank") == "boss"
		or model:GetAttribute("Rank") == "secret_boss"
	then
		return
	end
	local root = model.PrimaryPart
	if root == nil then
		return
	end
	local height = tonumber(model:GetAttribute("Height")) or 4
	local gui = Theme.make("BillboardGui", {
		Name = "SBE_EnemyBar",
		Size = UDim2.fromOffset(170, 38),
		StudsOffsetWorldSpace = Vector3.new(0, height * 0.6 + 1.5, 0),
		MaxDistance = 90,
		LightInfluence = 0,
		Adornee = root,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local name = Theme.label({
		Size = UDim2.new(1, 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.fontBold,
		TextSize = 16,
		TextStrokeTransparency = 0.4,
		Parent = gui,
	})
	local _, fill = Theme.bar(gui, "Health", UDim2.new(1, 0, 0, 10), UDim2.fromOffset(0, 22), Theme.colors.hp)
	local function refresh()
		local hp = tonumber(model:GetAttribute("HP")) or 0
		local maxHp = math.max(1, tonumber(model:GetAttribute("MaxHP")) or 1)
		fill.Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1)
		local burning = false
		for key in model:GetAttributes() do
			if string.sub(key, 1, 7) == "Effect_" then
				burning = true
			end
		end
		name.Text = `{model:GetAttribute("DisplayName") or "?"}  Lv {model:GetAttribute("Level") or "?"}`
		name.TextColor3 = if burning then Color3.fromRGB(255, 170, 90) else Theme.colors.text
	end
	refresh()
	model.AttributeChanged:Connect(refresh)
	model.Destroying:Connect(function()
		gui:Destroy()
	end)
end

function EnemyBars.start()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(attach)
	for _, model in CollectionService:GetTagged(TAG) do
		attach(model)
	end
end

return EnemyBars
