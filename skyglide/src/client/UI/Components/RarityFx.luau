--!strict
-- Rarity outlines in the genre's style: plain rarity-coloured strokes for the low tiers, and for
-- Legendary and up a gradient stroke that spins around the item (gold for Legendary, rainbow for
-- Mythic and Secret). The spin is a native looping tween, so it costs no script time per frame.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Rarity = require(ReplicatedStorage:WaitForChild("Shared").Config.Rarity)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)

local RarityFx = {}

local SPIN = TweenInfo.new(2.6, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1)
local LEGENDARY = Rarity.Order("Legendary")
local MYTHIC = Rarity.Order("Mythic")

-- True when the tier gets the animated outline.
function RarityFx.Animated(rarity: string): boolean
	return Rarity.Order(rarity) >= LEGENDARY
end

local function sequence(rarity: string): ColorSequence
	if Rarity.Order(rarity) >= MYTHIC then
		return Theme.Rainbow
	end
	local light, color, dark = Theme.RarityLight(rarity), Theme.Rarity(rarity), Theme.RarityDark(rarity)
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, light),
		ColorSequenceKeypoint.new(0.3, color),
		ColorSequenceKeypoint.new(0.5, dark),
		ColorSequenceKeypoint.new(0.7, color),
		ColorSequenceKeypoint.new(1, light),
	})
end

-- Styles `stroke` for `rarity` (call again when the rarity changes).
function RarityFx.Stroke(stroke: UIStroke, rarity: string)
	local gradient = stroke:FindFirstChild("RarityGradient") :: UIGradient?
	if not RarityFx.Animated(rarity) then
		stroke.Color = Theme.Rarity(rarity)
		if gradient then
			gradient:Destroy()
		end
		return
	end
	stroke.Color = Color3.new(1, 1, 1) -- the gradient supplies the colour
	if gradient == nil then
		local g = Instance.new("UIGradient")
		g.Name = "RarityGradient"
		g.Parent = stroke
		TweenService:Create(g, SPIN, { Rotation = 360 }):Play()
		gradient = g
	end
	(gradient :: UIGradient).Color = sequence(rarity)
end

-- Turns the animated outline off and on (e.g. while the item shows a selection outline).
function RarityFx.SetEnabled(stroke: UIStroke, enabled: boolean)
	local gradient = stroke:FindFirstChild("RarityGradient") :: UIGradient?
	if gradient then
		gradient.Enabled = enabled
	end
end

return RarityFx
