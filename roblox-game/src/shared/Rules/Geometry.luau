--!strict
-- Hit-area tests on the flat ground plane (x, z). Pure math on numbers, so it runs anywhere.
-- `facing` is the direction the attack points (it does not need to be normalized).
-- `targetRadius` makes big targets easier to hit, the way players expect.

local DataTypes = require(script.Parent.DataTypes)

local Geometry = {}

local function normalize(x: number, z: number): (number, number)
	local length = math.sqrt(x * x + z * z)
	if length < 1e-6 then
		return 0, 1
	end
	return x / length, z / length
end

function Geometry.inCircle(
	cx: number,
	cz: number,
	tx: number,
	tz: number,
	radius: number,
	targetRadius: number
): boolean
	local dx, dz = tx - cx, tz - cz
	local reach = radius + targetRadius
	return dx * dx + dz * dz <= reach * reach
end

function Geometry.inRing(
	cx: number,
	cz: number,
	tx: number,
	tz: number,
	radius: number,
	width: number,
	targetRadius: number
): boolean
	local dx, dz = tx - cx, tz - cz
	local distance = math.sqrt(dx * dx + dz * dz)
	return math.abs(distance - radius) <= width / 2 + targetRadius
end

function Geometry.inCone(
	ox: number,
	oz: number,
	fx: number,
	fz: number,
	tx: number,
	tz: number,
	radius: number,
	angleDeg: number,
	targetRadius: number
): boolean
	local dx, dz = tx - ox, tz - oz
	local distance = math.sqrt(dx * dx + dz * dz)
	if distance > radius + targetRadius then
		return false
	end
	if distance <= targetRadius then
		return true -- standing inside the attacker counts as hit
	end
	local nfx, nfz = normalize(fx, fz)
	local cosAngle = (dx * nfx + dz * nfz) / distance
	-- widen the cone by the target's size at this distance
	local half = math.rad(angleDeg / 2) + math.atan(targetRadius / distance)
	return cosAngle >= math.cos(math.min(half, math.pi))
end

-- A rectangle starting at the origin and extending `length` along facing.
function Geometry.inLine(
	ox: number,
	oz: number,
	fx: number,
	fz: number,
	tx: number,
	tz: number,
	length: number,
	width: number,
	targetRadius: number
): boolean
	local nfx, nfz = normalize(fx, fz)
	local dx, dz = tx - ox, tz - oz
	local along = dx * nfx + dz * nfz
	local side = math.abs(dx * -nfz + dz * nfx)
	return along >= -targetRadius and along <= length + targetRadius and side <= width / 2 + targetRadius
end

-- Tests a data-defined area (abilities.json / enemies.json `area`).
-- single_target uses `range` as a small forward cone.
function Geometry.hitsArea(
	area: DataTypes.Area,
	range: number,
	ox: number,
	oz: number,
	fx: number,
	fz: number,
	tx: number,
	tz: number,
	targetRadius: number
): boolean
	local shape = area.shape
	if shape == "circle" then
		return Geometry.inCircle(ox, oz, tx, tz, area.radius_studs or range, targetRadius)
	elseif shape == "cone" then
		return Geometry.inCone(ox, oz, fx, fz, tx, tz, area.radius_studs or range, area.angle_deg or 90, targetRadius)
	elseif shape == "line" or shape == "box" then
		return Geometry.inLine(ox, oz, fx, fz, tx, tz, area.length_studs or range, area.width_studs or 4, targetRadius)
	elseif shape == "ring" then
		return Geometry.inRing(ox, oz, tx, tz, area.radius_studs or range, area.width_studs or 4, targetRadius)
	end
	return Geometry.inCone(ox, oz, fx, fz, tx, tz, range, 60, targetRadius)
end

-- Where a circle/ring area is centred: on the attacker for melee, at the target point for
-- ranged attacks (range larger than the area).
function Geometry.areaCenterDistance(area: DataTypes.Area, range: number): number
	if (area.shape == "circle" or area.shape == "ring") and range > (area.radius_studs or 0) then
		return range
	end
	return 0
end

return Geometry
