--!strict
-- Client side of the match flow. Reacts to MatchPublic (everyone watching) and MatchPrivate
-- (participants) and drives: camera, HUD swap, selection, aiming, countdown, round-end flyer
-- finisher + heart break, victory banner, results and requeue.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.Game)
local Remotes = require(Shared.Net.Remotes)

local Client = script.Parent.Parent
local UIController = require(script.Parent.UIController)
local CameraController = require(script.Parent.CameraController)
local AimController = require(script.Parent.AimController)
local BattleRenderer = require(script.Parent.BattleRenderer)
local AudioController = require(script.Parent.AudioController)
local HUD = require(Client.UI.Screens.HUD)
local BattleHUD = require(Client.UI.Screens.BattleHUD)
local SelectionScreen = require(Client.UI.Screens.SelectionScreen)
local ResultsScreen = require(Client.UI.Screens.ResultsScreen)
local RevealScreen = require(Client.UI.Screens.RevealScreen)
local Flyers = require(Client.VFX.Flyers)
local Effects = require(Client.VFX.Effects)

local MatchController = {}

local localPlayer = Players.LocalPlayer

local active: { [string]: any }? = nil -- { MatchId, Station, Mode, Summary, Closed }
local lastRoundBanner = 0
local pendingRequeue: string? = nil

local function isParticipant(summary: { [string]: any }): ({ [string]: any }?)
	for _, p in summary.Participants do
		if p.UserId == localPlayer.UserId then
			return p
		end
	end
	return nil
end

local function begin(summary: { [string]: any })
	active = { MatchId = summary.MatchId, Station = summary.Station, Mode = summary.Mode, Summary = summary, Closed = false }
	lastRoundBanner = 0
	UIController.CloseMenus()
	RevealScreen.Hold(true)
	HUD.SetVisible(false)
	BattleHUD.Show(summary)
	local cf, kind = BattleRenderer.StationCFrame(summary.Station)
	if cf and kind then
		CameraController.EnterBattle(cf, kind)
	end
end

local function finish()
	local wasActive = active
	if wasActive == nil then
		return
	end
	wasActive.Closed = true
	active = nil
	AimController.Disable()
	SelectionScreen.Hide()
	BattleHUD.Hide()
	CameraController.ExitBattle()
	HUD.SetVisible(true)
	if not ResultsScreen.IsOpen() then
		RevealScreen.Hold(false)
	end
	local mode = pendingRequeue
	pendingRequeue = nil
	if mode then
		task.delay(0.6, function()
			Remotes.Event("QueueRequest"):FireServer("Play", mode)
		end)
	end
end

-- Where a participant (player or practice bot) is standing.
local function targetPosition(stationIndex: number, userId: number): Vector3?
	local player = Players:GetPlayerByUserId(userId)
	if player and player.Character then
		local root = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			return root.Position + Vector3.new(0, 1, 0)
		end
	end
	if userId < 0 then
		local stations = Workspace:FindFirstChild("Lobby") and Workspace.Lobby:FindFirstChild("Stations")
		if stations then
			for _, model in stations:GetChildren() do
				if model:GetAttribute("StationIndex") == stationIndex then
					local bot = model:FindFirstChild(GameConfig.Bots.Name)
					if bot and bot:IsA("Model") then
						return bot:GetPivot().Position + Vector3.new(0, 1, 0)
					end
				end
			end
		end
	end
	return nil
end

local function playFinisher(payload: { [string]: any })
	local summary = payload.Summary
	local station = summary.Station
	local winners = payload.WinnerBalls or {}
	local losers = payload.LoserUserIds or {}
	if #winners == 0 or #losers == 0 then
		return
	end
	task.delay(0.75, function()
		for i, loserId in losers do
			local ballInfo = winners[((i - 1) % #winners) + 1]
			local anchor = if i <= #winners then BattleRenderer.DetachBall(station, ballInfo.Id) else nil
			local from = if anchor then anchor.Position else nil
			local to = targetPosition(station, loserId)
			if from == nil then
				local cf = BattleRenderer.StationCFrame(station)
				from = if cf then cf.Position else nil
			end
			if from and to then
				AudioController.Play("Whoosh", from)
				Flyers.Play(payload.Flyer, from, to, anchor, function()
					AudioController.Play("HeartBreak", to)
					Effects.Popup(to + Vector3.new(0, 2.5, 0), "-1", Color3.fromHex("#EF2B3C"), 1.6)
					if active and active.MatchId == summary.MatchId then
						BattleHUD.BreakHeart(payload.Loser, summary.Hearts[payload.Loser])
						CameraController.Shake(0.5, 0.3)
					end
				end)
			end
		end
	end)
end

local function onPublic(payload: { [string]: any })
	local summary = payload.Summary
	if summary == nil then
		return
	end
	local me = isParticipant(summary)
	BattleRenderer.SetSummary(summary.Station, summary, me ~= nil)
	local kind = payload.Type

	if kind == "RoundEnd" and not payload.Draw then
		playFinisher(payload)
	end
	if me == nil then
		return
	end
	if active == nil or active.MatchId ~= summary.MatchId then
		if kind == "Closed" then
			return
		end
		begin(summary)
	end
	local a = active :: { [string]: any }
	a.Summary = summary
	if kind ~= "RoundEnd" then
		BattleHUD.Update(summary)
	end

	if kind == "Intro" then
		BattleHUD.Banner(if summary.Practice then "PRACTICE" else "BATTLE!", Color3.new(1, 1, 1), 1.6)
	elseif kind == "Selection" then
		if lastRoundBanner ~= summary.Round then
			lastRoundBanner = summary.Round
			BattleHUD.Banner("ROUND " .. summary.Round, Color3.new(1, 1, 1), 1.2)
		end
		local waiting = 0
		for _, p in summary.Participants do
			if p.UserId ~= localPlayer.UserId and not p.Picked then
				waiting += 1
			end
		end
		SelectionScreen.SetOpponentStatus(if waiting == 0 then "Everyone is ready!" else (if summary.Mode == "2v2" then string.format("%d still choosing...", waiting) else "Opponent is choosing..."))
		BattleHUD.PhaseTimer(nil, nil)
	elseif kind == "Aim" then
		SelectionScreen.Hide()
		BattleHUD.PhaseTimer("AIM", summary.Deadline)
	elseif kind == "Countdown" then
		AimController.Disable()
		BattleHUD.HideAim()
		BattleHUD.PhaseTimer(nil, nil)
		BattleHUD.Countdown(summary.Deadline)
	elseif kind == "Battle" then
		BattleHUD.Overtime(nil)
	elseif kind == "RoundEnd" then
		BattleHUD.Overtime(nil)
		if payload.Draw then
			BattleHUD.Banner("DRAW!", Color3.fromHex("#C9CCD3"), 1.6)
		elseif payload.Winner == me.Team then
			BattleHUD.Banner("ROUND WON", Color3.fromHex("#7CFF6B"), 1.8)
		else
			BattleHUD.Banner("ROUND LOST", Color3.fromHex("#FF5A6A"), 1.8)
		end
	elseif kind == "Victory" then
		local won = payload.WinnerTeam == me.Team
		BattleHUD.Banner(if won then "VICTORY!" else "DEFEAT", if won then Color3.fromHex("#FFC72C") else Color3.fromHex("#FF5A6A"), 3)
	elseif kind == "Closed" then
		finish()
	end
end

local function onPrivate(payload: { [string]: any })
	if payload.Type == "Selection" then
		SelectionScreen.Show(payload)
	elseif payload.Type == "Aim" then
		local cf, kind = BattleRenderer.StationCFrame(payload.Station)
		if cf == nil or kind == nil then
			return
		end
		local defId: string? = nil
		if active then
			local me = isParticipant(active.Summary)
			defId = if me then me.Ball else nil
		end
		AimController.Enable({
			Station = cf,
			Kind = kind,
			X = payload.X,
			Y = payload.Y,
			Radius = payload.Radius,
			DefaultAngle = payload.DefaultAngle,
			Half = payload.Half,
			DefId = defId,
			OnLocked = function()
				BattleHUD.AimLocked()
			end,
		})
		BattleHUD.ShowAim(payload.Deadline, GameConfig.Timings.AimTime, function()
			AimController.Lock()
		end)
	elseif payload.Type == "Results" then
		local mode = if active then active.Mode else "1v1"
		ResultsScreen.Show(payload, mode, function()
			if active == nil then
				RevealScreen.Hold(false)
			end
		end, function(requeueMode: string)
			if active and not active.Closed then
				pendingRequeue = requeueMode
			else
				Remotes.Event("QueueRequest"):FireServer("Play", requeueMode)
			end
		end)
	end
end

function MatchController.InMatch(): boolean
	return active ~= nil
end

function MatchController.Start()
	Remotes.Event("MatchPublic").OnClientEvent:Connect(onPublic)
	Remotes.Event("MatchPrivate").OnClientEvent:Connect(onPrivate)
	BattleRenderer.Overtime:Connect(function(index: number, level: number)
		if active and active.Station == index then
			BattleHUD.Overtime(level)
			if level == 1 then
				BattleHUD.Banner("OVERTIME", Color3.fromHex("#FF5A6A"), 1.4)
			end
		end
	end)
end

return MatchController
