-- Root ScreenGui. Everything is laid out on a 1280x720 reference canvas and scaled
-- to the device with one UIScale, so phones, tablets and monitors keep the same layout.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local UIKit = require(script.Parent.UIKit)

local Gui = {}

Gui.Screen = nil :: ScreenGui?
Gui.Root = nil :: Frame?
Gui.Layers = {} :: { [string]: Frame }
Gui.scale = 1

local REF_W, REF_H = 1280, 720

function Gui.init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screen = UIKit.new("ScreenGui", {
		Name = "MechUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	local root = UIKit.new("Frame", { Name = "Root", BackgroundTransparency = 1, Parent = screen })
	local scale = UIKit.new("UIScale", { Parent = root })
	local function fit()
		local size = screen.AbsoluteSize
		if size.X < 1 or size.Y < 1 then
			return
		end
		local s = math.min(size.X / REF_W, size.Y / REF_H)
		local minScale = if UserInputService.TouchEnabled then 0.62 else 0.5 -- 78px buttons stay >= 48px on phones
		s = math.clamp(s, minScale, 1.35)
		Gui.scale = s
		scale.Scale = s
		root.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	for i, name in { "Hud", "Panels", "Toasts", "Fly" } do
		Gui.Layers[name] = UIKit.new("Frame", {
			Name = name,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = i * 10,
			Parent = root,
		})
	end
	Gui.Screen = screen
	Gui.Root = root
end

-- Converts a screen-space pixel position into the scaled root's coordinates.
function Gui.toRoot(screenPos: Vector2): UDim2
	local root = Gui.Root :: Frame
	local rel = (screenPos - root.AbsolutePosition) / Gui.scale
	return UDim2.fromOffset(rel.X, rel.Y)
end

return Gui
