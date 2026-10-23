--!strict
-- Hover tooltips for HUD buttons (mouse and gamepad selection; touch has no hover): a small
-- raised dark card with a gold title and one line of help, placed beside the target (or beside a
-- container such as the whole menu column, so it never covers the neighbouring buttons) on the
-- side with more room. One shared card on the Toasts layer, so it shows above everything; opening a
-- menu hides it.
local UserInputService = game:GetService("UserInputService")

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Create = require(UI.Create)
local UIController = require(UI.Parent.Controllers.UIController)

local Tooltip = {}

local WIDTH, HEIGHT = 300, 84
local GAP = 14

local card: Frame? = nil
local titleLabel: TextLabel
local bodyLabel: TextLabel
local owner: GuiObject? = nil

local function ensure(): Frame?
	local current = card
	if current and current.Parent then
		return current
	end
	local layer: Frame? = UIController.Layer("Toasts")
	if layer == nil then
		return nil
	end
	local frame: Frame = Create("Frame", {
		Name = "Tooltip",
		BackgroundColor3 = Theme.Colors.PanelDeep,
		BackgroundTransparency = 0.04,
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		Visible = false,
		ZIndex = 50,
		Parent = layer,
	})
	Create.Corner(14, frame)
	Create.Stroke(frame, Theme.Colors.Stroke, Theme.Outline, 0, true)
	Create.Gradient(frame, Theme.Colors.PanelLight, Theme.Colors.PanelDeep, 90)
	titleLabel = Create.Text({
		Name = "Title",
		Text = "",
		Size = UDim2.new(1, -24, 0, 30),
		Position = UDim2.fromOffset(12, 8),
		Font = Theme.Fonts.Display,
		TextSize = 26,
		Scaled = true,
		XAlign = Enum.TextXAlignment.Left,
		Color = Theme.Colors.Skill,
		Stroke = 2.2,
		ZIndex = 51,
		Parent = frame,
	})
	bodyLabel = Create.Text({
		Name = "Body",
		Text = "",
		Size = UDim2.new(1, -24, 0, 36),
		Position = UDim2.fromOffset(12, 40),
		Font = Theme.Fonts.Body,
		TextSize = 19,
		Scaled = true,
		Wrapped = true,
		XAlign = Enum.TextXAlignment.Left,
		YAlign = Enum.TextYAlignment.Top,
		Stroke = 1.4,
		ZIndex = 51,
		Parent = frame,
	})
	card = frame
	UIController.ScreenOpened:Connect(function()
		Tooltip.Hide()
	end)
	return frame
end

local function show(target: GuiObject, title: string, body: string, beside: GuiObject?)
	local frame = ensure()
	if frame == nil then
		return
	end
	local root = frame.Parent :: Frame
	local s = math.max(UIController.Scale, 0.01)
	local pos = (target.AbsolutePosition - root.AbsolutePosition) / s
	local size = target.AbsoluteSize / s
	local box = beside or target
	local boxPos = (box.AbsolutePosition - root.AbsolutePosition) / s
	local boxSize = box.AbsoluteSize / s
	local screen = root.AbsoluteSize / s
	local rightSide = boxPos.X + boxSize.X / 2 < screen.X / 2
	local x = if rightSide then boxPos.X + boxSize.X + GAP else boxPos.X - GAP - WIDTH
	local y = math.clamp(pos.Y + size.Y / 2 - HEIGHT / 2, 8, math.max(8, screen.Y - HEIGHT - 8))
	frame.Position = UDim2.fromOffset(x, y)
	titleLabel.Text = title
	bodyLabel.Text = body
	frame.Visible = true
	owner = target
end

function Tooltip.Hide()
	owner = nil
	if card then
		card.Visible = false
	end
end

-- Shows `title` / `body` beside `target` (or beside `beside`) while the mouse is over it or a
-- gamepad selects it.
function Tooltip.Attach(target: GuiObject, title: string, body: string, beside: GuiObject?)
	target.MouseEnter:Connect(function()
		if UserInputService.MouseEnabled then
			show(target, title, body, beside)
		end
	end)
	target.MouseLeave:Connect(function()
		if owner == target then
			Tooltip.Hide()
		end
	end)
	target.SelectionGained:Connect(function()
		show(target, title, body, beside)
	end)
	target.SelectionLost:Connect(function()
		if owner == target then
			Tooltip.Hide()
		end
	end)
	target.AncestryChanged:Connect(function()
		if owner == target and not target:IsDescendantOf(game) then
			Tooltip.Hide()
		end
	end)
end

return Tooltip
