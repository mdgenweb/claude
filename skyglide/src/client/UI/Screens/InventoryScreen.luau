--!strict
-- Inventory menu ("Inventory"): tab "Gliders" lists owned gliders (strongest first) and owned
-- relics with Equip; tab "Potions" lists potion counts with Use plus the active boost timers.
-- Equip/Use are RequestEquipThrowable / RequestUseBoost intents.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Gliders = require(Shared.Definitions.Gliders)
local Relics = require(Shared.Definitions.Relics)
local Boosts = require(Shared.Definitions.Boosts)
local Format = require(Shared.Util.Format)
local GliderFactory = require(Shared.Visual.GliderFactory)

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
local ItemSlot = require(Components.ItemSlot)

local InventoryScreen = {}

local PANEL = Vector2.new(1240, 740)
local WIDTH = PANEL.X - 36
local TAB_H = 64

local shell: MenuShell.Shell
local tabs: MenuTabs.Tabs
local pages: { [string]: GuiObject } = {}
local gliderGrid: ScrollingFrame
local gliderSlots: { [string]: ItemSlot.Slot } = {}
local selectedGlider: string? = nil
local equipButton: Button.Button
local gliderInfo: TextLabel
local potionCards: { [string]: MenuCard.Card } = {}

local function serverNow(): number
	local derived = StateController.Derived()
	return (if type(derived.ServerTime) == "number" then derived.ServerTime else os.time()) + StateController.Since()
end

local function equippedId(data: { [string]: any }): string
	if type(data.Relic) == "string" and data.Relic ~= "" then
		return "relic:" .. data.Relic
	end
	return if type(data.Glider) == "string" then data.Glider else Gliders.Default
end

local function refreshGliders(data: { [string]: any })
	local owned = if type(data.Gliders) == "table" then data.Gliders else {}
	local relics = if type(data.Relics) == "table" then data.Relics else {}
	local equipped = equippedId(data)
	local entries: { { Id: string, Name: string, Rarity: string, Stat: string, Power: number } } = {}
	for _, relic in Relics.List do
		if relics[relic.Id] then
			table.insert(entries, { Id = "relic:" .. relic.Id, Name = relic.Name, Rarity = "Mythic", Stat = "+125% vs best", Power = math.huge })
		end
	end
	for _, glider in Gliders.List do
		if owned[glider.Id] then
			table.insert(entries, { Id = glider.Id, Name = glider.Name, Rarity = glider.Rarity, Stat = "+" .. Format.Short(glider.SkillPerRing) .. " Skill", Power = glider.SkillPerRing })
		end
	end
	table.sort(entries, function(a, b)
		return a.Power > b.Power
	end)
	local alive: { [string]: boolean } = {}
	for i, entry in entries do
		alive[entry.Id] = true
		local slot = gliderSlots[entry.Id]
		if not slot then
			local id = entry.Id
			slot = ItemSlot.new({
				Parent = gliderGrid,
				Name = id,
				Rarity = entry.Rarity,
				Build = function()
					local model = GliderFactory.ForId(id, 3, true)
					-- show the glider from slightly above so the wings read
					model:PivotTo(model:GetPivot() * CFrame.Angles(math.rad(25), 0, 0))
					return model
				end,
				Title = entry.Name,
				Stat = entry.Stat,
				OnClick = function()
					selectedGlider = id
					local current = StateController.Data
					if current then
						refreshGliders(current)
					end
				end,
			})
			gliderSlots[entry.Id] = slot
		end
		local s = slot :: ItemSlot.Slot
		s.Instance.LayoutOrder = i
		s:SetCorner(if entry.Id == equipped then Theme.Icons.Check else nil)
		s:SetSelected(entry.Id == selectedGlider)
	end
	for id, slot in gliderSlots do
		if not alive[id] then
			slot:Destroy()
			gliderSlots[id] = nil
		end
	end
	if selectedGlider == nil or not alive[selectedGlider] then
		selectedGlider = equipped
	end
	local sel = selectedGlider :: string
	local relicId = string.match(sel, "^relic:(.+)$")
	if relicId then
		local relic = Relics.Get(relicId)
		local best = Gliders.BestOwned(owned)
		gliderInfo.Text = string.format("%s %s  ·  always 125%% better than your best glider (%s: +%s Skill per ring)", Theme.Icons.Relic, if relic then relic.Name else "Relic", best.Name, Format.Short(best.SkillPerRing))
	else
		local glider = Gliders.Get(sel)
		gliderInfo.Text = if glider then string.format("%s %s  ·  +%s Skill for every thermal ring (%s)", Theme.Icons.Glider, glider.Name, Format.Short(glider.SkillPerRing), glider.Rarity) else ""
	end
	local isEquipped = sel == equipped
	equipButton:SetText(if isEquipped then "EQUIPPED" else "EQUIP")
	equipButton:SetStyle(if isEquipped then "Grey" else "Green")
	equipButton:SetEnabled(not isEquipped)
end

local function refreshPotions(data: { [string]: any })
	local potions = if type(data.Potions) == "table" then data.Potions else {}
	local active = if type(data.Boosts) == "table" then data.Boosts else {}
	local now = serverNow()
	for _, boost in Boosts.List do
		local card = potionCards[boost.Id]
		local count = potions[boost.Id] or 0
		local expiry = active[boost.Id]
		local remaining = if type(expiry) == "number" then expiry - now else 0
		card:SetSubtitle(string.format("You have %d", count))
		if remaining > 0 then
			card:SetBadge("ACTIVE " .. Format.Clock(remaining), Theme.Colors.Success)
		else
			card:SetBadge(nil)
		end
		card:SetAction(if count > 0 then "USE" else "NONE LEFT", if count > 0 then "Green" else "Disabled", count > 0)
	end
end

local function refresh()
	local data = StateController.Data
	if data == nil then
		return
	end
	if tabs.Selected == "Gliders" then
		refreshGliders(data)
	else
		refreshPotions(data)
	end
end

local function showPage(key: string)
	for k, page in pages do
		page.Visible = k == key
	end
	refresh()
end

function InventoryScreen.Init()
	shell = MenuShell.new({
		Name = "Inventory",
		Title = "Inventory",
		Icon = Theme.Icons.Inventory,
		Size = PANEL,
		Accent = Color3.fromHex("#5FB8FF"),
		OnOpen = function(tab: any)
			if tab == "Potions" or tab == "Gliders" then
				tabs:Select(tab, true)
				showPage(tab)
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
	tabs = MenuTabs.new({
		Parent = content,
		Tabs = {
			{ Key = "Gliders", Text = "Gliders", Icon = Theme.Icons.Glider, Style = "Blue" },
			{ Key = "Potions", Text = "Potions", Icon = Theme.Icons.Potion, Style = "Green" },
		},
		Size = UDim2.new(1, 0, 0, TAB_H),
		TabWidth = 240,
		OnChanged = showPage,
	})

	-- Gliders page
	local glidersPage: Frame = Create("Frame", {
		Name = "Gliders",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, TAB_H + 12),
		Size = UDim2.new(1, 0, 1, -(TAB_H + 12)),
		Parent = content,
	})
	pages.Gliders = glidersPage
	gliderGrid = MenuGrid.new({
		Parent = glidersPage,
		Name = "Grid",
		Size = UDim2.new(1, 0, 1, -86),
		Cell = Vector2.new(MenuGrid.CellWidth(WIDTH, 6), 176),
	})
	local footer: Frame = Create("Frame", {
		Name = "Footer",
		BackgroundColor3 = Theme.Colors.CardDeep,
		Position = UDim2.new(0, 0, 1, -76),
		Size = UDim2.new(1, 0, 0, 76),
		Parent = glidersPage,
	})
	Create.Corner(14, footer)
	gliderInfo = Create.Text({
		Text = "",
		Size = UDim2.new(1, -280, 1, -16),
		Position = UDim2.fromOffset(14, 8),
		Font = Theme.Fonts.Body,
		TextSize = 24,
		Scaled = true,
		Wrapped = true,
		XAlign = Enum.TextXAlignment.Left,
		Stroke = 1.5,
		Parent = footer,
	})
	equipButton = Button.new({
		Parent = footer,
		Name = "Equip",
		Size = UDim2.fromOffset(240, 62),
		Position = UDim2.new(1, -8, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Style = "Green",
		Text = "EQUIP",
		TextSize = 28,
		OnClick = function()
			local id = selectedGlider
			if id then
				task.spawn(Net.Invoke, "RequestEquipThrowable", false, id)
			end
		end,
	})

	-- Potions page
	local potionsPage = MenuGrid.new({
		Parent = content,
		Name = "Potions",
		Position = UDim2.fromOffset(0, TAB_H + 12),
		Size = UDim2.new(1, 0, 1, -(TAB_H + 12)),
		Cell = Vector2.new(MenuGrid.CellWidth(WIDTH, 3), 330),
		Center = true,
	})
	potionsPage.Visible = false
	pages.Potions = potionsPage
	for i, boost in Boosts.List do
		local id = boost.Id
		potionCards[id] = MenuCard.new({
			Parent = potionsPage,
			Name = id,
			LayoutOrder = i,
			Accent = Color3.fromHex(boost.Color),
			Icon = if boost.Stat == "Luck" then Theme.Icons.Luck elseif boost.Stat == "Wins" then Theme.Icons.Wins else Theme.Icons.Skill,
			Title = boost.Name,
			Subtitle = "",
			Description = string.format("x%s %s for %d minutes. Using more adds time.", Format.Short(boost.Multiplier), boost.Stat, math.floor(boost.Duration / 60)),
			ButtonText = "",
			OnClick = function()
				task.spawn(Net.Invoke, "RequestUseBoost", false, id)
			end,
		})
	end

	-- start on the Gliders tab (MenuTabs starts with nothing selected)
	tabs:Select("Gliders", true)
	showPage("Gliders")

	UIController.Register("Inventory", shell)
	StateController.DataChanged:Connect(function()
		if shell:IsOpen() then
			refresh()
		end
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 1 then
			acc = 0
			if shell:IsOpen() and tabs.Selected == "Potions" then
				refresh()
			end
		end
	end)
end

return InventoryScreen
