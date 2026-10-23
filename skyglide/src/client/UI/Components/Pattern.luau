--!strict
-- Subtle diagonal stripes for panel backgrounds and header bars (the genre's patterned panels),
-- drawn without images: one white overlay whose UIGradient transparency alternates between clear
-- and faint, rotated. A UIGradient holds at most 20 keypoints, so one overlay draws up to 9 soft
-- stripes. Pure decoration: it sits under the panel's content and takes no input.
local Pattern = {}

-- `strength` is how opaque the stripes get (0.04 is a hint, 0.12 is clearly visible).
function Pattern.Stripes(parent: GuiObject, strength: number, corner: number, zIndex: number?, bands: number?): Frame
	local overlay = Instance.new("Frame")
	overlay.Name = "Pattern"
	overlay.BackgroundColor3 = Color3.new(1, 1, 1)
	overlay.BorderSizePixel = 0
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = zIndex or 1
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, corner)
	c.Parent = overlay
	local n = math.clamp(bands or 9, 1, 9)
	local points = {}
	for i = 0, 2 * n do
		table.insert(points, NumberSequenceKeypoint.new(i / (2 * n), if i % 2 == 0 then 1 else 1 - strength))
	end
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 35
	gradient.Transparency = NumberSequence.new(points)
	gradient.Parent = overlay
	overlay.Parent = parent
	return overlay
end

return Pattern
