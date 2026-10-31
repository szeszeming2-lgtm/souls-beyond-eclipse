--!strict
-- Character movement from the unified input: camera-relative walking, sprint, jump, the
-- Flash Step dash, slower walking while guarding, slows from status effects, and knockback.
-- Roblox's default control scripts are switched off so every device goes through our actions.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Data = require(Shared:WaitForChild("Data"))
local Net = require(Shared.Net)
local InputController = require(script.Parent.InputController)
local Notifications = require(script.Parent.Notifications)

local player = Players.LocalPlayer
local MOVE = Data.combat.movement
local DODGE = Data.abilities["abl_flash_step"]
local SPRINT_AFTER_S = 0.3
local KNOCKBACK_TIME_S = 0.18

local MovementController = {}

local guarding = false
local dodgeReadyAt = 0
local dodgeTimes: { number } = {}
local facingLock: (() -> Vector3?)? = nil -- set by the camera while locked on

local function parts(): (Humanoid?, BasePart?)
	local character = player.Character
	if character == nil then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid == nil or humanoid.Health <= 0 then
		return nil, nil
	end
	return humanoid, root
end

-- Flat camera-relative direction for a 2D move vector.
function MovementController.worldDirection(move: Vector2): Vector3
	local camera = Workspace.CurrentCamera
	if camera == nil or move.Magnitude < 0.01 then
		return Vector3.zero
	end
	local look = camera.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z)
	forward = if forward.Magnitude > 1e-3 then forward.Unit else Vector3.new(0, 0, -1)
	local right = Vector3.new(-forward.Z, 0, forward.X)
	return right * move.X + forward * move.Y
end

-- Turns the character to face a flat direction right away (the client owns its character).
function MovementController.face(direction: Vector3)
	local _, root = parts()
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if root and flat.Magnitude > 1e-3 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat.Unit)
	end
end

function MovementController.setFacingLock(provider: (() -> Vector3?)?)
	facingLock = provider
end

function MovementController.setGuarding(on: boolean)
	guarding = on
end

local function slowMultiplier(): number
	local mult = 1
	local now = Net.now()
	for name, expiry in player:GetAttributes() do
		if string.sub(name, 1, 7) == "Effect_" and type(expiry) == "number" and expiry > now then
			local status = Data.statusEffects[string.sub(name, 8)]
			local cc = status and status.cc
			if cc and cc.type == "slow" then
				mult *= 1 - (cc.slow_fraction or 0)
			end
		end
	end
	return mult
end

local function stunned(): boolean
	local expiry = player:GetAttribute("Effect_sts_staggered")
	return type(expiry) == "number" and expiry > Net.now()
end

local function push(root: BasePart, velocity: Vector3, seconds: number)
	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local mover = Instance.new("LinearVelocity")
	mover.Attachment0 = attachment
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	mover.PrimaryTangentAxis = Vector3.xAxis
	mover.SecondaryTangentAxis = Vector3.zAxis
	mover.PlaneVelocity = Vector2.new(velocity.X, velocity.Z)
	mover.MaxForce = math.huge
	mover.Parent = root
	task.delay(seconds, function()
		mover:Destroy()
		attachment:Destroy()
	end)
end

-- Flash Step. Moves the character immediately; the server owns the invulnerability.
function MovementController.dodge()
	local humanoid, root = parts()
	local now = os.clock()
	if humanoid == nil or root == nil or now < dodgeReadyAt or stunned() then
		return
	end
	local window = Data.combat.dodge.chain_cooldown_s + DODGE.cooldown_s * Data.combat.dodge.chain_limit
	local recent = {}
	for _, t in dodgeTimes do
		if now - t < window then
			table.insert(recent, t)
		end
	end
	if #recent >= Data.combat.dodge.chain_limit then
		return
	end
	table.insert(recent, now)
	dodgeTimes = recent
	dodgeReadyAt = now + DODGE.cooldown_s
	local direction = MovementController.worldDirection(InputController.moveVector())
	if direction.Magnitude < 0.1 then
		direction = -root.CFrame.LookVector -- no direction held: step back
	end
	direction = Vector3.new(direction.X, 0, direction.Z).Unit
	local movement = DODGE.movement
	local distance = if movement then movement.distance_studs else 14
	local duration = if movement then movement.duration_s else 0.18
	push(root, direction * (distance / duration), duration)
	Net.event("Action"):FireServer({ a = "dodge", dir = { x = direction.X, z = direction.Z } })
end

local function step()
	local humanoid, root = parts()
	if humanoid == nil or root == nil then
		return
	end
	local move = if stunned() then Vector2.zero else InputController.moveVector()
	local direction = MovementController.worldDirection(move)
	humanoid:Move(direction, false)

	local held = InputController.isDown("dodge_sprint")
	local sprinting = held and os.clock() - dodgeReadyAt + DODGE.cooldown_s > SPRINT_AFTER_S and move.Magnitude > 0.1
	local speed = if guarding then MOVE.guard_walk_speed elseif sprinting then MOVE.sprint_speed else MOVE.walk_speed
	humanoid.WalkSpeed = speed * slowMultiplier()

	local lockedDirection = if facingLock then facingLock() else nil
	if lockedDirection then
		humanoid.AutoRotate = false
		local flat = Vector3.new(lockedDirection.X, 0, lockedDirection.Z)
		if flat.Magnitude > 1e-3 then
			local target = CFrame.lookAt(root.Position, root.Position + flat.Unit)
			root.CFrame = root.CFrame:Lerp(target, 0.3)
		end
	else
		humanoid.AutoRotate = true
	end
end

function MovementController.start()
	local playerModule =
		require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript) :: any
	playerModule:GetControls():Disable()

	InputController.pressed:Connect(function(actionId: string)
		if actionId == "jump" then
			local humanoid = parts()
			if humanoid and not guarding and not stunned() then
				humanoid.Jump = true
			end
		elseif actionId == "dodge_sprint" then
			MovementController.dodge()
		end
	end)

	Notifications.on("knockback", function(message: any)
		local _, root = parts()
		if root and type(message.x) == "number" and type(message.z) == "number" and type(message.studs) == "number" then
			local direction = Vector3.new(message.x, 0, message.z)
			if direction.Magnitude > 1e-3 then
				push(root, direction.Unit * (message.studs / KNOCKBACK_TIME_S), KNOCKBACK_TIME_S)
			end
		end
	end)

	RunService.RenderStepped:Connect(step)
end

return MovementController
