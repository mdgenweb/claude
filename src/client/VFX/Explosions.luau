--!strict
-- Death explosions (cosmetic, owner's equipped Explosion). Each style is a short composition of
-- pooled primitives from Effects, kept readable and brief so it never hides the next phase.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local CosmeticDefinitions = require(Shared.Definitions.CosmeticDefinitions)

local Effects = require(script.Parent.Effects)

local Explosions = {}

local hex = Color3.fromHex

type Ctx = { pos: Vector3, right: Vector3, up: Vector3, normal: Vector3, colors: { Color3 }, size: number }

local styles: { [string]: (Ctx) -> () } = {
	Burst = function(c)
		Effects.Flash(c.pos, c.size * 2.6, c.colors[1], 0.3)
		Effects.Ring(c.pos, c.normal, c.size * 2.2, c.colors[2] or c.colors[1], 0.4)
		Effects.Sparks(c.pos, c.colors[2] or c.colors[1], 40, 22, 0.9)
		Effects.Smoke(c.pos, c.colors[3] or hex("#3A3A3A"), 8)
		Effects.Debris(c.pos, c.colors, 10, 0.45, 12, 0.8, c.right, c.up)
	end,
	Confetti = function(c)
		Effects.Flash(c.pos, c.size * 1.8, Color3.new(1, 1, 1), 0.2)
		Effects.Debris(c.pos, c.colors, 34, 0.32, 16, 1.4, c.right, c.up)
		Effects.Sparks(c.pos, c.colors[1], 20, 16, 0.5)
	end,
	Bubbles = function(c)
		for i = 1, 9 do
			local p = Effects.Part(Enum.PartType.Ball)
			p.Material = Enum.Material.Glass
			p.Transparency = 0.45
			p.Color = c.colors[(i % #c.colors) + 1]
			p.Size = Vector3.one * 0.3
			local a = i * 0.7
			p.Position = c.pos
			p.Parent = Effects.Folder()
			local target = c.pos + (c.right * math.cos(a) + c.up * math.sin(a)) * (1.5 + (i % 3)) + c.up * 1.2
			local tween = game:GetService("TweenService"):Create(p, TweenInfo.new(0.7 + i * 0.05, Enum.EasingStyle.Quad), { Position = target, Size = Vector3.one * (0.8 + (i % 3) * 0.3) })
			tween:Play()
			task.delay(0.75 + i * 0.05, function()
				Effects.Flash(p.Position, 1.2, Color3.new(1, 1, 1), 0.12)
				p:Destroy()
			end)
		end
	end,
	Pixels = function(c)
		Effects.Flash(c.pos, c.size * 2, c.colors[1], 0.15)
		Effects.Debris(c.pos, c.colors, 24, 0.5, 14, 0.9, c.right, c.up, Enum.PartType.Block)
	end,
	Splash = function(c)
		Effects.Debris(c.pos, c.colors, 18, 0.7, 10, 1.0, c.right, c.up, Enum.PartType.Ball)
		Effects.Ring(c.pos, c.normal, c.size * 2.4, c.colors[1], 0.5, 0.4)
	end,
	Shards = function(c)
		Effects.Flash(c.pos, c.size * 2.2, c.colors[1], 0.2)
		Effects.Debris(c.pos, c.colors, 16, 0.6, 18, 0.7, c.right, c.up, Enum.PartType.Block)
		Effects.Sparks(c.pos, Color3.new(1, 1, 1), 24, 18, 0.4)
	end,
	Nova = function(c)
		Effects.Flash(c.pos, c.size * 5, Color3.new(1, 1, 1), 0.35)
		Effects.Ring(c.pos, c.normal, c.size * 4, c.colors[2] or c.colors[1], 0.5, 0.3)
		Effects.Ring(c.pos, c.normal, c.size * 2.5, c.colors[3] or c.colors[1], 0.35, 0.3)
		Effects.Sparks(c.pos, c.colors[2] or c.colors[1], 50, 26, 0.8)
	end,
	Thunder = function(c)
		Effects.Lightning(c.pos + c.up * 14, c.pos, c.colors[1], 0.35)
		Effects.Lightning(c.pos + c.up * 14 + c.right * 2, c.pos, c.colors[2] or c.colors[1], 0.3)
		Effects.Flash(c.pos, c.size * 3.2, Color3.new(1, 1, 1), 0.25)
		Effects.Sparks(c.pos, c.colors[1], 30, 20, 0.6)
	end,
	Implode = function(c)
		local p = Effects.Part(Enum.PartType.Ball)
		p.Color = c.colors[1]
		p.Material = Enum.Material.Neon
		p.Size = Vector3.one * c.size * 3
		p.Position = c.pos
		p.Transparency = 0.2
		p.Parent = Effects.Folder()
		local tween = game:GetService("TweenService"):Create(p, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Size = Vector3.one * 0.1 })
		tween:Play()
		Effects.Ring(c.pos, c.normal, c.size * 3, c.colors[2] or c.colors[1], 0.45)
		task.delay(0.45, function()
			p:Destroy()
			Effects.Flash(c.pos, c.size * 3, c.colors[3] or c.colors[1], 0.25)
			Effects.Sparks(c.pos, c.colors[2] or c.colors[1], 30, 20, 0.6)
		end)
	end,
}

function Explosions.Play(explosionId: string?, pos: Vector3, station: CFrame, size: number?)
	local def = CosmeticDefinitions.Get("Explosion", explosionId or "classic") or CosmeticDefinitions.Get("Explosion", "classic")
	local colors: { Color3 } = {}
	local hexes: { string } = if def then def.Colors else { "#FFB347", "#FF5E1A" }
	for _, h in hexes do
		table.insert(colors, hex(h))
	end
	local style = styles[if def then def.Style else "Burst"] or styles.Burst
	style({
		pos = pos,
		right = station.RightVector,
		up = station.UpVector,
		normal = -station.LookVector,
		colors = colors,
		size = size or 1.5,
	})
end

return Explosions
