--!strict
-- Token-bucket rate limiter for client requests. Pure: the caller passes the time.
-- A bucket holds up to `capacity` tokens and refills `perSecond` tokens each second.

local RateLimiter = {}

export type Bucket = { tokens: number, capacity: number, perSecond: number, updatedAt: number }

function RateLimiter.new(capacity: number, perSecond: number, now: number): Bucket
	return { tokens = capacity, capacity = capacity, perSecond = perSecond, updatedAt = now }
end

-- Takes one token if available. Returns false when the caller is sending too fast.
function RateLimiter.allow(bucket: Bucket, now: number): boolean
	local elapsed = math.max(0, now - bucket.updatedAt)
	bucket.tokens = math.min(bucket.capacity, bucket.tokens + elapsed * bucket.perSecond)
	bucket.updatedAt = now
	if bucket.tokens >= 1 then
		bucket.tokens -= 1
		return true
	end
	return false
end

return RateLimiter
