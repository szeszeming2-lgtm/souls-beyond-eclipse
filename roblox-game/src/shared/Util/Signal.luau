--!strict
-- Minimal signal: connect handlers, fire events. Each handler runs in its own thread, so one
-- failing handler cannot stop the others.

export type Connection = { Disconnect: (self: Connection) -> () }
export type Signal = {
	Connect: (self: Signal, handler: (...any) -> ()) -> Connection,
	Once: (self: Signal, handler: (...any) -> ()) -> Connection,
	Fire: (self: Signal, ...any) -> (),
}

local Signal = {}

function Signal.new(): Signal
	local handlers: { [number]: (...any) -> () } = {}
	local nextId = 0
	local self = {}

	function self.Connect(_: any, handler: (...any) -> ()): Connection
		nextId += 1
		local id = nextId
		handlers[id] = handler
		return {
			Disconnect = function(_: any)
				handlers[id] = nil
			end,
		} :: any
	end

	function self.Once(this: any, handler: (...any) -> ()): Connection
		local connection: Connection
		connection = this:Connect(function(...)
			connection:Disconnect()
			handler(...)
		end)
		return connection
	end

	function self.Fire(_: any, ...: any)
		for _, handler in table.clone(handlers) do
			task.spawn(handler, ...)
		end
	end

	return self :: any
end

return Signal
