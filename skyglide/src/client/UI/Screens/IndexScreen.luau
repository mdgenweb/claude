--!strict
-- Index menu ("Index"): the pet collection book that simulators keep. One tab per world plus
-- Special (the Robux egg and the exclusive pets). Each egg is a section with its own completion
-- bar, and every pet is a card: pets found so far show their model, name and boost, the rest a
-- black silhouette with "???" (their rarity outline still shows). An overall bar counts every
-- pet in the game. Discoveries come from the server (PlayerData.Index, set when a pet is first
-- owned); the screen only reads them. Cards are built when a tab is first shown and stay static
-- (no spin), so a closed Index costs nothing per frame.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Pets = require(Shared.Definitions.Pets)
local Eggs = require(Shared.Definitions.Eggs)
local Worlds = require(Shared.Definitions.Worlds)
local Format = require(Shared.Util.Format)
local PetFactory = require(Shared.Visual.PetFactory)

local Client = script.Parent.Parent.Parent
local StateController = require(Client.Controllers.StateController)
local UIController = require(Client.Controllers.UIController)
local Theme = require(Client.UI.Theme)
local Create = require(Client.UI.Create)
local Components = Client.UI.Components
local MenuShell = require(Components.MenuShell)
local MenuTabs = require(Components.MenuTabs)
local MenuGrid = require(Components.MenuGrid)
local ItemSlot = require(Components.ItemSlot)

local IndexScreen = {}

local PANEL = Vector2.new(1240, 740)
local WIDTH = PANEL.X - 36
local TAB_H = 64
local SUMMARY_H = 48
local LIST_TOP = TAB_H + 12 + SUMMARY_H + 12
local HEADER_H = 44
local COLUMNS = 7
local GAP = 12
local INSET = 8
local CARD_W = math.floor((WIDTH - MenuGrid.ScrollBar - INSET * 2 - GAP * (COLUMNS - 1)) / COLUMNS)
local CARD_H = 184
local GOLD_TOP = Color3.fromHex("#FFE27A")
local GOLD_BOTTOM = Color3.fromHex("#F2A900")
local SPECIAL = "Special"

type Section = { Title: string, Icon: string, Pets: { string } }
type Card = { Slot: ItemSlot.Slot, PetId: string }
type SectionRefs = { Pets: { string }, Count: TextLabel, Fill: Frame, Cards: { Card } }

local shell: MenuShell.Shell
local tabs: MenuTabs.Tabs
local pages: { [string]: ScrollingFrame } = {}
local built: { [string]: { SectionRefs } } = {}
local summaryText: TextLabel
local summaryFill: Frame
local summaryPercent: TextLabel

-- Pet ids of an egg, in its listed order, without repeats.
local function eggPets(egg: Eggs.Egg): { string }
	local out, seen = {}, {}
	for _, entry in egg.Pets do
		if not seen[entry.Pet] then
			seen[entry.Pet] = true
			table.insert(out, entry.Pet)
		end
	end
	return out
end

local function sectionsFor(tab: string): { Section }
	local sections: { Section } = {}
	if tab == SPECIAL then
		for _, egg in Eggs.List do
			if egg.World == nil then
				table.insert(sections, { Title = egg.Name, Icon = Theme.Icons.Egg, Pets = eggPets(egg) })
			end
		end
		local exclusives = {}
		for _, pet in Pets.List do
			if pet.Exclusive then
				table.insert(exclusives, pet.Id)
			end
		end
		if #exclusives > 0 then
			table.insert(sections, { Title = "Exclusives", Icon = Theme.Icons.Star, Pets = exclusives })
		end
	else
		local world = tonumber(tab)
		for _, egg in Eggs.List do
			if egg.World == world then
				table.insert(sections, { Title = egg.Name, Icon = Theme.Icons.Egg, Pets = eggPets(egg) })
			end
		end
	end
	return sections
end

local function found(): { [string]: boolean }
	local data = StateController.Data
	return if data and type(data.Index) == "table" then data.Index else {}
end

-- A thin rounded progress bar; returns the fill.
local function bar(parent: Instance, size: UDim2, position: UDim2, anchor: Vector2): Frame
	local track: Frame = Create("Frame", {
		Name = "Bar",
		BackgroundColor3 = Theme.Colors.LevelTrack,
		Size = size,
		Position = position,
		AnchorPoint = anchor,
		Parent = parent,
	})
	Create.Round(track)
	Create.Stroke(track, Theme.Colors.Stroke, 2.5, 0, true)
	local fill: Frame = Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(0, 1),
		Parent = track,
	})
	Create.Round(fill)
	Create.Gradient(fill, GOLD_TOP, GOLD_BOTTOM, 90)
	return fill
end

local function setFill(fill: Frame, have: number, total: number)
	local f = if total > 0 then have / total else 0
	fill.Size = UDim2.fromScale(f, 1)
	fill.Visible = f > 0
end

local function buildCard(parent: Instance, petId: string, order: number): Card?
	local pet = Pets.Get(petId)
	if not pet then
		return nil
	end
	local slot = ItemSlot.new({
		Parent = parent,
		Name = petId,
		LayoutOrder = order,
		Rarity = pet.Rarity,
		Build = function()
			return PetFactory.ForId(petId, 3)
		end,
		Spin = 0,
		Silhouette = true,
		Title = "???",
		Stat = pet.Rarity,
	})
	return { Slot = slot, PetId = petId }
end

local function buildPage(tab: string)
	local page = pages[tab]
	local refs: { SectionRefs } = {}
	local y = 0
	for i, section in sectionsFor(tab) do
		local rows = math.max(1, math.ceil(#section.Pets / COLUMNS))
		local height = HEADER_H + 8 + rows * CARD_H + (rows - 1) * GAP
		local frame: Frame = Create("Frame", {
			Name = "Section" .. i,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.new(1, 0, 0, height),
			Parent = page,
		})
		local header: Frame = Create("Frame", {
			Name = "Header",
			BackgroundColor3 = Theme.Colors.CardDeep,
			Size = UDim2.new(1, 0, 0, HEADER_H),
			Parent = frame,
		})
		Create.Corner(12, header)
		Create.Text({
			Name = "Title",
			Text = section.Icon .. " " .. section.Title,
			Size = UDim2.new(0.45, 0, 1, -10),
			Position = UDim2.new(0, 12, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			Font = Theme.Fonts.Display,
			TextSize = 28,
			Scaled = true,
			XAlign = Enum.TextXAlignment.Left,
			Stroke = 2.2,
			Parent = header,
		})
		local fill = bar(header, UDim2.new(0.3, 0, 0, 18), UDim2.new(1, -110, 0.5, 0), Vector2.new(1, 0.5))
		local count = Create.Text({
			Name = "Count",
			Text = "",
			Size = UDim2.fromOffset(90, 30),
			Position = UDim2.new(1, -12, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Font = Theme.Fonts.Display,
			TextSize = 26,
			Scaled = true,
			XAlign = Enum.TextXAlignment.Right,
			Stroke = 2,
			Parent = header,
		})
		local grid: Frame = Create("Frame", {
			Name = "Cards",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, HEADER_H + 8),
			Size = UDim2.new(1, 0, 0, height - HEADER_H - 8),
			Parent = frame,
		})
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.fromOffset(CARD_W, CARD_H)
		layout.CellPadding = UDim2.fromOffset(GAP, GAP)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = grid
		local cards: { Card } = {}
		for n, petId in section.Pets do
			local card = buildCard(grid, petId, n)
			if card then
				table.insert(cards, card)
			end
		end
		table.insert(refs, { Pets = section.Pets, Count = count, Fill = fill, Cards = cards })
		y += height + 16
	end
	page.CanvasSize = UDim2.fromOffset(0, y + INSET * 2)
	built[tab] = refs
end

local function refresh()
	local index = found()
	-- whole game
	local total, have = #Pets.List, 0
	for _, pet in Pets.List do
		if index[pet.Id] then
			have += 1
		end
	end
	summaryText.Text = string.format("📖 Discovered %d / %d pets", have, total)
	summaryPercent.Text = Format.Percent(if total > 0 then have / total * 100 else 0)
	setFill(summaryFill, have, total)
	-- tab labels: a check once a tab is complete
	for key, button in tabs.Buttons do
		local all, got = 0, 0
		for _, section in sectionsFor(key) do
			for _, petId in section.Pets do
				all += 1
				if index[petId] then
					got += 1
				end
			end
		end
		local world = tonumber(key)
		local def = if world then Worlds.Get(world) else nil
		local name = if def then def.Name else SPECIAL
		button:SetText((if all > 0 and got == all then Theme.Icons.Check .. " " else "") .. name)
	end
	-- the built tab pages
	for _, refs in built do
		for _, section in refs do
			local got = 0
			for _, card in section.Cards do
				local pet = Pets.Get(card.PetId) :: Pets.Pet
				local isFound = index[card.PetId] == true
				if isFound then
					got += 1
				end
				card.Slot:SetSilhouette(not isFound)
				card.Slot:SetTitle(if isFound then pet.Name else "???")
				card.Slot:SetStat(if isFound then "x" .. Format.Short(1 + pet.SkillBoost) .. " Skill" else pet.Rarity)
			end
			section.Count.Text = string.format("%d/%d", got, #section.Cards)
			section.Count.TextColor3 = if got == #section.Cards then Theme.Colors.Success else Theme.Colors.Text
			setFill(section.Fill, got, #section.Cards)
		end
	end
end

local function showPage(key: string)
	if built[key] == nil then
		buildPage(key)
	end
	for k, page in pages do
		page.Visible = k == key
	end
	refresh()
end

function IndexScreen.Init()
	shell = MenuShell.new({
		Name = "Index",
		Title = "Index",
		Icon = "📖",
		Size = PANEL,
		Accent = Color3.fromHex("#C98CFF"),
		OnOpen = function()
			-- open on the world the player is in
			local data = StateController.Data
			local world = if data then tostring(tonumber(data.World) or 1) else "1"
			if tabs.Buttons[world] then
				tabs:Select(world, true)
				showPage(world)
			else
				refresh()
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
	local specs: { MenuTabs.TabSpec } = {}
	for i = 1, Worlds.Count do
		local def = Worlds.Get(i)
		table.insert(specs, { Key = tostring(i), Text = if def then def.Name else ("World " .. i), Style = "Blue" })
	end
	table.insert(specs, { Key = SPECIAL, Text = SPECIAL, Style = "Purple" })
	tabs = MenuTabs.new({
		Parent = content,
		Tabs = specs,
		Size = UDim2.new(1, 0, 0, TAB_H),
		TabWidth = math.floor((WIDTH - 12 * (#specs - 1)) / #specs),
		OnChanged = showPage,
	})

	local summary: Frame = Create("Frame", {
		Name = "Summary",
		BackgroundColor3 = Theme.Colors.CardDeep,
		Position = UDim2.fromOffset(0, TAB_H + 12),
		Size = UDim2.new(1, 0, 0, SUMMARY_H),
		Parent = content,
	})
	Create.Corner(14, summary)
	summaryText = Create.Text({
		Name = "Text",
		Text = "",
		Size = UDim2.new(0.42, 0, 1, -12),
		Position = UDim2.new(0, 14, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Font = Theme.Fonts.Display,
		TextSize = 28,
		Scaled = true,
		XAlign = Enum.TextXAlignment.Left,
		Stroke = 2.2,
		Parent = summary,
	})
	summaryFill = bar(summary, UDim2.new(0.44, 0, 0, 22), UDim2.new(1, -120, 0.5, 0), Vector2.new(1, 0.5))
	summaryPercent = Create.Text({
		Name = "Percent",
		Text = "",
		Size = UDim2.fromOffset(96, 32),
		Position = UDim2.new(1, -12, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Font = Theme.Fonts.Display,
		TextSize = 28,
		Scaled = true,
		XAlign = Enum.TextXAlignment.Right,
		Color = Theme.Colors.Skill,
		Stroke = 2.2,
		Parent = summary,
	})

	for _, spec in specs do
		local page: ScrollingFrame = Create("ScrollingFrame", {
			Name = "Page_" .. spec.Key,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, LIST_TOP),
			Size = UDim2.new(1, 0, 1, -LIST_TOP),
			CanvasSize = UDim2.new(),
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = MenuGrid.ScrollBar,
			ScrollBarImageColor3 = Theme.Colors.PanelEdge,
			VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
			Selectable = false,
			ClipsDescendants = true,
			Visible = false,
			Parent = content,
		})
		Create.Padding(page, INSET, INSET)
		pages[spec.Key] = page
	end

	tabs:Select("1", true)
	showPage("1")

	UIController.Register("Index", shell)
	StateController.DataChanged:Connect(function()
		if shell:IsOpen() then
			refresh()
		end
	end)
end

return IndexScreen
