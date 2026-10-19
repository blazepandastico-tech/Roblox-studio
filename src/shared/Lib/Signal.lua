--[[
	Signal
	Piccolo sistema di eventi in puro Luau, usato per far comunicare i servizi
	tra loro (es. "un gigante è stato ucciso") senza dipendenze circolari.
]]

local Connection = {}
Connection.__index = Connection

function Connection.new(signal, fn)
	return setmetatable({
		Connected = true,
		_signal = signal,
		_fn = fn,
	}, Connection)
end

function Connection:Disconnect()
	if not self.Connected then
		return
	end
	self.Connected = false
	local list = self._signal._connections
	local index = table.find(list, self)
	if index then
		table.remove(list, index)
	end
end

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _connections = {} }, Signal)
end

function Signal:Connect(fn: (...any) -> ())
	local connection = Connection.new(self, fn)
	table.insert(self._connections, connection)
	return connection
end

function Signal:Once(fn: (...any) -> ())
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		fn(...)
	end)
	return connection
end

function Signal:Fire(...)
	-- Copia della lista: un handler può disconnettersi durante il Fire.
	for _, connection in table.clone(self._connections) do
		if connection.Connected then
			task.spawn(connection._fn, ...)
		end
	end
end

function Signal:Wait()
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal:DisconnectAll()
	for _, connection in table.clone(self._connections) do
		connection:Disconnect()
	end
end

return Signal
