--!strict
-- Pets menu ("Pets"): every owned pet in a rarity-bordered grid (equipped first, then strongest),
-- a detail pane with Equip/Unequip and Lock/Unlock, Equip Best, and a multi-select delete mode
-- (locked pets can't be picked). Every action is a RequestPetAction intent; the server owns the
-- inventory and slot limits.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Pets = require(Shared.Definitions.Pets)
local Economy = require(Shared.Config.Economy)
local Rarity = require(Shared.Config.Rarity)
local Format = require(Shared.Util.Format)
local PetFactory = require(Shared.Visual.PetFactory)

local Client = script.Parent.Parent.Parent
local StateController = require(Client.Controllers.StateController)
local UIController = require(Client.Controllers.UIController)
local Net = require(Client.Controllers.Net)
local Theme = require(Client.UI.Theme)
local Create = require(Client.UI.Create)
local Components = Client.UI.Components
local Button = require(Components.Button)
local MenuShell = require(Components.MenuShell)
local MenuGrid = require(Components.MenuGrid)
local ItemSlot = require(Components.ItemSlot)
local Viewport = require(Components.Viewport)

local PetsScreen = {}

local PANEL = Vector2.new(1240, 740)
local WIDTH = PANEL.X - 36
local HEIGHT = PANEL.Y - 78 - 16
local BAR_H = 70
local DETAIL_W = 360
local GRID_W = WIDTH - DETAIL_W - 16

local shell: MenuShell.Shell
local grid: ScrollingFrame
local slots: { [string]: ItemSlot.Slot } = {}
local selected: string? = nil
local deleteMode = false
local toDelete: { [string]: boolean } = {}

local summary: TextLabel
local equipBestButton: Button.Button
local deleteButton: Button.Button
local detail: Frame
local detailPreview: Frame
local detailName: TextLabel
local detailRarity: TextLabel
local detailStats: TextLabel
local equipButton: Button.Button
local lockButton: Button.Button
local emptyLabel: TextLabel
local previewId: string? = nil

local function petScore(def: Pets.Pet): number
	return def.SkillBoost * 1000 + def.WinsBoost
end

local function multiplierText(def: Pets.Pet): string
	return "x" .. Format.Short(1 + def.SkillBoost) .. " Skill"
end

local function ownedPets(data: { [string]: any }): { [string]: { Id: string, Locked: boolean } }
	return if type(data.Pets) == "table" then data.Pets else {}
end

local function equippedSet(data: { [string]: any }): { [string]: boolean }
	local set = {}
	if type(data.EquippedPets) == "table" then
		for _, uid in data.EquippedPets do
			set[uid] = true
		end
	end
	return set
end

local function refreshDetail(data: { [string]: any })
	local pets = ownedPets(data)
	local equipped = equippedSet(data)
	if deleteMode then
		local count = 0
		for _ in toDelete do
			count += 1
		end
		detailName.Text = "DELETE MODE"
		detailRarity.Text = string.format("%d selected", count)
		detailStats.Text = "Tap pets to select them.\nLocked pets can't be deleted."
		equipButton:SetText(string.format("DELETE %d", count))
		equipButton:SetStyle("Red")
		equipButton:SetEnabled(count > 0)
		lockButton:SetText("CANCEL")
		lockButton:SetStyle("Grey")
		lockButton:SetEnabled(true)
		return
	end
	local owned = if selected then pets[selected] else nil
	local def = if owned then Pets.Get(owned.Id) else nil
	if not owned or not def then
		detailName.Text = "Select a pet"
		detailRarity.Text = ""
		detailStats.Text = "Pets multiply your Skill.\nHatch eggs to get more!"
		equipButton:SetText("EQUIP")
		equipButton:SetEnabled(false)
		lockButton:SetText("LOCK")
		lockButton:SetEnabled(false)
		if previewId then
			detailPreview:ClearAllChildren()
			previewId = nil
		end
		return
	end
	detailName.Text = def.Name
	detailRarity.Text = string.upper(def.Rarity)
	detailRarity.TextColor3 = Theme.Rarity(def.Rarity)
	local lines = { Theme.Icons.Skill .. " " .. multiplierText(def) }
	if def.WinsBoost > 0 then
		table.insert(lines, Theme.Icons.Wins .. " +" .. Format.Short(def.WinsBoost * 100) .. "% Wins")
	end
	if def.Exclusive then
		table.insert(lines, Theme.Icons.Star .. " Exclusive")
	end
	detailStats.Text = table.concat(lines, "\n")
	local isEquipped = equipped[selected :: string] == true
	equipButton:SetText(if isEquipped then "UNEQUIP" else "EQUIP")
	equipButton:SetStyle(if isEquipped then "Orange" else "Green")
	equipButton:SetEnabled(true)
	lockButton:SetText(if owned.Locked then "UNLOCK" else "LOCK")
	lockButton:SetStyle(if owned.Locked then "Purple" else "Blue")
	lockButton:SetEnabled(true)
	if previewId ~= owned.Id then
		detailPreview:ClearAllChildren()
		previewId = owned.Id
		Viewport.Model(detailPreview, PetFactory.ForId(owned.Id, 3), { Spin = 0.8, Yaw = math.pi, Pitch = math.rad(-8) })
	end
end

local function refresh()
	local data = StateController.Data
	if data == nil then
		return
	end
	local pets = ownedPets(data)
	local equipped = equippedSet(data)
	local derived = StateController.Derived()

	-- sort: equipped first, then strongest, then rarity, then uid
	local uids = {}
	for uid, owned in pets do
		if Pets.Get(owned.Id) then
			table.insert(uids, uid)
		end
	end
	table.sort(uids, function(a, b)
		local ea, eb = equipped[a] == true, equipped[b] == true
		if ea ~= eb then
			return ea
		end
		local da, db = Pets.Get(pets[a].Id) :: Pets.Pet, Pets.Get(pets[b].Id) :: Pets.Pet
		local sa, sb = petScore(da), petScore(db)
		if sa ~= sb then
			return sa > sb
		end
		if da.Rarity ~= db.Rarity then
			return Rarity.Order(da.Rarity) > Rarity.Order(db.Rarity)
		end
		return a < b
	end)

	local alive: { [string]: boolean } = {}
	local totalBoost = 0
	for i, uid in uids do
		alive[uid] = true
		local owned = pets[uid]
		local def = Pets.Get(owned.Id) :: Pets.Pet
		if equipped[uid] then
			totalBoost += def.SkillBoost
		end
		local slot = slots[uid]
		if not slot then
			local petId = owned.Id
			local thisUid = uid
			slot = ItemSlot.new({
				Parent = grid,
				Name = "Pet_" .. uid,
				Rarity = def.Rarity,
				Build = function()
					return PetFactory.ForId(petId, 2.2)
				end,
				Title = def.Name,
				Stat = multiplierText(def),
				OnClick = function()
					if deleteMode then
						local current = StateController.Data
						local now = if current then ownedPets(current)[thisUid] else nil
						if now and not now.Locked then
							if toDelete[thisUid] then
								toDelete[thisUid] = nil :: any
							else
								toDelete[thisUid] = true
							end
						end
					else
						selected = thisUid
					end
					refresh()
				end,
			})
			slots[uid] = slot
		end
		local s = slot :: ItemSlot.Slot
		s.Instance.LayoutOrder = i
		s:SetCorner(if equipped[uid] then Theme.Icons.Check else nil)
		s:SetTag(if owned.Locked then Theme.Icons.Lock else nil)
		s:SetSelected(if deleteMode then toDelete[uid] == true else selected == uid)
		s:SetDimmed(deleteMode and owned.Locked)
	end
	for uid, slot in slots do
		if not alive[uid] then
			slot:Destroy()
			slots[uid] = nil
			toDelete[uid] = nil
			if selected == uid then
				selected = nil
			end
		end
	end

	local slotsMax = if type(derived.PetSlots) == "number" then derived.PetSlots else Economy.PetSlots
	local equippedCount = if type(data.EquippedPets) == "table" then #data.EquippedPets else 0
	summary.Text = string.format(
		"%s Equipped %d/%d   ·   🎒 Storage %d/%d   ·   %s Pet boost x%s",
		Theme.Icons.Check,
		equippedCount,
		slotsMax,
		#uids,
		Economy.PetInventory,
		Theme.Icons.Skill,
		Format.Short(1 + totalBoost)
	)
	emptyLabel.Visible = #uids == 0
	deleteButton:SetText(if deleteMode then "DONE" else "DELETE")
	equipBestButton:SetEnabled(#uids > 0 and not deleteMode)
	refreshDetail(data)
end

local function onPrimary()
	if deleteMode then
		local list = {}
		for uid in toDelete do
			table.insert(list, uid)
		end
		if #list == 0 then
			return
		end
		task.spawn(function()
			local result = Net.Invoke("RequestPetAction", false, "Delete", list)
			if result.ok then
				toDelete = {}
				deleteMode = false
				refresh()
			end
		end)
		return
	end
	local data = StateController.Data
	local uid = selected
	if not data or not uid then
		return
	end
	local action = if equippedSet(data)[uid] then "Unequip" else "Equip"
	task.spawn(Net.Invoke, "RequestPetAction", false, action, uid)
end

local function onSecondary()
	if deleteMode then
		deleteMode = false
		toDelete = {}
		refresh()
		return
	end
	local data = StateController.Data
	local uid = selected
	if not data or not uid then
		return
	end
	local owned = ownedPets(data)[uid]
	if owned then
		task.spawn(Net.Invoke, "RequestPetAction", false, if owned.Locked then "Unlock" else "Lock", uid)
	end
end

function PetsScreen.Init()
	shell = MenuShell.new({
		Name = "Pets",
		Title = "Pets",
		Icon = Theme.Icons.Pets,
		Size = PANEL,
		Accent = Color3.fromHex("#FFB86B"),
		OnOpen = function()
			deleteMode = false
			toDelete = {}
			refresh()
		end,
		FirstSelection = function()
			return equipBestButton.Instance
		end,
	})
	local content = shell.Content

	local bar: Frame = Create("Frame", {
		Name = "Bar",
		BackgroundColor3 = Theme.Colors.CardDeep,
		Size = UDim2.new(1, 0, 0, BAR_H),
		Parent = content,
	})
	Create.Corner(14, bar)
	summary = Create.Text({
		Name = "Summary",
		Text = "",
		Size = UDim2.new(1, -420, 1, -16),
		Position = UDim2.fromOffset(14, 8),
		Font = Theme.Fonts.Display,
		TextSize = 26,
		Scaled = true,
		XAlign = Enum.TextXAlignment.Left,
		Stroke = 2,
		Parent = bar,
	})
	equipBestButton = Button.new({
		Parent = bar,
		Name = "EquipBest",
		Size = UDim2.fromOffset(200, 60),
		Position = UDim2.new(1, -214, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Style = "Green",
		Text = "EQUIP BEST",
		TextSize = 24,
		OnClick = function()
			task.spawn(Net.Invoke, "RequestPetAction", false, "EquipBest")
		end,
	})
	deleteButton = Button.new({
		Parent = bar,
		Name = "Delete",
		Size = UDim2.fromOffset(190, 60),
		Position = UDim2.new(1, -8, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Style = "Red",
		Text = "DELETE",
		TextSize = 24,
		OnClick = function()
			deleteMode = not deleteMode
			toDelete = {}
			refresh()
		end,
	})

	grid = MenuGrid.new({
		Parent = content,
		Name = "PetGrid",
		Position = UDim2.fromOffset(0, BAR_H + 12),
		Size = UDim2.new(0, GRID_W, 1, -(BAR_H + 12)),
		Cell = Vector2.new(MenuGrid.CellWidth(GRID_W, 5), 176),
	})
	emptyLabel = Create.Text({
		Name = "Empty",
		Text = "No pets yet! Hatch an egg in the hub " .. Theme.Icons.Egg,
		Size = UDim2.new(0, GRID_W, 0, 60),
		Position = UDim2.fromOffset(0, BAR_H + 120),
		Font = Theme.Fonts.Display,
		TextSize = 30,
		Scaled = true,
		Color = Theme.Colors.TextDim,
		Stroke = 2,
		Parent = content,
	})

	detail = Create("Frame", {
		Name = "Detail",
		BackgroundColor3 = Theme.Colors.CardDeep,
		Position = UDim2.new(1, -DETAIL_W, 0, BAR_H + 12),
		Size = UDim2.new(0, DETAIL_W, 1, -(BAR_H + 12)),
		Parent = content,
	})
	Create.Corner(16, detail)
	Create.Stroke(detail, Theme.Colors.PanelEdge, 2, 0.4, true)
	detailPreview = Create("Frame", {
		Name = "Preview",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 10),
		Size = UDim2.new(1, -40, 0, 210),
		Parent = detail,
	})
	detailName = Create.Text({
		Text = "",
		Size = UDim2.new(1, -24, 0, 40),
		Position = UDim2.fromOffset(12, 224),
		Font = Theme.Fonts.Display,
		TextSize = 34,
		Scaled = true,
		Stroke = 2.5,
		Parent = detail,
	})
	detailRarity = Create.Text({
		Text = "",
		Size = UDim2.new(1, -24, 0, 28),
		Position = UDim2.fromOffset(12, 266),
		Font = Theme.Fonts.Display,
		TextSize = 24,
		Scaled = true,
		Stroke = 2,
		Parent = detail,
	})
	detailStats = Create.Text({
		Text = "",
		Size = UDim2.new(1, -24, 0, 100),
		Position = UDim2.fromOffset(12, 300),
		Font = Theme.Fonts.Body,
		TextSize = 24,
		Wrapped = true,
		YAlign = Enum.TextYAlignment.Top,
		Stroke = 1.4,
		Parent = detail,
	})
	equipButton = Button.new({
		Parent = detail,
		Name = "Equip",
		Size = UDim2.new(1, -24, 0, 62),
		Position = UDim2.new(0, 12, 1, -84),
		AnchorPoint = Vector2.new(0, 1),
		Style = "Green",
		Text = "EQUIP",
		TextSize = 26,
		OnClick = onPrimary,
	})
	lockButton = Button.new({
		Parent = detail,
		Name = "Lock",
		Size = UDim2.new(1, -24, 0, 62),
		Position = UDim2.new(0, 12, 1, -12),
		AnchorPoint = Vector2.new(0, 1),
		Style = "Blue",
		Text = "LOCK",
		TextSize = 26,
		OnClick = onSecondary,
	})

	UIController.Register("Pets", shell)
	StateController.DataChanged:Connect(function()
		if shell:IsOpen() then
			refresh()
		end
	end)
	local _ = HEIGHT
end

return PetsScreen
