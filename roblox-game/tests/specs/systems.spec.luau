-- Settings, input mapping, reward guards, the client protocol, enemy brain, boss phases, dev gate.

local Settings = loader:require(Shared.Rules.Settings)
local InputMap = loader:require(Shared.Rules.InputMap)
local RewardGuards = loader:require(Shared.Rules.RewardGuards)
local Protocol = loader:require(Shared.Rules.Protocol)
local EnemyBrain = loader:require(Shared.Rules.EnemyBrain)
local BossPhases = loader:require(Shared.Rules.BossPhases)
local DevGate = loader:require(Shared.Rules.DevGate)
local Data = loader:require(Shared.Data)

local defs = Data.settings.settings

describe("Settings", function()
	it("defaults come from settings.json, filtered by platform", function()
		local roblox = Settings.defaults(defs, "roblox")
		expect(roblox.difficulty).toBe("normal")
		expect(roblox.effects_quality).toBe("auto")
		expect(Settings.defaults(defs, "pc").effects_quality).toBe(nil)
	end)

	it("clamps and snaps sliders, rejects bad values", function()
		local def = Settings.find(defs, "camera_sensitivity")
		local ok, v = Settings.coerce(def, 99)
		expect(ok).toBe(true)
		expect(v).toBe(def.max)
		local _, snapped = Settings.coerce(def, 1.04)
		expect(snapped).toBeNear(1.0)
		expect(Settings.coerce(def, "fast")).toBe(false)
		expect(Settings.coerce(Settings.find(defs, "difficulty"), "nightmare")).toBe(false)
	end)

	it("sanitize keeps good values and resets bad ones", function()
		local clean, reset =
			Settings.sanitize({ difficulty = "story", camera_shake = "loud", unknown = 1 }, defs, "roblox")
		expect(clean.difficulty).toBe("story")
		expect(clean.camera_shake).toBe(0.6)
		expect(reset).toEqual({ "camera_shake" })
	end)
end)

describe("Input mapping", function()
	local inputs = Data.inputActions

	it("maps keys, buttons and touch to actions", function()
		local map = InputMap.build(inputs, "roblox", {})
		expect(InputMap.actionFor(map, "gameplay", "keyboard_mouse", "MouseButton1")).toBe("light_attack")
		expect(InputMap.actionFor(map, "gameplay", "gamepad", "ButtonX")).toBe("light_attack")
		expect(InputMap.actionFor(map, "gameplay", "touch", "TouchButtonAttack")).toBe("light_attack")
		expect(InputMap.actionFor(map, "gameplay", "keyboard_mouse", "Q")).toBe("ability_1")
		expect(InputMap.actionFor(map, "menu", "keyboard_mouse", "Q")).toBe("menu_tab_prev")
	end)

	it("on Roblox, pause avoids the keys Roblox keeps for itself", function()
		local roblox = InputMap.build(inputs, "roblox", {})
		expect(InputMap.actionFor(roblox, "gameplay", "keyboard_mouse", "Escape")).toBe(nil)
		expect(InputMap.actionFor(roblox, "gameplay", "keyboard_mouse", "P")).toBe("pause")
		expect(InputMap.actionFor(roblox, "gameplay", "gamepad", "ButtonStart")).toBe(nil)
		expect(InputMap.actionFor(roblox, "gameplay", "gamepad", "ButtonSelect")).toBe("pause")
		local pc = InputMap.build(inputs, "pc", {})
		expect(InputMap.actionFor(pc, "gameplay", "keyboard_mouse", "Escape")).toBe("pause")
	end)

	it("WASD drives the move axis", function()
		local map = InputMap.build(inputs, "roblox", {})
		local action, x, y = InputMap.directionFor(map, "gameplay", "keyboard_mouse", "W")
		expect(action).toBe("move")
		expect(x).toBe(0)
		expect(y).toBe(1)
		local _, ax = InputMap.directionFor(map, "gameplay", "keyboard_mouse", "A")
		expect(ax).toBe(-1)
	end)

	it("the right-click preset swaps guard and heavy", function()
		local map = InputMap.build(inputs, "roblox", { "right_click_guard" })
		expect(InputMap.actionFor(map, "gameplay", "keyboard_mouse", "MouseButton2")).toBe("guard")
		expect(InputMap.actionFor(map, "gameplay", "keyboard_mouse", "C")).toBe("heavy_attack")
	end)

	it("every gameplay action can be used on every device", function()
		local map = InputMap.build(inputs, "roblox", {})
		for _, action in inputs.actions do
			for _, device in InputMap.DEVICES do
				expect(#InputMap.hintsFor(map, action.id, device)).toBeAtLeast(1)
			end
		end
	end)
end)

describe("Reward guards", function()
	local grind = Data.progression.anti_grind

	it("full XP for normal play, less for farming one enemy", function()
		local state = RewardGuards.newGrind()
		for i = 1, grind.full_reward_kills do
			expect(RewardGuards.grindMultiplier(state, "enm_gloamling", i, grind)).toBe(1)
		end
		local next = RewardGuards.grindMultiplier(state, "enm_gloamling", 30, grind)
		expect(next).toBeLessThan(1)
		for i = 1, 50 do
			RewardGuards.grindMultiplier(state, "enm_gloamling", 40 + i, grind)
		end
		expect(RewardGuards.grindMultiplier(state, "enm_gloamling", 95, grind)).toBe(grind.floor_multiplier)
		expect(RewardGuards.grindMultiplier(state, "enm_lampeater", 96, grind)).toBe(1)
	end)

	it("recovers after the window passes", function()
		local state = RewardGuards.newGrind()
		for i = 1, 40 do
			RewardGuards.grindMultiplier(state, "enm_gloamling", i, grind)
		end
		expect(RewardGuards.grindMultiplier(state, "enm_gloamling", 40 + grind.window_s, grind)).toBe(1)
	end)

	it("clamps impossible XP rates without punishing", function()
		local rate = RewardGuards.newRate()
		local allowed, alarmed = RewardGuards.clampXp(rate, 500, 0, 100, 8)
		expect(allowed).toBe(500)
		expect(alarmed).toBe(false)
		allowed, alarmed = RewardGuards.clampXp(rate, 1000, 10, 100, 8)
		expect(allowed).toBe(300)
		expect(alarmed).toBe(true)
		allowed = RewardGuards.clampXp(rate, 100, 70, 100, 8)
		expect(allowed).toBe(100)
	end)
end)

describe("Server rejects client-claimed XP and rewards", function()
	it("accepts plain intents", function()
		expect(Protocol.parseAction({ a = "light" }) ~= nil).toBe(true)
		expect(Protocol.parseAction({ a = "dodge", dir = { x = 0.6, z = 0.8 } }) ~= nil).toBe(true)
	end)

	it("rejects any attempt to send XP, rewards or damage", function()
		local attempts = {
			{ a = "grant_xp", amount = 1e9 },
			{ a = "light", xp = 5000 },
			{ a = "light", damage = 99999 },
			{ a = "reward", item = "wpn_hearthwick" },
			{ a = "special", currency = 100 },
		}
		for _, payload in attempts do
			local parsed, reason = Protocol.parseAction(payload)
			expect(parsed).toBe(nil)
			expect(reason ~= nil).toBe(true)
		end
	end)

	it("rejects malformed payloads without crashing", function()
		for _, payload in
			{
				nil,
				5,
				"light",
				{},
				{ a = 7 },
				{ a = "dodge", dir = { x = 5, z = 5 } },
				{ a = "dodge", dir = { x = 0 / 0, z = 0 } },
			}
		do
			expect(Protocol.parseAction(payload)).toBe(nil)
		end
	end)

	it("checks settings payload shape", function()
		expect(Protocol.parseSettings({ difficulty = "story" }, 50) ~= nil).toBe(true)
		expect(Protocol.parseSettings({ difficulty = { 1, 2 } }, 50)).toBe(nil)
		expect(Protocol.parseSettings({ [1] = true }, 50)).toBe(nil)
	end)
end)

describe("Enemy brain", function()
	local attacks = {
		{ id = "swipe", range = 6, readyAt = 0 },
		{ id = "pounce", range = 18, readyAt = 0 },
	}

	it("chases a target out of reach", function()
		local d = EnemyBrain.decide({
			now = 0,
			distanceToTarget = 30,
			distanceFromHome = 0,
			leashRange = 90,
			attacks = attacks,
			hasAttackToken = true,
			busy = false,
		})
		expect(d.kind).toBe("chase")
	end)

	it("prefers the short attack up close and the long one further away", function()
		expect(EnemyBrain.pickAttack(attacks, 4, 0)).toBe("swipe")
		expect(EnemyBrain.pickAttack(attacks, 12, 0)).toBe("pounce")
	end)

	it("waits without an attack token (only a few attackers at once)", function()
		local d = EnemyBrain.decide({
			now = 0,
			distanceToTarget = 4,
			distanceFromHome = 0,
			leashRange = 90,
			attacks = attacks,
			hasAttackToken = false,
			busy = false,
		})
		expect(d.kind).toBe("wait")
	end)

	it("gives up and goes home past the leash", function()
		local d = EnemyBrain.decide({
			now = 0,
			distanceToTarget = 4,
			distanceFromHome = 120,
			leashRange = 90,
			attacks = attacks,
			hasAttackToken = true,
			busy = false,
		})
		expect(d.kind).toBe("return")
	end)

	it("respects cooldowns", function()
		local cooling = { { id = "swipe", range = 6, readyAt = 10 } }
		expect(EnemyBrain.pickAttack(cooling, 4, 5)).toBe(nil)
	end)
end)

describe("Boss phases", function()
	local boss = Data.enemies["enm_lampeater"].boss

	it("finds the phase for an HP fraction", function()
		expect(BossPhases.indexFor(boss.phases, 1)).toBe(1)
		expect(BossPhases.indexFor(boss.phases, 0.61)).toBe(1)
		expect(BossPhases.indexFor(boss.phases, 0.6)).toBe(2)
		expect(BossPhases.indexFor(boss.phases, 0.1)).toBe(3)
	end)

	it("restarts from the furthest phase reached, not full HP", function()
		expect(BossPhases.resetHp(boss.phases, 3, 1000, true)).toBe(250)
		expect(BossPhases.resetHp(boss.phases, 3, 1000, false)).toBe(1000)
	end)

	it("offers more help after more defeats", function()
		local t = Data.difficulty.boss_assist.offer_after_failures
		expect(#BossPhases.assistOffers(1, t)).toBe(0)
		expect(BossPhases.assistOffers(t.tip, t)).toEqual({ "tip" })
		expect(#BossPhases.assistOffers(t.support_buff, t)).toBe(3)
	end)
end)

describe("Dev tools", function()
	it("only ever run inside Roblox Studio", function()
		expect(DevGate.allowed(true)).toBe(true)
		expect(DevGate.allowed(false)).toBe(false)
		expect(DevGate.allowed(nil :: any)).toBe(false)
	end)
end)
