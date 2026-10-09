--!strict
-- Shared shell for the menu screens (Shop, Rebirth, Gifts, Settings, Admin). Builds a Panel in the
-- "Menus" layer and dresses it in the menu style: deep-blue gradient body, coloured inner edge,
-- accent header ribbon and a chunky emoji + display-font title with a heavy stroke. It implements
-- the UIController Screen contract (Open/Close/IsOpen), keeps gamepad selection inside the panel,
-- closes on gamepad B and forwards L1/R1 (or Q/E) to OnShoulder for tab cycling.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Create = require(UI.Create)
local Panel = require(script.Parent.Panel)
local UIController = require(UI.Parent.Controllers.UIController)

export type ShellProps = {
	Name: string, -- UIController screen name
	Title: string,
	Icon: string?,
	Size: Vector2, -- design pixels (keep <= 1300 x 760)
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

function MenuShell.new(props: ShellProps): Shell
	local accent = props.Accent or Theme.Colors.PanelEdge
	local panel = Panel.new({
		Parent = UIController.Layer("Menus"),
		Name = props.Name,
		Title = (if props.Icon then props.Icon .. " " else "") .. string.upper(props.Title),
		Size = props.Size,
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
	local corner = body:FindFirstChildOfClass("UICorner")
	if corner then
		corner.CornerRadius = UDim.new(0, 18)
	end
	local outer = body:FindFirstChildOfClass("UIStroke")
	if outer then
		outer.Thickness = 4
	end
	-- bright inner edge
	local edge: Frame = Create("Frame", {
		Name = "Edge",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(5, 5),
		Size = UDim2.new(1, -10, 1, -10),
		ZIndex = 0,
		Parent = body,
	})
	Create.Corner(14, edge)
	Create.Stroke(edge, accent, 2, 0.35, true)
	-- accent header ribbon behind the title
	local ribbon: Frame = Create("Frame", {
		Name = "Ribbon",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.25,
		Position = UDim2.fromOffset(5, 5),
		Size = UDim2.new(1, -10, 0, 72),
		ZIndex = 0,
		Parent = body,
	})
	Create.Corner(14, ribbon)
	local ribbonGradient = Create.Gradient(ribbon, accent, MenuShell.Shade(accent, 0.45), 0)
	ribbonGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.7, 0.75),
		NumberSequenceKeypoint.new(1, 1),
	})
	local title = panel.Title
	if title then
		title.Size = UDim2.new(0.6, 0, 0, 56)
		title.Position = UDim2.fromOffset(26, 12)
		local stroke = title:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Thickness = 4
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
