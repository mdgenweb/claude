--!strict
-- Modal panel in the reference style: dark navy body, thin bright border, big display-font
-- title, close button breaking out of the top-right corner, pop-in animation.
local TweenService = game:GetService("TweenService")

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
	Size: Vector2, -- design pixels
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
	-- extra shrink so big menus always fit small screens (phones in landscape)
	local function fit(): number
		local screen = root.AbsoluteSize
		local s = math.max(UIController.Scale, 0.01)
		if screen.X <= 0 or screen.Y <= 0 then
			return 1
		end
		return math.min(1, screen.Y * 0.95 / (props.Size.Y * s), screen.X * 0.97 / (props.Size.X * s))
	end
	local body: Frame = Create("Frame", {
		Name = "Body",
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.04,
		Size = UDim2.fromScale(1, 1),
		Parent = holder,
	})
	Create.Corner(4, body)
	Create.Stroke(body, props.Border or Theme.Colors.PanelBorder, 2, 0, true)

	local title: TextLabel? = nil
	local contentTop = 16
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
		end, UDim2.new(1, -4, 0, 4), 62)
	end
	return self :: Panel
end

return Panel
