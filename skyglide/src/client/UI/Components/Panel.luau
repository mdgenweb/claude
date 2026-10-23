--!strict
-- Modal panel in the reference style: dark navy body on a soft drop shadow, thin bright border,
-- big display-font title, red close key breaking out of the top-right corner, pop-in animation.
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Create = require(UI.Create)
local Button = require(script.Parent.Button)
local AudioController = require(UI.Parent.Controllers.AudioController)
local UIController = require(UI.Parent.Controllers.UIController)

export type PanelProps = {
	Parent: Instance,
	Name: string,
	Title: string?,
	Size: Vector2, -- design pixels (the height may shrink on short screens, see fit())
	MinHeight: number?, -- shortest design height the content still works at (default 520)
	OnResize: ((contentHeight: number) -> ())?, -- the panel height changed (screens re-layout)
	OnClose: (() -> ())?,
	TitleSize: number?,
	Border: Color3?,
}

export type Panel = {
	Root: Frame, -- full-screen dimmer + holder
	Body: Frame,
	Content: Frame,
	Title: TextLabel?,
	Visible: boolean,
	Open: (Panel) -> (),
	Close: (Panel) -> (),
	SetTitle: (Panel, string) -> (),
}

local Panel = {}

local POP = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local FADE = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function Panel.new(props: PanelProps): Panel
	local root: Frame = Create("Frame", {
		Name = props.Name,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Active = true,
		Parent = props.Parent,
	})
	local holder: Frame = Create("Frame", {
		Name = "Holder",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(props.Size.X, props.Size.Y),
		Parent = root,
	})
	local scale = Instance.new("UIScale")
	scale.Parent = holder
	-- Fits the panel to the screen. Wide, short screens (phones in landscape) would shrink a tall
	-- panel until everything in it is tiny, so there the panel gets shorter instead (content
	-- scrolls) and keeps the scale the width allows; touch screens may also grow a little.
	local minHeight = math.min(props.Size.Y, props.MinHeight or 520)
	local contentTop = 16
	local lastHeight = props.Size.Y
	local function fit(): number
		local screen = root.AbsoluteSize
		local s = math.max(UIController.Scale, 0.01)
		if screen.X <= 0 or screen.Y <= 0 then
			return 1
		end
		local grow = if UserInputService.TouchEnabled then 1.15 else 1
		local byWidth = math.min(grow, screen.X * 0.97 / (props.Size.X * s))
		local height = math.clamp(screen.Y * 0.95 / (s * byWidth), minHeight, props.Size.Y)
		holder.Size = UDim2.fromOffset(props.Size.X, height)
		if height ~= lastHeight then
			lastHeight = height
			if props.OnResize then
				props.OnResize(height - contentTop - 16)
			end
		end
		return math.min(byWidth, screen.Y * 0.95 / (height * s))
	end
	local shadow: Frame = Create("Frame", {
		Name = "Shadow",
		BackgroundColor3 = Theme.Shadow.Color,
		BackgroundTransparency = Theme.Shadow.Transparency,
		Position = UDim2.fromOffset(0, Theme.Shadow.Offset),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
		Parent = holder,
	})
	Create.Corner(4, shadow)
	local body: Frame = Create("Frame", {
		Name = "Body",
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.04,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Parent = holder,
	})
	Create.Corner(4, body)
	Create.Stroke(body, props.Border or Theme.Colors.PanelBorder, 2, 0, true)

	local title: TextLabel? = nil
	if props.Title then
		title = Create.Text({
			Name = "Title",
			Text = props.Title,
			Size = UDim2.new(0.45, 0, 0, props.TitleSize or 58),
			Position = UDim2.fromOffset(24, 10),
			Font = Theme.Fonts.Display,
			TextSize = props.TitleSize or 58,
			Scaled = true,
			XAlign = Enum.TextXAlignment.Left,
			Stroke = 2,
			Parent = body,
		})
		contentTop = (props.TitleSize or 58) + 22
	end
	local content: Frame = Create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, contentTop),
		Size = UDim2.new(1, -36, 1, -contentTop - 16),
		Parent = body,
	})

	local self = {
		Root = root,
		Body = body,
		Content = content,
		Title = title,
		Visible = false,
	} :: any

	function self.Open(this: any)
		if this.Visible then
			return
		end
		this.Visible = true
		root.Visible = true
		local target = fit()
		scale.Scale = 0.86 * target
		root.BackgroundTransparency = 1
		TweenService:Create(scale, POP, { Scale = target }):Play()
		TweenService:Create(root, FADE, { BackgroundTransparency = 0.55 }):Play()
		AudioController.Play("Open")
	end
	function self.Close(this: any)
		if not this.Visible then
			return
		end
		this.Visible = false
		AudioController.Play("Close")
		local t = TweenService:Create(scale, FADE, { Scale = 0.9 * fit() })
		TweenService:Create(root, FADE, { BackgroundTransparency = 1 }):Play()
		t:Play()
		t.Completed:Once(function()
			if not this.Visible then
				root.Visible = false
			end
		end)
	end
	function self.SetTitle(_: any, text: string)
		if title then
			title.Text = text
		end
	end

	UIController.ScaleChanged:Connect(function()
		if self.Visible then
			scale.Scale = fit()
		end
	end)

	if props.OnClose then
		local onClose = props.OnClose
		Button.Close(holder, function()
			onClose()
		end, UDim2.new(1, -4, 0, 4), if UserInputService.TouchEnabled then 84 else 62)
	end
	return self :: Panel
end

return Panel
