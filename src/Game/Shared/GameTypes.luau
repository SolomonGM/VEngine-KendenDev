-- src/Game/Shared/GameTypes.luau
--!strict
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local EngineTypes = require(ReplicatedFirst.EngineShared.EngineTypes)

export type PlayerCharacter = {
	--[=[
        The humanoid for the player. Contains its WalkSpeed and JumpPower
    ]=]
	Humanoid: { Animator: Animator } & Humanoid,
	HumanoidRootPart: Part,

	IsRunning: BoolValue,
	IsRagdolled: BoolValue,

	MaxStamina: NumberValue,
	CurrentStamina: NumberValue,

	MaxHunger: NumberValue,
	CurrentHunger: NumberValue,
}

export type HitboxType = "MouseOneHeavy" | "MouseOneNormal" | "KnockBack"

export type FightingBridge = {
	Events: {
		CreateHitbox: EngineTypes.EngineSharedReplicatedEvent<HitboxType, CFrame, CFrame, Vector3, string>,
	},

	CreateRemoteHitbox: (
		self: FightingBridge,
		hitboxType: HitboxType,
		cameraPosition: CFrame,
		hitboxPosition: CFrame,
		hitboxSize: Vector3,
		hitboxProjection: Enum.PartType
	) -> (),
}

export type PlayerBridge = {
	--[=[
		Bridge event list.
	]=]
	Events: {
		SetRunning: EngineTypes.EngineSharedReplicatedEvent<number, boolean>,
		SetRagdoll: EngineTypes.EngineSharedReplicatedEvent<number, boolean>,
		PerformDash: EngineTypes.EngineSharedReplicatedEvent<nil>,
		PerformDash_Acknowledgement: EngineTypes.EngineSharedReplicatedEvent<boolean>,
		-- SetClan: EngineTypes.EngineSharedReplicatedEvent,
	},

	--[=[
		Set the IsRunning BoolValue in the server for the given Target.

		@yields
		@param target: The player's UserId to set its running.
		@param mode: What to set its running mode to.
	]=]
	SetIsRunning: (self: PlayerBridge, targetUserId: number, mode: boolean) -> (),

	--[=[
		Set the IsRagdoll BoolValue in the server for the given Target. Will automatically ragdoll the character on the server side.

		@yields
		@param target: The player's UserId to set its ragdoll.
		@param mode: What to set its ragdoll mode to.
	]=]
	SetRagdoll: (self: PlayerBridge, targetUserId: number, mode: boolean) -> (),

	--[=[
		Sends a request to the server requsting a dash to be performed.

		@yields
		@return Whether or not the dash can be performed.
	]=]
	TryPerformDash: (self: PlayerBridge) -> boolean,

	--[=[
		Set the Clan StringValue in the server for the given Target

		@yields
		@param target: The player's UserId to set its clan.
		@param clanName: What to set its clan name to.
	]=]
	SetClan: (self: PlayerBridge, targetUserId: number, clanName: string) -> (),
}

export type BanIdentifiers = {
	BanIdentifiers: { [string]: string },
	--[=[
		Retrieves a list of all the possible bans and their identifiers.
	]=]
	GetBanIdentifiers: (self: BanIdentifiers) -> { [string]: string },
}

export type RagdollManager = {
	--[=[
		Disables the Motor6D Instances on the characters rig, adding BallSocketConstraints and switching its state to "Physics", the SocketBallConstraints will be removed some time later..

		@yields
		@param player: The Rig to ragdoll
	]=]
	RagdollRig: (self: RagdollManager, playerCharacter: Model) -> (),

	--[=[
		Enables the Motor6D Instances on the characters rig, removing any BallSocketConstraints and switching its state to Standing.

		@yields
		@param player: The rig to remove the ragdoll state from.
	]=]
	UnragdollRig: (self: RagdollManager, playerCharacter: Model) -> (),
}

export type CombatStyle = "Basic"

export type CombatTool = {
	LoadedAnimationPack: CombatAnimationPack,
	Connections: { RBXScriptConnection },

	ReloadCurrentAnimationPack: (self: CombatTool) -> (),
	ConnectTool: (self: CombatTool, tool: Tool) -> (),
	GetAnimationPack: (self: CombatTool, packName: CombatStyle) -> CombatAnimationPack,
}

export type CombatAnimationPack = {
	PackName: string,
	MouseOnes: { [number]: Animation },
	HeavyAttack: Animation,
	Block: Animation,
	Idle: Animation,
	Walk: Animation,
}

export type Clan = {
	Id: number,
	Name: string,
	Tag: string,
	Chance: number,
}

export type ClanManager = {
	GetDefaultClan: (self: ClanManager) -> Clan,
	GetPlayerClan: (self: ClanManager, player: Player) -> Clan,
	GetClanFromName: (self: ClanManager, clanName: string) -> Clan?,
	SetPlayerClan: (self: ClanManager, player: Player, newClan: Clan) -> (),
}

export type FightingManager = {}

return {}
