--!strict
-- Rarity-bordered item card (reference "Prize Preview" cards): art area + dark name bar.
-- Supports orbs (2D OrbArt), explosions (burst icon), flyers (3D viewport), tickets (machine).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BallDefinitions = require(Shared.Definitions.BallDefinitions)
local CosmeticDefinitions = require(Shared.Definitions.CosmeticDefinitions)
local GachaDefinitions = require(Shared.Definitions.GachaDefinitions)
local PropFactory = require(Shared.Visual.PropFactory)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Create = require(UI.Create)
local OrbArt = require(script.Parent.OrbArt)
local Icons = require(script.Parent.Icons)
local Viewport = require(script.Parent.Viewport)
local CosmeticModels = require(UI.Parent.VFX.CosmeticModels)
local AudioController = require(UI.Parent.Controllers.AudioController)

local ItemCard = {}

export type CardProps = {
	Parent: Instance?,
	Kind: string, -- "Ball" | "Explosion" | "Flyer" | "Ticket"
	Id: string,
	Size: UDim2?,
	Count: number?,
	Locked: boolean?,
	Selected: boolean?,
	LayoutOrder: number?,
	OnClick: (() -> ())?,
	ShowName: boolean?,
	Spin: boolean?,
}

export type Card = {
	Instance: TextButton,
	SetCount: (Card, number?) -> (),
	SetSelected: (Card, boolean) -> (),
	SetLocked: (Card, boolean) -> (),
}

function ItemCard.Info(kind: string, id: string): (string, string)
	if kind == "Ball" then
		local def = BallDefinitions.Get(id)
		return if def then def.DisplayName else id, if def then def.Rarity else "Uncommon"
	elseif kind == "Ticket" then
		local crate = GachaDefinitions.Get(id)
		return if crate then crate.DisplayName else id, if id == "AdvancedOrbGacha" then "Epic" else "Rare"
	end
	local def = CosmeticDefinitions.Get(kind, id)
	return if def then def.DisplayName else id, if def then def.Rarity else "Uncommon"
end

-- Burst icon for explosion cosmetics (rays in the cosmetic's colours).
function ItemCard.ExplosionArt(parent: Instance, id: string, z: number): Frame
	local def = CosmeticDefinitions.Get("Explosion", id)
	local colors = if def then def.Colors else { "#FFB347", "#FF5E1A" }
	local f: Frame = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z, Parent = parent })
	Create.Aspect(f, 1)
	for k = 0, 7 do
		Icons.Rect(f, 0.5, 0.5, 0.12, 0.9, Color3.fromHex(colors[(k % #colors) + 1]), k * 22.5, 0.5, z)
	end
	Icons.Circle(f, 0.5, 0.5, 0.5, Color3.fromHex(colors[1]), 0, z + 1)
	Icons.Circle(f, 0.5, 0.5, 0.3, Color3.new(1, 1, 1), 0.2, z + 2)
	return f
end

function ItemCard.Art(parent: Instance, kind: string, id: string, z: number, spin: boolean?): GuiObject
	if kind == "Ball" then
		return OrbArt.Draw(parent, id, z).Root
	elseif kind == "Explosion" then
		return ItemCard.ExplosionArt(parent, id, z)
	elseif kind == "Flyer" then
		return Viewport.Model(parent, CosmeticModels.Flyer(id), { Spin = if spin then 0.8 else nil, Yaw = math.rad(-120), ZIndex = z, Zoom = 1.0 })
	else
		return Viewport.Model(parent, PropFactory.GachaMachine(id == "AdvancedOrbGacha"), { Spin = if spin then 0.6 else nil, Yaw = math.rad(-20), ZIndex = z, Zoom = 0.95 })
	end
end

function ItemCard.new(props: CardProps): Card
	local name, rarity = ItemCard.Info(props.Kind, props.Id)
	local rColor = Theme.Rarity(rarity)
	local root: TextButton = Create("TextButton", {
		Name = props.Kind .. "_" .. props.Id,
		Size = props.Size or UDim2.fromOffset(158, 155),
		BackgroundColor3 = Theme.Colors.CardInner,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = props.LayoutOrder or 0,
		Selectable = true,
	})
	local border = Create.Stroke(root, rColor, 2.5, 0, true)
	local bg: Frame = Create("Frame", {
		Name = "Bg",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.82,
		Size = UDim2.fromScale(1, 1),
		Parent = root,
	})
	Create.Gradient(bg, rColor, Theme.Colors.CardInner, 90)
	local artHolder: Frame = Create("Frame", {
		Name = "Art",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.04),
		Size = UDim2.fromScale(0.82, if props.ShowName == false then 0.92 else 0.7),
		Parent = root,
	})
	ItemCard.Art(artHolder, props.Kind, props.Id, 2, props.Spin)

	if props.ShowName ~= false then
		local bar: Frame = Create("Frame", {
			Name = "NameBar",
			BackgroundColor3 = Color3.fromHex("#0F1424"),
			BackgroundTransparency = 0.1,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 0.2),
			ZIndex = 5,
			Parent = root,
		})
		Create.Text({
			Text = name,
			Size = UDim2.new(1, -8, 1, -2),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Font = Theme.Fonts.Body,
			TextSize = 24,
			Scaled = true,
			Stroke = 1.5,
			ZIndex = 6,
			Parent = bar,
		})
	end

	local countLabel = Create.Text({
		Name = "Count",
		Text = "",
		Size = UDim2.fromScale(0.4, 0.17),
		Position = UDim2.new(1, -6, 0, 4),
		AnchorPoint = Vector2.new(1, 0),
		Font = Theme.Fonts.Display,
		TextSize = 22,
		Scaled = true,
		XAlign = Enum.TextXAlignment.Right,
		Stroke = 2,
		ZIndex = 7,
		Parent = root,
	})
	local lockShade: Frame = Create("Frame", {
		Name = "LockShade",
		BackgroundColor3 = Color3.fromHex("#05070D"),
		BackgroundTransparency = 0.35,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 8,
		Visible = false,
		Parent = root,
	})
	Icons.Lock(UDim2.fromScale(0.34, 0.34), lockShade).Position = UDim2.fromScale(0.33, 0.25)
	local scale = Instance.new("UIScale")
	scale.Parent = root

	local self = { Instance = root } :: any
	function self.SetCount(_: any, n: number?)
		countLabel.Text = if n and n > 1 then ("x" .. n) else ""
	end
	function self.SetSelected(_: any, selected: boolean)
		border.Thickness = if selected then 4.5 else 2.5
		border.Color = if selected then Color3.new(1, 1, 1) else rColor
		TweenService:Create(scale, TweenInfo.new(0.15), { Scale = if selected then 1.05 else 1 }):Play()
	end
	function self.SetLocked(_: any, locked: boolean)
		lockShade.Visible = locked
	end
	self:SetCount(props.Count)
	self:SetLocked(props.Locked == true)
	if props.Selected then
		self:SetSelected(true)
	end

	root.MouseEnter:Connect(function()
		if props.OnClick then
			TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1.04 }):Play()
		end
	end)
	root.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1 }):Play()
	end)
	if props.OnClick then
		local onClick = props.OnClick
		root.Activated:Connect(function()
			AudioController.Play("Select")
			onClick()
		end)
	end
	root.Parent = props.Parent
	return self :: Card
end

return ItemCard
