--!strict
-- Routes server notifications ("level_up", "loot", "cooldown", "knockback"...) to whoever
-- listens for that kind.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local Notifications = {}

local handlers: { [string]: { (message: any) -> () } } = {}

function Notifications.on(kind: string, handler: (message: any) -> ())
	handlers[kind] = handlers[kind] or {}
	table.insert(handlers[kind], handler)
end

function Notifications.start()
	Net.event("Notify").OnClientEvent:Connect(function(message: any)
		if type(message) ~= "table" or type(message.kind) ~= "string" then
			return
		end
		local list: { (message: any) -> () } = handlers[message.kind] or {}
		for _, handler in list do
			task.spawn(handler, message)
		end
	end)
end

return Notifications
