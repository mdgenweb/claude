-- Notifications: small stacked toasts for routine events and a big centre banner
-- (with rotating sunburst) for the moments that matter: new form, gate, rebirth.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.Theme)

local UIKit = require(script.Parent.UIKit)
local Gui = require(script.Parent.Gui)
local Sound = require(script.Parent.Parent.Controllers.Sound)

local Toasts = {}

local STYLE = {
	Upgrade = { Theme.Swatch.Orange, "⚡" },
	Form = { Theme.Swatch.Orange, "🤖" },
	Gate = { Theme.Swatch.Blue, "🔓" },
	Rebirth = { Theme.Swatch.Purple, "♻️" },
	Reward = { Theme.Swatch.Yellow, "⚙️" },
	Daily = { Theme.Swatch.Yellow, "📋" },
	Unlock = { Theme.Swatch.Green, "🎨" },
	Purchase = { Theme.Swatch.Green, "🛒" },
	Boost = { Theme.Swatch.Orange, "🚀" },
	Error = { Theme.Swatch.Red, "⚠️" },
	Info = { Theme.Swatch.Blue, "💡" },
}

local stack: Frame? = nil
local order = 0

local function getStack(): Frame
	if stack then
		return stack
	end
	stack = UIKit.new("Frame", {
		Name = "ToastStack",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(420, 300),
		Position = UDim2.new(0.5, 0, 0, 118),
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = Gui.Layers.Toasts,
	})
	UIKit.list(stack :: Frame, true, 10, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)
	return stack :: Frame
end

function Toasts.show(kind: string, title: string, body: string?, duration: number?)
	local style = STYLE[kind] or STYLE.Info
	order += 1
	local holder = UIKit.new("Frame", {
		Name = "Toast",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(400, if body and body ~= "" then 70 else 54),
		LayoutOrder = order,
		Parent = getStack(),
	})
	local surface = UIKit.surface(holder, { Size = UDim2.fromScale(1, 1), Swatch = style[1], Radius = Theme.Radius.M })
	UIKit.icon(surface.Face, style[2], UDim2.fromOffset(44, 44), UDim2.new(0, 10, 0.5, 0), Vector2.new(0, 0.5))
	local hasBody = body and body ~= ""
	UIKit.text(surface.Face, {
		Text = title,
		TextSize = 24,
		Size = UDim2.new(1, -72, if hasBody then 0.52 else 0.8, 0),
		Position = UDim2.new(0, 62, if hasBody then 0.08 else 0.1, 0),
		XAlign = Enum.TextXAlignment.Left,
	})
	if hasBody then
		UIKit.text(surface.Face, {
			Text = body,
			TextSize = 17,
			Font = Theme.Font.Body,
			Size = UDim2.new(1, -72, 0.36, 0),
			Position = UDim2.new(0, 62, 0.56, 0),
			XAlign = Enum.TextXAlignment.Left,
		})
	end
	UIKit.pop(holder, 0.25)
	if kind == "Error" then
		UIKit.shake(holder)
	end
	task.delay(duration or 3, function()
		local scale = UIKit.scaleOf(holder)
		UIKit.tween(scale, 0.2, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.wait(0.22)
		holder:Destroy()
	end)
end

function Toasts.error(message: string?)
	if message and message ~= "" then
		Toasts.show("Error", message, nil, 2.4)
	end
end

local bannerBusy = false

function Toasts.celebrate(kind: string, title: string, subtitle: string?)
	local style = STYLE[kind] or STYLE.Info
	Sound.play("Upgrade")
	if bannerBusy then
		Toasts.show(kind, title, subtitle)
		return
	end
	bannerBusy = true
	local holder = UIKit.new("Frame", {
		Name = "Celebration",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(640, 220),
		Position = UDim2.fromScale(0.5, 0.36),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = Gui.Layers.Toasts,
	})
	local burst = UIKit.sunburst(holder, style[1].Top, 12, 1)
	burst.Size = UDim2.fromScale(1.4, 3)
	UIKit.text(holder, {
		Text = subtitle or "",
		TextSize = 34,
		Size = UDim2.new(1, 0, 0, 44),
		Position = UDim2.fromScale(0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = Theme.White,
		ZIndex = 3,
	})
	local main = UIKit.text(holder, {
		Text = string.upper(title),
		TextSize = 92,
		Size = UDim2.new(1, 0, 0, 110),
		Position = UDim2.new(0.5, 0, 0, 46),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = style[1].Top,
		StrokeThickness = 6,
		ZIndex = 3,
		Rotation = -3,
	})
	UIKit.gradient(main, { Top = Color3.new(1, 1, 1), Bottom = style[1].Top, Deep = style[1].Deep })
	local scale = UIKit.scaleOf(holder)
	scale.Scale = 0.2
	UIKit.tween(scale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(2.4, function()
		UIKit.tween(scale, 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.wait(0.27)
		holder:Destroy()
		bannerBusy = false
	end)
end

return Toasts
