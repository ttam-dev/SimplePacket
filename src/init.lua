--!strict
--!optimize 2

-- Requires
local Signal = require(script.Signal)
local Task = require(script.Task)
local Types = require(script.Types)

-- Types
export type Packet = {
	Type: "Packet",
	Id: number,
	Name: string,
	Reads: (any) -> any,
	Writes: (any) -> (),
	IsResponse: boolean,
	ResponseTimeout: number,
	ResponseTimeoutValue: any,
	OnServerEvent: Signal.Signal<(Player, ...any)>,
	OnClientEvent: Signal.Signal<...any>,
	OnServerInvoke: nil | (player: Player, ...any) -> ...any,
	OnClientInvoke: nil | (...any) -> ...any,
	Response: (self: Packet) -> Packet,
	Fire: (self: Packet, ...any) -> ...any,
	FireClient: (self: Packet, player: Player, ...any) -> ...any,
	Serialize: (self: Packet, ...any) -> (buffer, { Instance }?),
	Deserialize: (self: Packet, serializeBuffer: buffer, instances: { Instance }?) -> ...any,
}

-- Varables
local Timeout
local RunService = game:GetService("RunService")
local PlayersService = game:GetService("Players")
local reads, writes, Import, Export, Truncate, Ended =
	Types.Reads, Types.Writes, Types.Import, Types.Export, Types.Truncate, Types.Ended
local ReadU8, WriteU8 = reads.NumberU8, writes.NumberU8
local Packet = {} :: Packet
local packets = {} :: { [string | number]: Packet }
local playerCursors: { [Player]: Types.Cursor }
local playerThreads: { [Player]: { [number]: { Yielded: thread, Timeout: thread }, Index: number } }
local threads: { [number]: { Yielded: thread, Timeout: thread }, Index: number }
local remoteEvent: RemoteEvent
local packetCounter: number
local cursor =
	{ Buffer = buffer.create(128), BufferLength = 128, BufferOffset = 0, Instances = {}, InstancesOffset = 0 }
local isServer = RunService:IsServer()
local isStudio = RunService:IsStudio()

-- Constructor
local function Constructor(_, name: string)
	local packet = packets[name] :: Packet
	if packet then
		return packet
	end
	local packet = (setmetatable({}, Packet) :: any) :: Packet
	packet.Name = name
	if isServer then
		packet.Id = packetCounter
		packet.OnServerEvent = Signal() :: Signal.Signal<(Player, ...any)>
		remoteEvent:SetAttribute(name, packetCounter)
		packets[packetCounter] = packet
		packetCounter += 1
	else
		packet.Id = remoteEvent:GetAttribute(name) :: number
		packet.OnClientEvent = Signal() :: Signal.Signal<...any>
		if packet.Id then
			packets[packet.Id] = packet
		end
	end
	--packet.Reads, packet.Writes = ParametersToFunctions(table.pack(...))
	packet.Reads, packet.Writes = reads.Any, writes.Any
	packets[packet.Name] = packet
	return packet
end

-- Packet
Packet["__index"] = Packet
Packet.Type = "Packet"

function Packet:Response()
	self.ResponseTimeout = self.ResponseTimeout or 10
	self.IsResponse = true
	return self
end

function Packet:Fire(...: any)
	assert(self.Id, "Packet is not registered on the server")
	local data: { [number]: any } = { ... }
	if #data <= 1 and typeof(data[1]) ~= "table" then
		data = data[1]
	end
	if self.IsResponse then
		if isServer then
			error("You must use FireClient(player)", 2)
		end
		local responseThread
		for _ = 1, 128 do
			responseThread = threads[threads.Index]
			if responseThread then
				threads.Index = (threads.Index + 1) % 128
			else
				break
			end
		end
		if responseThread then
			error("Cannot have more than 128 yielded threads", 2)
		end
		Import(cursor)
		WriteU8(self.Id)
		WriteU8(threads.Index)
		threads[threads.Index] = {
			Yielded = coroutine.running(),
			Timeout = Task:Delay(self.ResponseTimeout, Timeout, threads, threads.Index, self.ResponseTimeoutValue),
		}
		threads.Index = (threads.Index + 1) % 128
		--WriteParameters(self.Writes, data)
		self.Writes(data)
		cursor = Export()
		return coroutine.yield()
	else
		Import(cursor)
		WriteU8(self.Id)
		--WriteParameters(self.Writes, data)
		self.Writes(data)
		cursor = Export()
	end
end

function Packet:FireClient(player: Player, ...: any)
	if player.Parent == nil then
		return
	end
	local data: { [number]: any } = { ... }
	if #data <= 1 and typeof(data[1]) ~= "table" then
		data = data[1]
	end
	if self.IsResponse then
		local threads = playerThreads[player]
		if threads == nil then
			threads = { Index = 0 }
			playerThreads[player] = threads
		end
		local responseThread
		for _ = 1, 128 do
			responseThread = threads[threads.Index]
			if responseThread then
				threads.Index = (threads.Index + 1) % 128
			else
				break
			end
		end
		if responseThread then
			error("Cannot have more than 128 yielded threads", 2)
			return
		end
		Import(playerCursors[player] or {
			Buffer = buffer.create(128),
			BufferLength = 128,
			BufferOffset = 0,
			Instances = {},
			InstancesOffset = 0,
		})
		WriteU8(self.Id)
		WriteU8(threads.Index)
		threads[threads.Index] = {
			Yielded = coroutine.running(),
			Timeout = Task:Delay(self.ResponseTimeout, Timeout, threads, threads.Index, self.ResponseTimeoutValue),
		}
		threads.Index = (threads.Index + 1) % 128
		--WriteParameters(self.Writes, data)
		self.Writes(data)
		playerCursors[player] = Export()
		return coroutine.yield()
	else
		Import(playerCursors[player] or {
			Buffer = buffer.create(128),
			BufferLength = 128,
			BufferOffset = 0,
			Instances = {},
			InstancesOffset = 0,
		})
		WriteU8(self.Id)
		--WriteParameters(self.Writes, data)
		self.Writes(data)
		playerCursors[player] = Export()
	end
end

function Packet:Serialize(...: any)
	local data: { [number]: any } = { ... }
	if #data <= 1 and typeof(data[1]) ~= "table" then
		data = data[1]
	end
	Import({ Buffer = buffer.create(128), BufferLength = 128, BufferOffset = 0, Instances = {}, InstancesOffset = 0 })
	--WriteParameters(self.Writes, { ... })
	self.Writes(data)
	return Truncate()
end

function Packet:Deserialize(serializeBuffer: buffer, instances: { Instance }?)
	Import({
		Buffer = serializeBuffer,
		BufferLength = buffer.len(serializeBuffer),
		BufferOffset = 0,
		Instances = instances or {},
		InstancesOffset = 0,
	})
	local data = self.Reads()
	return typeof(data) == "table" and table.unpack(data) or data
end

-- Functions
function Timeout(
	threads: { [number]: { Yielded: thread, Timeout: thread }, Index: number },
	threadIndex: number,
	value: any
)
	local responseThreads = threads[threadIndex]
	task.defer(responseThreads.Yielded, value)
	threads[threadIndex] = nil
end

-- Initialize
if isServer then
	playerCursors = {}
	playerThreads = {}
	packetCounter = 0
	remoteEvent = Instance.new("RemoteEvent", script)

	local playerBytes = {}

	local thread = task.spawn(function()
		while true do
			coroutine.yield()
			if cursor.BufferOffset > 0 then
				local truncatedBuffer = buffer.create(cursor.BufferOffset)
				buffer.copy(truncatedBuffer, 0, cursor.Buffer, 0, cursor.BufferOffset)
				if cursor.InstancesOffset == 0 then
					remoteEvent:FireAllClients(truncatedBuffer)
				else
					remoteEvent:FireAllClients(truncatedBuffer, cursor.Instances)
					cursor.InstancesOffset = 0
					table.clear(cursor.Instances)
				end
				cursor.BufferOffset = 0
			end
			for player, cursor in playerCursors do
				local truncatedBuffer = buffer.create(cursor.BufferOffset)
				buffer.copy(truncatedBuffer, 0, cursor.Buffer, 0, cursor.BufferOffset)
				if cursor.InstancesOffset == 0 then
					remoteEvent:FireClient(player, truncatedBuffer)
				else
					remoteEvent:FireClient(player, truncatedBuffer, cursor.Instances)
				end
			end
			table.clear(playerCursors)
			table.clear(playerBytes)
		end
	end)

	local respond = function(packet: Packet, player: Player, threadIndex: number, ...)
		if packet.OnServerInvoke == nil then
			if isStudio then
				warn("OnServerInvoke not found for packet:", packet.Name, "discarding event:", ...)
			end
			return
		end
		local values: { [number]: any } = { packet.OnServerInvoke(player, ...) }
		if #values <= 1 and typeof(values[1]) ~= "table" then
			values = values[1]
		end
		if player.Parent == nil then
			return
		end
		Import(playerCursors[player] or {
			Buffer = buffer.create(128),
			BufferLength = 128,
			BufferOffset = 0,
			Instances = {},
			InstancesOffset = 0,
		})
		WriteU8(packet.Id)
		WriteU8(threadIndex + 128)
		--WriteParameters(packet.ResponseWrites, values)
		packet.Writes(values)
		playerCursors[player] = Export()
	end

	local onServerEvent = function(player: Player, receivedBuffer: buffer, instances: { Instance }?)
		local bytes = (playerBytes[player] or 0) + math.max(buffer.len(receivedBuffer), 800)
		if bytes > 8_000 then
			if isStudio then
				warn(player.Name, "is exceeding the data/rate limit; some events may be dropped")
			end
			return
		end
		playerBytes[player] = bytes
		Import({
			Buffer = receivedBuffer,
			BufferLength = buffer.len(receivedBuffer),
			BufferOffset = 0,
			Instances = instances or {},
			InstancesOffset = 0,
		})
		while Ended() == false do
			local packet = packets[ReadU8()] -- if this is nil then the packet is not registered
			if packet.IsResponse then
				local threadIndex = ReadU8()
				if threadIndex < 128 then
					local data = packet.Reads()
					if typeof(data) == "table" then
						Task:Defer(respond, packet, player, threadIndex, table.unpack(data))
					else
						Task:Defer(respond, packet, player, threadIndex, data)
					end
				else
					threadIndex -= 128
					local responseThreads = playerThreads[player][threadIndex]
					if responseThreads then
						task.cancel(responseThreads.Timeout)
						local data = packet.Reads()
						if typeof(data) == "table" then
							task.defer(responseThreads.Yielded, table.unpack(data))
						else
							task.defer(responseThreads.Yielded, data)
						end
						playerThreads[player][threadIndex] = nil
					elseif isStudio then
						warn(
							"Response thread not found for packet:",
							packet.Name,
							"discarding response:",
							packet.Reads()
						)
					end
				end
			else
				local data = packet.Reads()
				if typeof(data) == "table" then
					packet.OnServerEvent:Fire(player, table.unpack(data))
				else
					packet.OnServerEvent:Fire(player, data)
				end
			end
		end
	end

	remoteEvent.OnServerEvent:Connect(function(player: Player, ...)
		local _, errorMessage: string? = pcall(onServerEvent, player, ...)
		if errorMessage and isStudio then
			warn(player.Name, errorMessage)
		end
	end)

	PlayersService.PlayerRemoving:Connect(function(player)
		playerCursors[player] = nil
		playerThreads[player] = nil
		playerBytes[player] = nil
	end)

	RunService.Heartbeat:Connect(function(_)
		task.defer(thread)
	end)
else
	threads = { Index = 0 }
	remoteEvent = script:WaitForChild("RemoteEvent")
	local totalTime = 0

	local thread = task.spawn(function()
		while true do
			coroutine.yield()
			if cursor.BufferOffset > 0 then
				local truncatedBuffer = buffer.create(cursor.BufferOffset)
				buffer.copy(truncatedBuffer, 0, cursor.Buffer, 0, cursor.BufferOffset)
				if cursor.InstancesOffset == 0 then
					remoteEvent:FireServer(truncatedBuffer)
				else
					remoteEvent:FireServer(truncatedBuffer, cursor.Instances)
					cursor.InstancesOffset = 0
					table.clear(cursor.Instances)
				end
				cursor.BufferOffset = 0
			end
		end
	end)

	local respond = function(packet: Packet, threadIndex: number, ...)
		if packet.OnClientInvoke == nil then
			warn("OnClientInvoke not found for packet:", packet.Name, "discarding event:", ...)
			return
		end
		local values: { [number]: any } = { packet.OnClientInvoke(...) }
		if #values <= 1 and typeof(values[1]) ~= "table" then
			values = values[1]
		end
		Import(cursor)
		WriteU8(packet.Id)
		WriteU8(threadIndex + 128)
		--WriteParameters(packet.ResponseWrites, values)
		packet.Writes(values)
		cursor = Export()
	end

	remoteEvent.OnClientEvent:Connect(function(receivedBuffer: buffer, instances: { Instance }?)
		Import({
			Buffer = receivedBuffer,
			BufferLength = buffer.len(receivedBuffer),
			BufferOffset = 0,
			Instances = instances or {},
			InstancesOffset = 0,
		})
		while Ended() == false do
			local packet = packets[ReadU8()]
			if packet.IsResponse then
				local threadIndex = ReadU8()
				if threadIndex < 128 then
					local data = packet.Reads()
					if typeof(data) == "table" then
						Task:Defer(respond, packet, threadIndex, table.unpack(data))
					else
						Task:Defer(respond, packet, threadIndex, data)
					end
				else
					threadIndex -= 128
					local responseThreads = threads[threadIndex]
					if responseThreads then
						task.cancel(responseThreads.Timeout)
						local data = packet.Reads()
						if typeof(data) == "table" then
							task.defer(responseThreads.Yielded, table.unpack(data))
						else
							task.defer(responseThreads.Yielded, data)
						end
						threads[threadIndex] = nil
					else
						warn(
							"Response thread not found for packet:",
							packet.Name,
							"discarding response:",
							packet.Reads()
						)
					end
				end
			else
				local data = packet.Reads()
				if typeof(data) == "table" then
					packet.OnClientEvent:Fire(table.unpack(data))
				else
					packet.OnClientEvent:Fire(data)
				end
			end
		end
	end)

	remoteEvent.AttributeChanged:Connect(function(name)
		local packet = packets[name]
		if packet then
			if packet.Id then
				packets[packet.Id] = nil
			end
			packet.Id = remoteEvent:GetAttribute(name) :: number
			if packet.Id then
				packets[packet.Id] = packet
			end
		end
	end)

	RunService.Heartbeat:Connect(function(deltaTime)
		totalTime += deltaTime
		if totalTime > 0.016666666666666666 then
			totalTime %= 0.016666666666666666
			task.defer(thread)
		end
	end)
end

return setmetatable({}, { __call = Constructor })
