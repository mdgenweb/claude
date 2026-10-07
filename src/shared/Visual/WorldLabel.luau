--!strict
-- Floating world text in the reference style (wide display font, thick dark stroke).
local WorldLabel = {}

WorldLabel.DisplayFont = Font.new("rbxasset://fonts/families/Michroma.json", Enum.FontWeight.Regular)
WorldLabel.BodyFont = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold)

export type LabelSpec = {
	Name: string?,
	Size: Vector2, -- studs
	Offset: Vector3?,
	MaxDistance: number?,
	AlwaysOnTop: boolean?,
	Lines: { { Text: string, Color: string?, Height: number, Font: Font?, Name: string? } },
}

function WorldLabel.Create(adornee: Instance, spec: LabelSpec): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = spec.Name or "Label"
	gui.Size = UDim2.new(spec.Size.X, 0, spec.Size.Y, 0) -- Scale components of a BillboardGui are studs
	gui.StudsOffsetWorldSpace = spec.Offset or Vector3.zero
	gui.MaxDistance = spec.MaxDistance or 220
	gui.AlwaysOnTop = spec.AlwaysOnTop == true
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Active = false

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = gui

	local total = 0
	for _, line in spec.Lines do
		total += line.Height
	end
	for i, line in spec.Lines do
		local label = Instance.new("TextLabel")
		label.Name = line.Name or ("Line" .. i)
		label.LayoutOrder = i
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, line.Height / total)
		label.FontFace = line.Font or WorldLabel.DisplayFont
		label.Text = line.Text
		label.TextScaled = true
		label.TextColor3 = Color3.fromHex(line.Color or "#FFFFFF")
		label.RichText = true
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(10, 12, 20)
		stroke.Thickness = 3
		stroke.LineJoinMode = Enum.LineJoinMode.Round
		stroke.Parent = label
		label.Parent = gui
	end
	gui.Parent = adornee
	return gui
end

return WorldLabel
