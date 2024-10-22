--!strict

local DataStoreService = game:GetService("DataStoreService")
local PlayerService = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")

local Red = require(ReplicatedStorage.ThirdPartyShared.Red)
local Types = require(game:GetService("ReplicatedFirst"):WaitForChild("EngineShared"):WaitForChild("EngineTypes"))

local EngineDatastoreValidation: Types.EngineDatastoreValidation = RunService:IsServer()
		and require(ReplicatedFirst.EngineShared.EngineDatastoreValidation) :: any
	or {} -- Clients cannot use this module.
local LoggerConstructor = require(ReplicatedFirst.EngineShared.Logger)

local logger = LoggerConstructor.new("EngineKeybinds", false, 5)

if RunService:IsClient() and not ReplicatedStorage:GetAttribute("KeybindsSystem_Initialized") then
	logger:PrintWarning(
		"WARNING: EngineKeybinds has been used on the client, but the server is yet to initialize it! This is a first time warning, a spin lock will now begin."
	)
	repeat
		task.wait(1)
	until ReplicatedStorage:GetAttribute("KeybindsSystem_Initialized")
end

local engineKeybindsModule = {}

if RunService:IsServer() and ReplicatedStorage:GetAttribute("KeybindsSystem_Initialized") then
	return (
		{ -- Thunks, system already initialized
			Initialize = function(_, _) end,
			SetKeybind = function(_, _, _) end,
			GetKeybind = function(_) end,
		} :: any
	) :: Types.EngineKeybinds
end

if not ReplicatedFirst:WaitForChild("Shared"):WaitForChild("Enums"):WaitForChild("GameKeybinds", 5) then
	logger:PrintCritical("Failed to load enum database! EngineKeybinds will not be initialized!")
	return (
		{
			Initialize = function(_, _)
				error("Keybinds system not initialized")
			end,
			SetKeybind = function(_, _, _)
				error("Keybinds system not initialized")
			end,
			GetKeybind = function(_)
				error("Keybinds system not initialized")
			end,
		} :: any
	) :: Types.EngineKeybinds
else
	engineKeybindsModule.ExistingKeybinds =
		require(ReplicatedFirst:WaitForChild("Shared"):WaitForChild("Enums"):WaitForChild("GameKeybinds"))
end

local redEvents = {
	["set"] = Red.Function(
		"__engine_keybind__set",
		function(keybindEnum: any, keycode: any): (Types.EngineEnumItem?, Enum.KeyCode?)
			if typeof(keybindEnum) ~= "table" then
				logger:PrintWarning(
					"Attempted to call __engine_keybind_set function using an invalid type as the keybindEnum! Sending nil instead."
				)
				keybindEnum = nil
			end
			if typeof(keycode) ~= "EnumItem" then
				logger:PrintWarning(
					"Attempted to call __engine_keybind_set function using an invalid type as the keycode! Sending nil instead."
				)
				keycode = nil
			end
			return keybindEnum, keycode
		end,
		function(...: unknown)
			return ...
		end
	),
}

function engineKeybindsModule:GetKeybind(keybindEnum: Types.EngineEnumItem): Enum.KeyCode?
	local keybinds = PlayerService.LocalPlayer:WaitForChild("Keybinds")

	local keybindValue = keybinds:WaitForChild(keybindEnum.Name)

	if keybindValue and keybindValue:IsA("StringValue") then
		-- Map string value into Enum.

		for _, enumVal in Enum.KeyCode:GetEnumItems() do
			if enumVal.Name == keybindValue.Value then
				return enumVal -- Keycode found.
			end
		end
	end

	return nil -- No keycode matched.
end

function engineKeybindsModule:SetKeybind(keybindEnum: Types.EngineEnumItem, keycode: Enum.KeyCode)
	local success, ret = redEvents.set:Call(keybindEnum, keycode):Await()

	if not ret or not success then
		logger:PrintCritical("// Keybind system not initialized or internal system error //")
		error(nil)
		return
	end

	-- Operation successful.
end

-- #region Server binds
function engineKeybindsModule:Initialize()
	if RunService:IsServer() then
		local keybindDatastore = DataStoreService:GetDataStore("VEngineInternal/Keybinds")

		local function onPlayerAdded(player: Player) -- TODO: Complete keybind system.
			-- Initialize keybinds folders
			local extracted: { [string]: Enum.KeyCode }
			local i = 0
			while i < 3 do
				local success, itemOrError = pcall(function(player_: Player)
					return keybindDatastore:GetAsync(tostring(player_.UserId))
				end, player)

				if success and itemOrError then
					extracted = itemOrError
					logger:PrintInformation("Data retrieval succeeded on " .. tostring(i) .. " attempts.")
					break
				elseif success and not itemOrError then
					logger:PrintInformation("Player has never saved keybinds before; Initializing from scratch!")
					break
				elseif not success then
					logger:PrintError(
						"DataStore retrieval failed with error '"
							.. tostring(itemOrError)
							.. "'. Attempt "
							.. tostring(i)
					)
				end
				i += 1
			end

			if not extracted then
				extracted = engineKeybindsModule.ExistingKeybinds.GetDefaultKeybinds()
			end

			local keyBinds = Instance.new("Configuration")
			keyBinds.Parent = player
			keyBinds.Name = "Keybinds"

			for indx, value in extracted do
				local strVal = Instance.new("StringValue")
				strVal.Parent = keyBinds
				strVal.Name = indx
				strVal.Value = typeof(value) == "EnumItem" and value.Name
					or typeof(value) == "string" and value
					or "Unknown" -- Assume it is a String
			end
		end

		for _, player in PlayerService:GetPlayers() do
			task.spawn(onPlayerAdded, player)
		end

		PlayerService.PlayerAdded:Connect(onPlayerAdded)

		PlayerService.PlayerRemoving:Connect(function(player: Player)
			local keybinds = player:FindFirstChild("Keybinds")
			if not keybinds then
				logger:PrintCritical(
					"Player does not have keybinds in its Player object, was it removed by a third party script? "
				)
				return
			end

			-- Parse into table.
			local keybinds_t = {}

			for _, value in keybinds:GetChildren() do
				keybinds_t[value.Name] = (value :: StringValue).Value
			end

			local validationResult = EngineDatastoreValidation.IsValidForDatastore(keybinds_t, "table", 255)

			if validationResult ~= EngineDatastoreValidation.ValidationFailureReason.Success then
				logger:PrintCritical(
					"Validation engine failed with error: "
						.. tostring(validationResult)
						.. " this is not meant to happen, was invalid data placed into the keybind Value?"
				)
				return
			end

			local i = 0
			while i < 3 do
				local success, itemOrError = pcall(function(plr: Player)
					return keybindDatastore:SetAsync(tostring(plr.UserId), keybinds_t)
				end, player)

				if success then
					logger:PrintInformation("Data save succeeded on " .. tostring(i) .. " attempts.")
					break
				elseif not success then
					logger:PrintError(
						"DataStore save failed with error '" .. tostring(itemOrError) .. "'. Attempt " .. tostring(i)
					)
				end
				i += 1
			end
		end)

		redEvents.set:SetCallback(function(player: Player, keybindEnum: any, keycode: any)
			local keybindName = keybindEnum.Name
			local keybinds = player:FindFirstChild("Keybinds")

			if not keybinds then
				logger:PrintError("ERROR: Keybinds were not initialized correctly?")
				return nil
			end

			local keybindValue = keybinds:FindFirstChild(keybindName)

			if keybindValue and keybindValue:IsA("StringValue") then
				keybindValue.Value = keycode.Name
				return true
			end

			return nil
		end)

		ReplicatedStorage:SetAttribute("KeybindsSystem_Initialized", true)
	end
end
-- #endregion Server binds

return (engineKeybindsModule :: any) :: Types.EngineKeybinds
