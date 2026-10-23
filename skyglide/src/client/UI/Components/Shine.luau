--!strict
-- Glint sweep for calls to action (buy / hatch / claim buttons, offer tiles): a white overlay whose
-- UIGradient is transparent except for one bright diagonal band, swept across by tweening the
-- gradient Offset every few seconds. One shared scheduler drives every shine, each starting at a
-- random phase so the screen never glints in lockstep. Overlays that leave the game are dropped.
local TweenService = game:GetService("TweenService")

local Shine = {}

type Entry = { Gradient: UIGradient, Overlay: Frame, Period: number, Next: number }

local SWEEP = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local BAND = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.36, 1),
	NumberSequenceKeypoint.new(0.46, 0.6),
	NumberSequenceKeypoint.new(0.5, 0.3),
	NumberSequenceKeypoint.new(0.54, 0.6),
	NumberSequenceKeypoint.new(0.64, 1),
	NumberSequenceKeypoint.new(1, 1),
})
local START = Vector2.new(-1, 0) -- band left of the face
local FINISH = Vector2.new(1, 0) -- band right of the face (also the resting state)

local entries: { Entry } = {}
local running = false
local rng = Random.new()

local function loop()
	while #entries > 0 do
		local now = os.clock()
		for i = #entries, 1, -1 do
			local e = entries[i]
			if e.Overlay.Parent == nil then
				table.remove(entries, i)
			elseif now >= e.Next then
				e.Next = now + e.Period
				if e.Overlay.Visible then
					e.Gradient.Offset = START
					TweenService:Create(e.Gradient, SWEEP, { Offset = FINISH }):Play()
				end
			end
		end
		task.wait(0.25)
	end
	running = false
end

-- Puts a shine overlay on `face`, above its background and gloss; give it a ZIndex below the
-- face's text. `corner` should match the face's rounding. Returns the overlay (hide it to pause).
function Shine.Add(face: GuiObject, corner: UDim, zIndex: number, period: number?): Frame
	local overlay = Instance.new("Frame")
	overlay.Name = "Shine"
	overlay.BackgroundColor3 = Color3.new(1, 1, 1)
	overlay.BorderSizePixel = 0
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = zIndex
	local c = Instance.new("UICorner")
	c.CornerRadius = corner
	c.Parent = overlay
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 20
	gradient.Transparency = BAND
	gradient.Offset = FINISH
	gradient.Parent = overlay
	overlay.Parent = face
	local p = period or 3.4
	table.insert(entries, { Gradient = gradient, Overlay = overlay, Period = p, Next = os.clock() + rng:NextNumber(0.4, p) })
	if not running then
		running = true
		task.spawn(loop)
	end
	return overlay
end

return Shine
