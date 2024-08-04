--!strict
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")

local EngineTypes = require(ReplicatedFirst.EngineShared.EngineTypes)
local moduleBaseConstructor = require(ReplicatedFirst:WaitForChild("EngineShared"):WaitForChild("EngineModule"))
local Types = require(ReplicatedFirst:WaitForChild("EngineShared"):WaitForChild("EngineTypes"))

local engineEvent: Types.EngineSharedReplicatedEventFactory =
	moduleBaseConstructor.new() :: Types.EngineSharedReplicatedEventFactory

local IsInitialized = false
local KEY_EXCHANGED = false
local ENCRYPTION_KEY = 0

local function InitializeIfUninitialized()
	if not IsInitialized then
		engineEvent:Initialize(
			require(ReplicatedFirst:WaitForChild("EngineShared"):WaitForChild("EngineEnvironment")) :: any -- Break cyclic dependency.
		)
	end
end

engineEvent.ModuleName = "Engine/Networking/EngineSharedReplicatedEventFactory"

engineEvent.Validators = {
	NoArgumentsValidator = function(...)
		if select("#", ...) ~= 0 then
			error(
				"[VEngine::EngineSharedReplicatedEvent::Validators::NoArgumentsValidator/CRITICAL]: EngineSharedReplicatedEvent has been invoked with arguments, whilist not requiring them."
			)
			return ...
		end

		return ...
	end,
} :: { [string]: <T>(...T) -> ...T }

local strtable = {
	"a",
	"_",
	"1",
	"Q",
	"2",
	"b",
	"3",
	"A",
	"4",
	"c",
	"5",
	"Z",
	"6",
	"d",
	"7",
	"W",
	"8",
	"e",
	"9",
	"S",
	"0",
	"f",
	"X",
	"g",
	"E",
	"h",
	"D",
	"i",
	"C",
	"j",
	"R",
	"k",
	"F",
	"l",
	"V",
	"m",
	"T",
	"n",
	"G",
	"o",
	"B",
	"p",
	"N",
	"q",
	"H",
	"r",
	"Y",
	"s",
	"M",
	"t",
	"J",
	"u",
	"U",
	"v",
	"K",
	"w",
	"I",
	"x",
	"L",
	"y",
	"O",
	"z",
	"P",
}

local function reversable_xorstring(key: number, s: string)
	local xored = ""
	for _, xx in pairs({ string.byte(s, 1, #s) }) do
		xored = xored .. string.char(bit32.bxor(xx, key % 127) % 127)
	end
	return xored
end

local function xorstring(key: number, s)
	local rng = Random.new(key)
	local xored = ""
	local tKey = rng:NextInteger(1, key)
	local maxBit = 1
	for _, str in pairs({ string.byte(s, 1, #s) }) do
		local selected = 1
		local attempts = 0
		repeat
			attempts += 1
			task.wait()
			tKey %= math.ceil(maxBit + rng:NextInteger(1, key) % (#s % str))
			maxBit += math.ceil(#s % rng:NextInteger(5, 7))
			selected = math.ceil(bit32.bxor(str, tKey, maxBit, 127) % (128 + (#s % str)))
			if maxBit >= #strtable then
				maxBit = 1
			end
		until selected <= maxBit and selected > 0
		xored = xored .. strtable[selected]
	end

	return xored
end

local magics_inverted = {
	CFrame = 0x0,
	Vector3 = 0x1,
	Player = 0x2,
}

local magics = {
	[magics_inverted.CFrame] = "CFrame",
	[magics_inverted.Vector3] = "Vector3",
	[magics_inverted.Player] = "Player",
}

local deserializers = {
	[magics_inverted.CFrame] = function(buf: buffer): CFrame
		assert(buffer.readi32(buf, 0x0) == magics_inverted.CFrame, "Invalid magic for buffer.")
		local posX = buffer.readf64(buf, 0x4)
		local posY = buffer.readf64(buf, 0xC)
		local posZ = buffer.readf64(buf, 0x14)
		local pos = Vector3.new(posX, posY, posZ)

		local vxX = buffer.readf64(buf, 0x14 + 0x8)
		local vxY = buffer.readf64(buf, 0x14 + 0x10)
		local vxZ = buffer.readf64(buf, 0x14 + 0x18)
		local vX = Vector3.new(vxX, vxY, vxZ)

		local vyX = buffer.readf64(buf, 0x2C + 0x8)
		local vyY = buffer.readf64(buf, 0x2C + 0x10)
		local vyZ = buffer.readf64(buf, 0x2C + 0x18)
		local vY = Vector3.new(vyX, vyY, vyZ)

		local vzX = buffer.readf64(buf, 0x44 + 0x8)
		local vzY = buffer.readf64(buf, 0x44 + 0x10)
		local vzZ = buffer.readf64(buf, 0x44 + 0x18)
		local vZ = Vector3.new(vzX, vzY, vzZ)

		return CFrame.fromMatrix(pos, vX, vY, vZ)
	end :: (buf: buffer) -> CFrame,

	[magics_inverted.Vector3] = function(buf: buffer): Vector3
		assert(buffer.readi32(buf, 0x0) == magics_inverted.Vector3, "Invalid magic for buffer.")
		local x = buffer.readf64(buf, 0x4)
		local y = buffer.readf64(buf, 0xC)
		local z = buffer.readf64(buf, 0x14)

		return Vector3.new(x, y, z)
	end :: (buf: buffer) -> Vector3,

	[magics_inverted.Player] = function(buf: buffer): Player
		assert(buffer.readi32(buf, 0x0) == magics_inverted.Player, "Invalid magic for buffer.")

		local uid = buffer.readu32(buf, 0x4)
		local player = Players:GetPlayerByUserId(uid)

		assert(player ~= nil, "Invalid buffer when serializing")

		return player
	end,
} :: { [number]: (buf: buffer) -> any }

local serializers = {
	[magics_inverted.CFrame] = function(coordinateFrame: CFrame): buffer
		local buf = buffer.create(0x44 + 0x18 + 0x8)

		buffer.writei32(buf, 0x0, magics_inverted.CFrame)

		local pos = coordinateFrame.Position
		buffer.writef64(buf, 0x4, pos.X)
		buffer.writef64(buf, 0xC, pos.Y)
		buffer.writef64(buf, 0x14, pos.Z)

		local vX = coordinateFrame.XVector
		buffer.writef64(buf, 0x14 + 0x8, vX.X)
		buffer.writef64(buf, 0x14 + 0x10, vX.Y)
		buffer.writef64(buf, 0x14 + 0x18, vX.Z)

		local vY = coordinateFrame.YVector
		buffer.writef64(buf, 0x2C + 0x8, vY.X)
		buffer.writef64(buf, 0x2C + 0x10, vY.Y)
		buffer.writef64(buf, 0x2C + 0x18, vY.Z)

		local vZ = coordinateFrame.ZVector
		buffer.writef64(buf, 0x44 + 0x8, vZ.X)
		buffer.writef64(buf, 0x44 + 0x10, vZ.Y)
		buffer.writef64(buf, 0x44 + 0x18, vZ.Z)

		return buf
	end,

	[magics_inverted.Vector3] = function(vec: Vector3): buffer
		local buf = buffer.create(0x14 + 0x8)
		buffer.writei32(buf, 0x0, magics_inverted.Vector3)
		buffer.writef64(buf, 0x4, vec.X)
		buffer.writef64(buf, 0xC, vec.Y)
		buffer.writef64(buf, 0x14, vec.Z)

		return buf
	end,

	[magics_inverted.Player] = function(player: Player): buffer
		local uid = player.UserId
		local buf = buffer.create(0x8)
		buffer.writei32(buf, 0x0, magics_inverted.Player)
		buffer.writeu32(buf, 0x4, uid)

		return buf
	end,
} :: { [number]: (buf: any) -> buffer }

local function deserialize_buffer(buf: buffer): any
	print("Buffer found, reading magic...")

	local magic = buffer.readi32(buf, 0x0)

	if not magics[magic] then
		if RunService:IsStudio() then
			warn("Unrecognized magical header. Ignoring buffer, assuming there is no pattern associated with it.")
		end

		return buf
	end

	if RunService:IsStudio() then
		print("Recognized magic for " .. magics[magic] .. " deserializing.")
	end
	return deserializers[magic](buf)
end

local function serialize_userdata<T>(obj: T): buffer | T
	print("userdata found, attempting to serialize into Buffer")

	if not magics_inverted[typeof(obj)] and typeof(obj) ~= "Instance" then
		warn("No serializer for typeof " .. typeof(obj) .. " (C struct/userdata) found, ignoring.")
		return obj
	end

	local tid = ""

	if typeof(obj) == "Instance" then
		warn("Assuming object to be a serializable one via its ClassName property.")
		tid = (obj :: Instance).ClassName

		if not magics_inverted[tid] then
			warn("No serializer find for Instance of class " .. tid .. ", ignoring.")
			return obj
		end
	end

	print("Recognized as a " .. (typeof(obj) == "Instance" and tid or typeof(obj)) .. ". Using serializer for it.")

	return serializers[magics_inverted[typeof(obj) == "Instance" and tid or typeof(obj)]](obj)
end

local function xorTable(key: number, t: any, enableUserDataToBuffer: boolean)
	if typeof(t) ~= "table" then
		return t
	end

	local nT = {} :: { any }
	for idx, obj in t do
		if typeof(idx) == "string" then
			idx = reversable_xorstring(key + #idx, idx)
		end
		if type(obj) == "vector" then
			nT[idx] = serialize_userdata(obj)
			continue
		end

		if type(obj) == "userdata" and enableUserDataToBuffer then
			nT[idx] = serialize_userdata(obj)
			continue
		end

		if type(obj) == "string" then
			nT[idx] = reversable_xorstring(key, obj)
			continue
		end

		if type(obj) == "buffer" then
			nT[idx] = deserialize_buffer(obj :: buffer)
			continue
		end

		if type(obj) == "table" then
			nT[idx] = xorTable(key, t, enableUserDataToBuffer)
			continue
		end

		if type(obj) == "boolean" then
			nT[idx] = not obj
			continue
		end

		nT[idx] = obj -- Raw set, nothing can be done to hide or znup this value up
	end

	return nT
end

function engineEvent.CreateEvent<T...>(
	_self: Types.EngineSharedReplicatedEventFactory,
	eventName: string | Types.SharedEventOptions,
	validate: (T...) -> T...
): Types.EngineSharedReplicatedEvent<T...>
	InitializeIfUninitialized()

	if IsInitialized and not KEY_EXCHANGED and ENCRYPTION_KEY ~= 0 then
		while not KEY_EXCHANGED do
			task.wait()
		end
	end

	if ENCRYPTION_KEY == 1 and KEY_EXCHANGED then
		error("???")
	end

	if ENCRYPTION_KEY ~= 0 then
		while not KEY_EXCHANGED do
			task.wait()
		end
		if typeof(eventName) == "string" then
			eventName = xorstring(ENCRYPTION_KEY, eventName)
		else
			eventName.Name = xorstring(ENCRYPTION_KEY, eventName.Name)
		end
	end

	if
		typeof(eventName) == "string" and _self.EventMap[eventName]
		or _self.EventMap[(eventName :: Types.SharedEventOptions).Name]
	then
		return _self.EventMap[typeof(eventName) == "string" and eventName or (eventName :: Types.SharedEventOptions).Name]
	end

	local function ThrowIfClient()
		if RunService:IsClient() then
			error("You may not invoke this function from the Client! This function is Server only!")
		end
	end

	local function ThrowIfServer()
		if RunService:IsServer() then
			error("You may not invoke this function from the Server! This function is Client only!")
		end
	end
	local backingRemoteEvent = (_self.EngineEnvironment :: any).RedNetworking.SharedSignalEvent(eventName, function(...)
		return ... -- We must use our own validator, as Red is incapable of throwing an error when being told to do so. Lol.
	end)
	local localSignal = _self.EngineEnvironment.RedSignal()
	local remoteEvent = (
		{
			RedRemoteEvent = backingRemoteEvent,
			LocalEvent = localSignal,
		} :: any
	) :: EngineTypes.EngineSharedReplicatedEvent<T...>

	do
		function remoteEvent:FireServer<T>(...)
			ThrowIfServer()
			validate(...)
			local nArgs = eventName == "__exchange_key" and { ... } or xorTable(ENCRYPTION_KEY, { ... }, true) -- Key exchange, ignore encryption.
			self.LocalEvent:Fire(nil, table.unpack(nArgs))
			self.RedRemoteEvent:FireServer(table.unpack(nArgs))
		end

		function remoteEvent:FireClient<T>(player: Player, ...)
			ThrowIfClient()
			validate(...)
			local nArgs = eventName == "__exchange_key" and { ... } or xorTable(ENCRYPTION_KEY, { ... }, true) -- Key exchange, ignore encryption.
			self.LocalEvent:Fire(player, table.unpack(nArgs))
			self.RedRemoteEvent:FireClient(player, table.unpack(nArgs))
		end

		function remoteEvent:FireAllClients<T>(...)
			ThrowIfClient()
			validate(...)
			local nArgs = eventName == "__exchange_key" and { ... } or xorTable(ENCRYPTION_KEY, { ... }, true) -- Key exchange, ignore encryption.
			self.LocalEvent:Fire(game:GetService("Players"):GetPlayers(), table.unpack(nArgs))
			self.RedRemoteEvent:FireAllClients(table.unpack(nArgs))
		end

		function remoteEvent:FireForClients<T>(players: { Player }, ...)
			ThrowIfClient()
			validate(...)
			local nArgs = eventName == "__exchange_key" and { ... } or xorTable(ENCRYPTION_KEY, { ... }, true) -- Key exchange, ignore encryption.
			self.LocalEvent:Fire(players, table.unpack(nArgs))
			self.RedRemoteEvent:FireClients(players, table.unpack(nArgs))
		end

		function remoteEvent:WaitRemote<T>()
			local nRet, invoked
			remoteEvent:OnFire(function(...)
				nRet = { ... }
				invoked = true
			end, true, false)

			while not invoked do
				task.wait()
			end

			return table.unpack(nRet)
		end

		function remoteEvent:WaitLocal<T>()
			local nRet, invoked
			remoteEvent:OnFire(function(...)
				nRet = { ... }
				invoked = true
			end, true, true)

			while not invoked do
				task.wait()
			end

			return table.unpack(nRet)
		end

		--- Connects a callback for when the event is invoked. Can be used by both Client and Server, and will connect respectively to the correct signals.
		--- @param callback Will execute when the event is invoked.
		--- @return An abstraction for a connection.
		function remoteEvent:OnFire<T...>(
			callback: ({ Player }, T...) -> () | (Player, T...) -> () | (T...) -> (),
			once: boolean,
			localEvent: boolean
		): Types.EngineEventConnection? -- Engine "Clone" of RBXScriptConnection.
			if typeof(once) ~= "boolean" or typeof(localEvent) ~= "boolean" then
				error(
					"Cannot set event fire condition: Once and LocalEvent is not set. This is not allowed, and causes issues when handling events."
				)
				return nil -- Should crash.
			end
			--- @class EngineEventConnection
			local connection = {
				Connected = true,
				Disconnect = function(_: Types.EngineEventConnection) end,
			}
			local localDisconnect = function() end
			local remoteDisconnect = function() end
			local disconnectClosure = function()
				localDisconnect()
				remoteDisconnect()
			end
			local oCallback = function(...)
				-- Wrapper.
				if not connection then
					return -- Signal disconnected.
				end
				-- When obtaining a callback from the server, the first argument is pushed to the left, this will cause issues when calling down the remote to a client for exchanging information.
				validate(
					table.unpack(
						xorTable(ENCRYPTION_KEY, { ... }, false),
						(
							(
								(typeof(select(1, ...)) == "Instance" and select(1, ...):IsA("Player"))
								or (
									typeof(select(1, ...)) == "table"
									and #select(1, ...)
									and typeof(select(1, ...)[1]) == nil
								)
							) and 2
						) or 1
					)
				) -- Validate on receive, do NOT trust the other side.

				print({ ... })
				print(xorTable(ENCRYPTION_KEY, { ... }, false))

				if eventName == "__exchange_key" then
					print("THIS IS A XOR KEY EXCHANGE. ASSERTED AS UNENCRYPTED.");
					(callback :: (typeof(...)) -> ())(table.unpack(xorTable(ENCRYPTION_KEY, { ... }, false), 1))
				else
					(callback :: (typeof(...)) -> ())(table.unpack(xorTable(ENCRYPTION_KEY, { ... }, false), 1))
				end

				if once and connection then
					connection:Disconnect() -- Signal connected and Once is toggled.
				end
			end

			if not localEvent then
				if RunService:IsClient() then
					connection.Disconnect = function(_self)
						if not _self.Connected then
							return
						end
						_self.Connected = false
						disconnectClosure()
					end
					remoteDisconnect = self.RedRemoteEvent:OnClient(oCallback)
				else
					connection.Disconnect = function(_self)
						if not _self.Connected then
							return
						end
						_self.Connected = false
						disconnectClosure()
					end
					remoteDisconnect = self.RedRemoteEvent:OnServer(oCallback)
				end
			end

			if localEvent then
				if once then
					localDisconnect = self.LocalEvent:Once(callback :: any)
				else
					localDisconnect = self.LocalEvent:Connect(oCallback)
				end
			end

			return connection
		end
	end

	if typeof(eventName) == "table" then
		eventName = eventName.Name
	end

	_self.EventMap[eventName :: string] = remoteEvent
	return _self.EventMap[eventName :: string] :: Types.EngineSharedReplicatedEvent<T...>
end

function engineEvent:Initialize(envManager: Types.EngineEnvironmentManager)
	engineEvent.EngineEnvironment = envManager.GetEngineGlobals()
	engineEvent.EventMap = {}
	IsInitialized = true
	ENCRYPTION_KEY = 0
	local xchangeEvent = engineEvent:CreateEvent("__exchange_key", function(s)
		assert(typeof(s) == "number", "????")
		return s
	end) :: EngineTypes.EngineSharedReplicatedEvent<number>
	ENCRYPTION_KEY = 1

	if RunService:IsServer() then
		ENCRYPTION_KEY = math.ceil(os.time() + os.clock() / task.wait(0.03) * 1.144)
		KEY_EXCHANGED = true
		print(ENCRYPTION_KEY)
		xchangeEvent:OnFire(function(player: Player, _)
			print("Exchanged key with player " .. player.UserId)
			xchangeEvent:FireClient(player, ENCRYPTION_KEY)
		end, false, false)
	elseif RunService:IsClient() then
		xchangeEvent:FireServer(0)
		ENCRYPTION_KEY = xchangeEvent:WaitRemote()
		KEY_EXCHANGED = true
	end
end

return engineEvent
