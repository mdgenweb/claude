--!strict
-- Shop menu ("Shop"): tabs Passes / Skill / Potions / Codes with the codes box pinned to the
-- bottom of the panel like the genre. Offers come from Config/Monetization; every buy button only
-- sends a RequestPurchase intent (the server opens the Roblox prompt, or in Studio grants a free
-- TEST for ids left at 0). Unconfigured ids show "TEST (Studio)" in Studio and a disabled "SOON"
-- in live servers. UIController.Open("Shop", tab?) jumps to "Passes" | "Skill" | "Potions" | "Codes".
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Monetization = require(Shared.Config.Monetization)
local Boosts = require(Shared.Definitions.Boosts)
local Eggs = require(Shared.Definitions.Eggs)
local Pets = require(Shared.Definitions.Pets)
local Worlds = require(Shared.Definitions.Worlds)
local Rarity = require(Shared.Config.Rarity)
local Format = require(Shared.Util.Format)

local Client = script.Parent.Parent.Parent
local StateController = require(Client.Controllers.StateController)
local UIController = require(Client.Controllers.UIController)
local Net = require(Client.Controllers.Net)
local Theme = require(Client.UI.Theme)
local Create = require(Client.UI.Create)
local Components = Client.UI.Components
local Button = require(Components.Button)
local MenuShell = require(Components.MenuShell)
local MenuTabs = require(Components.MenuTabs)
local MenuCard = require(Components.MenuCard)
local MenuGrid = require(Components.MenuGrid)

local ShopScreen = {}

local hex = Color3.fromHex
local IS_STUDIO = RunService:IsStudio()

local PANEL = Vector2.new(1240, 740)
local WIDTH = PANEL.X - 36 -- Panel content width
local HEIGHT = PANEL.Y - 78 - 16 -- Panel content height (title 56 + 22)
local TAB_H = 64
local CODES_H = 76
local PAGE_TOP = TAB_H + 12
local PAGE_H = HEIGHT - PAGE_TOP - CODES_H - 12

local TABS = {
	{ Key = "Passes", Text = "Passes", Icon = "💎", Style = "Pink" },
	{ Key = "Skill", Text = "Skill", Icon = Theme.Icons.Skill, Style = "Gold" },
	{ Key = "Potions", Text = "Potions", Icon = Theme.Icons.Potion, Style = "Green" },
	{ Key = "Codes", Text = "Codes", Icon = Theme.Icons.Codes, Style = "Purple" },
}

-- Monetization pass Icon keys -> emoji
local PASS_ICONS: { [string]: string } = {
	Auto = Theme.Icons.Auto,
	Skill = Theme.Icons.Skill,
	Wins = Theme.Icons.Wins,
	Pet = Theme.Icons.Pets,
	Egg = Theme.Icons.Egg,
	Pad = "🏋️",
}

local PASS_ACCENTS: { [string]: string } = {
	AutoThrow = "#FF5A5A",
	DoubleSkill = "#FFD447",
	DoubleWins = "#5BE05B",
	PetSlots = "#FFB86B",
	TripleHatch = "#C98CFF",
	Pad3x = "#5FB8FF",
	Pad15x = "#FF7F50",
	Pad50x = "#FFC53D",
}

local PASS_BADGES: { [string]: string } = {
	DoubleSkill = "POPULAR",
	Pad50x = "BEST",
}

type PackLook = { Accent: string, Rainbow: boolean, Badge: string? }

local SKILL_PACKS: { [string]: PackLook } = {
	Skill10K = { Accent = "#FFD447", Rainbow = false },
	Skill100K = { Accent = "#FF5A5A", Rainbow = false },
	Skill1M = { Accent = "#B65CFF", Rainbow = true, Badge = "BEST VALUE" },
}

type Entry = (data: { [string]: any }) -> ()

local shell: MenuShell.Shell
local tabs: MenuTabs.Tabs
local pages: { [string]: GuiObject } = {}
local updaters: { Entry } = {}
local codeBox: TextBox
local codeStroke: UIStroke

-- Button text/style/enabled for a Robux offer.
local function priceAction(id: number, robux: number, owned: boolean): (string, string, boolean)
	if owned then
		return "OWNED", "Grey", false
	end
	if id == 0 then
		if IS_STUDIO then
			return "TEST (Studio)", "Orange", true
		end
		return "SOON", "Disabled", false
	end
	return Theme.Icons.Robux .. " " .. tostring(robux), "Green", true
end

local function buy(kind: string, key: string)
	Net.Invoke("RequestPurchase", false, kind, key)
end

local function currentWorld(data: { [string]: any }): Worlds.World
	return Worlds.Get(if type(data.World) == "number" then data.World else 1) or Worlds.List[1]
end

local function refresh()
	local data = StateController.Data
	if data == nil then
		return
	end
	for _, update in updaters do
		update(data)
	end
end

-- Pages -------------------------------------------------------------------------------------------

local function buildPasses(parent: Frame)
	local columns = 4
	local grid = MenuGrid.new({
		Parent = parent,
		Name = "PassesGrid",
		Size = UDim2.fromScale(1, 1),
		Cell = Vector2.new(MenuGrid.CellWidth(WIDTH, columns), 318),
	})
	for i, pass in Monetization.Passes do
		local card = MenuCard.new({
			Parent = grid,
			Name = pass.Key,
			LayoutOrder = i,
			Accent = hex(PASS_ACCENTS[pass.Key] or "#5FB8FF"),
			Icon = PASS_ICONS[pass.Icon] or Theme.Icons.Star,
			Title = pass.Name,
			Subtitle = "GAME PASS",
			Description = pass.Description,
			ButtonText = "",
			OnClick = function()
				buy("Pass", pass.Key)
			end,
		})
		table.insert(updaters, function()
			local owned = StateController.HasPass(pass.Key)
			local text, style, enabled = priceAction(pass.Id, pass.Robux, owned)
			card:SetAction(text, style, enabled)
			if owned then
				card:SetBadge("OWNED", Theme.Colors.Success)
			elseif PASS_BADGES[pass.Key] then
				card:SetBadge(PASS_BADGES[pass.Key], Theme.Colors.Danger)
			else
				card:SetBadge(nil)
			end
		end)
	end
end

local function starterPackText(): string
	local pack = Monetization.StarterPack
	local lines = {}
	local pet = Pets.Get(pack.Pet)
	if pet then
		table.insert(lines, string.format("%s %s (x%s Skill)", Theme.Icons.Pets, pet.Name, Format.Short(1 + pet.SkillBoost)))
	end
	local parts = {}
	for _, boost in Boosts.List do
		local n = pack.Potions[boost.Id]
		if n and n > 0 then
			table.insert(parts, string.format("%d %s", n, boost.Stat))
		end
	end
	if #parts > 0 then
		table.insert(lines, Theme.Icons.Potion .. " " .. table.concat(parts, ", ") .. " potions")
	end
	table.insert(lines, Theme.Icons.Wins .. " " .. Format.Commas(pack.Wins) .. " Wins")
	return table.concat(lines, "\n")
end

local function overlordText(egg: Eggs.Egg?): string
	if egg == nil then
		return "Hatch one premium egg."
	end
	local best: Pets.Pet? = nil
	for _, entry in egg.Pets do
		local pet = Pets.Get(entry.Pet)
		if pet and (best == nil or Rarity.Order(pet.Rarity) > Rarity.Order(best.Rarity)) then
			best = pet
		end
	end
	local text = "Hatch one " .. egg.Name .. " in any world."
	if best then
		text ..= string.format("\nChance at %s (x%s Skill)!", best.Name, Format.Short(1 + best.SkillBoost))
	end
	return text
end

local function buildSkill(parent: Frame)
	local columns = 3
	local grid = MenuGrid.new({
		Parent = parent,
		Name = "SkillGrid",
		Size = UDim2.fromScale(1, 1),
		Cell = Vector2.new(MenuGrid.CellWidth(WIDTH, columns), 340),
	})
	local order = 0
	for _, product in Monetization.Products do
		if product.Kind ~= "Skill" then
			continue
		end
		order += 1
		local look: PackLook = SKILL_PACKS[product.Key] or { Accent = "#FFD447", Rainbow = false, Badge = nil }
		local card = MenuCard.new({
			Parent = grid,
			Name = product.Key,
			LayoutOrder = order,
			Accent = hex(look.Accent),
			Rainbow = look.Rainbow,
			Icon = Theme.Icons.Skill,
			Title = product.Name,
			Subtitle = "",
			Description = "Instant Skill, scaled up in every new world. Still pays at MAX LEVEL.",
			ButtonText = "",
			OnClick = function()
				buy("Product", product.Key)
			end,
		})
		table.insert(updaters, function(data)
			local world = currentWorld(data)
			card:SetTitle("+" .. Format.Short((product.Amount or 0) * world.SkillPackScale) .. " Skill")
			card:SetSubtitle("in " .. world.Name)
			local text, style, enabled = priceAction(product.Id, product.Robux, false)
			card:SetAction(text, style, enabled)
			card:SetBadge(look.Badge, Theme.Colors.Danger)
		end)
	end

	local starter = Monetization.Product("StarterPack")
	if starter then
		local product = starter
		local card = MenuCard.new({
			Parent = grid,
			Name = "StarterPack",
			LayoutOrder = 10,
			Accent = hex("#FFB300"),
			Icon = Theme.Icons.Star,
			Title = product.Name,
			Subtitle = "ONE TIME ONLY",
			Description = starterPackText(),
			ButtonText = "",
			OnClick = function()
				buy("Product", product.Key)
			end,
		})
		table.insert(updaters, function(data)
			local owned = type(data.Flags) == "table" and data.Flags.StarterPack == true
			local text, style, enabled = priceAction(product.Id, product.Robux, owned)
			card:SetAction(text, style, enabled)
			card:SetBadge(if owned then "OWNED" else "HOT", if owned then Theme.Colors.Success else Theme.Colors.Danger)
		end)
	end

	local overlord = Monetization.Product("OverlordEgg")
	if overlord then
		local product = overlord
		local egg = Eggs.Get(product.Ref or "")
		local card = MenuCard.new({
			Parent = grid,
			Name = "OverlordEgg",
			LayoutOrder = 11,
			Accent = hex(if egg then egg.Accent else "#39FF14"),
			Icon = Theme.Icons.Egg,
			Title = product.Name,
			Subtitle = "PREMIUM EGG",
			Description = overlordText(egg),
			ButtonText = "",
			OnClick = function()
				buy("Product", product.Key)
			end,
		})
		table.insert(updaters, function()
			local text, style, enabled = priceAction(product.Id, product.Robux, false)
			card:SetAction(text, style, enabled)
		end)
	end
end

local function buildPotions(parent: Frame)
	local columns = 3
	local grid = MenuGrid.new({
		Parent = parent,
		Name = "PotionsGrid",
		Size = UDim2.fromScale(1, 1),
		Cell = Vector2.new(MenuGrid.CellWidth(WIDTH, columns), 340),
		Center = true,
	})
	local order = 0
	for _, product in Monetization.Products do
		if product.Kind ~= "Potion" then
			continue
		end
		order += 1
		local boost = Boosts.Get(product.Ref or "")
		local minutes = if boost then math.floor(boost.Duration / 60) else 10
		local card = MenuCard.new({
			Parent = grid,
			Name = product.Key,
			LayoutOrder = order,
			Accent = hex(if boost then boost.Color else "#5BE05B"),
			Icon = Theme.Icons.Potion,
			Title = product.Name,
			Subtitle = "",
			Description = string.format(
				"%d potions. Each one doubles your %s for %d minutes. Timers stack!",
				product.Amount or 1,
				if boost then boost.Stat else "Skill",
				minutes
			),
			ButtonText = "",
			OnClick = function()
				buy("Product", product.Key)
			end,
		})
		table.insert(updaters, function(data)
			local potions = if type(data.Potions) == "table" then data.Potions else {}
			local owned = tonumber(potions[product.Ref or ""]) or 0
			card:SetSubtitle("You own: " .. Format.Commas(owned))
			local text, style, enabled = priceAction(product.Id, product.Robux, false)
			card:SetAction(text, style, enabled)
		end)
	end
end

local function buildCodes(parent: Frame)
	local box: Frame = Create("Frame", {
		Name = "CodesInfo",
		BackgroundColor3 = Theme.Colors.PanelDeep,
		BackgroundTransparency = 0.2,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -40, 1, -30),
		Parent = parent,
	})
	Create.Corner(18, box)
	Create.Stroke(box, hex("#C98CFF"), 3, 0.2, true)
	Create.Text({
		Name = "Ticket",
		Text = Theme.Icons.Codes,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 22),
		Size = UDim2.fromOffset(150, 130),
		Font = Theme.Fonts.Display,
		TextSize = 110,
		Scaled = true,
		Parent = box,
	})
	Create.Text({
		Name = "Headline",
		Text = "REDEEM CODES",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 160),
		Size = UDim2.new(1, -60, 0, 60),
		Font = Theme.Fonts.Display,
		TextSize = 58,
		Scaled = true,
		Color = hex("#E6C9FF"),
		Stroke = 4,
		Parent = box,
	})
	Create.Text({
		Name = "Body",
		Text = "Type a code in the box below and press REDEEM for free Wins, Skill and potions.\nCodes are not case-sensitive and each one works once per player.",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 232),
		Size = UDim2.new(1, -100, 0, 110),
		Font = Theme.Fonts.Body,
		TextSize = 26,
		Scaled = true,
		Wrapped = true,
		Color = Theme.Colors.TextDim,
		Stroke = 1.5,
		Parent = box,
	})
	Create.Text({
		Name = "Arrow",
		Text = "⬇️",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromOffset(60, 52),
		Font = Theme.Fonts.Display,
		TextSize = 44,
		Scaled = true,
		Parent = box,
	})
end

-- Codes bar (bottom of every tab) ------------------------------------------------------------------

local function trim(s: string): string
	return (string.gsub(string.gsub(s, "^%s+", ""), "%s+$", ""))
end

local function redeem()
	local text = trim(codeBox.Text)
	if text == "" then
		UIController.Toast("Type a code first!", "Error")
		return
	end
	local result = Net.Invoke("RequestRedeemCode", false, text)
	if result.ok then
		codeBox.Text = ""
	end
end

local function buildCodesBar(parent: Frame)
	local bar: Frame = Create("Frame", {
		Name = "CodesBar",
		BackgroundColor3 = Theme.Colors.PanelDeep,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, CODES_H),
		Parent = parent,
	})
	Create.Corner(16, bar)
	codeStroke = Create.Stroke(bar, hex("#C98CFF"), 3, 0, true)
	Create.Text({
		Name = "Label",
		Text = Theme.Icons.Codes .. " CODES",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 18, 0.5, 0),
		Size = UDim2.fromOffset(190, 48),
		Font = Theme.Fonts.Display,
		TextSize = 40,
		Scaled = true,
		XAlign = Enum.TextXAlignment.Left,
		Stroke = 3,
		Parent = bar,
	})
	local input: TextBox = Create("TextBox", {
		Name = "CodeInput",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 220, 0.5, 0),
		Size = UDim2.new(1, -220 - 250, 0, 60),
		BackgroundColor3 = hex("#F2F5FA"),
		ClearTextOnFocus = false,
		Text = "",
		PlaceholderText = "Enter code here...",
		PlaceholderColor3 = hex("#8C93A3"),
		TextColor3 = hex("#1B1F3B"),
		FontFace = Theme.Fonts.Display,
		TextSize = 32,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Selectable = true,
		Parent = bar,
	})
	Create.Corner(12, input)
	Create.Stroke(input, Theme.Colors.Stroke, 3, 0, true)
	Create.Padding(input, 16, 0)
	input:GetPropertyChangedSignal("Text"):Connect(function()
		if #input.Text > 32 then
			input.Text = string.sub(input.Text, 1, 32)
		end
	end)
	input.FocusLost:Connect(function(enterPressed: boolean)
		if enterPressed then
			redeem()
		end
	end)
	codeBox = input
	Button.new({
		Parent = bar,
		Name = "Redeem",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(222, 62),
		Style = "Green",
		Text = "REDEEM",
		TextSize = 34,
		Corner = 12,
		OnClick = redeem,
	})
end

local PULSE = TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 1, true)

local function showPage(key: string)
	for k, page in pages do
		page.Visible = k == key
	end
	if key == "Codes" then
		codeStroke.Thickness = 3
		TweenService:Create(codeStroke, PULSE, { Thickness = 7 }):Play()
		if UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled and not MenuShell.UsingGamepad() then
			codeBox:CaptureFocus()
		end
	end
end

function ShopScreen.Init()
	shell = MenuShell.new({
		Name = "Shop",
		Title = "Shop",
		Icon = Theme.Icons.Shop,
		Size = PANEL,
		Accent = hex("#FF8FC8"),
		OnOpen = function(tab: any)
			if type(tab) == "string" and pages[tab] then
				tabs:Select(tab, true)
				showPage(tab)
			end
			refresh()
		end,
		OnClose = function()
			if codeBox:IsFocused() then
				codeBox:ReleaseFocus()
			end
		end,
		OnShoulder = function(direction: number)
			tabs:Cycle(direction)
		end,
		FirstSelection = function()
			return tabs.Buttons[tabs.Selected].Instance
		end,
	})
	local content = shell.Content

	tabs = MenuTabs.new({
		Parent = content,
		Tabs = TABS,
		Size = UDim2.new(1, 0, 0, TAB_H),
		TabWidth = 220,
		OnChanged = showPage,
	})

	local builders: { [string]: (Frame) -> () } = {
		Passes = buildPasses,
		Skill = buildSkill,
		Potions = buildPotions,
		Codes = buildCodes,
	}
	for _, spec in TABS do
		local page: Frame = Create("Frame", {
			Name = spec.Key .. "Page",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, PAGE_TOP),
			Size = UDim2.new(1, 0, 0, PAGE_H),
			Visible = false,
			Parent = content,
		})
		pages[spec.Key] = page
		builders[spec.Key](page)
	end
	buildCodesBar(content)

	tabs:Select("Passes", true)
	showPage("Passes")

	UIController.Register("Shop", shell)
	StateController.DataChanged:Connect(function()
		if shell:IsOpen() then
			refresh()
		end
	end)
	refresh()
end

return ShopScreen
