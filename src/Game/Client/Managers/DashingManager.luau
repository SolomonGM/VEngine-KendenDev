--!strict
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local UserInputService = game:GetService("UserInputService")

local EngineTypes = require(ReplicatedFirst.EngineShared.EngineTypes)
local PlayerBridge = require(ReplicatedFirst.Shared.Bridges.PlayerBridge)
local GameTypes = require(ReplicatedFirst.Shared.GameTypes)
local moduleBaseConstructor = require(ReplicatedFirst:WaitForChild("EngineShared"):WaitForChild("EngineModule"))

local module = moduleBaseConstructor.new()

module.ModuleName = "Managers/DashingManager"

type DashDirection = "Front" | "Back" | "Left" | "Right"

local function AssertDashDirection(): { DashDirection }
	if not Players.LocalPlayer.Character or not Players.LocalPlayer.Character.PrimaryPart then
		warn("No character found to perform dash")
		return {}
	end

	-- local humanoidRootPart = Players.LocalPlayer.Character.PrimaryPart :: BasePart
	-- We must make use of SIMPLE mathemathics for this.
	-- Negative Z : Forward
	-- Positive Z : Backwards
	-- Positive X : Rightwards
	-- Negative X : Leftwards
	-- local currentVelocity = humanoidRootPart.CFrame:VectorToObjectSpace(humanoidRootPart.AssemblyLinearVelocity)
	-- local isRightward = math.round(currentVelocity.X) < -1
	-- local isLeftward = math.round(currentVelocity.X) > 1
	-- local isForward = math.round(currentVelocity.Z) < -1
	-- local isBackward = math.round(currentVelocity.Z) > 1

	local directions = {}

	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		table.insert(directions, "Front")
	elseif UserInputService:IsKeyDown(Enum.KeyCode.S) then
		table.insert(directions, "Back")
	end

	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		table.insert(directions, "Right")
	elseif UserInputService:IsKeyDown(Enum.KeyCode.A) then
		table.insert(directions, "Left")
	end

	return (directions :: { any }) :: { DashDirection }
end

local dashAnimation: Animation? = nil
local currentTrack: AnimationTrack? = nil
local dashTime = 0
local cooldownForDashInSeconds = 3

local function PerformDash()
	local playerCharacter = Players.LocalPlayer.Character :: GameTypes.PlayerCharacter
	if not playerCharacter or not ((playerCharacter :: any) :: Model).PrimaryPart then
		warn("No character found to perform dash")
		return
	end
	if (tick() - dashTime) < cooldownForDashInSeconds then
		return
	end

	local dashDirections: { DashDirection } = AssertDashDirection() :: { DashDirection }

	local useBackAnimation = false
	if #dashDirections == 0 then
		table.insert(dashDirections, "Back")
		useBackAnimation = true
	end

	-- When we are in a shift lock state, we want to use the other animations, however, outside of shiftlock, we just want to use the Front dash, else it will look weird.
	local animationId = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
			and (table.find(dashDirections, "Front") and "rbxassetid://18468298097" or table.find(
				dashDirections,
				"Back"
			) and "rbxassetid://18468311797" or table.find(dashDirections, "Left") and "rbxassetid://18468319796" or table.find(
				dashDirections,
				"Right"
			) and "rbxassetid://18468330068" or "rbxassetid://18468311797")
		or not useBackAnimation and "rbxassetid://18468298097" -- Front dash.
		or "rbxassetid://18468311797" -- Back dash.

	if dashAnimation then
		dashAnimation = nil
	end
	dashAnimation = Instance.new("Animation") :: Animation;
	(dashAnimation :: Animation).AnimationId = animationId;
	(dashAnimation :: Animation).Name = "DashAnimation"

	if currentTrack and currentTrack.IsPlaying then
		currentTrack:Stop(0.3)
		currentTrack:Destroy()
	end

	currentTrack = playerCharacter.Humanoid.Animator:LoadAnimation(dashAnimation :: Animation)
	local nCurrentTrack = currentTrack :: AnimationTrack
	nCurrentTrack:Play(0.1, 1, 1)

	local dashMultiplier = 20

	local t = workspace.CurrentCamera.CFrame:VectorToWorldSpace(
		Vector3.new(
			((table.find(dashDirections, "Left") and -100 or 0) + (table.find(dashDirections, "Right") and 100 or 0))
				* dashMultiplier
				/ (playerCharacter.Humanoid.Jump and 1.5 or 0.75),
			0,
			((table.find(dashDirections, "Front") and -100 or 0) + (table.find(dashDirections, "Back") and 100 or 0))
				* dashMultiplier
				/ (playerCharacter.Humanoid.Jump and 1.5 or 0.75)
		)
	)

	local impulse = Vector3.new(t.X, not playerCharacter.Humanoid.Jump and 50.145 or 0, t.Z)
	playerCharacter.HumanoidRootPart:ApplyImpulse(impulse)
	dashTime = tick()
end

local function CanDash(): boolean
	local character = Players.LocalPlayer.Character :: GameTypes.PlayerCharacter
	if not character then
		return false
	end

	if character.IsRagdolled.Value then
		return false
	end

	if (tick() - dashTime) < cooldownForDashInSeconds then
		return false
	end
	return true
end

function module:PreInitialize(_: EngineTypes.EngineEnvironmentManager)
	UserInputService.InputBegan:Connect(function(inputObject: InputObject, gameProcessedEvent: boolean)
		if gameProcessedEvent then
			return
		end

		if
			inputObject.UserInputType == Enum.UserInputType.Keyboard
			and inputObject.KeyCode == Enum.KeyCode.Q
			and (CanDash())
		then
			if PlayerBridge:TryPerformDash() then -- Dash attempt was true.
				PerformDash()
			end
		end
	end)
end

function module:Initialize(_: EngineTypes.EngineEnvironmentManager) end

return module
