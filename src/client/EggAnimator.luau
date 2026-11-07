--!nonstrict
--[[
	EggAnimator
	-----------
	Flottement / rotation des œufs proches du joueur (visuel uniquement).
	On limite volontairement le nombre d'œufs animés pour rester léger.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local EggAnimator = {}

local MAX_ANIMATED = 10
local RANGE = 90
local INTERVAL = 0.05

local elapsed = 0
local accumulator = 0

local function baseCFrameOf(model: Model): CFrame?
	local attribute = model:GetAttribute("BaseCFrame")
	if typeof(attribute) == "CFrame" then
		return attribute
	end
	return nil
end

function EggAnimator.init()
	RunService.RenderStepped:Connect(function(delta)
		elapsed += delta
		accumulator += delta
		if accumulator < INTERVAL then
			return
		end
		accumulator = 0

		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end

		local origin = root.Position
		local animated = 0
		for _, model in ipairs(CollectionService:GetTagged("EggVisual")) do
			if animated >= MAX_ANIMATED then
				break
			end
			if model:IsA("Model") and model.Parent and model.PrimaryPart then
				local carried = model:GetAttribute("Carried") == true
				local base = baseCFrameOf(model)
				if base and not carried then
					local distance = (base.Position - origin).Magnitude
					if distance < RANGE then
						local uid = model:GetAttribute("Uid")
						local phase = 1
						if type(uid) == "string" and #uid > 0 then
							phase = string.byte(uid, 1) or 1
						end
						local bob = math.sin(elapsed * 1.8 + phase) * 0.16 + 0.2
						local yaw = elapsed * 0.5 + phase * 0.7
						model:PivotTo(base * CFrame.new(0, bob, 0) * CFrame.Angles(0, yaw, 0))
						animated += 1
					end
				end
			end
		end
	end)
end

return EggAnimator
