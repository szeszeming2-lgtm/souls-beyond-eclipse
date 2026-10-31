--!strict
-- Shared look for every screen: colours, fonts, and small helpers to build UI in code.
-- Text is sized for phones and TVs: base sizes are large and everything scales with the screen.

local Workspace = game:GetService("Workspace")

local Theme = {}

Theme.colors = {
	panel = Color3.fromRGB(14, 16, 24),
	panelLight = Color3.fromRGB(30, 34, 48),
	text = Color3.fromRGB(240, 236, 228),
	dim = Color3.fromRGB(170, 168, 180),
	accent = Color3.fromRGB(242, 163, 58), -- lantern orange
	hp = Color3.fromRGB(229, 72, 77),
	spirit = Color3.fromRGB(242, 193, 78),
	xp = Color3.fromRGB(127, 184, 255),
	boss = Color3.fromRGB(200, 60, 80),
	good = Color3.fromRGB(120, 210, 140),
	barBack = Color3.fromRGB(40, 40, 52),
}

-- Attack-tell colours per colour-blind setting. The unblockable tell also shows a "!" icon,
-- so it never depends on colour alone.
Theme.tellColors = {
	none = { normal = Color3.fromRGB(255, 138, 61), unblockable = Color3.fromRGB(255, 46, 77) },
	protanopia = { normal = Color3.fromRGB(255, 210, 63), unblockable = Color3.fromRGB(61, 123, 255) },
	deuteranopia = { normal = Color3.fromRGB(255, 210, 63), unblockable = Color3.fromRGB(61, 123, 255) },
	tritanopia = { normal = Color3.fromRGB(255, 138, 61), unblockable = Color3.fromRGB(220, 40, 160) },
} :: { [string]: { normal: Color3, unblockable: Color3 } }

Theme.font = Enum.Font.GothamMedium
Theme.fontBold = Enum.Font.GothamBold

-- Screen scale: phones a little smaller, TVs larger, never so small text is hard to read.
function Theme.screenScale(): number
	local camera = Workspace.CurrentCamera
	local size = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local short = math.min(size.X, size.Y)
	return math.clamp(short / 760, 0.85, 1.4)
end

-- Creates an Instance and sets its properties. `Parent` is set last.
function Theme.make(className: string, props: { [string]: any }, children: { Instance }?): any
	local instance = (Instance.new :: any)(className)
	for key, value in props do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	local list: { Instance } = children or {}
	for _, child in list do
		child.Parent = instance
	end
	if props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

function Theme.label(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		TextColor3 = Theme.colors.text,
		Font = Theme.font,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for key, value in props do
		defaults[key] = value
	end
	return Theme.make("TextLabel", defaults)
end

function Theme.button(props: { [string]: any }): TextButton
	local defaults = {
		BackgroundColor3 = Theme.colors.panelLight,
		TextColor3 = Theme.colors.text,
		Font = Theme.fontBold,
		TextSize = 20,
		AutoButtonColor = true,
		Selectable = true,
	}
	for key, value in props do
		defaults[key] = value
	end
	local button = Theme.make("TextButton", defaults)
	Theme.make("UICorner", { CornerRadius = UDim.new(0, 8), Parent = button })
	return button
end

function Theme.corner(parent: Instance, radius: number?)
	Theme.make("UICorner", { CornerRadius = UDim.new(0, radius or 8), Parent = parent })
end

-- A bar: returns (frame, fill, text).
function Theme.bar(
	parent: Instance,
	name: string,
	size: UDim2,
	position: UDim2,
	color: Color3
): (Frame, Frame, TextLabel)
	local frame = Theme.make("Frame", {
		Name = name,
		Size = size,
		Position = position,
		BackgroundColor3 = Theme.colors.barBack,
		BorderSizePixel = 0,
		Parent = parent,
	})
	Theme.corner(frame, 6)
	local fill = Theme.make("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = frame,
	})
	Theme.corner(fill, 6)
	local text = Theme.label({
		Name = "Text",
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 14,
		Font = Theme.fontBold,
		TextStrokeTransparency = 0.5,
		ZIndex = 3,
		Parent = frame,
	})
	return frame, fill, text
end

-- Short on-screen names for input names ("MouseButton1" -> "LMB").
local SHORT = {
	MouseButton1 = "LMB",
	MouseButton2 = "RMB",
	MouseButton3 = "MMB",
	LeftShift = "Shift",
	RightShift = "Shift",
	LeftControl = "Ctrl",
	LeftAlt = "Alt",
	Return = "Enter",
	Backspace = "Bksp",
	ButtonL1 = "LB",
	ButtonR1 = "RB",
	ButtonL2 = "LT",
	ButtonR2 = "RT",
	ButtonL3 = "L3",
	ButtonR3 = "R3",
	ButtonSelect = "View",
	ButtonStart = "Menu",
	DPadUp = "D-pad Up",
	DPadDown = "D-pad Down",
	DPadLeft = "D-pad Left",
	DPadRight = "D-pad Right",
	Thumbstick1 = "Left stick",
	Thumbstick2 = "Right stick",
	["Composite:WASD"] = "WASD",
	["Composite:Arrows"] = "Arrows",
	["Composite:DPad"] = "D-pad",
}

function Theme.inputName(name: string): string
	local short = SHORT[name]
	if short then
		return short
	end
	local button = string.match(name, "^Button(%a)$")
	if button then
		return button
	end
	local touch = string.match(name, "^TouchButton(.+)$")
	if touch then
		return touch
	end
	return name
end

return Theme
