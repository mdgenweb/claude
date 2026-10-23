--!strict
-- Sunburst behind big rewards (hatch reveals, special landings): long beams through the centre,
-- bright in the middle and fading toward their tips, alternating wide and thin, slowly spinning.
-- Purely decorative; Show/Hide fade it.
local TweenService = game:GetService("TweenService")

local UI = script.Parent.Parent
local Create = require(UI.Create)

export type Rays = {
	Instance: Frame,
	Show: (Rays, Color3, number?) -> (),
	Hide: (Rays) -> (),
}

local Rays = {}

local FADE = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SPIN = TweenInfo.new(16, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1)
local BEAM = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.18, 0.75),
	NumberSequenceKeypoint.new(0.5, 0.2),
	NumberSequenceKeypoint.new(0.82, 0.75),
	NumberSequenceKeypoint.new(1, 1),
})

-- `size` is the beam length (design px); `beams` full-length beams give 2x as many rays.
function Rays.new(parent: Instance, size: number, beams: number?, zIndex: number?, position: UDim2?): Rays
	local holder: Frame = Create("Frame", {
		Name = "Rays",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position or UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = zIndex or 1,
		Parent = parent,
	})
	local n = beams or 8
	local list: { Frame } = {}
	for i = 1, n do
		local wide = i % 2 == 1
		local beam: Frame = Create("Frame", {
			Name = "Beam",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 0, 0, size * (if wide then 0.1 else 0.05)),
			Rotation = (i - 1) * 180 / n,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 1,
			ZIndex = zIndex or 1,
			Parent = holder,
		})
		Create.Round(beam)
		local gradient = Instance.new("UIGradient")
		gradient.Transparency = BEAM
		gradient.Parent = beam
		table.insert(list, beam)
	end

	local self = { Instance = holder } :: any
	local spin: Tween? = nil

	-- `strength` 0..1 (default 1): how solid the beams get.
	function self.Show(_: any, color: Color3, strength: number?)
		local alpha = 1 - 0.75 * math.clamp(strength or 1, 0, 1)
		holder.Visible = true
		for _, beam in list do
			beam.BackgroundColor3 = color
			beam.BackgroundTransparency = 1
			TweenService:Create(beam, FADE, { BackgroundTransparency = alpha }):Play()
		end
		if spin == nil then
			holder.Rotation = 0
			local tween = TweenService:Create(holder, SPIN, { Rotation = 360 })
			tween:Play()
			spin = tween
		end
	end

	function self.Hide(_: any)
		if spin then
			spin:Cancel()
			spin = nil
		end
		holder.Visible = false
	end

	return self :: Rays
end

return Rays
