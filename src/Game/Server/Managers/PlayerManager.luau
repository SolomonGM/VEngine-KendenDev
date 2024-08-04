--!strict
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")

local EngineTypes = require(ReplicatedFirst.EngineShared.EngineTypes)
local GameTypes = require(ReplicatedFirst.Shared.GameTypes)

local BanIdentifiers: GameTypes.BanIdentifiers
local PlayerBridge: GameTypes.PlayerBridge
local RagdollManager: GameTypes.RagdollManager

local moduleBaseConstructor = require(ReplicatedFirst.EngineShared.EngineModule)

local module = moduleBaseConstructor.new()

module.ModuleName = "Managers/PlayerManager"

function module:PreInitialize(envManager: EngineTypes.EngineEnvironmentManager)
	print("Pre-init server")
	RagdollManager = (envManager:GetEngineModule("Managers/RagdollManager") :: any) :: GameTypes.RagdollManager
	PlayerBridge = (envManager:GetEngineModule("Shared/Bridges/PlayerBridge") :: any) :: GameTypes.PlayerBridge
	BanIdentifiers = (envManager:GetEngineModule("BanIdentifiers") :: any) :: GameTypes.BanIdentifiers

	local ConnectionMap = {} :: { [number]: { RBXScriptConnection } }

	local function onPlayerAdded(player: Player)
		ConnectionMap[player.UserId] = {}

		local fightingStyle = Instance.new("StringValue")
		fightingStyle.Value = "Basic"
		fightingStyle.Parent = player
		fightingStyle.Name = "FightingStyle"

		player.CharacterAdded:Connect(function(character: Model)
			local isRunning = Instance.new("BoolValue")
			isRunning.Value = false
			isRunning.Parent = character
			isRunning.Name = "IsRunning"

			local isRagdolled = Instance.new("BoolValue")
			isRagdolled.Value = false
			isRagdolled.Parent = character
			isRagdolled.Name = "IsRagdolled"

			isRagdolled.Changed:Connect(function(newValue: boolean)
				if newValue then
					RagdollManager:RagdollRig(character)
				else
					RagdollManager:UnragdollRig(character)
				end
			end)

			local maxStamina = Instance.new("NumberValue")
			maxStamina.Value = 100
			maxStamina.Parent = character
			maxStamina.Name = "MaxStamina"

			local currentStamina = Instance.new("NumberValue")
			currentStamina.Value = 100
			currentStamina.Parent = character
			currentStamina.Name = "CurrentStamina"

			local maxHunger = Instance.new("NumberValue")
			maxHunger.Value = 100
			maxHunger.Parent = character
			maxHunger.Name = "MaxHunger"

			local currentHunger = Instance.new("NumberValue")
			currentHunger.Value = 100
			currentHunger.Parent = character
			currentHunger.Name = "CurrentHunger"

			local staminaDecreaseRate = Instance.new("NumberValue")
			staminaDecreaseRate.Value = 7
			staminaDecreaseRate.Parent = character
			staminaDecreaseRate.Name = "StaminaDecreaseRate"

			local staminaRecoveryRate = Instance.new("NumberValue")
			staminaRecoveryRate.Value = 5
			staminaRecoveryRate.Parent = character
			staminaRecoveryRate.Name = "StaminaRecoveryRate"

			do -- Overhead UI
				local head = character:WaitForChild("Head")
				local humanoid = character:WaitForChild("Humanoid") :: Humanoid
				local clan = player:WaitForChild("Clan") :: StringValue

				humanoid.DisplayName = ""

				local billBoardGui = Instance.new("BillboardGui")
				billBoardGui.Name = "Overhead"
				billBoardGui.Adornee = head
				billBoardGui.ExtentsOffset = Vector3.new(0, 3, 0)
				billBoardGui.Size = UDim2.new(4, 0, 1, 0)
				billBoardGui.StudsOffset = Vector3.new(0, 1, 0)

				local nameLabel = Instance.new("TextLabel")
				nameLabel.Name = "NameLabel"
				nameLabel.Text = character.Name
				nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
				nameLabel.BackgroundTransparency = 1
				nameLabel.Size = UDim2.new(1, 0, 1, 0)
				nameLabel.Font = Enum.Font.SourceSansBold
				nameLabel.TextSize = 14
				nameLabel.ZIndex = 2
				nameLabel.Parent = billBoardGui

				local clanLabel = Instance.new("TextLabel")
				clanLabel.Name = "ClanLabel"
				clanLabel.Text = clan and clan.Value or "No Clan"
				clanLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
				clanLabel.BackgroundTransparency = 1
				clanLabel.Size = UDim2.new(1, 0, 0.5, 0)
				clanLabel.Font = Enum.Font.SourceSansBold
				clanLabel.TextSize = 14
				clanLabel.Position = UDim2.new(0, 0, 0.7, 0)
				clanLabel.ZIndex = 2
				clanLabel.Parent = billBoardGui

				if clan then
					clan.Changed:Connect(function()
						clanLabel.Text = clan.Value
					end)
				end

				billBoardGui.Parent = head
			end
		end)

		local reviveThread = nil :: thread?
		player.CharacterAdded:Connect(function(character: Model)
			local humanoid = character:WaitForChild("Humanoid") :: Humanoid
			humanoid.RequiresNeck = true
			humanoid.BreakJointsOnDeath = false
			humanoid.Died:Connect(function()
				if reviveThread then
					return
				end
				humanoid.Health = 0
				task.spawn(function()
					RagdollManager:RagdollRig(character)
				end)
				reviveThread = task.delay(3, function()
					player:LoadCharacter()
					reviveThread = nil
				end)
			end)

			for _, part in character:GetDescendants() do
				if part:IsA("BasePart") then
					part.CollisionGroup = "Character"
					local collideBox = Instance.new("Part")
					collideBox.Name = "CollisionBox"
					collideBox.CollisionGroup = "CollisionBox"
					collideBox.Parent = part
					collideBox.Transparency = 1
					collideBox.CFrame = part.CFrame
					collideBox.Size = Vector3.new(1, 1, 1)
					collideBox.CanCollide = false
					collideBox:SetNetworkOwner(nil)

					local weld = Instance.new("WeldConstraint")
					weld.Part0 = part
					weld.Part1 = collideBox
					weld.Enabled = true
					weld.Parent = part
					weld.Name = "ColliderWeld"
				end
			end
		end)

		table.insert(
			ConnectionMap[player.UserId],
			RunService.Heartbeat:Connect(function(deltaTime: number)
				if not player.Character then
					return
				end
				if
					player.Character:FindFirstChild("CurrentStamina")
					and ((player.Character :: any).CurrentStamina :: Instance):IsA("NumberValue")
				then
					local currentStamina = player.Character:FindFirstChild("CurrentStamina") :: NumberValue
					local maxStamina = player.Character:FindFirstChild("MaxStamina") :: NumberValue
					local staminaDecreaseRate = player.Character:FindFirstChild("StaminaDecreaseRate") :: NumberValue
					local staminaRecoveryRate = player.Character:FindFirstChild("StaminaRecoveryRate") :: NumberValue
					local isRunning = player.Character:FindFirstChild("IsRunning") :: BoolValue

					if currentStamina and isRunning and isRunning.Value then
						currentStamina.Value = math.max(currentStamina.Value - deltaTime * staminaDecreaseRate.Value, 0)
					end

					if currentStamina and isRunning and not isRunning.Value then
						currentStamina.Value =
							math.min(currentStamina.Value + deltaTime * staminaRecoveryRate.Value, maxStamina.Value)
					end
				end
			end)
		)

		player:LoadCharacter()
	end

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Players.CharacterAutoLoads = false
	Players.PlayerAdded:Connect(onPlayerAdded)

	Players.PlayerRemoving:Connect(function(player: Player)
		local connections = ConnectionMap[player.UserId]
		if not connections then
			return
		end
		for _, connection in connections do
			if connection.Connected then
				connection:Disconnect()
			end
		end
	end)

	PlayerBridge.Events.SetRunning:OnFire(function(player: Player, userId: number, mode: boolean)
		if player and userId ~= player.UserId then -- The player should not be able to invoke this event with the client sided validation code. Still, if they do, punish.
			Players:BanAsync({
				UserIds = {
					player.UserId,
				},
				Duration = -1,
				DisplayReason = "Suspected Cheating (" .. BanIdentifiers:GetBanIdentifiers().ValidationBypass .. ")",
				PrivateReason = "BanID -> "
					.. BanIdentifiers:GetBanIdentifiers().ValidationBypass
					.. " ; Validation Bypass. Possibly hooking the functions of the games' networking to attempt and gain an advantage over the game.",
			})
			return
		end

		local target = Players:GetPlayerByUserId(userId)
		if not target then
			warn("Cannot set IsRunning: Player does not exist.")
			return
		end

		if not target.Character then
			return
		end

		local isRunning = target.Character:FindFirstChild("IsRunning") :: BoolValue

		if isRunning and isRunning:IsA("BoolValue") then
			isRunning.Value = mode
		end
	end, false, false)

	PlayerBridge.Events.SetRagdoll:OnFire(function(player: Player, userId: number, mode: boolean)
		if player and userId ~= player.UserId then -- The player should not be able to invoke this event with the client sided validation code. Still, if they do, punish.
			Players:BanAsync({
				UserIds = {
					player.UserId,
				},
				Duration = -1,
				DisplayReason = "Suspected Cheating (" .. BanIdentifiers:GetBanIdentifiers().ValidationBypass .. ")",
				PrivateReason = "BanID -> "
					.. BanIdentifiers:GetBanIdentifiers().ValidationBypass
					.. " ; Validation Bypass. Possibly hooking the functions of the games' networking to attempt and gain an advantage over the game.",
			})
			return
		end

		local target = Players:GetPlayerByUserId(userId)
		if not target then
			warn("Cannot set IsRagdolled: Player does not exist.")
			return
		end

		if not target.Character then
			return
		end

		local isRagdolled = target.Character:FindFirstChild("IsRagdolled") :: BoolValue

		if isRagdolled and isRagdolled:IsA("BoolValue") then
			isRagdolled.Value = mode
		end
	end, false, false)

	PlayerBridge.Events.PerformDash:OnFire(function(player: Player)
		local playerCharacter = player.Character :: GameTypes.PlayerCharacter
		if not playerCharacter then
			return
		end
		if playerCharacter.CurrentStamina.Value < 20 then
			PlayerBridge.Events.PerformDash_Acknowledgement:FireClient(player, false)
			return
		end

		playerCharacter.CurrentStamina.Value -= 15
		PlayerBridge.Events.PerformDash_Acknowledgement:FireClient(player, true)
	end, false, false)

	--[[
		PlayerBridge.Events.SetClan:OnFire(function(player: Player, userId: number, clanName: string)
			if player and userId ~= player.UserId then -- The player should not be able to invoke this event with the client sided validation code. Still, if they do, punish.
				Players:BanAsync({
					UserIds = {
						player.UserId,
					},
					Duration = -1,
					DisplayReason = "Suspected Cheating (" .. BanIdentifiers:GetBanIdentifiers().ValidationBypass .. ")",
					PrivateReason = "BanID -> "
						.. BanIdentifiers:GetBanIdentifiers().ValidationBypass
						.. " ; Validation Bypass. Possibly hooking the functions of the games' networking to attempt and gain an advantage over the game.",
				})
				return
			end

			local target = Players:GetPlayerByUserId(userId)
			if not target then
				warn("Cannot set Clan: Player does not exist.")
				return
			end

			if not target.Character then
				return
			end

			local clan = target.Character:FindFirstChild("Clan") :: StringValue

			if clan and clan:IsA("StringValue") then
				clan.Value = clanName
				-- Save the updated clan to the datastore
				local success, errorMessage = pcall(function()
					ClanManager:SetPlayerClan(target, clanName)
				end)
				if not success then
					warn("Failed to save updated clan for player " .. target.Name .. ": " .. errorMessage)
				end
			end
		end, false, false)
	]]
end

function module:Initialize(_: EngineTypes.EngineEnvironmentManager)
	print("Initializing server...")
end

return module
