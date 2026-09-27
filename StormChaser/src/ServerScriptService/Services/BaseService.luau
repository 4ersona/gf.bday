--[[
	BaseService  (ModuleScript)
	Location: ServerScriptService > Services > BaseService

	Owns the 8 base plots.
	  * Init():  clones ServerStorage.ServerAssets.BaseTemplate into
	             Workspace.Bases.Plot1..Plot8 at WorldConfig.GetPlots() CFrames.
	  * Start(): assigns a free plot on PlayerAdded, releases it on PlayerRemoving.

	Attributes written
	  Workspace.Bases.PlotN      PlotId (number), OwnerUserId (number, 0 = free), OwnerName (string)
	  PlotN.Base.BaseZone        PlotId (tag "BaseZone")
	  Player                     PlotId (number, 0 = none)

	Public API (for Phase 3)
	  BaseService.GetPlot(player) -> Model?          the PlotN container
	  BaseService.GetPlotById(plotId) -> Model?
	  BaseService.GetOwnerUserId(plotId) -> number
	  BaseService.GetBaseSpawnCFrame(player) -> CFrame?
	  BaseService.GetCoreSlots(plotId) -> {Attachment}   sorted by SlotIndex
	  BaseService.GetDefenseSlots(plotId) -> {Attachment}
	  BaseService.SetUnlockedCoreSlots(plotId, count)    expand rack 8 -> 24
	  BaseService.IsInsideBase(plotId, position) -> boolean
	  BaseService.PlotAssigned  (BindableEvent) Fire(player, plotModel)
	  BaseService.PlotReleased  (BindableEvent) Fire(userId, plotModel)

	Loaded by ServerScriptService > ServicesLoader (Init on all, then Start).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local WorldConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("WorldConfig"))

local BaseService = {}

BaseService.PlotAssigned = Instance.new("BindableEvent")
BaseService.PlotReleased = Instance.new("BindableEvent")

type PlotRecord = {
	Id: number,
	Container: Model,
	Base: Model,
	OwnerUserId: number,
}

local plots: { PlotRecord } = {}
local plotByUserId: { [number]: PlotRecord } = {}

local UNLOCKED_COLOR = Color3.fromHex("3CF0FF")
local LOCKED_COLOR = Color3.fromHex("3A3440")

--------------------------------------------------------------------------------
-- INTERNAL
--------------------------------------------------------------------------------
local function getOrCreateContainer(parent: Instance, name: string): Model
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Model") then
		return existing
	end
	-- The convention says PlotN exists; if it is a Folder (or missing) replace it
	-- with a Model so it can be pivoted/streamed as a unit.
	local model = Instance.new("Model")
	model.Name = name
	if existing then
		for _, child in existing:GetChildren() do
			child.Parent = model
		end
		existing:Destroy()
	end
	model.Parent = parent
	return model
end

local function findDescendant(root: Instance, name: string): Instance?
	return root:FindFirstChild(name, true)
end

local function setSign(record: PlotRecord, name: string, userId: number)
	local gui = findDescendant(record.Base, "ClaimGui")
	if not gui then
		return
	end
	local label = gui:FindFirstChild("OwnerName") :: TextLabel?
	local headshot = gui:FindFirstChild("Headshot") :: ImageLabel?
	if label then
		label.Text = if userId ~= 0 then name .. "'s Base" else "Free Plot!"
	end
	if headshot then
		headshot.Image = ""
		if userId ~= 0 then
			-- Thumbnail fetch yields and can fail; never block plot assignment on it.
			task.spawn(function()
				local ok, image = pcall(function()
					return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
				end)
				-- Only apply if the plot still belongs to this user.
				if ok and record.OwnerUserId == userId then
					headshot.Image = image
				end
			end)
		end
	end
end

local function setOwner(record: PlotRecord, player: Player?)
	local userId = if player then player.UserId else 0
	local name = if player then player.DisplayName else ""
	record.OwnerUserId = userId
	record.Container:SetAttribute("OwnerUserId", userId)
	record.Container:SetAttribute("OwnerName", name)
	setSign(record, name, userId)
end

--------------------------------------------------------------------------------
-- LIFECYCLE
--------------------------------------------------------------------------------
function BaseService.Init()
	local template = ServerStorage:WaitForChild("ServerAssets"):WaitForChild("BaseTemplate") :: Model
	local basesFolder = Workspace:WaitForChild("Bases")

	for _, plot in WorldConfig.GetPlots() do
		local container = getOrCreateContainer(basesFolder, plot.Name)
		-- Idempotent: drop any previous clone (e.g. left in the place file)
		local old = container:FindFirstChild("Base")
		if old then
			old:Destroy()
		end

		local base = template:Clone()
		base.Name = "Base"
		base:PivotTo(plot.CFrame)
		-- A base should stream in as one piece so CoreSlots/defenses are never half-loaded.
		base.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		base.Parent = container

		container:SetAttribute("PlotId", plot.Id)
		local zone = findDescendant(base, "BaseZone")
		if zone then
			zone:SetAttribute("PlotId", plot.Id)
		end

		local record: PlotRecord = { Id = plot.Id, Container = container, Base = base, OwnerUserId = 0 }
		plots[plot.Id] = record
		setOwner(record, nil)
	end
	print(("[BaseService] %d plots ready"):format(#plots))
end

local function assign(player: Player)
	if plotByUserId[player.UserId] then
		return
	end
	for _, record in plots do
		if record.OwnerUserId == 0 then
			setOwner(record, player)
			plotByUserId[player.UserId] = record
			player:SetAttribute("PlotId", record.Id)
			BaseService.PlotAssigned:Fire(player, record.Container)
			return
		end
	end
	-- More players than plots: set the place's Max Players to 8 (Game Settings).
	player:SetAttribute("PlotId", 0)
	warn(("[BaseService] No free plot for %s (server has more than %d players?)"):format(player.Name, #plots))
end

local function release(player: Player)
	local record = plotByUserId[player.UserId]
	if not record then
		return
	end
	plotByUserId[player.UserId] = nil
	setOwner(record, nil)
	BaseService.SetUnlockedCoreSlots(record.Id, WorldConfig.Bases.CoreSlots.Start)
	BaseService.PlotReleased:Fire(player.UserId, record.Container)
end

function BaseService.Start()
	Players.PlayerAdded:Connect(assign)
	Players.PlayerRemoving:Connect(release)
	for _, player in Players:GetPlayers() do
		assign(player)
	end
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------
function BaseService.GetPlot(player: Player): Model?
	local record = plotByUserId[player.UserId]
	return record and record.Container
end

function BaseService.GetPlotById(plotId: number): Model?
	local record = plots[plotId]
	return record and record.Container
end

function BaseService.GetOwnerUserId(plotId: number): number
	local record = plots[plotId]
	return if record then record.OwnerUserId else 0
end

function BaseService.GetBaseSpawnCFrame(player: Player): CFrame?
	local record = plotByUserId[player.UserId]
	if not record then
		return nil
	end
	local spawn = findDescendant(record.Base, "BaseSpawn") :: Attachment?
	return spawn and spawn.WorldCFrame
end

local function slotsByTag(plotId: number, tag: string): { Attachment }
	local record = plots[plotId]
	local list = {}
	if not record then
		return list
	end
	for _, inst in CollectionService:GetTagged(tag) do
		if inst:IsDescendantOf(record.Base) then
			table.insert(list, inst)
		end
	end
	table.sort(list, function(a, b)
		return (a:GetAttribute("SlotIndex") or 0) < (b:GetAttribute("SlotIndex") or 0)
	end)
	return list
end

function BaseService.GetCoreSlots(plotId: number): { Attachment }
	return slotsByTag(plotId, "CoreSlot")
end

function BaseService.GetDefenseSlots(plotId: number): { Attachment }
	return slotsByTag(plotId, "DefenseSlot")
end

-- Unlocks the first `count` CoreSlots (clamped to Start..Max) and lights their pedestals.
function BaseService.SetUnlockedCoreSlots(plotId: number, count: number)
	local record = plots[plotId]
	if not record then
		return
	end
	local cs = WorldConfig.Bases.CoreSlots
	count = math.clamp(count, cs.Start, cs.Max)
	for _, slot in BaseService.GetCoreSlots(plotId) do
		local index = slot:GetAttribute("SlotIndex")
		local unlocked = index <= count
		slot:SetAttribute("Unlocked", unlocked)
		local pedestal = findDescendant(record.Base, "Pedestal" .. index) :: BasePart?
		if pedestal then
			pedestal.Color = if unlocked then UNLOCKED_COLOR else LOCKED_COLOR
			pedestal.Material = if unlocked then Enum.Material.Neon else Enum.Material.SmoothPlastic
			pedestal.Transparency = if unlocked then 0 else 0.5
		end
	end
	record.Container:SetAttribute("UnlockedCoreSlots", count)
end

-- Point-in-box test against the plot's BaseZone (for raid detection).
function BaseService.IsInsideBase(plotId: number, position: Vector3): boolean
	local record = plots[plotId]
	local zone = record and findDescendant(record.Base, "BaseZone") :: BasePart?
	if not zone then
		return false
	end
	local rel = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z
end

return BaseService
