--!strict
-- "Rewards fly into the counter", the genre's payout feedback: a burst of reward icons pops out
-- around a start point, then each one arcs into a target GuiObject (e.g. the Wins counter). The
-- first arrival calls onArrive (bump the counter); every arrival ticks a coin sound. Icons are
-- pooled Components/Icon objects (3D icon images, emoji until uploaded) in an "FxRewards" frame on
-- the Toasts layer, so the burst also plays above open menus.
local TweenService = game:GetService("TweenService")

local UI = script.Parent.Parent
local Create = require(UI.Create)
local UIController = require(UI.Parent.Controllers.UIController)
local AudioController = require(UI.Parent.Controllers.AudioController)
local Icon = require(script.Parent.Icon)

local RewardFly = {}

local POOL = 12
local SIZE = 54
local POP_TIME = 0.28
local FLY_TIME = 0.5
local STAGGER = 0.05
-- When the first icon lands (counters start rolling up then).
RewardFly.ArriveTime = POP_TIME + FLY_TIME

local POP = TweenInfo.new(POP_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local FLY = TweenInfo.new(FLY_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local pool: { GuiObject } = {}
local free: { GuiObject } = {}
local rng = Random.new()

local holder: Frame? = nil
local function layer(): Frame?
	local current = holder
	if current and current.Parent then
		return current
	end
	local toasts: Frame? = UIController.Layer("Toasts") -- nil until UIController.Init
	if toasts == nil then
		return nil
	end
	local fx: Frame = Create("Frame", {
		Name = "FxRewards",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
		Parent = toasts,
	})
	holder = fx
	return fx
end

-- Centre of a GuiObject in the layer's design pixels.
local function centreOf(gui: GuiObject, root: Frame): Vector2
	local s = math.max(UIController.Scale, 0.01)
	return (gui.AbsolutePosition + gui.AbsoluteSize / 2 - root.AbsolutePosition) / s
end

local function take(root: Frame, icon: string): GuiObject?
	local reused = table.remove(free)
	if reused then
		Icon.Set(reused, icon)
		return reused
	end
	if #pool >= POOL then
		return nil
	end
	local label = Icon.new({
		Icon = icon,
		Name = "RewardIcon",
		Size = UDim2.fromOffset(SIZE, SIZE),
		TextSize = SIZE,
		Parent = root,
	})
	table.insert(pool, label)
	return label
end

-- Flies `count` icons (max 12) from `from` (a GuiObject, or the screen centre) into `to`.
function RewardFly.Burst(icon: string, from: GuiObject?, to: GuiObject, count: number, onArrive: (() -> ())?)
	local root = layer()
	if root == nil or root.AbsoluteSize.X <= 0 then
		if onArrive then
			onArrive()
		end
		return
	end
	local s = math.max(UIController.Scale, 0.01)
	local start = if from and from.Visible then centreOf(from, root) else root.AbsoluteSize / (2 * s)
	local goal = centreOf(to, root)
	local arrived = false
	for i = 1, math.clamp(count, 1, POOL) do
		local label = take(root, icon)
		if label == nil then
			break
		end
		local angle = rng:NextNumber(0, math.pi * 2)
		local spread = Vector2.new(math.cos(angle), math.sin(angle)) * rng:NextNumber(60, 150)
		local burst = start + spread
		label.Rotation = rng:NextNumber(-25, 25)
		label.Size = UDim2.fromOffset(SIZE * 0.4, SIZE * 0.4)
		label.Position = UDim2.fromOffset(start.X, start.Y)
		label.Visible = true
		TweenService:Create(label, POP, { Position = UDim2.fromOffset(burst.X, burst.Y), Size = UDim2.fromOffset(SIZE, SIZE) }):Play()
		task.delay(POP_TIME + (i - 1) * STAGGER, function()
			local fly = TweenService:Create(label, FLY, {
				Position = UDim2.fromOffset(goal.X, goal.Y),
				Size = UDim2.fromOffset(SIZE * 0.6, SIZE * 0.6),
				Rotation = 0,
			})
			fly:Play()
			fly.Completed:Once(function()
				label.Visible = false
				table.insert(free, label)
				AudioController.Play("Coin", nil, 0.04)
				if not arrived then
					arrived = true
					if onArrive then
						onArrive()
					end
				end
			end)
		end)
	end
end

return RewardFly
