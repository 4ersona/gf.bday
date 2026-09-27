--[[
	HubGenerator  (ModuleScript)
	Location: ServerStorage > DevTools > HubGenerator

	Builds the Hub from parts (placeholder art you can later swap for meshes).
	Every position comes from WorldConfig.Biomes.Hub.Layout.

	Output (owned & rebuilt on every run => idempotent):
		Workspace > Map > Hub > Generated
			Spawn            SpawnLocation + decorative ring
			Shop_<Name> x4   building, coloured roof, big sign, NPC ("ShopNPC")
			SellPad          glowing ring pad                  ("SellPad")
			Leaderboard_<Stat> x3 board w/ SurfaceGui list     ("Leaderboard", Stat)
			RebirthAltar     stepped altar + crystal           ("RebirthAltar")
			EventBoard       board w/ SurfaceGui               ("EventBoard")
			DailyChest       chest + prompt                    ("DailyChest")
			BaseTeleportPad  pad to the player's base          ("TeleportPad", Destination="Base")

	Run from the Command Bar (Edit mode):
		local m = game.ServerStorage.DevTools.HubGenerator:Clone(); m.Parent = game.ServerStorage.DevTools
		local ok, err = pcall(function() require(m).Build() end); m:Destroy(); if not ok then warn(err) end

	Phase 3 contract (what gameplay code can rely on):
		* ShopNPC model: attribute Shop = "Upgrades"|"Pets"|"Vehicles"|"Cosmetics";
		  its ProximityPrompt is at <model>.Body.Prompt
		* SellPad part: CanTouch = true; touch to sell
		* RebirthAltar model: prompt at <model>.Top.Prompt
		* DailyChest model: prompt at <model>.Base.Prompt; lid part = <model>.Lid
		* Leaderboard model: attribute Stat; rows go in <model>.Board.BoardGui.List
		* EventBoard model: text in <model>.Board.BoardGui.Status
]]

local Workspace = game:GetService("Workspace")

local BuildKit = require(script.Parent:WaitForChild("BuildKit"))

local HubGenerator = {}

-- Palette (Phase 1, Hub): green, cream, blue, coral + neutrals
local CREAM = Color3.fromHex("E8D9B5")
local GREEN = Color3.fromHex("7BD35A")
local BLUE = Color3.fromHex("3FA9F5")
local CORAL = Color3.fromHex("FF7A59")
local PINK = Color3.fromHex("FF5CE1")
local WOOD = Color3.fromHex("A8743F")
local DARK = Color3.fromHex("3A3440")

local function woodPart(props)
	props.Material = Enum.Material.Wood
	props.MaterialVariant = "StormPlainsWood"
	props.Color = props.Color or WOOD
	return BuildKit.part(props)
end

--------------------------------------------------------------------------------
-- PLACEMENT
--------------------------------------------------------------------------------
-- CFrame at a Hub-local point on the ground, facing the plaza centre
-- (LookVector / local -Z = "front").
local function placeFacingCentre(W, localPos: Vector2): CFrame
	local hub = W.Biomes.Hub
	local world = W.ToWorld("Hub", localPos)
	local y = BuildKit.groundY(world.X, world.Y, hub.Center.Y)
	local pos = Vector3.new(world.X, y, world.Y)
	local centre = Vector3.new(hub.Center.X, y, hub.Center.Z)
	if (pos - centre).Magnitude < 1 then
		return CFrame.new(pos)
	end
	return CFrame.lookAt(pos, centre)
end

--------------------------------------------------------------------------------
-- PIECES
--------------------------------------------------------------------------------
local function buildSpawn(W, parent)
	local L = W.Biomes.Hub.Layout
	local cf = placeFacingCentre(W, L.Spawn)
	local m = BuildKit.model("Spawn", parent)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0 -- no forcefield bubble (friendlier look)
	spawn.Size = Vector3.new(L.SpawnRadius * 1.2, 1, L.SpawnRadius * 1.2)
	spawn.CFrame = cf * CFrame.new(0, 0.5, 0)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Color = CREAM
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.CastShadow = false
	spawn.Parent = m
	-- Remove the default decal texture for a clean stylised look
	for _, d in spawn:GetChildren() do
		if d:IsA("Decal") then
			d:Destroy()
		end
	end

	BuildKit.disc({ Name = "Ring", Parent = m, Color = BLUE, Material = Enum.Material.Neon, CanCollide = false }, cf, L.SpawnRadius, 0.4)
	BuildKit.disc({ Name = "RingInner", Parent = m, Color = CREAM, CanCollide = false }, cf, L.SpawnRadius - 2, 0.5)
	m.PrimaryPart = spawn
	return m
end

local function buildShop(W, parent, shopDef)
	local L = W.Biomes.Hub.Layout
	local width, depth = L.ShopFootprint.X, L.ShopFootprint.Y
	local cf = placeFacingCentre(W, shopDef.Pos)
	local m = BuildKit.model("Shop_" .. shopDef.Shop, parent)
	m:SetAttribute("Shop", shopDef.Shop)
	local wallH = 14

	local floor = BuildKit.part({ Name = "Floor", Parent = m, Color = CREAM, Size = Vector3.new(width, 1, depth),
		CFrame = cf * CFrame.new(0, 0.5, 0) })
	-- Back and side walls (front is open toward the plaza)
	BuildKit.part({ Name = "WallBack", Parent = m, Color = CREAM, Size = Vector3.new(width, wallH, 2),
		CFrame = cf * CFrame.new(0, 1 + wallH / 2, depth / 2 - 1) })
	for _, side in { -1, 1 } do
		BuildKit.part({ Name = "WallSide", Parent = m, Color = CREAM, Size = Vector3.new(2, wallH, depth),
			CFrame = cf * CFrame.new(side * (width / 2 - 1), 1 + wallH / 2, 0) })
		-- chunky rounded corner pillars
		BuildKit.part({ Name = "Pillar", Parent = m, Color = shopDef.Roof, Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(wallH + 2, 4, 4),
			CFrame = cf * CFrame.new(side * (width / 2 - 1), 1 + (wallH + 2) / 2, -depth / 2 + 1) * CFrame.Angles(0, 0, math.rad(90)) })
	end
	-- Two stepped slabs = a chunky, readable roof in the shop's colour
	BuildKit.part({ Name = "Roof", Parent = m, Color = shopDef.Roof, Size = Vector3.new(width + 6, 3, depth + 6),
		CFrame = cf * CFrame.new(0, 1 + wallH + 1.5, 0) })
	BuildKit.part({ Name = "RoofTop", Parent = m, Color = shopDef.Roof, Size = Vector3.new(width - 6, 3, depth - 6),
		CFrame = cf * CFrame.new(0, 1 + wallH + 4.5, 0) })
	-- Awning over the open front
	BuildKit.part({ Name = "Awning", Parent = m, Color = CREAM, Size = Vector3.new(width + 2, 1, 7),
		CFrame = cf * CFrame.new(0, 1 + wallH - 1, -depth / 2 - 2.5) * CFrame.Angles(math.rad(-12), 0, 0), CanQuery = false })

	-- Big sign above the roof, readable from across the plaza
	local sign = BuildKit.part({ Name = "Sign", Parent = m, Color = DARK, Size = Vector3.new(width * 0.8, 7, 1),
		CFrame = cf * CFrame.new(0, 1 + wallH + 10, -depth / 2 + 3), CanQuery = false })
	BuildKit.sign(sign, string.upper(shopDef.Shop), { TextColor = shopDef.Roof, StrokeColor = Color3.new(1, 1, 1), StrokeThickness = 2 })
	BuildKit.sign(sign, string.upper(shopDef.Shop), { Face = Enum.NormalId.Back, TextColor = shopDef.Roof, StrokeColor = Color3.new(1, 1, 1), StrokeThickness = 2 })

	-- Counter
	woodPart({ Name = "Counter", Parent = m, Size = Vector3.new(width * 0.6, 4, 3),
		CFrame = cf * CFrame.new(0, 3, -depth / 2 + 9) })

	-- NPC: friendly round shopkeeper (swap for a rig/mesh later)
	local npc = BuildKit.model("ShopNPC", m)
	local body = BuildKit.part({ Name = "Body", Parent = npc, Color = shopDef.Roof, Shape = Enum.PartType.Ball,
		Size = Vector3.new(5, 5, 5), CFrame = cf * CFrame.new(0, 3.5, -depth / 2 + 13) })
	BuildKit.part({ Name = "Head", Parent = npc, Color = CREAM, Shape = Enum.PartType.Ball,
		Size = Vector3.new(4, 4, 4), CFrame = cf * CFrame.new(0, 7.5, -depth / 2 + 13), CanCollide = false })
	for _, side in { -1, 1 } do
		BuildKit.part({ Name = "Eye", Parent = npc, Color = DARK, Shape = Enum.PartType.Ball, CanCollide = false, CanQuery = false,
			Size = Vector3.new(0.7, 0.7, 0.7), CFrame = cf * CFrame.new(side * 0.8, 7.9, -depth / 2 + 11.2) })
	end
	npc.PrimaryPart = body
	BuildKit.tag(npc, "ShopNPC", { Shop = shopDef.Shop })
	BuildKit.prompt(body, W, "Open " .. shopDef.Shop, shopDef.Shop .. " Shop")

	m.PrimaryPart = floor
	return m
end

local function buildSellPad(W, parent)
	local L = W.Biomes.Hub.Layout
	local cf = placeFacingCentre(W, L.SellPad)
	local r = L.SellPadRadius
	local m = BuildKit.model("SellPad", parent)

	-- Glowing ring = slightly larger Neon disc under the pad
	BuildKit.disc({ Name = "GlowRing", Parent = m, Color = GREEN, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false },
		cf, r + 2.5, 0.8)
	local pad = BuildKit.disc({ Name = "Pad", Parent = m, Color = CREAM, CanTouch = true }, cf, r, 1.2)
	BuildKit.tag(pad, "SellPad")
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = GREEN, 18, 1.5, false
	light.Parent = pad
	BuildKit.billboard(pad, "SELL", { TextColor = GREEN, Size = UDim2.fromScale(12, 4), Offset = Vector3.new(0, 7, 0) })
	m.PrimaryPart = pad
	return m
end

-- Shared board builder for leaderboards and the event board.
local function buildBoard(W, parent, name: string, localPos: Vector2, title: string, accent: Color3)
	local cf = placeFacingCentre(W, localPos)
	local m = BuildKit.model(name, parent)
	for _, side in { -1, 1 } do
		woodPart({ Name = "Post", Parent = m, Size = Vector3.new(2, 24, 2), CFrame = cf * CFrame.new(side * 9, 12, 0.5) })
	end
	local board = BuildKit.part({ Name = "Board", Parent = m, Color = DARK, Size = Vector3.new(18, 20, 1),
		CFrame = cf * CFrame.new(0, 14, 0) })
	BuildKit.part({ Name = "Header", Parent = m, Color = accent, Size = Vector3.new(19, 3, 1.4),
		CFrame = cf * CFrame.new(0, 25, 0), CanQuery = false })

	-- SurfaceGui: Title + List (Phase 3 fills List with rows)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Parent = board
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.fromScale(1, 0.15)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.FredokaOne
	titleLabel.TextScaled = true
	titleLabel.TextColor3 = accent
	titleLabel.Text = title
	titleLabel.Parent = gui
	m.PrimaryPart = board
	return m, gui
end

local function buildLeaderboards(W, parent)
	local accents = { BLUE, CORAL, GREEN, PINK }
	for i, lb in W.Biomes.Hub.Layout.Leaderboards do
		local m, gui = buildBoard(W, parent, "Leaderboard_" .. lb.Stat, lb.Pos, "TOP " .. string.upper(lb.Stat), accents[(i - 1) % #accents + 1])
		local list = Instance.new("Frame")
		list.Name = "List"
		list.BackgroundTransparency = 1
		list.Position = UDim2.fromScale(0.05, 0.17)
		list.Size = UDim2.fromScale(0.9, 0.8)
		list.Parent = gui
		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0.01, 0)
		layout.Parent = list
		BuildKit.tag(m, "Leaderboard", { Stat = lb.Stat })
	end
end

local function buildEventBoard(W, parent)
	local m, gui = buildBoard(W, parent, "EventBoard", W.Biomes.Hub.Layout.EventBoard, "STORM EVENTS", CORAL)
	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.Position = UDim2.fromScale(0.05, 0.2)
	status.Size = UDim2.fromScale(0.9, 0.75)
	status.Font = Enum.Font.FredokaOne
	status.TextScaled = true
	status.TextWrapped = true
	status.TextColor3 = Color3.new(1, 1, 1)
	status.Text = "Clear skies... for now!"
	status.Parent = gui
	BuildKit.tag(m, "EventBoard")
end

local function buildRebirthAltar(W, parent)
	local cf = placeFacingCentre(W, W.Biomes.Hub.Layout.RebirthAltar)
	local m = BuildKit.model("RebirthAltar", parent)
	BuildKit.disc({ Name = "Step1", Parent = m, Color = CREAM }, cf, 14, 1.5)
	BuildKit.disc({ Name = "Step2", Parent = m, Color = Color3.fromHex("7B5CFF") }, cf * CFrame.new(0, 1.5, 0), 10, 1.5)
	local top = BuildKit.disc({ Name = "Top", Parent = m, Color = CREAM }, cf * CFrame.new(0, 3, 0), 6, 3)
	local crystal = BuildKit.part({ Name = "Crystal", Parent = m, Color = PINK, Material = Enum.Material.Neon,
		Size = Vector3.new(3.5, 7, 3.5), CanCollide = false, CanQuery = false,
		CFrame = cf * CFrame.new(0, 11, 0) * CFrame.Angles(0, math.rad(45), math.rad(45)) })
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = PINK, 16, 1.5, false
	light.Parent = crystal
	BuildKit.billboard(top, "REBIRTH", { TextColor = PINK, Offset = Vector3.new(0, 14, 0) })
	BuildKit.prompt(top, W, "Rebirth", "Rebirth Altar")
	BuildKit.tag(m, "RebirthAltar")
	m.PrimaryPart = top
end

local function buildDailyChest(W, parent)
	local cf = placeFacingCentre(W, W.Biomes.Hub.Layout.DailyChest)
	local m = BuildKit.model("DailyChest", parent)
	local base = woodPart({ Name = "Base", Parent = m, Color = CORAL, Size = Vector3.new(7, 4, 5), CFrame = cf * CFrame.new(0, 2, 0) })
	-- Rounded lid: a half-buried cylinder reads as a treasure-chest dome
	woodPart({ Name = "Lid", Parent = m, Color = CORAL, Shape = Enum.PartType.Cylinder, Size = Vector3.new(7, 5, 5),
		CFrame = cf * CFrame.new(0, 4, 0) })
	BuildKit.part({ Name = "Trim", Parent = m, Color = CREAM, Size = Vector3.new(7.2, 1, 5.2), CFrame = cf * CFrame.new(0, 3.6, 0), CanQuery = false })
	BuildKit.part({ Name = "Lock", Parent = m, Color = Color3.fromHex("FFB23F"), Material = Enum.Material.Neon,
		Size = Vector3.new(1.4, 1.6, 0.6), CFrame = cf * CFrame.new(0, 3.2, -2.7), CanCollide = false, CanQuery = false })
	BuildKit.billboard(base, "DAILY GIFT", { TextColor = Color3.fromHex("FFB23F"), Offset = Vector3.new(0, 8, 0), Size = UDim2.fromScale(10, 2.5) })
	BuildKit.prompt(base, W, "Claim", "Daily Reward")
	BuildKit.tag(m, "DailyChest")
	m.PrimaryPart = base
end

local function buildBaseTeleportPad(W, parent)
	local cf = placeFacingCentre(W, W.Biomes.Hub.Layout.BaseTeleportPad)
	local m = BuildKit.model("BaseTeleportPad", parent)
	BuildKit.disc({ Name = "GlowRing", Parent = m, Color = BLUE, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false }, cf, 8.5, 0.8)
	local pad = BuildKit.disc({ Name = "Pad", Parent = m, Color = CREAM, CanTouch = true }, cf, 7, 1.2)
	BuildKit.tag(pad, "TeleportPad", { Destination = "Base" })
	BuildKit.billboard(pad, "MY BASE", { TextColor = BLUE })
	m.PrimaryPart = pad
end

--------------------------------------------------------------------------------
-- PUBLIC
--------------------------------------------------------------------------------
function HubGenerator.Build()
	local W = BuildKit.config()
	local map = BuildKit.ensure(Workspace, "Map")
	local hubFolder = BuildKit.ensure(map, "Hub")
	local out = BuildKit.reset(hubFolder, "Generated")

	buildSpawn(W, out)
	for _, shop in W.Biomes.Hub.Layout.Shops do
		buildShop(W, out, shop)
	end
	buildSellPad(W, out)
	buildLeaderboards(W, out)
	buildEventBoard(W, out)
	buildRebirthAltar(W, out)
	buildDailyChest(W, out)
	buildBaseTeleportPad(W, out)

	local parts = 0
	for _, d in out:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	print(("[HubGenerator] Built Hub: %d parts in Workspace.Map.Hub.Generated"):format(parts))
end

function HubGenerator.Clear()
	local map = Workspace:FindFirstChild("Map")
	local hub = map and map:FindFirstChild("Hub")
	local gen = hub and hub:FindFirstChild("Generated")
	if gen then
		gen:Destroy()
	end
	print("[HubGenerator] Cleared.")
end

return HubGenerator
