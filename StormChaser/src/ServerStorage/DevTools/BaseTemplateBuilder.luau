--[[
	BaseTemplateBuilder  (ModuleScript)
	Location: ServerStorage > DevTools > BaseTemplateBuilder

	Builds the plot template that BaseService clones into Plot1..Plot8:
		ServerStorage > ServerAssets > BaseTemplate   (Model, rebuilt every run)

	Template is authored around the origin, pivot = origin, front (entrance) = -Z.
	BaseService pivots it to WorldConfig.GetPlots()[i].CFrame, whose LookVector
	points at the Hub, so every entrance faces the plaza.

	Contents (all dimensions derive from WorldConfig.Bases):
		Floor              platform (PrimaryPart)
		ThemeRegion        recolourable inset + accent posts   (attribute ThemeRegion = true)
		CoreRack           tiered rack with 24 "CoreSlot" attachments
		                   (SlotIndex 1..24; Unlocked = SlotIndex <= CoreSlots.Start)
		DefensePads        4 "DefenseSlot" attachments (SlotIndex 1..4)
		Entrance           2 pillars + arch + "LaserGateSlot" attachment (Width, Height attrs)
		Walls              low perimeter wall with an entrance gap
		ClaimSign          SurfaceGui: Headshot (ImageLabel) + OwnerName (TextLabel)
		HubTeleportPad     "TeleportPad" (Destination = "Hub")
		Floor.BaseSpawn    Attachment: where BaseService drops the owner
		BaseZone           invisible volume, tag "BaseZone" (PlotId set by BaseService)

	Run from the Command Bar (Edit mode):
		local m = game.ServerStorage.DevTools.BaseTemplateBuilder:Clone(); m.Parent = game.ServerStorage.DevTools
		local ok, err = pcall(function() require(m).Build() end); m:Destroy(); if not ok then warn(err) end
]]

local ServerStorage = game:GetService("ServerStorage")

local BuildKit = require(script.Parent:WaitForChild("BuildKit"))

local BaseTemplateBuilder = {}

local CREAM = Color3.fromHex("E8D9B5")
local DARK = Color3.fromHex("3A3440")
local BLUE = Color3.fromHex("3FA9F5")
local CYAN = Color3.fromHex("3CF0FF")
local CORAL = Color3.fromHex("FF7A59")
local VIOLET = Color3.fromHex("7B5CFF")

local function attachment(parent: BasePart, name: string, worldCf: CFrame, tag: string?, attrs: { [string]: any }?): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.CFrame = parent.CFrame:ToObjectSpace(worldCf)
	a.Parent = parent
	if tag then
		BuildKit.tag(a, tag, attrs)
	end
	return a
end

function BaseTemplateBuilder.Build()
	local W = BuildKit.config()
	local B = W.Bases
	local size = B.PlotSize
	local hx, hz = size.X / 2, size.Z / 2
	local origin = CFrame.new()

	local assets = BuildKit.ensure(ServerStorage, "ServerAssets")
	local model = BuildKit.reset(assets, "BaseTemplate", "Model") :: Model

	-- FLOOR ------------------------------------------------------------------
	local floor = BuildKit.part({ Name = "Floor", Parent = model, Color = CREAM, Material = Enum.Material.SmoothPlastic,
		Size = Vector3.new(size.X, 1, size.Z), CFrame = origin * CFrame.new(0, 0.5, 0) })
	local floorTop = 1

	-- THEME REGION (Phase 3 recolours everything with ThemeRegion = true) ---------
	local theme = BuildKit.part({ Name = "ThemeRegion", Parent = model, Color = B.ThemeColor, CanQuery = false,
		Size = Vector3.new(size.X - 16, 0.2, size.Z - 16), CFrame = origin * CFrame.new(0, floorTop + 0.1, 0) })
	theme:SetAttribute("ThemeRegion", true)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local post = BuildKit.part({ Name = "ThemeAccent", Parent = model, Color = CORAL, Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(10, 5, 5), CFrame = origin * CFrame.new(sx * (hx - 3), floorTop + 5, sz * (hz - 3)) * CFrame.Angles(0, 0, math.rad(90)) })
			post:SetAttribute("ThemeRegion", true)
		end
	end

	-- WALLS (low, chunky) with a gap for the entrance ----------------------------
	local wallH, gap = 4, 30
	local walls = BuildKit.model("Walls", model)
	local function wall(cx: number, cz: number, sx: number, sz: number)
		BuildKit.part({ Name = "Wall", Parent = walls, Color = CREAM, Size = Vector3.new(sx, wallH, sz),
			CFrame = origin * CFrame.new(cx, floorTop + wallH / 2, cz) })
	end
	wall(0, hz - 1, size.X, 2) -- back
	wall(-hx + 1, 0, 2, size.Z - 4) -- left
	wall(hx - 1, 0, 2, size.Z - 4) -- right
	local frontSeg = (size.X - gap) / 2
	wall(-(gap / 2 + frontSeg / 2), -hz + 1, frontSeg, 2) -- front-left
	wall(gap / 2 + frontSeg / 2, -hz + 1, frontSeg, 2) -- front-right

	-- ENTRANCE + LASER GATE SLOT ---------------------------------------------------
	local entrance = BuildKit.model("Entrance", model)
	local pillarH = 16
	for _, side in { -1, 1 } do
		BuildKit.part({ Name = "Pillar", Parent = entrance, Color = VIOLET, Size = Vector3.new(4, pillarH, 4),
			CFrame = origin * CFrame.new(side * (gap / 2 - 2), floorTop + pillarH / 2, -hz + 1) })
	end
	local arch = BuildKit.part({ Name = "Arch", Parent = entrance, Color = VIOLET, Size = Vector3.new(gap, 3, 4),
		CFrame = origin * CFrame.new(0, floorTop + pillarH + 1.5, -hz + 1) })
	attachment(floor, "LaserGateSlot", origin * CFrame.new(0, floorTop + (pillarH / 2), -hz + 1), "LaserGateSlot",
		{ Width = gap - 8, Height = pillarH })
	entrance.PrimaryPart = arch

	-- STORM CORE RACK (back of plot): tiers of CoreSlot attachments ------------------
	local cs = B.CoreSlots
	local rows = math.ceil(cs.Max / cs.Columns)
	local rack = BuildKit.model("CoreRack", model)
	local rackW = cs.Columns * cs.Spacing + 6
	local rackBackZ = hz - 8
	for row = 1, rows do
		-- each tier is a step higher and further back (stadium seating)
		local tierZ = rackBackZ - (rows - row) * 6
		local tierH = row * 2
		local tier = BuildKit.part({ Name = "Tier" .. row, Parent = rack, Color = DARK, Size = Vector3.new(rackW, tierH, 6),
			CFrame = origin * CFrame.new(0, floorTop + tierH / 2, tierZ) })
		for col = 1, cs.Columns do
			local index = (row - 1) * cs.Columns + col
			if index > cs.Max then
				break
			end
			local x = (col - (cs.Columns + 1) / 2) * cs.Spacing
			local unlocked = index <= cs.Start
			local pedestal = BuildKit.part({ Name = "Pedestal" .. index, Parent = rack, Shape = Enum.PartType.Cylinder,
				Color = if unlocked then CYAN else DARK, Material = if unlocked then Enum.Material.Neon else Enum.Material.SmoothPlastic,
				Transparency = if unlocked then 0 else 0.5, CanCollide = false, CanQuery = false,
				Size = Vector3.new(0.6, 4, 4),
				CFrame = origin * CFrame.new(x, floorTop + tierH + 0.3, tierZ) * CFrame.Angles(0, 0, math.rad(90)) })
			pedestal:SetAttribute("SlotIndex", index)
			-- Slot faces the entrance (-Z, the default LookVector) so cores face visitors
			attachment(tier, "CoreSlot", origin * CFrame.new(x, floorTop + tierH + 0.6, tierZ),
				"CoreSlot", { SlotIndex = index, Unlocked = unlocked })
		end
	end
	local rackSign = BuildKit.part({ Name = "RackSign", Parent = rack, Color = DARK, Size = Vector3.new(rackW * 0.6, 4, 1),
		CFrame = origin * CFrame.new(0, floorTop + rows * 2 + 6, rackBackZ + 2), CanQuery = false })
	BuildKit.sign(rackSign, "STORM CORES", { TextColor = CYAN })

	-- DEFENSE SLOTS (4 pads) ----------------------------------------------------------
	local defense = BuildKit.model("DefensePads", model)
	local defensePositions = {
		Vector3.new(-(hx - 14), 0, -(hz - 16)), Vector3.new(hx - 14, 0, -(hz - 16)),
		Vector3.new(-(hx - 14), 0, 4), Vector3.new(hx - 14, 0, 4),
	}
	for i = 1, B.DefenseSlots do
		local p = defensePositions[(i - 1) % #defensePositions + 1]
		local base = origin * CFrame.new(p.X, floorTop, p.Z) -- faces -Z: toward raiders at the entrance
		local pad = BuildKit.disc({ Name = "DefensePad" .. i, Parent = defense, Color = CORAL }, base, 5, 0.8)
		attachment(pad, "DefenseSlot", base * CFrame.new(0, 0.8, 0), "DefenseSlot", { SlotIndex = i })
	end

	-- CLAIM SIGN (outside, beside the entrance, facing the plaza) -----------------------
	local claim = BuildKit.model("ClaimSign", model)
	local signX = gap / 2 + 12
	BuildKit.part({ Name = "Post", Parent = claim, Color = DARK, Size = Vector3.new(1.5, 12, 1.5),
		CFrame = origin * CFrame.new(signX, floorTop + 6, -hz - 4) })
	local board = BuildKit.part({ Name = "Board", Parent = claim, Color = DARK, Size = Vector3.new(18, 7, 1),
		CFrame = origin * CFrame.new(signX, floorTop + 13, -hz - 4) })
	local gui = Instance.new("SurfaceGui")
	gui.Name = "ClaimGui"
	gui.Face = Enum.NormalId.Front -- local -Z: toward the plaza
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.MaxDistance = 150
	gui.Parent = board
	local headshot = Instance.new("ImageLabel")
	headshot.Name = "Headshot"
	headshot.BackgroundColor3 = BLUE
	headshot.Size = UDim2.fromScale(0.3, 0.86)
	headshot.Position = UDim2.fromScale(0.03, 0.07)
	headshot.Image = ""
	headshot.Parent = gui
	Instance.new("UICorner", headshot).CornerRadius = UDim.new(0.5, 0)
	local ownerName = Instance.new("TextLabel")
	ownerName.Name = "OwnerName"
	ownerName.BackgroundTransparency = 1
	ownerName.Size = UDim2.fromScale(0.62, 0.86)
	ownerName.Position = UDim2.fromScale(0.36, 0.07)
	ownerName.Font = Enum.Font.FredokaOne
	ownerName.TextScaled = true
	ownerName.TextColor3 = Color3.new(1, 1, 1)
	ownerName.Text = "Free Plot!"
	ownerName.Parent = gui
	claim.PrimaryPart = board

	-- TELEPORT PAD back to the Hub (inside, left of the entrance) ------------------------
	local tpBase = origin * CFrame.new(-(gap / 2 + 10), floorTop, -(hz - 12))
	BuildKit.disc({ Name = "HubPadRing", Parent = model, Color = BLUE, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false }, tpBase, 6.5, 0.4)
	local tpPad = BuildKit.disc({ Name = "HubTeleportPad", Parent = model, Color = CREAM, CanTouch = true }, tpBase, 5, 0.7)
	BuildKit.tag(tpPad, "TeleportPad", { Destination = "Hub" })
	BuildKit.billboard(tpPad, "TO HUB", { TextColor = BLUE, Size = UDim2.fromScale(8, 2.5) })

	-- OWNER SPAWN POINT: just inside the entrance, facing the rack (+Z) --------------------
	attachment(floor, "BaseSpawn", origin * CFrame.new(0, floorTop + 3, -(hz - 24)) * CFrame.Angles(0, math.rad(180), 0))

	-- BASE ZONE (raid detection volume) -------------------------------------------------
	local zoneH = 80
	local zone = BuildKit.part({ Name = "BaseZone", Parent = model, Size = Vector3.new(size.X, zoneH, size.Z),
		CFrame = origin * CFrame.new(0, zoneH / 2, 0), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false,
		CastShadow = false })
	BuildKit.tag(zone, "BaseZone", { PlotId = 0 })

	model.PrimaryPart = floor
	model.WorldPivot = origin

	local parts = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	print(("[BaseTemplateBuilder] Built ServerStorage.ServerAssets.BaseTemplate (%d parts, %d CoreSlots, %d DefenseSlots)")
		:format(parts, cs.Max, B.DefenseSlots))
	if parts > W.Budgets.Bases.MaxPartsPerPlot then
		warn("[BaseTemplateBuilder] Over budget: " .. parts .. " > " .. W.Budgets.Bases.MaxPartsPerPlot)
	end
end

return BaseTemplateBuilder
