--!nonstrict
-- Using the selected item: right-click (mouse), tap empty space (touch) or X (gamepad) throws or
-- feeds the selected potion, or places the selected golem/prop at the pointer.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Potions = require(Shared.Data.Potions)
local Signal = require(Shared.Util.Signal)

local ToolController = {
	Used = Signal.new(), -- (selection)
	lastUse = 0,
}

function ToolController:Init(controllers)
	self.C = controllers
end

function ToolController:Start()
	local Input = self.C.InputController
	local State = self.C.State
	Input.PointerDown:Connect(function(button, position)
		if button == "secondary" then
			self:Use(position)
		end
	end)
	Input.Tap:Connect(function(position)
		if not self.C.GrabController.lastPressConsumed then
			self:Use(position)
		end
	end)
	Input.Action:Connect(function(action)
		if action == "mode" then
			State:SetMode(if State.mode == "throw" then "feed" else "throw")
			self.C.SoundController:Play("click", nil, { pitch = if State.mode == "feed" then 0.8 else 1.2 })
		elseif action == "deselect" then
			State:Select(nil)
		end
	end)
end

function ToolController:Use(position: Vector2)
	local State = self.C.State
	local selection = State.selected
	if not selection or State.photoMode or not State.lab then
		return
	end
	local now = os.clock()
	if now - self.lastUse < Config.Potions.ThrowCooldown then
		return
	end
	local point = self.C.CameraController:ScreenToPlane(position)
	if not point then
		return
	end
	self.lastUse = now
	if selection.kind == "potion" then
		local potion = Potions.ById[selection.id]
		local count = State:PotionCount(selection.id)
		if not potion or count == 0 then
			self.C.SoundController:Play("error")
			self.C.UIController:Toast(
				"Out of " .. (if potion then potion.name else "that potion") .. "! Brew more at the cauldron.",
				"error"
			)
			return
		end
		local target = nil
		if State.mode == "feed" then
			local part, model = self.C.GrabController:Pick(position)
			if part and model and model:GetAttribute("GolemId") then
				target = part
			end
		end
		Net.event("Use"):FireServer({
			kind = "potion",
			id = selection.id,
			mode = State.mode,
			x = point.X,
			y = point.Y,
			target = target,
		})
		self.C.VFXController.Ring(point, 2.5, potion.color, 0.25)
	else
		Net.event("Use"):FireServer({ kind = selection.kind, id = selection.id, x = point.X, y = point.Y })
		self.C.SoundController:Play("spawn", point)
	end
	self.Used:Fire(selection)
end

return ToolController
