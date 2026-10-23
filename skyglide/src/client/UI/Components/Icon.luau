--!strict
-- Icons from the downloaded 3D icon set (Fluent Emoji 3D by Microsoft, MIT licence; the PNGs are
-- in assets/icons, credits in assets/CREDITS.md). Roblox can only show images uploaded to Roblox,
-- so each icon's content string comes from Config/AssetIds (written by scripts/upload_assets.py).
--
-- Components pass the emoji they always used (Theme.Icons.Wins) or a Theme.Icons key ("Wins").
-- When that icon has an uploaded image, Icon.new makes an ImageLabel with the emoji as a child
-- label that shows until the image has loaded (and stays if it never loads, e.g. still in
-- moderation); otherwise it makes the plain emoji label, exactly as before the upload.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetIds = require(ReplicatedStorage:WaitForChild("Shared").Config.AssetIds)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Create = require(UI.Create)

local Icon = {}

export type IconProps = {
	Icon: string, -- emoji (Theme.Icons.X) or Theme.Icons key
	Parent: Instance?,
	Name: string?,
	Size: UDim2,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	ZIndex: number?,
	TextSize: number?, -- emoji fallback max size
	LayoutOrder: number?,
}

local byEmoji: { [string]: string } = {}
for key, emoji in Theme.Icons :: { [string]: string } do
	byEmoji[emoji] = key
	-- the same emoji without the variation selector (U+FE0F), e.g. "⚙" for "⚙️"
	byEmoji[(string.gsub(emoji, "\u{FE0F}", ""))] = key
end

-- Theme.Icons key for an emoji or key, or nil.
function Icon.KeyFor(emojiOrKey: string): string?
	if (Theme.Icons :: { [string]: string })[emojiOrKey] then
		return emojiOrKey
	end
	return byEmoji[emojiOrKey]
end

-- Uploaded image for an emoji or key, or nil.
function Icon.Image(emojiOrKey: string): string?
	local key = Icon.KeyFor(emojiOrKey)
	local content = if key then AssetIds.Icons[key] else nil
	return if content and content ~= "" then content else nil
end

-- The emoji text for an emoji or key.
function Icon.Emoji(emojiOrKey: string): string
	local key = Icon.KeyFor(emojiOrKey)
	return if key then (Theme.Icons :: { [string]: string })[key] else emojiOrKey
end

local function emojiLabel(text: string, size: UDim2, textSize: number?, zIndex: number?): TextLabel
	return Create.Text({
		Name = "Emoji",
		Text = text,
		Size = size,
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Font = Theme.Fonts.Display,
		TextSize = textSize or 64,
		Scaled = true,
		ZIndex = zIndex,
	})
end

local function watch(image: ImageLabel, fallback: TextLabel)
	local function update()
		fallback.Visible = not image.IsLoaded or image.Image == ""
	end
	update()
	image:GetPropertyChangedSignal("IsLoaded"):Connect(update)
	image:GetPropertyChangedSignal("Image"):Connect(update)
end

function Icon.new(props: IconProps): GuiObject
	local image = Icon.Image(props.Icon)
	local emoji = Icon.Emoji(props.Icon)
	local object: GuiObject
	if image then
		local label: ImageLabel = Create("ImageLabel", {
			BackgroundTransparency = 1,
			Image = image,
			ScaleType = Enum.ScaleType.Fit,
			Size = props.Size,
		})
		local fallback = emojiLabel(emoji, UDim2.fromScale(1, 1), props.TextSize, props.ZIndex)
		fallback.Parent = label
		watch(label, fallback)
		object = label
	else
		object = emojiLabel(emoji, props.Size, props.TextSize, nil)
	end
	object.Name = props.Name or "Icon"
	object.Position = props.Position or UDim2.fromScale(0.5, 0.5)
	object.AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5)
	if props.ZIndex then
		object.ZIndex = props.ZIndex
	end
	if props.LayoutOrder then
		object.LayoutOrder = props.LayoutOrder
	end
	object.Parent = props.Parent
	return object
end

-- Changes what an Icon.new object shows (an image icon keeps showing the emoji until loaded).
function Icon.Set(object: GuiObject, emojiOrKey: string)
	local emoji = Icon.Emoji(emojiOrKey)
	if object:IsA("ImageLabel") then
		local fallback = object:FindFirstChild("Emoji") :: TextLabel?
		if fallback then
			fallback.Text = emoji
		end
		object.Image = Icon.Image(emojiOrKey) or ""
	elseif object:IsA("TextLabel") then
		object.Text = emoji
	end
end

return Icon
