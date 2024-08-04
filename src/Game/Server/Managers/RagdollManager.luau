--!strict
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local EngineTypes = require(ReplicatedFirst.EngineShared.EngineTypes)
local GameTypes = require(ReplicatedFirst.Shared.GameTypes)

local moduleBaseConstructor = require(ReplicatedFirst.EngineShared.EngineModule)

local module = moduleBaseConstructor.new() :: EngineTypes.BaseEngineModule & GameTypes.RagdollManager

module.ModuleName = "Managers/RagdollManager"

function module:RagdollRig(playerCharacter: Model)
	local humanoid = playerCharacter:WaitForChild("Humanoid", 5) :: Humanoid

	if not humanoid then
		warn("Cannot ragdoll player: Cannot find Humanoid")
		return
	end

	local joints = {}
	humanoid.Jump = true
	for _, joint in pairs(playerCharacter:GetDescendants()) do
		if joint.Name == "CollisionBox" and joint:IsA("BasePart") then
			joint.CanCollide = true
		end
		if joint:IsA("Motor6D") then
			table.insert(joints, joint)
		end
	end

	for _, joint in pairs(joints) do
		if joint.Name == "Neck" or joint.Name == "RootJoint" then
			continue -- The neck has to stay.
		end
		local attachment1 = Instance.new("Attachment")
		attachment1.Name = "SocketBallConstraintAttachment"
		attachment1.Parent = joint.Part0
		attachment1.CFrame = joint.C0

		local attachment2 = Instance.new("Attachment")
		attachment2.Name = "SocketBallConstraintAttachment"
		attachment2.Parent = joint.Part1
		attachment2.CFrame = joint.C1

		local socket = Instance.new("BallSocketConstraint")
		socket.Parent = joint.Parent
		socket.Attachment0 = attachment1
		socket.Attachment1 = attachment2
		socket.LimitsEnabled = true
		socket.TwistLimitsEnabled = true
		socket.Name = joint.Name

		joint:Destroy()

		if joint.Part0 then
			joint.Part0.CanCollide = true
		end
		if joint.Part1 then
			joint.Part1.CanCollide = true
		end
	end

	for _, part in playerCharacter:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = true
		end
	end

	local humanoidRootPart = playerCharacter:WaitForChild("HumanoidRootPart", 5) :: BasePart

	humanoidRootPart:ApplyImpulse(humanoidRootPart.CFrame.LookVector * 100)
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	humanoid.PlatformStand = true
	humanoid.AutoRotate = false
end

function module:UnragdollRig(playerCharacter: Model)
	local humanoid = playerCharacter:WaitForChild("Humanoid", 10) :: Humanoid

	if not humanoid then
		warn("Cannot unragdoll player: Cannot find Humanoid")
		return
	end

	for _, socket in pairs(playerCharacter:GetDescendants()) do
		if socket.Name == "CollisionBox" and socket:IsA("BasePart") then
			socket.CanCollide = true
		end
		if socket:IsA("BallSocketConstraint") then
			local Joint = Instance.new("Motor6D")
			Joint.Name = socket.Name

			local Attachment0 = socket.Attachment0 :: Attachment
			local Attachment1 = socket.Attachment1 :: Attachment

			Joint.Parent = socket.Parent

			Joint.Part0 = Attachment0.Parent :: BasePart
			Joint.Part1 = Attachment1.Parent :: BasePart

			Joint.C0 = Attachment0.CFrame
			Joint.C1 = Attachment1.CFrame

			Attachment0:Destroy()
			Attachment1:Destroy()
			socket:Destroy()
		end
	end

	local humanoidRootPart = playerCharacter:WaitForChild("HumanoidRootPart") :: BasePart
	humanoidRootPart.CanCollide = true
	humanoidRootPart:ApplyImpulse(Vector3.new(0, 50, 0))
	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	humanoid.PlatformStand = false
	humanoid.AutoRotate = true
end

function module:PreInitialize(_: EngineTypes.EngineEnvironmentManager)
	PhysicsService:RegisterCollisionGroup("CollisionBox")
	PhysicsService:RegisterCollisionGroup("Character")
	PhysicsService:CollisionGroupSetCollidable("CollisionBox", "Character", false)
	Players.CharacterAutoLoads = false
end

function module:Initialize(_: EngineTypes.EngineEnvironmentManager)
	print("Initializing server...")
end

return module
