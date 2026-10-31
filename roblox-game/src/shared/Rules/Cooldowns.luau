--!strict
-- Cooldown bookkeeping. Pure: the caller passes the current time in seconds.

local Cooldowns = {}

export type Cooldowns = { [string]: number } -- key -> time it becomes ready

function Cooldowns.new(): Cooldowns
	return {}
end

function Cooldowns.isReady(cooldowns: Cooldowns, key: string, now: number): boolean
	local readyAt = cooldowns[key]
	return readyAt == nil or now >= readyAt
end

function Cooldowns.start(cooldowns: Cooldowns, key: string, now: number, duration: number): number
	local readyAt = now + math.max(0, duration)
	cooldowns[key] = readyAt
	return readyAt
end

function Cooldowns.remaining(cooldowns: Cooldowns, key: string, now: number): number
	local readyAt = cooldowns[key]
	return if readyAt == nil then 0 else math.max(0, readyAt - now)
end

return Cooldowns
