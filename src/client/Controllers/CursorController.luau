--!nonstrict
-- Custom cursor (ring + context icon) and live cursors of other players in the same lab.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Potions = require(Shared.Data.Potions)
local PropsData = require(Shared.Data.Props)

local Theme = require(script.Parent.Parent.UI.Theme)

local CursorController = {}

local localPlayer = Players.LocalPlayer
local others = {} :: { [number]: any }

function CursorController:Init(controllers)
	self.C = controllers
end

local function circle(parent: Instance, size: number, z: number): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromOffset(size, size)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.ZIndex = z
	frame.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	return frame
end

local function userColor(userId: number): Color3
	return Color3.fromHSV((userId * 0.618034) % 1, 0.65, 1)
end

function CursorController:_build(overlay: Instance)
	local root = Instance.new("Frame")
	root.Name = "Cursor"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromOffset(48, 48)
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.ZIndex = 500
	root.Interactable = false
	root.Parent = overlay
	local ring = circle(root, 34, 501)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Parent = ring
	local shadow = Instance.new("UIStroke")
	shadow.Thickness = 1
	shadow.Color = Theme.Color.Text.Outline
	shadow.Transparency = 0.3
	local inner = circle(root, 8, 502)
	inner.BackgroundTransparency = 0
	inner.BackgroundColor3 = Color3.new(1, 1, 1)
	shadow.Parent = inner
	local icon = Instance.new("TextLabel")
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromOffset(28, 28)
	icon.Position = UDim2.fromOffset(34, 30)
	icon.FontFace = Theme.Font.UI
	icon.TextSize = 22
	icon.Text = ""
	icon.ZIndex = 503
	icon.Parent = root
	local scale = Instance.new("UIScale")
	scale.Parent = root
	self.root, self.ring, self.stroke, self.inner, self.icon, self.scale = root, ring, stroke, inner, icon, scale
end

function CursorController:Start()
	local overlay = self.C.UIController.overlay
	self:_build(overlay)
	local Input = self.C.InputController
	local State = self.C.State
	local remote = Net.unreliable("Cursor")

	remote.OnClientEvent:Connect(function(list)
		local now = os.clock()
		for _, entry in list do
			local userId, x, y, state, name = entry[1], entry[2], entry[3], entry[4], entry[5]
			if userId ~= localPlayer.UserId then
				local other = others[userId]
				if not other then
					local frame = Instance.new("Frame")
					frame.Name = "RemoteCursor"
					frame.BackgroundTransparency = 1
					frame.Size = UDim2.fromOffset(160, 50)
					frame.AnchorPoint = Vector2.new(0, 0)
					frame.Interactable = false
					frame.ZIndex = 400
					frame.Parent = overlay
					local dot = circle(frame, 22, 401)
					dot.Position = UDim2.fromOffset(0, 0)
					dot.AnchorPoint = Vector2.new(0.5, 0.5)
					local stroke = Instance.new("UIStroke")
					stroke.Thickness = 3
					stroke.Color = userColor(userId)
					stroke.Parent = dot
					local label = Instance.new("TextLabel")
					label.BackgroundColor3 = userColor(userId)
					label.Size = UDim2.fromOffset(0, 22)
					label.AutomaticSize = Enum.AutomaticSize.X
					label.Position = UDim2.fromOffset(14, 10)
					label.FontFace = Theme.Font.UI
					label.TextSize = 14
					label.TextColor3 = Theme.Color.Text.Inverse
					label.Text = "  " .. tostring(name) .. "  "
					label.ZIndex = 402
					label.Parent = frame
					local corner = Instance.new("UICorner")
					corner.CornerRadius = UDim.new(0, 8)
					corner.Parent = label
					other = {
						frame = frame,
						dot = dot,
						world = Vector3.new(x, y, 0),
						smooth = nil,
						seen = now,
						state = state,
					}
					others[userId] = other
				end
				other.world = Vector3.new(x, y, State.lab and State.lab.origin.Z or 0)
				other.seen = now
				other.state = state
			end
		end
	end)
	State.LabChanged:Connect(function(lab, previous)
		if previous and previous.ownerId ~= lab.ownerId then
			for userId, other in others do
				other.frame:Destroy()
				others[userId] = nil
			end
		end
	end)

	local sendTimer = 0
	RunService.RenderStepped:Connect(function(dt)
		local device = Input.device
		local showCustom = device ~= "touch" and not State.photoMode
		UserInputService.MouseIconEnabled = device == "touch"
		self.root.Visible = showCustom
		local pointer = Input.pointer
		self.root.Position = UDim2.fromOffset(pointer.X, pointer.Y)

		-- Context state.
		local Grab = self.C.GrabController
		local selection = State.selected
		local icon, color, size = "", Color3.new(1, 1, 1), 1
		if Grab.grabbing then
			icon, color, size = "✊", Theme.Color.Accent.Gold, 0.8
			self.inner.BackgroundColor3 = Theme.Color.Accent.Gold
		elseif Grab.hoverModel then
			icon, color, size = "✋", Theme.Color.Accent.Gold, 1.25
			self.inner.BackgroundColor3 = Color3.new(1, 1, 1)
		elseif selection then
			if selection.kind == "potion" then
				local potion = Potions.ById[selection.id]
				icon = if State.mode == "feed" then "🥄" else "🧪"
				color = if potion then potion.color else color
			elseif selection.kind == "golem" then
				icon = "🗿"
				color = Theme.Color.Accent.Cyan
			else
				local prop = PropsData.ById[selection.id]
				icon = if prop then prop.icon else "📦"
				color = Theme.Color.Accent.Cyan
			end
			self.inner.BackgroundColor3 = color
		else
			self.inner.BackgroundColor3 = Color3.new(1, 1, 1)
		end
		self.icon.Text = icon
		self.stroke.Color = color
		self.scale.Scale += (size - self.scale.Scale) * math.min(1, dt * 18)

		-- Remote cursors.
		local camera = Workspace.CurrentCamera
		local now = os.clock()
		for userId, other in others do
			if now - other.seen > 2 then
				other.frame:Destroy()
				others[userId] = nil
				continue
			end
			local screen, onScreen = camera:WorldToViewportPoint(other.world)
			local target = Vector2.new(screen.X, screen.Y)
			other.smooth = if other.smooth then other.smooth:Lerp(target, math.min(1, dt * 14)) else target
			other.frame.Visible = onScreen and not State.photoMode
			other.frame.Position = UDim2.fromOffset(other.smooth.X, other.smooth.Y)
			other.dot.BackgroundTransparency = if other.state == "grab" then 0.2 else 1
		end

		-- Stream own cursor (~12 Hz) while others are around.
		sendTimer -= dt
		if sendTimer <= 0 and State.lab and #State.lab.visitors > 1 then
			sendTimer = 1 / 12
			local plane = self.C.CameraController:ScreenToPlane(pointer)
			if plane then
				remote:FireServer(plane.X, plane.Y, if Grab.grabbing then "grab" else "")
			end
		end
	end)
end

return CursorController
