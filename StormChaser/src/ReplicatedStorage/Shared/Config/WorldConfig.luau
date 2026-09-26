--!strict
--[[
	WorldConfig  (ModuleScript)
	Location: ReplicatedStorage > Shared > Config > WorldConfig

	THE single source of truth for world geometry in STORM CHASER SIMULATOR.
	Every generator, service and client script reads positions/sizes from here.
	No other script may hardcode a world coordinate.

	Coordinate conventions
	----------------------
	* Studs. +X = "east" = progression direction (Hub -> Plains -> ... -> Volcanic).
	* Biome.Center is a Vector3: X/Z = centre of the biome rectangle, Y = the
	  nominal ground height of that biome.
	* Biome.Size is a Vector2 (X extent, Z extent) of the biome rectangle.
	* Anything inside a biome table that is a Vector2 called Pos / Points is in
	  BIOME-LOCAL XZ (relative to Biome.Center). Use WorldConfig.ToWorld() to
	  convert. This means moving a whole biome = editing one Center.
	* Space is a floating biome that sits directly above Volcanic.

	Safe to require from both server and client (pure data + pure functions).
]]

local WorldConfig = {}

--------------------------------------------------------------------------------
-- GLOBAL SETTINGS
--------------------------------------------------------------------------------

WorldConfig.Version = 1

-- Reference speed of the starter vehicle (studs/s). Biomes are 1200 studs long,
-- roads meander ~1350 studs per biome -> ~33-40 s to cross one biome.
WorldConfig.StarterVehicleSpeed = 36

WorldConfig.VoxelSize = 4 -- Terrain resolution (Roblox only supports 4)
WorldConfig.ChunkSize = 64 -- studs per WriteVoxels chunk (XZ)
WorldConfig.TerrainFloorY = -32 -- bottom of all ground terrain (multiple of 4)
WorldConfig.BlendWidth = 80 -- studs either side of a biome border that are blended
WorldConfig.MaxDriveSlopeDeg = 35 -- slope checker flags drivable ground steeper than this
WorldConfig.SteepMaterialSlopeDeg = 32 -- above this, terrain uses the biome's "Steep" material
WorldConfig.WaterLevel = 0 -- Y of the Tropical lagoon/sea surface

-- Whole playable world (ground + sky). Soft walls sit on the XZ edges of this box.
WorldConfig.WorldBounds = {
	Min = Vector3.new(-480, -200, -720),
	Max = Vector3.new(5280, 1100, 720),
}
-- Height of the rising "rim hills" along the north/south world edge (not Tropical,
-- which slopes into the sea instead) and how far in from the edge they start.
WorldConfig.EdgeHills = { Height = 34, Width = 130 }

-- Void catching (Navigation step)
WorldConfig.VoidY = -80 -- below this on the ground layer => respawn in nearest biome
WorldConfig.SpaceFallY = 600 -- falling below this from Space => respawn on nearest island

-- The order the player progresses through the world.
WorldConfig.BiomeOrder = { "Hub", "Plains", "Desert", "Tropical", "Volcanic", "Space" }

--------------------------------------------------------------------------------
-- HELPERS FOR BUILDING THE TABLES BELOW
--------------------------------------------------------------------------------

local M = Enum.Material
local function hex(h: string): Color3
	return Color3.fromHex(h)
end
local function v2(x: number, z: number): Vector2
	return Vector2.new(x, z)
end

--------------------------------------------------------------------------------
-- BIOMES
--------------------------------------------------------------------------------
--[[
	Field reference (per biome)
	  Center        Vector3   world centre (Y = nominal ground height)
	  Size          Vector2   XZ extent of the biome rectangle
	  HeightRange   {Min,Max} expected terrain surface range (used by audits/zones)
	  ZoneY         {Min,Max} vertical extent of the BiomeZone part
	  Priority      number    BiomeZone priority (higher wins on overlap)
	  Seed          number    fixed noise seed => reproducible terrain
	  Materials     table     ONLY the Phase-1 approved materials for this biome.
	                          Keys are "surface tags" the terrain generator emits.
	  Palette       {Color3}  Phase-1 palette
	  Unlock        {Type = "None"|"Energy"|"Rebirths", Amount = number}
	  Gate          {Position: Vector3, Facing: Vector3, Width: number, Height: number}
	                Gate on the WEST border of the biome (where you enter).
	  StormTypes    {string}  storm types allowed in this biome
	  Terrain       table     shape parameters for the procedural generator
	  Features      table     named shape features (biome-local)
	  Landmarks     {Name, Pos, Radius}      reserved footprints (props avoid them)
	  StormZones    {Pos, Size, MaxStorms, Tiers}  3-6 regular spawn zones
	  Supercell     {Pos, Size, Tiers}       the biome's Supercell arena
	  Teleporter    Vector2   pad back to Hub / Base
	  Beacon        Vector2   tall light pillar marking the biome
]]

local Biomes = {}
WorldConfig.Biomes = Biomes

-- HUB ------------------------------------------------------------------------
Biomes.Hub = {
	Name = "Hub",
	Order = 0,
	Center = Vector3.new(0, 0, 0),
	Size = v2(800, 800),
	HeightRange = { Min = 0, Max = 16 },
	ZoneY = { Min = -100, Max = 400 },
	Priority = 5, -- beats Plains in the shared blend strip
	Seed = 1001,
	Materials = {
		Top = M.Grass,
		Plaza = M.Cobblestone,
		Path = M.Cobblestone,
		Fill = M.Cobblestone,
		Steep = M.Grass,
	},
	Palette = { hex("7BD35A"), hex("E8D9B5"), hex("3FA9F5"), hex("FF7A59") },
	Unlock = { Type = "None", Amount = 0 },
	Gate = nil, -- you spawn here
	StormTypes = {},
	Terrain = {
		PlazaRadius = 185, -- perfectly flat within this radius
		CobbleCoreRadius = 70, -- cobblestone centre disc
		CobbleRing = { Inner = 160, Outer = 178 }, -- cobblestone ring road
		OuterHillHeight = 8, -- gentle rise toward the hub edge
		NoiseScale = 140,
	},
	Features = {},
	--[[ Hub layout (Hub-local XZ, Y = ground). Shops face the plaza centre.
	     The east side (z = -40..40, x > 0) stays clear for the main road. ]]
	Layout = {
		Spawn = v2(0, 0),
		SpawnRadius = 18,
		Shops = {
			{ Shop = "Upgrades", Pos = v2(-50, -120), Roof = hex("FF7A59") },
			{ Shop = "Pets", Pos = v2(-120, -50), Roof = hex("7BD35A") },
			{ Shop = "Vehicles", Pos = v2(-120, 55), Roof = hex("3FA9F5") },
			{ Shop = "Cosmetics", Pos = v2(-50, 125), Roof = hex("FF5CE1") },
		},
		ShopFootprint = v2(40, 34),
		SellPad = v2(85, -85),
		SellPadRadius = 16,
		RebirthAltar = v2(-160, 0),
		EventBoard = v2(110, 60),
		DailyChest = v2(35, -50),
		BaseTeleportPad = v2(35, 50),
		Leaderboards = {
			{ Stat = "Energy", Pos = v2(40, 140) },
			{ Stat = "Rebirths", Pos = v2(95, 118) },
			{ Stat = "StormsCaught", Pos = v2(135, 80) },
		},
	},
	Landmarks = {},
	StormZones = {},
	Supercell = nil,
	Teleporter = nil,
	Beacon = v2(0, 0),
}

-- PLAINS ---------------------------------------------------------------------
Biomes.Plains = {
	Name = "Plains",
	Order = 1,
	Center = Vector3.new(1000, 0, 0),
	Size = v2(1200, 1200),
	HeightRange = { Min = 0, Max = 30 },
	ZoneY = { Min = -100, Max = 400 },
	Priority = 1,
	Seed = 2002,
	Materials = {
		Top = M.Grass,
		Path = M.Ground,
		Dirt = M.Ground,
		Fill = M.Ground,
		Steep = M.Ground,
	},
	Palette = { hex("8EDB5A"), hex("C9A36A"), hex("A8743F") },
	Unlock = { Type = "None", Amount = 0 },
	Gate = { Position = Vector3.new(400, 0, 0), Facing = Vector3.xAxis, Width = 60, Height = 40 },
	StormTypes = { "Tornado", "Lightning" },
	Terrain = {
		BaseHeight = 2,
		HillHeight = 26, -- soft rolling hills
		HillScale = 260, -- wavelength (studs) of the main hill octave
		Octaves = 4,
		Gain = 0.42,
		DirtPatchChance = 0.12, -- fraction of ground that becomes noisy dirt patches
	},
	Features = {},
	Landmarks = {
		{ Name = "GiantWindmill", Pos = v2(-250, 330), Radius = 45 },
		{ Name = "RedBarn", Pos = v2(180, 260), Radius = 55 },
		{ Name = "GiantWeatherVane", Pos = v2(420, -330), Radius = 30 },
	},
	StormZones = {
		{ Pos = v2(-430, -320), Size = v2(200, 200), MaxStorms = 2, Tiers = "1,2" },
		{ Pos = v2(-470, 250), Size = v2(180, 180), MaxStorms = 2, Tiers = "1,2" },
		{ Pos = v2(-20, 320), Size = v2(170, 170), MaxStorms = 2, Tiers = "1,2,3" },
		{ Pos = v2(430, 330), Size = v2(200, 200), MaxStorms = 2, Tiers = "2,3" },
	},
	Supercell = { Pos = v2(160, -360), Size = v2(270, 270), Tiers = "3,4" },
	Teleporter = v2(-520, -45),
	Beacon = v2(0, 0),
}

-- DESERT ---------------------------------------------------------------------
Biomes.Desert = {
	Name = "Desert",
	Order = 2,
	Center = Vector3.new(2200, 0, 0),
	Size = v2(1200, 1200),
	HeightRange = { Min = 0, Max = 62 },
	ZoneY = { Min = -100, Max = 400 },
	Priority = 1,
	Seed = 3003,
	Materials = {
		Top = M.Sand,
		Path = M.Salt,
		Basin = M.Salt,
		Rock = M.Sandstone,
		Fill = M.Sandstone,
		Steep = M.Sandstone,
	},
	Palette = { hex("F2CF8A"), hex("D98F5B"), hex("C98A56") },
	Unlock = { Type = "Energy", Amount = 2500 },
	Gate = { Position = Vector3.new(1600, 0, 0), Facing = Vector3.xAxis, Width = 60, Height = 40 },
	StormTypes = { "DustDevil", "Tornado" },
	Terrain = {
		BaseHeight = 3,
		DuneHeight = 30, -- big smooth dunes
		DuneScale = 300, -- dune wavelength
		DuneWarp = 120, -- domain-warp strength (makes dunes curvy, not stripes)
		MesaEdge = 14, -- width of the steep mesa wall
	},
	Features = {
		-- Flat cracked-clay (Salt) basins. Radius = fully flat, Falloff = blend ring.
		Basins = {
			{ Pos = v2(-200, 140), Radius = 170, Falloff = 70, Height = 2 },
			{ Pos = v2(280, -180), Radius = 140, Falloff = 60, Height = 2 },
		},
		-- Sandstone mesas: steep sided (not drivable - flagged NoDrive), flat tops.
		Mesas = {
			{ Pos = v2(-40, -440), Radius = 70, Height = 55 },
			{ Pos = v2(500, 440), Radius = 70, Height = 60 },
			{ Pos = v2(-520, 420), Radius = 60, Height = 50 },
		},
	},
	Landmarks = {
		{ Name = "SandstoneArch", Pos = v2(-440, -330), Radius = 50 },
		{ Name = "GiantCompass", Pos = v2(120, 470), Radius = 40 },
		{ Name = "Oasis", Pos = v2(-330, 330), Radius = 60 },
		{ Name = "FriendlyFossil", Pos = v2(520, -120), Radius = 40 },
	},
	StormZones = {
		{ Pos = v2(-240, -330), Size = v2(180, 180), MaxStorms = 2, Tiers = "1,2,3" },
		{ Pos = v2(130, -260), Size = v2(200, 200), MaxStorms = 2, Tiers = "2,3" },
		{ Pos = v2(-60, 330), Size = v2(200, 200), MaxStorms = 2, Tiers = "1,2,3" },
		{ Pos = v2(330, 290), Size = v2(180, 180), MaxStorms = 2, Tiers = "2,3" },
	},
	Supercell = { Pos = v2(430, -350), Size = v2(240, 240), Tiers = "3,4,5" },
	Teleporter = v2(-520, -40),
	Beacon = v2(0, 0),
}

-- TROPICAL -------------------------------------------------------------------
Biomes.Tropical = {
	Name = "Tropical",
	Order = 3,
	Center = Vector3.new(3400, 0, 0),
	Size = v2(1200, 1200),
	HeightRange = { Min = -6, Max = 16 },
	ZoneY = { Min = -100, Max = 400 },
	Priority = 1,
	Seed = 4004,
	Materials = {
		Top = M.LeafyGrass,
		Path = M.Limestone,
		Beach = M.Limestone,
		Fill = M.Limestone,
		Steep = M.Limestone,
		Water = M.Water,
	},
	Palette = { hex("4FD17A"), hex("F5E6B8"), hex("2EC4D6"), hex("8C5A3C") },
	Unlock = { Type = "Energy", Amount = 25000 },
	Gate = { Position = Vector3.new(2800, 0, 0), Facing = Vector3.xAxis, Width = 60, Height = 40 },
	StormTypes = { "Hurricane", "Lightning" },
	Terrain = {
		BaseHeight = 7, -- grassy interior
		NoiseHeight = 6,
		NoiseScale = 220,
		SeaFloor = -6, -- lagoon / sea bottom (shallow water = cheap water)
		BeachBand = 3, -- ground within this many studs above WaterLevel is beach
		CoastWidth = 140, -- north/south edges slope into the sea over this distance
	},
	Features = {
		-- Shallow lagoons (ellipses). Radius = Vector2 radii in X and Z.
		Lagoons = {
			{ Pos = v2(-150, -340), Radius = v2(240, 140) },
			{ Pos = v2(250, 320), Radius = v2(220, 150) },
		},
	},
	Landmarks = {
		{ Name = "SunkenTemple", Pos = v2(-150, -340), Radius = 60 },
		{ Name = "Lighthouse", Pos = v2(480, -440), Radius = 30 },
		{ Name = "Shipwreck", Pos = v2(60, 470), Radius = 55 },
		{ Name = "BeachHuts", Pos = v2(-500, 420), Radius = 55 },
	},
	StormZones = {
		{ Pos = v2(-500, -250), Size = v2(160, 160), MaxStorms = 2, Tiers = "1,2,3" },
		{ Pos = v2(250, -280), Size = v2(200, 200), MaxStorms = 2, Tiers = "2,3,4" },
		{ Pos = v2(470, -160), Size = v2(140, 140), MaxStorms = 1, Tiers = "2,3" },
	},
	Supercell = { Pos = v2(-240, 300), Size = v2(240, 240), Tiers = "4,5" },
	Teleporter = v2(-520, 50),
	Beacon = v2(0, 0),
}

-- VOLCANIC -------------------------------------------------------------------
Biomes.Volcanic = {
	Name = "Volcanic",
	Order = 4,
	Center = Vector3.new(4600, 0, 0),
	Size = v2(1200, 1200),
	HeightRange = { Min = -3, Max = 116 },
	ZoneY = { Min = -100, Max = 560 },
	Priority = 1,
	Seed = 5005,
	Materials = {
		Top = M.Basalt,
		Rock = M.Basalt,
		Ash = M.Slate,
		Path = M.Slate,
		Lava = M.CrackedLava,
		Fill = M.Basalt,
		Steep = M.Basalt,
	},
	Palette = { hex("3A3440"), hex("7A7480"), hex("FF6A2B"), hex("FFB23F") },
	Unlock = { Type = "Rebirths", Amount = 1 },
	Gate = { Position = Vector3.new(4000, 0, 0), Facing = Vector3.xAxis, Width = 60, Height = 40 },
	StormTypes = { "LavaStorm", "Lightning" },
	Terrain = {
		BaseHeight = 3,
		JaggedHeight = 16, -- ridged basalt (south)
		JaggedScale = 150,
		AshHeight = 3, -- ash plains (north, around the road)
		AshScale = 200,
	},
	Features = {
		Volcano = {
			Pos = v2(60, -300),
			Radius = 300, -- foot of the cone
			Height = 110, -- rim height above base (linear cone => ~26 deg, drivable)
			RimRadius = 70,
			CraterRadius = 50, -- lava lake radius
			CraterDepth = 26, -- lava lake sits this far below the rim
		},
		-- Lava rivers: polylines (biome-local). Carved channels of CrackedLava.
		LavaRivers = {
			{ Width = 26, Depth = 3, Points = { v2(20, -235), v2(-120, -150), v2(-300, -60), v2(-480, -20) } },
			{ Width = 26, Depth = 3, Points = { v2(110, -235), v2(220, -100), v2(260, 60), v2(300, 260), v2(360, 480) } },
		},
	},
	Landmarks = {
		{ Name = "Volcano", Pos = v2(60, -300), Radius = 300 },
		{ Name = "ObsidianSpikes", Pos = v2(-380, -390), Radius = 60 },
		{ Name = "LavaBridge", Pos = v2(290, 203), Radius = 40 },
		{ Name = "ResearchStation", Pos = v2(-420, 400), Radius = 60 },
	},
	StormZones = {
		{ Pos = v2(-180, 340), Size = v2(200, 200), MaxStorms = 2, Tiers = "2,3,4" },
		{ Pos = v2(100, 380), Size = v2(180, 180), MaxStorms = 2, Tiers = "3,4" },
		{ Pos = v2(-440, -200), Size = v2(160, 160), MaxStorms = 2, Tiers = "2,3,4" },
	},
	Supercell = { Pos = v2(460, -300), Size = v2(210, 210), Tiers = "4,5" },
	Teleporter = v2(-520, -30),
	Beacon = v2(0, 0),
	-- The launch pad to Space lives in Volcanic (end of the main road).
	LaunchPad = { Pos = v2(440, 220), Radius = 18 },
}

-- SPACE (floating islands above Volcanic) --------------------------------------
Biomes.Space = {
	Name = "Space",
	Order = 5,
	Floating = true,
	Center = Vector3.new(4600, 720, 0),
	Size = v2(1200, 1200),
	HeightRange = { Min = 640, Max = 760 },
	ZoneY = { Min = 560, Max = 1100 },
	Priority = 10, -- overrides Volcanic in the sky
	Seed = 6006,
	Materials = {
		Top = M.Pavement, -- neon ground
		Rim = M.Glacier,
		Fill = M.Glacier, -- crystal rock
		Steep = M.Glacier,
	},
	Palette = { hex("1B1640"), hex("7B5CFF"), hex("3CF0FF"), hex("FF5CE1") },
	Unlock = { Type = "Rebirths", Amount = 3 },
	-- Space's "gate" is the launch pad; GateService checks Unlock there.
	Gate = nil,
	StormTypes = { "Cosmic" },
	Terrain = {
		TopFlatness = 1.2, -- max bump on island tops (flat for driving)
		EdgeWobble = 0.12, -- radius perturbation fraction
		ThicknessFactor = 0.55, -- underside depth = Radius * this
	},
	Features = {
		-- Islands: Pos (local XZ), Radius, TopOffset (Y relative to Center.Y)
		Islands = {
			{ Pos = v2(260, 180), Radius = 110, TopOffset = 0 }, -- 1 landing island
			{ Pos = v2(40, 300), Radius = 80, TopOffset = 12 }, -- 2
			{ Pos = v2(-190, 400), Radius = 95, TopOffset = 24 }, -- 3
			{ Pos = v2(-420, 220), Radius = 125, TopOffset = 8 }, -- 4 supercell island
			{ Pos = v2(-360, -60), Radius = 85, TopOffset = 20 }, -- 5
			{ Pos = v2(-120, -40), Radius = 100, TopOffset = 4 }, -- 6 hub island
			{ Pos = v2(120, -180), Radius = 90, TopOffset = 16 }, -- 7
			{ Pos = v2(-160, -330), Radius = 80, TopOffset = 30 }, -- 8
			{ Pos = v2(380, -300), Radius = 105, TopOffset = 10 }, -- 9
			{ Pos = v2(-440, -380), Radius = 75, TopOffset = 36 }, -- 10
		},
		-- Glowing bridges (parts) between island indices.
		Bridges = {
			{ 1, 2 }, { 2, 3 }, { 3, 4 }, { 4, 5 }, { 5, 6 }, { 6, 7 },
			{ 7, 9 }, { 6, 8 }, { 8, 10 }, { 2, 6 },
		},
		BridgeWidth = 24,
		BridgeColor = hex("7B5CFF"),
		BridgeRailColor = hex("3CF0FF"),
		LandingIsland = 1,
	},
	Landmarks = {
		{ Name = "CrashedSatellite", Pos = v2(-120, -40), Radius = 35, Island = 6 },
		{ Name = "AntennaTower", Pos = v2(380, -330), Radius = 20, Island = 9 },
		{ Name = "GiantCrystal", Pos = v2(-200, 400), Radius = 30, Island = 3 },
		-- The ringed planet is a sky prop, far outside the playable area.
		{ Name = "RingedPlanet", Pos = v2(900, -900), Radius = 0, SkyHeight = 1400 },
	},
	-- Space zones are circles on island tops (Size = diameter of the square part).
	StormZones = {
		{ Pos = v2(40, 300), Size = v2(100, 100), MaxStorms = 1, Tiers = "3,4,5", Island = 2 },
		{ Pos = v2(-360, -60), Size = v2(100, 100), MaxStorms = 1, Tiers = "3,4,5", Island = 5 },
		{ Pos = v2(120, -180), Size = v2(110, 110), MaxStorms = 1, Tiers = "4,5", Island = 7 },
		{ Pos = v2(-160, -330), Size = v2(100, 100), MaxStorms = 1, Tiers = "4,5", Island = 8 },
	},
	Supercell = { Pos = v2(-420, 220), Size = v2(150, 150), Tiers = "5,6", Island = 4 },
	Teleporter = v2(300, 230), -- on the landing island
	Beacon = v2(260, 180),
}

--------------------------------------------------------------------------------
-- BASES (8 plots in a ring around the Hub)
--------------------------------------------------------------------------------
-- Angles avoid 0 deg (due east) so the main road to Plains passes between plots.
WorldConfig.Bases = {
	Count = 8,
	RingRadius = 300, -- plot centre distance from Hub centre
	AngleOffsetDeg = 22.5,
	PlotSize = Vector3.new(110, 1, 110), -- floor footprint
	FloorY = 0, -- terrain is flattened to this under each plot
	CoreSlots = { Start = 8, Max = 24, Columns = 8, Spacing = 6 },
	DefenseSlots = 4,
	ThemeColor = hex("E8D9B5"),
}

-- Returns the 8 plot descriptors: {Id, Name, Position: Vector3, Angle, CFrame}
-- CFrame looks from the plot toward the Hub centre (entrance faces the plaza).
function WorldConfig.GetPlots(): { any }
	local b = WorldConfig.Bases
	local hub = Biomes.Hub.Center
	local plots = {}
	for i = 1, b.Count do
		local angle = math.rad(b.AngleOffsetDeg + (i - 1) * (360 / b.Count))
		local pos = Vector3.new(
			hub.X + math.cos(angle) * b.RingRadius,
			b.FloorY,
			hub.Z + math.sin(angle) * b.RingRadius
		)
		local lookAt = Vector3.new(hub.X, b.FloorY, hub.Z)
		plots[i] = {
			Id = i,
			Name = "Plot" .. i,
			Position = pos,
			Angle = angle,
			CFrame = CFrame.lookAt(pos, lookAt),
		}
	end
	return plots
end

--------------------------------------------------------------------------------
-- ROADS
--------------------------------------------------------------------------------
-- The main road runs west -> east through every ground biome and ends at the
-- launch pad. Points are WORLD XZ. Material comes from the biome it passes
-- through (Materials.Path). Hub spokes to each plot are added by GetRoads().
WorldConfig.Roads = {
	Width = 28, -- main road width
	SpokeWidth = 18, -- hub spokes to plots
	EdgeBlend = 16, -- terrain blends to road height over this distance
	MainRoad = {
		-- Hub
		v2(178, 0), v2(400, 0),
		-- Plains
		v2(620, 60), v2(860, -40), v2(1100, -120), v2(1340, -20), v2(1600, 0),
		-- Desert
		v2(1820, 90), v2(2060, 140), v2(2300, 40), v2(2560, -60), v2(2800, 0),
		-- Tropical
		v2(3020, -80), v2(3260, -120), v2(3500, -40), v2(3760, 60), v2(4000, 0),
		-- Volcanic -> launch pad
		v2(4220, 110), v2(4480, 170), v2(4740, 180), v2(5040, 220),
	},
}

-- Returns every road as {Name, Width, Points = {Vector2 world}}.
function WorldConfig.GetRoads(): { any }
	local r = WorldConfig.Roads
	local roads = {
		{ Name = "MainRoad", Width = r.Width, Points = r.MainRoad },
	}
	local hub = Biomes.Hub
	local ringInner = hub.Terrain.CobbleRing.Inner
	for _, plot in WorldConfig.GetPlots() do
		local dir = Vector2.new(plot.Position.X - hub.Center.X, plot.Position.Z - hub.Center.Z).Unit
		local c = Vector2.new(hub.Center.X, hub.Center.Z)
		local plotHalf = WorldConfig.Bases.PlotSize.X / 2
		table.insert(roads, {
			Name = "Spoke_" .. plot.Name,
			Width = r.SpokeWidth,
			Points = { c + dir * ringInner, c + dir * (WorldConfig.Bases.RingRadius - plotHalf + 6) },
		})
	end
	return roads
end

--------------------------------------------------------------------------------
-- GENERIC HELPERS (pure functions, usable anywhere)
--------------------------------------------------------------------------------

-- Biome-local XZ -> world XZ
function WorldConfig.ToWorld(biomeName: string, localPos: Vector2): Vector2
	local c = Biomes[biomeName].Center
	return Vector2.new(c.X + localPos.X, c.Z + localPos.Y)
end

-- Biome-local XZ -> world Vector3 at height y (defaults to biome Center.Y)
function WorldConfig.ToWorld3(biomeName: string, localPos: Vector2, y: number?): Vector3
	local c = Biomes[biomeName].Center
	return Vector3.new(c.X + localPos.X, y or c.Y, c.Z + localPos.Y)
end

function WorldConfig.GetBiome(name: string)
	return Biomes[name]
end

-- Ground biomes only (excludes floating Space), in progression order.
function WorldConfig.GetGroundBiomes(): { any }
	local list = {}
	for _, name in WorldConfig.BiomeOrder do
		if not Biomes[name].Floating then
			table.insert(list, Biomes[name])
		end
	end
	return list
end

-- Which biome a world position is in, respecting ZoneY and Priority.
-- (Mirrors what the BiomeZone parts do; handy on the server.)
function WorldConfig.GetBiomeAt(pos: Vector3): string?
	local best, bestPriority = nil, -math.huge
	for _, name in WorldConfig.BiomeOrder do
		local b = Biomes[name]
		local hx, hz = b.Size.X / 2, b.Size.Y / 2
		if math.abs(pos.X - b.Center.X) <= hx and math.abs(pos.Z - b.Center.Z) <= hz
			and pos.Y >= b.ZoneY.Min and pos.Y <= b.ZoneY.Max
			and b.Priority > bestPriority then
			best, bestPriority = name, b.Priority
		end
	end
	return best
end

-- Space island in world space: {Index, Center: Vector3 (top centre), Radius}
function WorldConfig.GetSpaceIslands(): { any }
	local space = Biomes.Space
	local out = {}
	for i, isl in space.Features.Islands do
		local w = WorldConfig.ToWorld("Space", isl.Pos)
		out[i] = {
			Index = i,
			Center = Vector3.new(w.X, space.Center.Y + isl.TopOffset, w.Y),
			Radius = isl.Radius,
		}
	end
	return out
end

-- Areas whose slopes are intentionally not drivable (the slope checker ignores
-- them). World XZ circles: {Center: Vector2, Radius}.
function WorldConfig.GetNoDriveAreas(): { any }
	local list = {}
	for _, m in Biomes.Desert.Features.Mesas do
		table.insert(list, { Center = WorldConfig.ToWorld("Desert", m.Pos), Radius = m.Radius + 20 })
	end
	local v = Biomes.Volcanic.Features.Volcano
	table.insert(list, { Center = WorldConfig.ToWorld("Volcanic", v.Pos), Radius = v.RimRadius + 16 })
	for _, lm in Biomes.Volcanic.Landmarks do
		if lm.Name == "ObsidianSpikes" then
			table.insert(list, { Center = WorldConfig.ToWorld("Volcanic", lm.Pos), Radius = lm.Radius })
		end
	end
	return list
end

-- Areas the terrain generator flattens (plots, pads, gates, teleporters).
-- {Center: Vector2 world, Radius, Falloff, TargetY: number? (nil = keep local height)}
function WorldConfig.GetFlattenAreas(): { any }
	local list = {}
	local b = WorldConfig.Bases
	for _, plot in WorldConfig.GetPlots() do
		table.insert(list, {
			Center = Vector2.new(plot.Position.X, plot.Position.Z),
			Radius = b.PlotSize.X * 0.72, -- covers the square's corners
			Falloff = 30,
			TargetY = b.FloorY,
		})
	end
	for _, name in WorldConfig.BiomeOrder do
		local biome = Biomes[name]
		if biome.Gate then
			table.insert(list, {
				Center = Vector2.new(biome.Gate.Position.X, biome.Gate.Position.Z),
				Radius = biome.Gate.Width * 0.6,
				Falloff = 30,
			})
		end
		if biome.Teleporter and not biome.Floating then
			table.insert(list, { Center = WorldConfig.ToWorld(name, biome.Teleporter), Radius = 14, Falloff = 14 })
		end
	end
	local pad = Biomes.Volcanic.LaunchPad
	table.insert(list, { Center = WorldConfig.ToWorld("Volcanic", pad.Pos), Radius = pad.Radius + 10, Falloff = 24 })
	return list
end

--------------------------------------------------------------------------------
-- STREAMING & PERFORMANCE BUDGETS (read by the audit script)
--------------------------------------------------------------------------------
WorldConfig.Budgets = {
	-- Per biome, counting BaseParts under Workspace.Map.<Biome>
	Hub = { MaxParts = 900, MaxUniqueMeshes = 40, MaxLights = 12 },
	Plains = { MaxParts = 1500, MaxUniqueMeshes = 30, MaxLights = 6 },
	Desert = { MaxParts = 1500, MaxUniqueMeshes = 30, MaxLights = 6 },
	Tropical = { MaxParts = 1700, MaxUniqueMeshes = 35, MaxLights = 8 },
	Volcanic = { MaxParts = 1500, MaxUniqueMeshes = 30, MaxLights = 14 },
	Space = { MaxParts = 1200, MaxUniqueMeshes = 25, MaxLights = 14 },
	Bases = { MaxPartsPerPlot = 250 },
	-- Terrain water: Tropical only, shallow (<= 8 studs deep).
	MaxWaterDepth = 8,
}

return WorldConfig
