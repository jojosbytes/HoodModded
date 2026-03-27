local module = {}

local RunService = game:GetService("RunService")

local DefaultPhysics = {
	Position = {
		MaxForce = Vector3.new(80000, 80000, 80000),
		P = 2000,
		D = 50,
	},
	Rotation = {
		MaxTorque = Vector3.new(80000, 80000, 80000),
		P = 2000,
		D = 50,
	}
}

local ReanimateSettings = {
	MatchVelocity = false,
	SyncPosition = true,
	SyncRotation = true,
	IgnoreParts = { "HumanoidRootPart" },
}

---------------------------------------------------------------------
-- INTERNAL: Create or fetch BodyMovers
---------------------------------------------------------------------
local function SetupBodyMovers(part)
	local bp = part:FindFirstChild("ReanimateBP")
	if not bp then
		bp = Instance.new("BodyPosition")
		bp.Name = "ReanimateBP"
		bp.MaxForce = DefaultPhysics.Position.MaxForce
		bp.P = DefaultPhysics.Position.P
		bp.D = DefaultPhysics.Position.D
		bp.Parent = part
	end

	local bg = part:FindFirstChild("ReanimateBG")
	if not bg then
		bg = Instance.new("BodyGyro")
		bg.Name = "ReanimateBG"
		bg.MaxTorque = DefaultPhysics.Rotation.MaxTorque
		bg.P = DefaultPhysics.Rotation.P
		bg.D = DefaultPhysics.Rotation.D
		bg.Parent = part
	end

	return bp, bg
end

---------------------------------------------------------------------
-- MAIN ANIMATION FUNCTION
---------------------------------------------------------------------

if not game.ReplicatedStorage:FindFirstChild("_Assets") then
	local AssetFolder = Instance.new("Folder")
	AssetFolder.Name = "_Assets"
	AssetFolder.Parent = game.ReplicatedStorage
	
	local PlaceHolder = game:GetObjects('rbxassetid://123624002404494')[1]
	PlaceHolder.Parent = AssetFolder
	PlaceHolder.Name = "PlaceHolder"
end

local AssetFolder = game.ReplicatedStorage["_Assets"]

module.Animate = function(DataTable)

	local Information = {
		AnimationId = DataTable.AnimationId or DataTable[1],
		AnimationSpeed = DataTable.AnimationSpeed or DataTable[2],
		AnimationPriority = DataTable.AnimationPriority or DataTable[3],
		AnimationLooped = DataTable.AnimationLooped or DataTable[4],
		CorpseRig = DataTable.CorpseRig or DataTable[5],
		PlayAnimation = DataTable.PlayAnimation or DataTable[6],

		-- NEW CUSTOMIZATION:
		FadeIn = DataTable.FadeIn or 0.15,
		FadeOut = DataTable.FadeOut or 0.15,
		Weight = DataTable.Weight or 1,
		StartTime = DataTable.StartTime or 0,
		OnStart = DataTable.OnStart,
		OnStop = DataTable.OnStop,
		OnLoop = DataTable.OnLoop,
	}

	local AnimationRigFake = AssetFolder.PlaceHolder:Clone()
	AnimationRigFake.Parent = workspace

	-----------------------------------------------------------------
	-- Load Animation
	-----------------------------------------------------------------
	local Animation = Instance.new("Animation")
	Animation.AnimationId = "rbxassetid://" .. Information.AnimationId
	Animation.Parent = AnimationRigFake

	local Animator = AnimationRigFake.Humanoid.Animator
	local AnimationTrack = Animator:LoadAnimation(Animation)
	
	-- These MUST be set on the Animation object
	AnimationTrack.Looped = Information.AnimationLooped
	AnimationTrack.Priority = Information.AnimationPriority
	
	-- Play with weight + fade-in
	if Information.PlayAnimation then
		AnimationTrack:Play(
			Information.FadeIn or 0.15,
			Information.Weight or 1,
			Information.AnimationSpeed or 1
		)

		-- Start at a specific time
		if Information.StartTime then
			AnimationTrack.TimePosition = Information.StartTime
		end
	end

	-----------------------------------------------------------------
	-- Disable collisions on fake rig
	-----------------------------------------------------------------
	local function disableCollide()
		for _, basepart in ipairs(AnimationRigFake:GetDescendants()) do
			if basepart:IsA("BasePart") then
				basepart.CanCollide = false
			end
		end
	end

	-----------------------------------------------------------------
	-- Reanimate Loop
	-----------------------------------------------------------------
	local function StartReanimate(CorpseRig, FakeRig)
		return RunService.RenderStepped:Connect(function()
			disableCollide()
			
			if not CorpseRig then return end
			if not CorpseRig:FindFirstChild("HumanoidRootPart") then return end
			
			for _, obj in ipairs(CorpseRig:GetChildren()) do
				if obj:IsA("BasePart") then

					-- Ignore list
					if table.find(ReanimateSettings.IgnoreParts, obj.Name) then
						continue
					end

					local fake = FakeRig:FindFirstChild(obj.Name)
					if fake then
						local bp, bg = SetupBodyMovers(obj)

						-- Position Sync
						if ReanimateSettings.SyncPosition then
							bp.Position = fake.Position

							if ReanimateSettings.MatchVelocity then
								bp.Velocity = fake.AssemblyLinearVelocity
							end
						end

						-- Rotation Sync
						if ReanimateSettings.SyncRotation then
							bg.CFrame = fake.CFrame
						end
					end
				end
			end
		end)
	end

	local connection = StartReanimate(Information.CorpseRig, AnimationRigFake)

	return {
		FakeRig = AnimationRigFake,
		Track = AnimationTrack,
		Connection = connection,
		Stop = function()
			AnimationTrack:Stop(Information.FadeOut)
			connection:Disconnect()
			AnimationRigFake:Destroy()
		end,
	}
end

return module
