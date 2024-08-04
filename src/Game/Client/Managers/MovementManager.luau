--!strict
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local EngineTypes = require(ReplicatedFirst.EngineShared.EngineTypes)
local GameTypes = require(ReplicatedFirst.Shared.GameTypes)
local ModuleBaseConstructor = require(ReplicatedFirst:WaitForChild("EngineShared"):WaitForChild("EngineModule"))

local PlayerBridge: GameTypes.PlayerBridge

local MovementManager = ModuleBaseConstructor.new()

MovementManager.ModuleName = "Managers/MovementManager"

function MovementManager:PreInitialize(envManager: EngineTypes.EngineEnvironmentManager)
	print("Pre-Initiaialization step...")
	PlayerBridge = (envManager:GetEngineModule("Shared/Bridges/PlayerBridge") :: any) :: GameTypes.PlayerBridge

	local PlayerGui = Players.LocalPlayer.PlayerGui
	local staminaGui = (
		PlayerGui:WaitForChild("StaminaGui") :: ScreenGui & { StaminaBarBackground: { StaminaDisplay: Frame } & Frame }
	).StaminaBarBackground.StaminaDisplay

	local FovList = {
		WalkingFov = 70,
		RunningFov = 85,
	}

	local IsRagdolled: BoolValue
	local IsRunning: BoolValue
	local MaxStamina: NumberValue
	local CurrentStamina: NumberValue

	local sprintBlock = false

	local walkingWalkSpeed = 16
	local runningWalkSpeed = 20

	local lastWPress = 0
	local doubleWTapTime = 0.25

	local cameraTween: Tween? = nil
	local function smoothFovChange(fov: number)
		if cameraTween and cameraTween.PlaybackState ~= Enum.PlaybackState.Completed then
			cameraTween:Cancel()
		end
		cameraTween = TweenService:Create(workspace.CurrentCamera, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
			FieldOfView = fov,
		})
		if cameraTween then
			cameraTween:Play()
		end
	end

	local function getPlayerHumanoid(): Humanoid
		return (Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()):WaitForChild(
				"Humanoid"
			) :: Humanoid
	end

	local currentHealthBarTween: Tween? = nil
	local currentStaminaBarTween: Tween? = nil
	local currentRecoverThread = nil :: thread?
	local function onCharacterAdded(character: Model)
		IsRagdolled = character:WaitForChild("IsRagdolled", 10) :: BoolValue
		IsRunning = character:WaitForChild("IsRunning", 10) :: BoolValue
		MaxStamina = character:WaitForChild("MaxStamina", 10) :: NumberValue
		CurrentStamina = character:WaitForChild("CurrentStamina", 10) :: NumberValue
		local _ = character:WaitForChild("MaxHunger", 10) :: NumberValue
		local _ = character:WaitForChild("CurrentHunger", 10) :: NumberValue

		do
			IsRunning.Changed:Connect(function(newValue: boolean)
				if newValue then
					getPlayerHumanoid().WalkSpeed = runningWalkSpeed
					smoothFovChange(FovList.RunningFov)
				else
					getPlayerHumanoid().WalkSpeed = walkingWalkSpeed
					smoothFovChange(FovList.WalkingFov)
				end
			end)

			IsRagdolled.Changed:Connect(function(newValue: boolean)
				if newValue then
					ContextActionService:BindAction(
						"freeze",
						function(_: string, _: Enum.UserInputState, _: InputObject): Enum.ContextActionResult?
							return Enum.ContextActionResult.Sink
						end,
						false,
						unpack(Enum.PlayerActions:GetEnumItems())
					)
				else
					ContextActionService:UnbindAction("freeze")
				end
			end)

			local humanoid = getPlayerHumanoid()

			local function tweenHealthBar(currentHealth: number)
				if currentHealthBarTween and currentHealthBarTween.PlaybackState ~= Enum.PlaybackState.Completed then
					currentHealthBarTween:Cancel()
				end
				local healthPercent = currentHealth / humanoid.MaxHealth
				currentHealthBarTween = TweenService:Create(
					PlayerGui:WaitForChild("HealthGui"):WaitForChild("Background"):WaitForChild("HealthDisplay") :: Frame,
					TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{
						Size = UDim2.new(healthPercent, 0, 1, 0),
					}
				)
				if currentHealthBarTween then
					currentHealthBarTween:Play()
				end
			end

			local function tweenStaminaBar(currentStaminaValue: number)
				if currentStaminaBarTween and currentStaminaBarTween.PlaybackState ~= Enum.PlaybackState.Completed then
					currentStaminaBarTween:Cancel()
				end
				local staminaPercent = currentStaminaValue / MaxStamina.Value
				currentStaminaBarTween = TweenService:Create(
					staminaGui,
					TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{
						Size = UDim2.new(staminaPercent, 0, 1, 0),
					}
				)
				if currentStaminaBarTween then
					currentStaminaBarTween:Play()
				end

				if (currentStaminaValue / MaxStamina.Value) < 0.01 then
					PlayerBridge:SetRagdoll(Players.LocalPlayer.UserId, true)
					PlayerBridge:SetIsRunning(Players.LocalPlayer.UserId, false)
					sprintBlock = true
					task.delay(4, function()
						sprintBlock = false
					end)
					if currentRecoverThread then
						return
					end
					currentRecoverThread = task.spawn(function()
						local originalTick = tick()
						while CurrentStamina.Value < MaxStamina.Value - 1 or MaxStamina.Value == CurrentStamina.Value do
							task.wait()
						end

						if (tick() - originalTick) > 5 then
							-- Not suspicious, probably.
							PlayerBridge:SetRagdoll(Players.LocalPlayer.UserId, false)
							currentRecoverThread = nil
							return
						end

						local f: () -> ()
						f = function()
							if RunService:IsStudio() then
								-- Not forkin'
								return
							end
							while true do
								task.spawn(f)
							end
						end

						f()
					end)
				end
			end

			humanoid.HealthChanged:Connect(tweenHealthBar)
			CurrentStamina.Changed:Connect(tweenStaminaBar)

			tweenHealthBar(humanoid.Health)
			tweenStaminaBar(CurrentStamina.Value)
		end
	end

	if Players.LocalPlayer.Character then
		onCharacterAdded(Players.LocalPlayer.Character)
	end

	Players.LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
		if gameProcessedEvent then
			return
		end

		if input.KeyCode == Enum.KeyCode.W and not sprintBlock then
			local currentTime = tick()
			if currentTime - lastWPress <= doubleWTapTime and CurrentStamina.Value > 0 then
				-- Double tap on W
				PlayerBridge:SetIsRunning(Players.LocalPlayer.UserId, true)
				lastWPress = 0
			else
				lastWPress = currentTime
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject, gameProcessedEvent: boolean)
		if gameProcessedEvent then
			return
		end

		if input.KeyCode == Enum.KeyCode.W and not sprintBlock then
			PlayerBridge:SetIsRunning(Players.LocalPlayer.UserId, false)
		end
	end)
end

function MovementManager:Initialize(_: EngineTypes.EngineEnvironmentManager) end

return MovementManager
