--!strict
-- Vertical scrolling grid for menu cards. Cell sizes are explicit design pixels (menus know their
-- own widths), the canvas grows automatically, and padding leaves room for tilted card badges
-- and strokes. Gamepad selection inside it scrolls the canvas automatically.
local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Create = require(UI.Create)

export type GridProps = {
	Parent: Instance,
	Name: string?,
	Size: UDim2,
	Position: UDim2?,
	Cell: Vector2,
	Gap: number?,
	Inset: number?, -- padding inside the canvas (default 12)
	Center: boolean?,
}

local MenuGrid = {}

MenuGrid.ScrollBar = 10

-- Cell width that fits `columns` cells in `width` design px (scroll bar + insets included).
function MenuGrid.CellWidth(width: number, columns: number, gap: number?, inset: number?): number
	local g = gap or 14
	local pad = inset or 12
	return math.floor((width - MenuGrid.ScrollBar - pad * 2 - g * (columns - 1)) / columns)
end

function MenuGrid.new(props: GridProps): ScrollingFrame
	local inset = props.Inset or 12
	local gap = props.Gap or 14
	local frame: ScrollingFrame = Create("ScrollingFrame", {
		Name = props.Name or "Grid",
		BackgroundTransparency = 1,
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = MenuGrid.ScrollBar,
		ScrollBarImageColor3 = Theme.Colors.PanelEdge,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		Selectable = false,
		ClipsDescendants = true,
		Parent = props.Parent,
	})
	Create.Padding(frame, inset, inset)
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(props.Cell.X, props.Cell.Y)
	layout.CellPadding = UDim2.fromOffset(gap, gap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = if props.Center then Enum.HorizontalAlignment.Center else Enum.HorizontalAlignment.Left
	layout.Parent = frame
	return frame
end

return MenuGrid
