--!strict
-- Shared shell for the menu screens (Shop, Rebirth, Gifts, Settings, Admin). Builds a Panel in the
-- "Menus" layer and dresses it in the simulator menu style: deep-blue gradient body with faint
-- diagonal stripes, a solid accent header bar (stripes, gloss, dark divider), coloured inner edge
-- and a chunky emoji + display-font title with a heavy stroke and a white-to-gold gradient. On open
-- the cards in the menu's grids pop in one after another. It implements
-- the UIController Screen contract (Open/Close/IsOpen), keeps gamepad selection inside the panel,
-- closes on gamepad B and forwards L1/R1 (or Q/E) to OnShoulder for tab cycling.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Create = require(UI.Create)
local Panel = require(script.Parent.Panel)
local Pattern = require(script.Parent.Pattern)
local UIController = require(UI.Parent.Controllers.UIController)

export type ShellProps = {
	Name: string, -- UIController screen name
	Title: string,
	Icon: string?,
	Size: Vector2, -- design pixels (keep <= 1300 x 760); the height shrinks on short screens
	MinHeight: number?, -- shortest design height the content still works at (default 520)
	OnResize: ((contentHeight: number) -> ())?, -- the content height changed (short screens)
	Accent: Color3?,
	OnOpen: ((...any) -> ())?, -- refresh content; receives UIController.Open's extra args
	OnClose: (() -> ())?,
	OnShoulder: ((number) -> ())?, -- -1 / +1 (L1/R1, Q/E)
	FirstSelection: (() -> GuiObject?)?, -- gamepad focus target when opened
}

export type Shell = {
	Panel: Panel.Panel,
	Body: Frame,
	Content: Frame,
	Name: string,
	Session: number, -- bumped on every open so per-open loops can tell they are stale
	Open: (Shell, ...any) -> (),
	Close: (Shell) -> (),
	IsOpen: (Shell) -> boolean,
}

local MenuShell = {}

local GAMEPAD_INPUTS: { [Enum.UserInputType]: boolean } = {
	[Enum.UserInputType.Gamepad1] = true,
	[Enum.UserInputType.Gamepad2] = true,
	[Enum.UserInputType.Gamepad3] = true,
	[Enum.UserInputType.Gamepad4] = true,
}

-- True when the player is currently driving the UI with a controller.
function MenuShell.UsingGamepad(): boolean
	return GAMEPAD_INPUTS[UserInputService:GetLastInputType()] == true
end

-- Darkens a colour (for gradient bottoms).
function MenuShell.Shade(c: Color3, f: number): Color3
	return Color3.new(c.R * f, c.G * f, c.B * f)
end

local POP_STAGGER = 0.03
local POP_MAX = 30

local function shownWithin(obj: Instance, root: Instance): boolean
	local node: Instance? = obj
	while node and node ~= root do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		end
		node = node.Parent
	end
	return node == root
end

-- Pops the cards of every visible grid under `root` in one after another (Back easing), the
-- genre's staggered entrance. Reuses a card's own UIScale when it has one.
function MenuShell.PopIn(root: Instance)
	local n = 0
	for _, layout in root:GetDescendants() do
		if not layout:IsA("UIGridLayout") then
			continue
		end
		local container = layout.Parent
		if container == nil or not shownWithin(container, root) then
			continue
		end
		local items: { GuiObject } = {}
		for _, child in container:GetChildren() do
			if child:IsA("GuiObject") and child.Visible then
				table.insert(items, child)
			end
		end
		table.sort(items, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		for _, item in items do
			n += 1
			if n > POP_MAX then
				return
			end
			local scale = item:FindFirstChildOfClass("UIScale")
			if scale == nil then
				local created = Instance.new("UIScale")
				created.Parent = item
				scale = created
			end
			local s = scale :: UIScale
			s.Scale = 0.55
			TweenService:Create(s, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, (n - 1) * POP_STAGGER), { Scale = 1 }):Play()
		end
	end
end

function MenuShell.new(props: ShellProps): Shell
	local accent = props.Accent or Theme.Colors.PanelEdge
	local panel = Panel.new({
		Parent = UIController.Layer("Menus"),
		Name = props.Name,
		Title = (if props.Icon then props.Icon .. " " else "") .. string.upper(props.Title),
		Size = props.Size,
		MinHeight = props.MinHeight,
		OnResize = props.OnResize,
		TitleSize = 56,
		Border = Theme.Colors.PanelBorder,
		OnClose = function()
			UIController.Close(props.Name)
		end,
	})
	local body = panel.Body
	local holder = body.Parent :: Frame

	-- deep-blue vertical gradient body with rounder corners
	body.BackgroundColor3 = Color3.new(1, 1, 1)
	body.BackgroundTransparency = 0
	Create.Gradient(body, Theme.Colors.PanelLight, Theme.Colors.PanelDeep, 90)
	local shadow: Instance = holder:FindFirstChild("Shadow") or body
	for _, frame in { body :: Instance, shadow } do
		local corner = frame:FindFirstChildOfClass("UICorner")
		if corner then
			corner.CornerRadius = UDim.new(0, 18)
		end
	end
	local outer = body:FindFirstChildOfClass("UIStroke")
	if outer then
		outer.Thickness = 4
	end
	-- solid accent header bar: rounded top (the body's corner), square bottom, gloss, dark divider
	local HEADER = 74 -- + 4 px divider = the panel's content top (title 56 + 22)
	-- faint stripes over the whole body (under everything else)
	Pattern.Stripes(body, 0.045, 18, 0)
	local header: Frame = Create("Frame", {
		Name = "Header",
		BackgroundColor3 = accent,
		Size = UDim2.new(1, 0, 0, HEADER),
		ZIndex = 1,
		Parent = body,
	})
	Create.Corner(18, header)
	Create("Frame", {
		Name = "Square",
		BackgroundColor3 = accent,
		Position = UDim2.new(0, 0, 1, -20),
		Size = UDim2.new(1, 0, 0, 20),
		Parent = header,
	})
	local gloss: Frame = Create("Frame", {
		Name = "Gloss",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.78,
		Position = UDim2.fromOffset(8, 5),
		Size = UDim2.new(1, -16, 0, HEADER * 0.42),
		ZIndex = 2,
		Parent = header,
	})
	Create.Corner(12, gloss)
	Pattern.Stripes(header, 0.12, 18, 2)
	Create("Frame", {
		Name = "Shade",
		BackgroundColor3 = MenuShell.Shade(accent, 0.6),
		Position = UDim2.new(0, 0, 1, -8),
		Size = UDim2.new(1, 0, 0, 8),
		ZIndex = 2,
		Parent = header,
	})
	Create("Frame", {
		Name = "Divider",
		BackgroundColor3 = Theme.Colors.Stroke,
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 4),
		ZIndex = 2,
		Parent = header,
	})
	-- bright inner edge
	local edge: Frame = Create("Frame", {
		Name = "Edge",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(5, 5),
		Size = UDim2.new(1, -10, 1, -10),
		ZIndex = 2,
		Parent = body,
	})
	Create.Corner(14, edge)
	Create.Stroke(edge, accent, 2, 0.35, true)
	panel.Content.ZIndex = 2
	local title = panel.Title
	if title then
		title.Size = UDim2.new(0.6, 0, 0, 58)
		title.Position = UDim2.fromOffset(26, 9)
		title.ZIndex = 2
		Create.Gradient(title, Color3.new(1, 1, 1), Color3.fromHex("#FFE48A"), 90)
		local stroke = title:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Thickness = 4.5
			stroke.Color = Theme.Colors.Stroke
		end
	end

	-- gamepad navigation stays inside the panel (close button included: it lives on the holder)
	holder.SelectionGroup = true
	holder.SelectionBehaviorUp = Enum.SelectionBehavior.Stop
	holder.SelectionBehaviorDown = Enum.SelectionBehavior.Stop
	holder.SelectionBehaviorLeft = Enum.SelectionBehavior.Stop
	holder.SelectionBehaviorRight = Enum.SelectionBehavior.Stop

	local self = {
		Panel = panel,
		Body = body,
		Content = panel.Content,
		Name = props.Name,
		Session = 0,
	} :: any

	local actionName = "SkyGlideMenu_" .. props.Name
	local function onAction(_: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
		if state ~= Enum.UserInputState.Begin or UserInputService:GetFocusedTextBox() ~= nil then
			return Enum.ContextActionResult.Pass
		end
		local key = input.KeyCode
		if key == Enum.KeyCode.ButtonB then
			UIController.Close(props.Name)
			return Enum.ContextActionResult.Sink
		end
		if props.OnShoulder then
			if key == Enum.KeyCode.ButtonL1 or key == Enum.KeyCode.Q then
				props.OnShoulder(-1)
				return Enum.ContextActionResult.Sink
			elseif key == Enum.KeyCode.ButtonR1 or key == Enum.KeyCode.E then
				props.OnShoulder(1)
				return Enum.ContextActionResult.Sink
			end
		end
		return Enum.ContextActionResult.Pass
	end

	function self.IsOpen(_: any): boolean
		return panel.Visible
	end

	function self.Open(this: any, ...: any)
		this.Session += 1
		if props.OnOpen then
			props.OnOpen(...)
		end
		panel:Open()
		MenuShell.PopIn(panel.Content)
		local keys = { Enum.KeyCode.ButtonB }
		if props.OnShoulder then
			table.insert(keys, Enum.KeyCode.ButtonL1)
			table.insert(keys, Enum.KeyCode.ButtonR1)
			table.insert(keys, Enum.KeyCode.Q)
			table.insert(keys, Enum.KeyCode.E)
		end
		ContextActionService:BindActionAtPriority(actionName, onAction, false, Enum.ContextActionPriority.High.Value, table.unpack(keys))
		if MenuShell.UsingGamepad() then
			local target = if props.FirstSelection then props.FirstSelection() else nil
			if target == nil then
				target = holder:FindFirstChild("Close") :: GuiObject?
			end
			GuiService.SelectedObject = target
		end
	end

	function self.Close(this: any)
		this.Session += 1
		ContextActionService:UnbindAction(actionName)
		local selected = GuiService.SelectedObject
		if selected and selected:IsDescendantOf(panel.Root) then
			GuiService.SelectedObject = nil
		end
		panel:Close()
		if props.OnClose then
			props.OnClose()
		end
	end

	return self :: Shell
end

return MenuShell
