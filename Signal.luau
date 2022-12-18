-- ThreadPool dependency: https://github.com/Someone-dQw4w9WgXcQ/Lua-ThreadPool
local spawnWithReuse = require(game:GetService("ReplicatedStorage"):WaitForChild("ThreadPool"))

local function disconnect(self: Connection)
	self.Connected = false

	local signal = self.Signal
	local prev = signal._handlerListHead
	if prev == self then
		signal._handlerListHead = self._next
	else
		while prev and prev._next ~= self do
			prev = prev._next
		end
		if prev then
			prev._next = self._next
		end
	end
end

local Signal = {}
Signal.__index = Signal

function Signal.new(): Signal
	return setmetatable({
		_handlerListHead = false
	}, Signal)
end

function Signal:Connect(callback: func): Connection
	local connection = {
		Connected = true,
		Signal = self,
		_Function = callback,
		_next = false,

		Disconnect = disconnect
	}
	local _handlerListHead = self._handlerListHead
	if _handlerListHead then
		connection._next = _handlerListHead
		self._handlerListHead = connection
	else
		self._handlerListHead = connection
	end
	return connection
end

function Signal:Once(callback: func)
	local connection
	connection = {
		Connected = true,
		Signal = self,
		_Function = function(...)
			if connection.Connected then
				connection.Connected = false

				local prev = self._handlerListHead
				if prev == connection then
					self._handlerListHead = connection._next
				else
					while prev and prev._next ~= connection do
						prev = prev._next
					end
					if prev then
						prev._next = connection._next
					end
				end
			end
			connection = nil
			callback(...)
		end,
		_next = false,

		Disconnect = disconnect
	}
	local _handlerListHead = self._handlerListHead
	if _handlerListHead then
		connection._next = _handlerListHead
		self._handlerListHead = connection
	else
		self._handlerListHead = connection
	end
	return connection
end

function Signal:DisconnectAll()
	self._handlerListHead = false
end

function Signal:Destroy()
	table.clear(self)
	setmetatable(self, nil)
end

function Signal:Fire(...)
	local item = self._handlerListHead
	while item do
		if item.Connected then
			spawnWithReuse(item._Function, ...)
		end
		item = item._next
	end
end

function Signal:Wait()
	local waitingThread = coroutine.running()
	local connection
	connection = {
		Connected = true,
		Signal = self,
		_Function = function(...)
			connection.Connected = false

			local prev = self._handlerListHead
			if prev == connection then
				self._handlerListHead = connection._next
			else
				while prev and prev._next ~= connection do
					prev = prev._next
				end
				if prev then
					prev._next = connection._next
				end
			end
			connection = nil
			coroutine.resume(waitingThread, ...)
		end,
		_next = false
	}
	return coroutine.yield()
end

type func = (...any) -> ()

export type Signal = typeof(setmetatable({}:: {_handlerListHead: false | Connection}, Signal))
export type Connection = {
	Connected: boolean,
	Signal: Signal,
	_Function: func,
	_next: false | Connection,

	Disconnect: typeof(disconnect)
}

return table.freeze(Signal)
