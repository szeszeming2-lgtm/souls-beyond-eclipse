--!strict
-- Third-person over-the-shoulder camera with lock-on. Mouse, right stick and touch swipes all
-- turn it. Camera shake follows the accessibility setting (0 = off).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Data = require(Shared:WaitForChild("Data"))
local Signal = require(Shared.Util.Signal)
local InputController = require(script.Parent.InputController)
local SettingsController = require(script.Parent.SettingsController)
local MovementController = require(script.Parent.MovementController)

local player = Players.LocalPlayer
local LOCK = Data.combat.lock_on
local ENEMY_TAG = "SBE_Enemy"
local MOUSE_DEG_PER_PIXEL = 0.25
local STICK_DEG_PER_S = 200
local TOUCH_DEG_PER_PIXEL = 0.35
local MIN_PITCH, MAX_PITCH = -70, 35
local MIN_ZOOM, MAX_ZOOM = 7, 22
local SHOULDER = 1.8
local FOCUS_HEIGHT = 2.6

local CameraController = {}
CameraController.lockChanged = Signal.new() -- (model or nil)

local yaw, pitch = 0, -12
local zoom = 13
local touchDelta = Vector2.zero
local lockTarget: Model? = nil
local shake = 0
local menuOpen = false
local reticle: BillboardGui? = nil

local function root(): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function targetPosition(model: Model): Vector3?
	local part = model.PrimaryPart
	if part == nil then
		return nil
	end
	local height = model:GetAttribute("Height")
	return part.Position + Vector3.new(0, if type(height) == "number" then height * 0.25 else 1, 0)
end

local function alive(model: Model): boolean
	local hp = model:GetAttribute("HP")
	return model.Parent ~= nil and type(hp) == "number" and hp > 0
end

local function setLock(model: Model?)
	lockTarget = model
	if reticle then
		reticle.Adornee = (if model then model.PrimaryPart else nil) :: any
		reticle.Enabled = model ~= nil
	end
	if model then
		MovementController.setFacingLock(function(): Vector3?
			local r = root()
			local p = lockTarget and targetPosition(lockTarget)
			return if r and p then p - r.Position else nil
		end)
	else
		MovementController.setFacingLock(nil)
	end
	CameraController.lockChanged:Fire(model)
end

-- Picks the enemy nearest the centre of the view, within range.
function CameraController.toggleLock()
	if lockTarget then
		setLock(nil)
		return
	end
	local camera = Workspace.CurrentCamera
	local r = root()
	if camera == nil or r == nil then
		return
	end
	local best: Model? = nil
	local bestScore = math.huge
	for _, instance in CollectionService:GetTagged(ENEMY_TAG) do
		if instance:IsA("Model") and alive(instance) then
			local p = targetPosition(instance)
			if p then
				local distance = (p - r.Position).Magnitude
				if distance <= LOCK.range_studs then
					local toTarget = (p - camera.CFrame.Position).Unit
					local angle = math.acos(math.clamp(toTarget:Dot(camera.CFrame.LookVector), -1, 1))
					local score = angle * 30 + distance * 0.2
					if angle < math.rad(70) and score < bestScore then
						best, bestScore = instance, score
					end
				end
			end
		end
	end
	setLock(best)
end

function CameraController.lockedTarget(): Model?
	return lockTarget
end

function CameraController.shake(amount: number)
	local setting = SettingsController.get("camera_shake")
	local scale = if type(setting) == "number" then setting else 0.6
	shake = math.min(1.5, shake + amount * scale)
end

function CameraController.addTouchDelta(delta: Vector2)
	touchDelta += delta
end

function CameraController.setMenuOpen(open: boolean)
	menuOpen = open
end

-- Flat "forward" of the camera, used to aim attacks when not locked on.
function CameraController.forward(): Vector3
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return Vector3.new(0, 0, -1)
	end
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	return if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
end

local function update(dt: number)
	local camera = Workspace.CurrentCamera
	local r = root()
	if camera == nil or r == nil then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable

	local mouseMode = InputController.device() == "keyboard_mouse" and not menuOpen
	UserInputService.MouseBehavior = if mouseMode then Enum.MouseBehavior.LockCenter else Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = not mouseMode

	local sensitivity = SettingsController.get("camera_sensitivity") or 1
	local invert = if SettingsController.get("invert_camera_y") then -1 else 1
	if mouseMode then
		local delta = UserInputService:GetMouseDelta()
		yaw -= delta.X * MOUSE_DEG_PER_PIXEL * sensitivity
		pitch -= delta.Y * MOUSE_DEG_PER_PIXEL * sensitivity * invert
	end
	local stick = InputController.cameraStick()
	local padSensitivity = SettingsController.get("gamepad_sensitivity") or 1
	yaw -= stick.X * STICK_DEG_PER_S * padSensitivity * dt
	pitch += stick.Y * STICK_DEG_PER_S * 0.6 * padSensitivity * invert * dt
	yaw -= touchDelta.X * TOUCH_DEG_PER_PIXEL * sensitivity
	pitch -= touchDelta.Y * TOUCH_DEG_PER_PIXEL * sensitivity * invert
	touchDelta = Vector2.zero

	if lockTarget then
		local p = if alive(lockTarget) then targetPosition(lockTarget) else nil
		if p == nil or (p - r.Position).Magnitude > LOCK.break_range_studs then
			setLock(nil)
		else
			local toTarget = p - r.Position
			local desiredYaw = math.deg(math.atan2(-toTarget.X, -toTarget.Z))
			local diff = (desiredYaw - yaw + 180) % 360 - 180
			yaw += diff * math.min(1, dt * 10)
			pitch += (-15 - pitch) * math.min(1, dt * 4)
		end
	end
	pitch = math.clamp(pitch, MIN_PITCH, MAX_PITCH)

	local focus = r.Position + Vector3.new(0, FOCUS_HEIGHT, 0)
	local rotation = CFrame.fromEulerAnglesYXZ(math.rad(pitch), math.rad(yaw), 0)
	local desired = focus + rotation:VectorToWorldSpace(Vector3.new(SHOULDER, 0, zoom))

	-- Keep walls from blocking the view.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances =
		{ player.Character :: Instance, Workspace:FindFirstChild("Enemies") :: Instance }
	local hit = Workspace:Raycast(focus, desired - focus, params)
	local position = if hit then hit.Position + (focus - desired).Unit * 0.6 else desired

	if shake > 0.01 then
		position += Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * shake
		shake *= math.exp(-dt * 12)
	else
		shake = 0
	end

	camera.CFrame = CFrame.new(position) * rotation.Rotation
	camera.Focus = CFrame.new(focus)
end

function CameraController.start()
	local gui = Instance.new("BillboardGui")
	gui.Name = "LockOnReticle"
	gui.Size = UDim2.fromOffset(36, 36)
	gui.AlwaysOnTop = true
	gui.Enabled = false
	local mark = Instance.new("TextLabel")
	mark.Size = UDim2.fromScale(1, 1)
	mark.BackgroundTransparency = 1
	mark.Text = "◇"
	mark.TextScaled = true
	mark.TextColor3 = Color3.fromRGB(255, 220, 150)
	mark.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	reticle = gui

	InputController.pressed:Connect(function(actionId: string)
		if actionId == "lock_on" then
			CameraController.toggleLock()
		end
	end)
	InputController.wheel:Connect(function(delta: number)
		if not menuOpen then
			zoom = math.clamp(zoom - delta * 1.5, MIN_ZOOM, MAX_ZOOM)
		end
	end)
	player.CharacterAdded:Connect(function()
		setLock(nil)
	end)
	RunService:BindToRenderStep("SBE_Camera", Enum.RenderPriority.Camera.Value + 1, update)
end

return CameraController
