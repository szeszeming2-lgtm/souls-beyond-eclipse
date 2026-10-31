--!strict
-- Bosses: one per boss arena in the map data. Adds phases, checkpoints, the boss bar and
-- optional help for players who keep losing.
--
-- Anti-frustration:
--   * Entering the arena sets your respawn checkpoint next to it.
--   * If everyone in the fight falls, the boss restarts at the start of the furthest phase
--     reached (checkpoint_each_phase), not at full health.
--   * After repeated defeats you are offered a tip, a suggested level, then a support buff.
--     All offers are optional.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Data = require(Shared:WaitForChild("Data"))
local Net = require(Shared.Net)
local BossPhases = require(Shared.Rules.BossPhases)
local DataTypes = require(Shared.Rules.DataTypes)

local PlayerDataService = require(script.Parent.PlayerDataService)
local CharacterService = require(script.Parent.CharacterService)
local CombatService = require(script.Parent.CombatService)
local EnemyService = require(script.Parent.EnemyService)
local FxService = require(script.Parent.FxService)

local CHECK_S = 0.5
local WIPE_RESET_S = 6 -- seconds with nobody alive in the arena before the boss resets
local RESPAWN_S = 45
local CHECKPOINT_CLEAR_MARGIN = 60

local BossService = {}

type Arena = {
	def: DataTypes.Enemy,
	boss: DataTypes.Boss,
	center: Vector3,
	radius: number,
	checkpoint: Vector3,
	level: number,
	state: Configuration,
	live: EnemyService.Live?,
	phase: number,
	furthest: number,
	emptySince: number?,
	offers: { [Player]: { string } },
}

local arenas: { Arena } = {}

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local function publish(arena: Arena, engaged: boolean)
	local live = arena.live
	local state = arena.state
	state:SetAttribute("Active", engaged and live ~= nil and live.alive)
	state:SetAttribute("Name", arena.def.name)
	state:SetAttribute("Title", arena.boss.title)
	state:SetAttribute("HP", if live then live.hp else 0)
	state:SetAttribute("MaxHP", if live then live.maxHp else 1)
	state:SetAttribute("Phase", arena.phase)
	state:SetAttribute("PhaseName", arena.boss.phases[arena.phase].name)
	state:SetAttribute("PhaseCount", #arena.boss.phases)
	state:SetAttribute("ArenaX", arena.center.X)
	state:SetAttribute("ArenaZ", arena.center.Z)
	state:SetAttribute("ArenaRadius", arena.radius)
end

local function applyPhase(arena: Arena, index: number, announce: boolean)
	local live = arena.live
	if live == nil then
		return
	end
	local phase = arena.boss.phases[index]
	arena.phase = index
	arena.furthest = math.max(arena.furthest, index)
	live.allowedAttacks = phase.attack_ids
	live.speedMult = phase.speed_mult
	if announce then
		live.invulnerableUntil = os.clock() + phase.transition_invulnerable_s
		live.actionToken += 1 -- a phase change interrupts the current attack
		live.busyUntil = os.clock() + phase.transition_invulnerable_s
		FxService.all({ k = "phase", name = phase.name, index = index, boss = arena.def.name })
	end
end

local function spawnBoss(arena: Arena)
	arena.phase = 1
	arena.furthest = 1
	arena.live = EnemyService.spawn(arena.def, arena.level, arena.center, {
		isBoss = true,
		leash = arena.radius + 15,
		allowedAttacks = arena.boss.phases[1].attack_ids,
	})
	applyPhase(arena, 1, false)
	publish(arena, false)
end

local function playersInArena(arena: Arena, margin: number): { Player }
	local out = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local offset = root.Position - arena.center
			if Vector3.new(offset.X, 0, offset.Z).Magnitude <= arena.radius + margin then
				table.insert(out, player)
			end
		end
	end
	return out
end

local function isAlive(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function onPlayerFell(arena: Arena, player: Player)
	local data = PlayerDataService.get(player)
	if data == nil then
		return
	end
	local id = arena.def.id
	data.boss_failures[id] = (data.boss_failures[id] or 0) + 1
	local thresholds = Data.difficulty.boss_assist.offer_after_failures
	local offers = BossPhases.assistOffers(data.boss_failures[id], thresholds)
	if #offers == 0 then
		return
	end
	arena.offers[player] = offers
	local tips = arena.boss.assist_tips
	Net.event("Notify"):FireClient(player, {
		kind = "assist",
		boss = arena.def.name,
		offers = offers,
		tip = tips[((data.boss_failures[id] - 1) % #tips) + 1],
		suggestedLevel = arena.boss.suggested_level,
		buffName = Data.statusEffects[Data.difficulty.boss_assist.support_buff_status_id].name,
	})
end

local function watchArena(arena: Arena)
	while true do
		task.wait(CHECK_S)
		local live = arena.live
		if live and live.alive then
			local inside = playersInArena(arena, 0)
			for _, player in inside do
				CharacterService.setCheckpoint(player, arena.checkpoint)
			end
			for _, player in Players:GetPlayers() do
				if not table.find(playersInArena(arena, CHECKPOINT_CLEAR_MARGIN), player) then
					CharacterService.setCheckpoint(player, nil)
				end
			end
			local anyAlive = false
			for _, player in inside do
				if isAlive(player) then
					anyAlive = true
				end
			end
			local engaged = live.hp < live.maxHp
			if engaged and not anyAlive then
				arena.emptySince = arena.emptySince or os.clock()
				if os.clock() - (arena.emptySince :: number) >= WIPE_RESET_S then
					-- Everyone fell or left: restart from the furthest phase's checkpoint.
					live.hp = BossPhases.resetHp(
						arena.boss.phases,
						arena.furthest,
						live.maxHp,
						arena.boss.checkpoint_each_phase
					)
					live.model:SetAttribute("HP", live.hp)
					live.target = nil
					applyPhase(arena, BossPhases.indexFor(arena.boss.phases, live.hp / live.maxHp), false)
					arena.emptySince = nil
				end
			else
				arena.emptySince = nil
			end
			publish(arena, #inside > 0)
		end
	end
end

function BossService.start()
	local folder = Instance.new("Folder")
	folder.Name = "BossStates"
	folder.Parent = ReplicatedStorage

	for _, map in Data.maps do
		for _, arenaData in map.boss_arenas do
			local def = Data.enemies[arenaData.boss_id]
			local boss = def and def.boss
			if def and boss then
				local state = Instance.new("Configuration")
				state.Name = arenaData.id
				state.Parent = folder
				local arena: Arena = {
					def = def,
					boss = boss,
					center = v3(arenaData.center),
					radius = arenaData.radius_studs,
					checkpoint = v3(arenaData.checkpoint_position),
					level = boss.suggested_level or 1,
					state = state,
					live = nil,
					phase = 1,
					furthest = 1,
					emptySince = nil,
					offers = {},
				}
				table.insert(arenas, arena)
				spawnBoss(arena)
				task.spawn(watchArena, arena)
			end
		end
	end

	EnemyService.damaged:Connect(function(enemy)
		for _, arena in arenas do
			local live = arena.live
			if live ~= nil and live == enemy and live.alive then
				local index = BossPhases.indexFor(arena.boss.phases, live.hp / live.maxHp)
				if index > arena.phase then
					applyPhase(arena, index, true)
				end
				publish(arena, true)
			end
		end
	end)

	EnemyService.defeated:Connect(function(enemy, rewarded: { Player })
		for _, arena in arenas do
			if arena.live == enemy then
				for _, player in rewarded do
					local data = PlayerDataService.get(player)
					if data then
						if not table.find(data.bosses_defeated, arena.def.id) then
							table.insert(data.bosses_defeated, arena.def.id)
						end
						data.boss_failures[arena.def.id] = 0
					end
					arena.offers[player] = nil
					Net.event("Notify")
						:FireClient(player, { kind = "boss_defeated", boss = arena.def.name, title = arena.boss.title })
				end
				arena.state:SetAttribute("Active", false)
				task.delay(RESPAWN_S, function()
					spawnBoss(arena)
				end)
			end
		end
	end)

	CombatService.assistRequested:Connect(function(player: Player, kind: string)
		for _, arena in arenas do
			local offers = arena.offers[player]
			if offers and kind == "support_buff" and table.find(offers, "support_buff") then
				CombatService.addBuff(player, Data.difficulty.boss_assist.support_buff_status_id)
				arena.offers[player] = nil
			end
		end
	end)

	local function watchDeaths(player: Player)
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
			if humanoid == nil then
				return
			end
			humanoid.Died:Connect(function()
				for _, arena in arenas do
					local live = arena.live
					if
						live
						and live.alive
						and live.hp < live.maxHp
						and table.find(playersInArena(arena, 10), player)
					then
						onPlayerFell(arena, player)
					end
				end
			end)
		end)
	end
	Players.PlayerAdded:Connect(watchDeaths)
	for _, player in Players:GetPlayers() do
		watchDeaths(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		for _, arena in arenas do
			arena.offers[player] = nil
		end
	end)
end

return BossService
