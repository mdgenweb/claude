--!nonstrict
-- Client-side store: the player's profile (replicated by DataService), the lab being viewed,
-- the active trial and pass ownership. UI and controllers subscribe to its signals.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Potions = require(Shared.Data.Potions)

local State = {
	data = nil :: any,
	lab = nil :: any,
	trial = nil :: any,
	passes = {} :: { [string]: boolean },
	ready = false,
	Ready = Signal.new(),
	Changed = Signal.new(), -- (key)
	LabChanged = Signal.new(), -- (state, previous)
	TrialChanged = Signal.new(), -- (phase, payload)
	Notified = Signal.new(), -- (kind, payload)
	selected = nil :: any, -- {kind, id}
	SelectionChanged = Signal.new(),
	mode = "throw",
	ModeChanged = Signal.new(),
	photoMode = false,
	PhotoModeChanged = Signal.new(),
}

function State:Init()
	Net.event("Data").OnClientEvent:Connect(function(kind, payload)
		if kind == "init" then
			self.data = payload
			if not self.ready then
				self.ready = true
				self.Ready:Fire()
			end
			self.Changed:Fire("*")
		elseif kind == "patch" and self.data then
			for key, value in payload do
				self.data[key] = value
				self.Changed:Fire(key)
			end
		end
	end)
	Net.event("Lab").OnClientEvent:Connect(function(labState)
		local previous = self.lab
		self.lab = labState
		self.LabChanged:Fire(labState, previous)
	end)
	Net.event("Trial").OnClientEvent:Connect(function(phase, payload)
		if phase == "start" then
			self.trial = payload
			self.trial.progress = 0
			self.trial.startedAt = os.clock()
		elseif phase == "progress" and self.trial then
			self.trial.progress = payload.progress
		elseif phase == "potions" and self.trial then
			self.trial.potions = payload.potions
		elseif phase == "end" then
			self.trial = nil
		end
		self.TrialChanged:Fire(phase, payload)
	end)
	Net.event("Notify").OnClientEvent:Connect(function(kind, payload)
		if kind == "passes" then
			self.passes = payload or {}
			self.Changed:Fire("passes")
		end
		self.Notified:Fire(kind, payload)
	end)
end

-- ─────────────────────────────── helpers ───────────────────────────────

function State:LabModel(): Model?
	local lab = self.lab
	if not lab then
		return nil
	end
	local labs = workspace:FindFirstChild("Labs")
	return labs and labs:FindFirstChild("Lab_" .. lab.ownerId) :: Model?
end

function State:IsMastered(potionId: string): boolean
	local data = self.data
	return data ~= nil and (data.brewCount[potionId] or 0) >= Config.Potions.MasteryBrews
end

-- Returns count (or -1 for infinite) of a potion usable right now (respects trials).
function State:PotionCount(potionId: string): number
	if self.trial and self.trial.potions and self.lab and self.lab.isOwner then
		for _, entry in self.trial.potions do
			if entry.id == potionId then
				return entry.count
			end
		end
		return 0
	end
	if self:IsMastered(potionId) then
		return -1
	end
	return (self.data and self.data.potions[potionId]) or 0
end

-- Potions shown on the hotbar: trial potions during a trial, else owned/mastered potions.
function State:HotbarPotions(): { string }
	local list = {}
	if self.trial and self.trial.potions and self.lab and self.lab.isOwner then
		for _, entry in self.trial.potions do
			table.insert(list, entry.id)
		end
		return list
	end
	if not self.data then
		return list
	end
	for _, potion in Potions.List do
		if self:PotionCount(potion.id) ~= 0 then
			table.insert(list, potion.id)
		end
	end
	return list
end

function State:Select(selection)
	self.selected = selection
	self.SelectionChanged:Fire(selection)
end

function State:SetMode(mode: string)
	self.mode = mode
	self.ModeChanged:Fire(mode)
end

function State:TimeScale(): number
	local lab = self.lab
	if not lab then
		return 1
	end
	if lab.paused then
		return 0
	end
	return lab.timeScale or 1
end

return State
