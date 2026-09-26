--[[
	TerrainGenerator  (ModuleScript)
	Location: ServerStorage > DevTools > TerrainGenerator

	Edit-time tool. Generates ALL base terrain (ground biomes + Space islands)
	and the Space bridges from WorldConfig. Run it from the Command Bar:

		local m = game.ServerStorage.DevTools.TerrainGenerator:Clone()
		m.Parent = game.ServerStorage.DevTools
		local ok, err = pcall(function() require(m).Generate() end)
		m:Destroy()
		if not ok then warn(err) end

	(Cloning first defeats the Command Bar's require() cache, so edits to this
	module or to WorldConfig are always picked up.)

	Other entry points:
		require(m).Clear()                          -- wipe terrain + bridges
		require(m).Generate({ SlopeMarkers = true }) -- also drop red markers on
		                                            -- drivable ground > MaxDriveSlopeDeg
		require(m).Generate({ Only = "Desert" })     -- regenerate one biome's area
		                                            -- (plus its blend strips)

	Idempotent: Generate() clears its own output (terrain in the regions it
	writes + Workspace.Map.Space.Bridges) before writing.

	Pipeline per terrain column (4x4 studs):
		1. Every ground biome whose (rect + BlendWidth) covers the column samples
		   its own height function; heights are blended by smooth weights.
		2. The dominant biome (noise-dithered in blend strips) picks the surface tag.
		3. Global passes: edge hills / coast -> flatten areas -> roads -> lava rivers.
		4. Slope is computed from neighbouring columns; material chosen from the
		   biome's Materials table (ONLY Phase-1 approved materials are used).
	Chunks of ChunkSize x ChunkSize studs are written with Terrain:WriteVoxels,
	with task.wait() between chunks so Studio stays responsive.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

--------------------------------------------------------------------------------
-- CONFIG (fresh copy in edit mode so Command Bar edits are picked up)
--------------------------------------------------------------------------------
local function freshRequire(module: ModuleScript)
	local ok, isEdit = pcall(function()
		return RunService:IsEdit()
	end)
	if ok and isEdit then
		local clone = module:Clone()
		clone.Parent = module.Parent
		local result = require(clone)
		clone:Destroy()
		return result
	end
	return require(module)
end

local WorldConfig = freshRequire(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("WorldConfig"))

local TerrainGenerator = {}

local VOXEL = WorldConfig.VoxelSize
local FLOOR_Y = WorldConfig.TerrainFloorY
local BLEND = WorldConfig.BlendWidth
local WATER_LEVEL = WorldConfig.WaterLevel
local Biomes = WorldConfig.Biomes

--------------------------------------------------------------------------------
-- MATH HELPERS
--------------------------------------------------------------------------------
local function clamp01(x: number): number
	return if x < 0 then 0 elseif x > 1 then 1 else x
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Hermite smoothstep from edge0 -> edge1 (works for edge0 > edge1 too)
local function smoothstep(edge0: number, edge1: number, x: number): number
	local t = clamp01((x - edge0) / (edge1 - edge0))
	return t * t * (3 - 2 * t)
end

-- One octave of seeded noise in roughly [-1, 1].
-- The seed shifts the sample into a different region of noise space; the
-- non-integer offsets avoid math.noise's zero value at integer lattice points.
local function noise2(x: number, z: number, seed: number): number
	local n = math.noise(x + seed * 0.1731 + 0.37, z - seed * 0.2917 + 0.61, seed * 0.0137 + 0.19)
	return math.clamp(n * 1.7, -1, 1)
end

-- Fractal Brownian motion: layered octaves, result in [-1, 1].
local function fbm(x: number, z: number, seed: number, scale: number, octaves: number, gain: number): number
	local sum, amp, freq, norm = 0, 1, 1 / scale, 0
	for o = 1, octaves do
		sum += noise2(x * freq, z * freq, seed + o * 101) * amp
		norm += amp
		amp *= gain
		freq *= 2
	end
	return sum / norm
end

-- Ridged noise in [0, 1]: sharp crests (used for dunes & jagged basalt).
local function ridged(x: number, z: number, seed: number, scale: number, octaves: number, gain: number): number
	local sum, amp, freq, norm = 0, 1, 1 / scale, 0
	for o = 1, octaves do
		-- soft abs (sqrt(n^2 + e)) rounds the crest a little so it stays drivable
		local v = noise2(x * freq, z * freq, seed + o * 57)
		local n = 1 - math.sqrt(v * v + 0.015)
		sum += n * n * amp
		norm += amp
		amp *= gain
		freq *= 2
	end
	return sum / norm
end

-- Distance from point p to segment ab, plus the parameter t along ab.
local function distToSegment(px: number, pz: number, ax: number, az: number, bx: number, bz: number): (number, number)
	local abx, abz = bx - ax, bz - az
	local lenSq = abx * abx + abz * abz
	local t = if lenSq > 0 then clamp01(((px - ax) * abx + (pz - az) * abz) / lenSq) else 0
	local cx, cz = ax + abx * t, az + abz * t
	local dx, dz = px - cx, pz - cz
	return math.sqrt(dx * dx + dz * dz), t
end

--------------------------------------------------------------------------------
-- PRECOMPUTED WORLD DATA (built once per Generate call from WorldConfig)
--------------------------------------------------------------------------------
type Segment = { ax: number, az: number, bx: number, bz: number, minX: number, maxX: number, minZ: number, maxZ: number }

local groundBiomes: { any } = {}
local roadSegments: { any } = {} -- { seg: Segment, width }
local riverSegments: { any } = {} -- { seg, width, depth }
local flattenAreas: { any } = {}
local noDriveAreas: { any } = {}

local function makeSegment(a: Vector2, b: Vector2, pad: number): Segment
	return {
		ax = a.X, az = a.Y, bx = b.X, bz = b.Y,
		minX = math.min(a.X, b.X) - pad, maxX = math.max(a.X, b.X) + pad,
		minZ = math.min(a.Y, b.Y) - pad, maxZ = math.max(a.Y, b.Y) + pad,
	}
end

local function prepare()
	groundBiomes = WorldConfig.GetGroundBiomes()

	table.clear(roadSegments)
	local edge = WorldConfig.Roads.EdgeBlend
	for _, road in WorldConfig.GetRoads() do
		for i = 1, #road.Points - 1 do
			table.insert(roadSegments, {
				seg = makeSegment(road.Points[i], road.Points[i + 1], road.Width / 2 + edge),
				width = road.Width,
			})
		end
	end

	table.clear(riverSegments)
	for _, river in Biomes.Volcanic.Features.LavaRivers do
		for i = 1, #river.Points - 1 do
			local a = WorldConfig.ToWorld("Volcanic", river.Points[i])
			local b = WorldConfig.ToWorld("Volcanic", river.Points[i + 1])
			table.insert(riverSegments, {
				seg = makeSegment(a, b, river.Width / 2 + 8),
				width = river.Width,
				depth = river.Depth,
			})
		end
	end

	flattenAreas = WorldConfig.GetFlattenAreas()
	noDriveAreas = WorldConfig.GetNoDriveAreas()
end

-- Called after sampleBiomes exists: areas without TargetY keep the natural
-- height at their centre (cached once instead of per column).
local function resolveFlattenTargets(sampleBiomes)
	for _, area in flattenAreas do
		if area.TargetY == nil then
			area.AutoY = (sampleBiomes(area.Center.X, area.Center.Y))
		end
	end
end

--------------------------------------------------------------------------------
-- PER-BIOME HEIGHT FUNCTIONS
-- Each returns (height, surfaceTag). lx/lz are biome-local coordinates.
-- They are evaluated slightly outside their rectangle inside blend strips,
-- so they must be well-defined everywhere.
--------------------------------------------------------------------------------
local BiomeShape = {}

-- HUB: perfectly flat plaza, cobblestone core + ring, gentle grassy rise outside.
function BiomeShape.Hub(b, wx: number, wz: number, lx: number, lz: number): (number, string)
	local t = b.Terrain
	local r = math.sqrt(lx * lx + lz * lz)
	local rise = smoothstep(t.PlazaRadius, t.PlazaRadius + 160, r)
	local n = fbm(wx, wz, b.Seed, t.NoiseScale, 3, 0.45) * 0.5 + 0.5
	local h = b.Center.Y + rise * (t.OuterHillHeight * n)
	local tag = "Top"
	if r <= t.CobbleCoreRadius or (r >= t.CobbleRing.Inner and r <= t.CobbleRing.Outer) then
		tag = "Plaza"
	end
	return h, tag
end

-- PLAINS: soft rolling hills; noisy dirt patches.
function BiomeShape.Plains(b, wx: number, wz: number, _lx: number, _lz: number): (number, string)
	local t = b.Terrain
	local hills = fbm(wx, wz, b.Seed, t.HillScale, t.Octaves, t.Gain) * 0.5 + 0.5
	local h = b.Center.Y + t.BaseHeight + hills * t.HillHeight
	local dirt = fbm(wx, wz, b.Seed + 7, 60, 2, 0.5)
	local tag = if dirt > 1 - t.DirtPatchChance * 2 then "Dirt" else "Top"
	return h, tag
end

-- DESERT: domain-warped ridged dunes, flat Salt basins, steep Sandstone mesas.
function BiomeShape.Desert(b, wx: number, wz: number, lx: number, lz: number): (number, string)
	local t = b.Terrain
	-- Domain warp so dune crests curve instead of forming straight stripes.
	local wxw = wx + fbm(wx, wz, b.Seed + 11, 400, 2, 0.5) * t.DuneWarp
	local wzw = wz + fbm(wx, wz, b.Seed + 23, 400, 2, 0.5) * t.DuneWarp
	local dune = ridged(wxw, wzw * 0.55, b.Seed, t.DuneScale, 2, 0.35)
	local h = b.Center.Y + t.BaseHeight + dune * t.DuneHeight
	local tag = "Top"

	-- Basins: fade dunes down to a flat cracked-clay floor.
	for _, basin in b.Features.Basins do
		local dx, dz = lx - basin.Pos.X, lz - basin.Pos.Y
		local d = math.sqrt(dx * dx + dz * dz)
		local f = 1 - smoothstep(basin.Radius, basin.Radius + basin.Falloff, d)
		if f > 0 then
			h = lerp(h, b.Center.Y + basin.Height, f)
			if f > 0.55 then
				tag = "Basin"
			end
		end
	end

	-- Mesas: noise-wobbled circle, steep wall, flat top.
	for i, mesa in b.Features.Mesas do
		local dx, dz = lx - mesa.Pos.X, lz - mesa.Pos.Y
		local d = math.sqrt(dx * dx + dz * dz)
		local ang = math.atan2(dz, dx)
		local wobble = 1 + 0.15 * noise2(math.cos(ang) * 1.3, math.sin(ang) * 1.3, b.Seed + i * 31)
		local radius = mesa.Radius * wobble
		local f = 1 - smoothstep(radius - t.MesaEdge, radius, d)
		if f > 0 then
			local top = b.Center.Y + mesa.Height + fbm(wx, wz, b.Seed + 5, 40, 2, 0.5) * 2
			h = math.max(h, lerp(h, top, f))
			tag = "Rock"
		end
	end
	return h, tag
end

-- TROPICAL: grassy island interior, shallow lagoons, beaches, north/south coast.
-- Returns a third value: water surface height (or nil).
function BiomeShape.Tropical(b, wx: number, wz: number, lx: number, lz: number): (number, string)
	local t = b.Terrain
	local n = fbm(wx, wz, b.Seed, t.NoiseScale, 3, 0.45)
	local h = b.Center.Y + t.BaseHeight + n * t.NoiseHeight

	-- Coast: the north and south edges slope down into shallow sea.
	local halfZ = b.Size.Y / 2
	local coastWobble = fbm(wx, 0, b.Seed + 9, 180, 2, 0.5) * 40
	local coast = smoothstep(halfZ - t.CoastWidth + coastWobble, halfZ - 20 + coastWobble, math.abs(lz))
	h = lerp(h, t.SeaFloor, coast)

	-- Lagoons: ellipses carved to the sea floor with a wobbly shoreline.
	for i, lag in b.Features.Lagoons do
		local ex = (lx - lag.Pos.X) / lag.Radius.X
		local ez = (lz - lag.Pos.Y) / lag.Radius.Y
		local e = math.sqrt(ex * ex + ez * ez) + fbm(wx, wz, b.Seed + i * 13, 90, 2, 0.5) * 0.12
		local f = 1 - smoothstep(0.7, 1.15, e)
		if f > 0 then
			h = lerp(h, t.SeaFloor, f)
		end
	end

	local tag = if h < WATER_LEVEL + t.BeachBand then "Beach" else "Top"
	return h, tag
end

-- VOLCANIC: ash plains (north) blending into jagged basalt (south), plus the
-- central volcano cone with a lava crater. Lava rivers are a global pass.
function BiomeShape.Volcanic(b, wx: number, wz: number, lx: number, lz: number): (number, string)
	local t = b.Terrain
	local base = b.Center.Y + t.BaseHeight

	local jag = ridged(wx, wz, b.Seed, t.JaggedScale, 3, 0.4) * t.JaggedHeight
	local ash = (fbm(wx, wz, b.Seed + 3, t.AshScale, 2, 0.5) * 0.5 + 0.5) * t.AshHeight
	-- ashMask: 1 = ash plains. North half + noise, so the road corridor is smooth.
	local ashMask = smoothstep(-80, 80, lz + fbm(wx, wz, b.Seed + 4, 260, 2, 0.5) * 140)
	local h = base + lerp(jag, ash, ashMask)
	local tag = if ashMask > 0.5 then "Ash" else "Top"

	-- Volcano: linear cone (~26 deg, drivable) with rounded foot, rim and crater.
	local v = b.Features.Volcano
	local dx, dz = lx - v.Pos.X, lz - v.Pos.Y
	local r = math.sqrt(dx * dx + dz * dz)
	if r < v.Radius + 40 then
		local ang = math.atan2(dz, dx)
		-- gullies make the cone feel sculpted, not a perfect cone
		local gully = noise2(math.cos(ang) * 3, math.sin(ang) * 3, b.Seed + 17) * 4
		local cone: number
		if r >= v.RimRadius then
			local k = clamp01((v.Radius - r) / (v.Radius - v.RimRadius))
			-- soften the foot: ease-in for the first 20% of the climb
			k = if k < 0.2 then (k * k) / 0.4 else k - 0.1
			cone = base + v.Height * k / 0.9 + gully * k
		else
			-- inside the rim: bowl down to the lava lake
			local rimTop = base + v.Height
			local floorY = rimTop - v.CraterDepth
			cone = lerp(floorY, rimTop, smoothstep(v.CraterRadius, v.RimRadius, r))
		end
		if cone > h then
			h = cone
			tag = if r < v.CraterRadius + 4 then "Lava" elseif r < v.Radius * 0.85 then "Rock" else tag
		end
	end
	return h, tag
end

-- Cheap weight of a ground biome at (wx, wz): 1 inside, fading to 0 over BLEND.
local function biomeWeight(b, wx: number, wz: number): number
	local dx = math.max(math.abs(wx - b.Center.X) - b.Size.X / 2, 0)
	local dz = math.max(math.abs(wz - b.Center.Z) - b.Size.Y / 2, 0)
	local d = math.sqrt(dx * dx + dz * dz)
	if d >= BLEND then
		return 0
	end
	return 1 - smoothstep(0, BLEND, d)
end

--------------------------------------------------------------------------------
-- RAW HEIGHT (biome blend only) - used by roads for their centre-line height
--------------------------------------------------------------------------------
local function sampleBiomes(wx: number, wz: number): (number, any, string, number)
	local sumW, sumH = 0, 0
	local bestB, bestTag, bestScore = nil, "Top", -math.huge
	local tropicalW = 0
	local nearest, nearestD = nil, math.huge

	for _, b in groundBiomes do
		local w = biomeWeight(b, wx, wz)
		if w > 0 then
			local h, tag = BiomeShape[b.Name](b, wx, wz, wx - b.Center.X, wz - b.Center.Z)
			sumW += w
			sumH += h * w
			-- Dither the material border with noise so seams look natural.
			local score = w + (if w < 1 then noise2(wx / 24, wz / 24, b.Seed) * 0.35 else 0)
			if score > bestScore then
				bestB, bestTag, bestScore = b, tag, score
			end
			if b.Name == "Tropical" then
				tropicalW = w
			end
		else
			local dx = math.max(math.abs(wx - b.Center.X) - b.Size.X / 2, 0)
			local dz = math.max(math.abs(wz - b.Center.Z) - b.Size.Y / 2, 0)
			local d = dx * dx + dz * dz
			if d < nearestD then
				nearest, nearestD = b, d
			end
		end
	end

	if sumW <= 0 then
		-- Outside every biome's blend strip (world corners): extend the nearest.
		local h, tag = BiomeShape[nearest.Name](nearest, wx, wz, wx - nearest.Center.X, wz - nearest.Center.Z)
		return h, nearest, tag, if nearest.Name == "Tropical" then 1 else 0
	end
	return sumH / sumW, bestB, bestTag, tropicalW / sumW
end

--------------------------------------------------------------------------------
-- FULL COLUMN SAMPLE (biomes + global passes)
-- Returns height, biome, tag, waterTop(or nil), roadMask(0..1)
--------------------------------------------------------------------------------
local function sampleColumn(wx: number, wz: number): (number, any, string, number?)
	local h, biome, tag, tropicalShare = sampleBiomes(wx, wz)

	-- 1) World-edge rim hills (north/south), replaced by sea in Tropical.
	local bounds = WorldConfig.WorldBounds
	local edgeDist = math.min(wz - bounds.Min.Z, bounds.Max.Z - wz, wx - bounds.Min.X, bounds.Max.X - wx)
	local eh = WorldConfig.EdgeHills
	local rim = smoothstep(eh.Width, 0, edgeDist) * (1 - tropicalShare)
	if rim > 0 then
		h += rim * eh.Height * (0.75 + 0.25 * noise2(wx / 70, wz / 70, 99))
		if rim > 0.3 and tag ~= "Rock" then
			tag = "Steep"
		end
	end

	-- 2) Flatten areas (plots, gates, pads).
	for _, area in flattenAreas do
		local dx, dz = wx - area.Center.X, wz - area.Center.Y
		local d = math.sqrt(dx * dx + dz * dz)
		if d < area.Radius + area.Falloff then
			local target = area.TargetY or area.AutoY
			h = lerp(h, target, 1 - smoothstep(area.Radius, area.Radius + area.Falloff, d))
		end
	end

	-- 3) Roads: level the terrain across the road to its (smoothed) centre height.
	local edge = WorldConfig.Roads.EdgeBlend
	local bestRoad, bestD, bestSeg, bestT = nil, math.huge, nil, 0
	for _, rs in roadSegments do
		local s = rs.seg
		if wx >= s.minX and wx <= s.maxX and wz >= s.minZ and wz <= s.maxZ then
			local d, t = distToSegment(wx, wz, s.ax, s.az, s.bx, s.bz)
			if d - rs.width / 2 < bestD then
				bestRoad, bestD, bestSeg, bestT = rs, d - rs.width / 2, s, t
			end
		end
	end
	if bestRoad then
		local s = bestSeg
		local cx, cz = lerp(s.ax, s.bx, bestT), lerp(s.az, s.bz, bestT)
		-- Average raw height along the road to smooth out bumps.
		local len = math.sqrt((s.bx - s.ax) ^ 2 + (s.bz - s.az) ^ 2)
		local ux, uz = (s.bx - s.ax) / len, (s.bz - s.az) / len
		local centre = 0
		for k = -2, 2 do
			local hh = sampleBiomes(cx + ux * k * 16, cz + uz * k * 16)
			centre += hh
		end
		centre /= 5
		-- Keep plots/gates flat even where a road meets them.
		for _, area in flattenAreas do
			local dx, dz = cx - area.Center.X, cz - area.Center.Y
			if area.TargetY and math.sqrt(dx * dx + dz * dz) < area.Radius + area.Falloff then
				centre = area.TargetY
			end
		end
		-- Never build roads under water.
		centre = math.max(centre, WATER_LEVEL + 1.5)
		local f = 1 - smoothstep(0, edge, bestD)
		h = lerp(h, centre, f)
		-- Dirt/cobble edge is noise-blended rather than a hard line.
		if bestD < noise2(wx / 10, wz / 10, 7) * 3 then
			tag = "Path"
		end
	end

	-- 4) Lava rivers (Volcanic): carve a channel of CrackedLava.
	if biome.Name == "Volcanic" then
		for _, rv in riverSegments do
			local s = rv.seg
			if wx >= s.minX and wx <= s.maxX and wz >= s.minZ and wz <= s.maxZ then
				local d = distToSegment(wx, wz, s.ax, s.az, s.bx, s.bz)
				local f = 1 - smoothstep(rv.width / 2 - 4, rv.width / 2 + 4, d)
				if f > 0 then
					h -= rv.depth * f
					if f > 0.4 then
						tag = "Lava"
					end
				end
			end
		end
	end

	-- Water: Tropical-dominant columns below sea level get a water layer.
	local waterTop = nil
	if biome.Name == "Tropical" and h < WATER_LEVEL then
		waterTop = WATER_LEVEL
	end
	return h, biome, tag, waterTop
end

-- Public: lets other dev tools estimate ground height without raycasting.
function TerrainGenerator.SampleHeight(wx: number, wz: number): number
	if #groundBiomes == 0 then
		prepare()
		resolveFlattenTargets(sampleBiomes)
	end
	return (sampleColumn(wx, wz))
end

--------------------------------------------------------------------------------
-- MATERIAL CHOICE (only the biome's approved materials)
--------------------------------------------------------------------------------
local function pickMaterial(biome, tag: string, slopeDeg: number): Enum.Material
	local mats = biome.Materials
	if slopeDeg > WorldConfig.SteepMaterialSlopeDeg and tag ~= "Path" and tag ~= "Lava" then
		return mats.Steep or mats.Top
	end
	return mats[tag] or mats.Top
end

local function isNoDrive(wx: number, wz: number): boolean
	for _, a in noDriveAreas do
		local dx, dz = wx - a.Center.X, wz - a.Center.Y
		if dx * dx + dz * dz < a.Radius * a.Radius then
			return true
		end
	end
	-- lava channels and their banks are not meant to be driven through
	for _, rv in riverSegments do
		local s = rv.seg
		if wx >= s.minX and wx <= s.maxX and wz >= s.minZ and wz <= s.maxZ then
			if distToSegment(wx, wz, s.ax, s.az, s.bx, s.bz) < rv.width / 2 + 8 then
				return true
			end
		end
	end
	return false
end

-- Public: true where steep ground is intentional (mesas, crater, lava rivers).
function TerrainGenerator.IsNoDrive(wx: number, wz: number): boolean
	if #groundBiomes == 0 then
		prepare()
	end
	return isNoDrive(wx, wz)
end

--------------------------------------------------------------------------------
-- VOXEL WRITING
--------------------------------------------------------------------------------
-- Generic chunk writer. columnFn(wx, wz) must return
--   bottom, top, topMaterial, fillMaterial, waterTop?   (bottom=nil => empty column)
-- Writes region [x0, x0+sx) x [yMin, yMax) x [z0, z0+sz) in one WriteVoxels call.
local function writeChunk(x0: number, z0: number, sx: number, sz: number, yMin: number, yMax: number, columns)
	local nx, nz = sx // VOXEL, sz // VOXEL
	local ny = math.max(1, (yMax - yMin) // VOXEL)
	local materials, occupancy = table.create(nx), table.create(nx)
	for i = 1, nx do
		local mi, oi = table.create(ny), table.create(ny)
		materials[i], occupancy[i] = mi, oi
		for j = 1, ny do
			mi[j], oi[j] = table.create(nz, Enum.Material.Air), table.create(nz, 0)
		end
		for k = 1, nz do
			local col = columns[i][k]
			if col then
				local bottom, top, topMat, fillMat, waterTop = col[1], col[2], col[3], col[4], col[5]
				for j = 1, ny do
					local cellBottom = yMin + (j - 1) * VOXEL
					local cellTop = cellBottom + VOXEL
					-- solid occupancy = overlap of [bottom, top] with the cell
					local occ = (math.min(top, cellTop) - math.max(bottom, cellBottom)) / VOXEL
					if occ > 0.02 then
						mi[j][k] = if cellTop > top - 6 then topMat else fillMat
						oi[j][k] = math.min(occ, 1)
					elseif waterTop and cellBottom < waterTop and cellBottom >= top - VOXEL then
						mi[j][k] = Enum.Material.Water
						oi[j][k] = math.min((waterTop - cellBottom) / VOXEL, 1)
					end
				end
			end
		end
	end
	local region = Region3.new(Vector3.new(x0, yMin, z0), Vector3.new(x0 + sx, yMin + ny * VOXEL, z0 + sz))
	Workspace.Terrain:WriteVoxels(region, VOXEL, materials, occupancy)
end

--------------------------------------------------------------------------------
-- GROUND GENERATION
--------------------------------------------------------------------------------
local function snapDown(v: number, step: number): number
	return math.floor(v / step) * step
end
local function snapUp(v: number, step: number): number
	return math.ceil(v / step) * step
end

-- Area of a ground biome including its blend strips, snapped to chunk grid.
local function biomeArea(b)
	local cs = WorldConfig.ChunkSize
	return snapDown(b.Center.X - b.Size.X / 2 - BLEND, cs), snapUp(b.Center.X + b.Size.X / 2 + BLEND, cs),
		snapDown(b.Center.Z - b.Size.Y / 2 - BLEND, cs), snapUp(b.Center.Z + b.Size.Y / 2 + BLEND, cs)
end

local slopeStats = {} -- [biomeName] = { count, samples = {Vector3} }
local slopeMarkers: Folder? = nil

local function generateGround(options)
	local cs = WorldConfig.ChunkSize
	local bounds = WorldConfig.WorldBounds
	local x0, x1 = snapDown(bounds.Min.X, cs), snapUp(bounds.Max.X, cs)
	local z0, z1 = snapDown(bounds.Min.Z, cs), snapUp(bounds.Max.Z, cs)
	if options.Only then
		local b = Biomes[options.Only]
		assert(b and not b.Floating, "Only= must name a ground biome")
		x0, x1, z0, z1 = biomeArea(b)
	end

	local chunksX, chunksZ = (x1 - x0) // cs, (z1 - z0) // cs
	local total, done = chunksX * chunksZ, 0
	local maxSlope = WorldConfig.MaxDriveSlopeDeg
	local n = cs // VOXEL
	print(("[TerrainGenerator] Ground: %d chunks (%d x %d studs)"):format(total, x1 - x0, z1 - z0))

	for cx = 0, chunksX - 1 do
		for cz = 0, chunksZ - 1 do
			local ox, oz = x0 + cx * cs, z0 + cz * cs

			-- Heights on an (n+2)^2 grid (1-column border for slope calc).
			local H, Bm, Tg, Wt = {}, {}, {}, {}
			for i = 0, n + 1 do
				H[i], Bm[i], Tg[i], Wt[i] = {}, {}, {}, {}
				for k = 0, n + 1 do
					local wx = ox + (i - 0.5) * VOXEL
					local wz = oz + (k - 0.5) * VOXEL
					local h, b, tag, water = sampleColumn(wx, wz)
					H[i][k], Bm[i][k], Tg[i][k], Wt[i][k] = h, b, tag, water
				end
			end

			local columns = table.create(n)
			local yTop = FLOOR_Y + VOXEL
			for i = 1, n do
				columns[i] = table.create(n)
				for k = 1, n do
					local h = H[i][k]
					local gx = (H[i + 1][k] - H[i - 1][k]) / (2 * VOXEL)
					local gz = (H[i][k + 1] - H[i][k - 1]) / (2 * VOXEL)
					local slope = math.deg(math.atan(math.sqrt(gx * gx + gz * gz)))
					local b, tag, water = Bm[i][k], Tg[i][k], Wt[i][k]
					local topMat = pickMaterial(b, tag, slope)
					columns[i][k] = { FLOOR_Y, h, topMat, b.Materials.Fill, water }
					yTop = math.max(yTop, h + VOXEL, (water or -math.huge) + VOXEL)

					-- Slope check on drivable, dry ground.
					if slope > maxSlope and not water and h > WATER_LEVEL then
						local wx = ox + (i - 0.5) * VOXEL
						local wz = oz + (k - 0.5) * VOXEL
						if not isNoDrive(wx, wz) then
							local st = slopeStats[b.Name]
							if not st then
								st = { count = 0, samples = {} }
								slopeStats[b.Name] = st
							end
							st.count += 1
							if #st.samples < 5 and st.count % 25 == 1 then
								table.insert(st.samples, Vector3.new(wx, h, wz))
							end
							if slopeMarkers and st.count % 4 == 1 then
								local p = Instance.new("Part")
								p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
								p.Material = Enum.Material.Neon
								p.Color = Color3.fromRGB(255, 40, 40)
								p.Size = Vector3.new(3, 12, 3)
								p.Position = Vector3.new(wx, h + 6, wz)
								p.Name = ("Slope_%d"):format(math.floor(slope))
								p.Parent = slopeMarkers
							end
						end
					end
				end
			end

			writeChunk(ox, oz, cs, cs, FLOOR_Y, snapUp(yTop, VOXEL), columns)

			done += 1
			if done % 40 == 0 or done == total then
				print(("[TerrainGenerator] Ground %d/%d (%d%%)"):format(done, total, math.floor(done / total * 100)))
			end
			task.wait()
		end
	end
end

--------------------------------------------------------------------------------
-- SPACE ISLANDS + BRIDGES
--------------------------------------------------------------------------------
local function ensureFolder(parent: Instance, name: string): Folder
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f :: Folder
end

local function generateIslands()
	local space = Biomes.Space
	local t = space.Terrain
	local cs = WorldConfig.ChunkSize
	for idx, isl in WorldConfig.GetSpaceIslands() do
		local R = isl.Radius
		local topY = isl.Center.Y
		local thickness = R * t.ThicknessFactor
		local seed = space.Seed + idx * 97
		local reach = R * (1 + t.EdgeWobble) + VOXEL
		local ix0, ix1 = snapDown(isl.Center.X - reach, VOXEL), snapUp(isl.Center.X + reach, VOXEL)
		local iz0, iz1 = snapDown(isl.Center.Z - reach, VOXEL), snapUp(isl.Center.Z + reach, VOXEL)
		local yMin = snapDown(topY - thickness * 1.35 - 8, VOXEL)
		local yMax = snapUp(topY + t.TopFlatness + VOXEL * 2, VOXEL)

		-- Walk the island in ChunkSize tiles.
		for tx = ix0, ix1 - 1, cs do
			for tz = iz0, iz1 - 1, cs do
				local sx, sz = math.min(cs, ix1 - tx), math.min(cs, iz1 - tz)
				local nx, nz = sx // VOXEL, sz // VOXEL
				local columns = table.create(nx)
				for i = 1, nx do
					columns[i] = table.create(nz, false)
					for k = 1, nz do
						local wx = tx + (i - 0.5) * VOXEL
						local wz = tz + (k - 0.5) * VOXEL
						local dx, dz = wx - isl.Center.X, wz - isl.Center.Z
						local ang = math.atan2(dz, dx)
						local wobble = 1 + t.EdgeWobble * noise2(math.cos(ang) * 1.6, math.sin(ang) * 1.6, seed)
						local edgeR = R * wobble
						local r = math.sqrt(dx * dx + dz * dz) / edgeR
						if r < 1 then
							-- flat top with a rounded lip; dome/cone underside
							local top = topY + fbm(wx, wz, seed, 50, 2, 0.5) * t.TopFlatness
								- smoothstep(0.86, 1, r) * 5
							local under = thickness * math.sqrt(1 - r * r) ^ 0.8
								* (0.85 + 0.3 * (fbm(wx, wz, seed + 3, 35, 2, 0.5) * 0.5 + 0.5))
							local topMat = if r < 0.88 then space.Materials.Top else space.Materials.Rim
							columns[i][k] = { top - math.max(under, 6), top, topMat, space.Materials.Fill, nil }
						else
							columns[i][k] = false
						end
					end
				end
				writeChunk(tx, tz, sx, sz, yMin, yMax, columns)
				task.wait()
			end
		end
		print(("[TerrainGenerator] Space island %d/%d"):format(idx, #space.Features.Islands))
	end
end

local function generateBridges()
	local space = Biomes.Space
	local f = space.Features
	local map = ensureFolder(Workspace, "Map")
	local spaceFolder = ensureFolder(map, "Space")
	local old = spaceFolder:FindFirstChild("Bridges")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Bridges"

	local islands = WorldConfig.GetSpaceIslands()
	for _, pair in f.Bridges do
		local a, b = islands[pair[1]], islands[pair[2]]
		local flatDir = Vector3.new(b.Center.X - a.Center.X, 0, b.Center.Z - a.Center.Z).Unit
		-- Start/end well inside each island so the deck overlaps solid ground.
		local p0 = a.Center + flatDir * (a.Radius * 0.8)
		local p1 = b.Center - flatDir * (b.Radius * 0.8)
		local length = (p1 - p0).Magnitude
		local mid = (p0 + p1) / 2
		local cf = CFrame.lookAt(mid, p1)

		local model = Instance.new("Model")
		model.Name = ("Bridge_%d_%d"):format(pair[1], pair[2])

		local deck = Instance.new("Part")
		deck.Name = "Deck"
		deck.Anchored = true
		deck.Material = Enum.Material.SmoothPlastic
		deck.Color = f.BridgeColor
		deck.Size = Vector3.new(f.BridgeWidth, 2, length)
		deck.CFrame = cf * CFrame.new(0, -1, 0) -- top surface flush with island tops
		deck.TopSurface = Enum.SurfaceType.Smooth
		deck.Parent = model

		for _, side in { -1, 1 } do
			local rail = Instance.new("Part")
			rail.Name = "GlowRail"
			rail.Anchored = true
			rail.CanCollide = true -- keeps vehicles on the bridge
			rail.CastShadow = false
			rail.CanQuery = false
			rail.CanTouch = false
			rail.Material = Enum.Material.Neon
			rail.Color = f.BridgeRailColor
			rail.Size = Vector3.new(1.2, 2.5, length)
			rail.CFrame = cf * CFrame.new(side * (f.BridgeWidth / 2 - 0.6), 1.25, 0)
			rail.Parent = model
		end
		model.PrimaryPart = deck
		model.Parent = folder
	end
	folder.Parent = spaceFolder
	print(("[TerrainGenerator] Built %d Space bridges"):format(#f.Bridges))
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------
local function clearOwnOutput()
	local map = Workspace:FindFirstChild("Map")
	local spaceFolder = map and map:FindFirstChild("Space")
	local bridges = spaceFolder and spaceFolder:FindFirstChild("Bridges")
	if bridges then
		bridges:Destroy()
	end
	local markers = map and map:FindFirstChild("_SlopeWarnings")
	if markers then
		markers:Destroy()
	end
end

-- Wipes ALL terrain and this tool's parts. (Terrain:Clear is instant.)
function TerrainGenerator.Clear()
	Workspace.Terrain:Clear()
	clearOwnOutput()
	print("[TerrainGenerator] Cleared terrain, bridges and slope markers.")
end

--[[
	options = {
		Only = "Desert",       -- optional: regenerate one ground biome's area only
		SlopeMarkers = true,   -- optional: red neon markers on too-steep drivable ground
		SkipSpace = true,      -- optional: skip islands + bridges
	}
]]
function TerrainGenerator.Generate(options: any?)
	local opts = options or {}
	local started = os.clock()
	prepare()
	resolveFlattenTargets(sampleBiomes)
	table.clear(slopeStats)

	-- Idempotency: clear what we are about to rebuild.
	if opts.Only then
		local ax0, ax1, az0, az1 = biomeArea(Biomes[opts.Only])
		Workspace.Terrain:FillBlock(
			CFrame.new((ax0 + ax1) / 2, 0, (az0 + az1) / 2),
			Vector3.new(ax1 - ax0, 700, az1 - az0), -- ground layer only, never reaches Space
			Enum.Material.Air
		)
		local map = Workspace:FindFirstChild("Map")
		local markers = map and map:FindFirstChild("_SlopeWarnings")
		if markers then
			markers:Destroy()
		end
	else
		TerrainGenerator.Clear()
	end

	if opts.SlopeMarkers then
		slopeMarkers = ensureFolder(ensureFolder(Workspace, "Map"), "_SlopeWarnings")
	else
		slopeMarkers = nil
	end

	generateGround(opts)
	if not opts.Only and not opts.SkipSpace then
		generateIslands()
		generateBridges()
	end

	-- Slope report
	print("[TerrainGenerator] ---- Slope report (drivable ground > " .. WorldConfig.MaxDriveSlopeDeg .. " deg) ----")
	local any = false
	for name, st in slopeStats do
		any = true
		local where = {}
		for _, p in st.samples do
			table.insert(where, ("(%d, %d, %d)"):format(p.X, p.Y, p.Z))
		end
		warn(("[TerrainGenerator] %s: %d steep columns (~%d sq studs). e.g. %s"):format(
			name, st.count, st.count * VOXEL * VOXEL, table.concat(where, " ")
		))
	end
	if not any then
		print("[TerrainGenerator] No steep drivable ground found.")
	end
	print(("[TerrainGenerator] Done in %.1f s"):format(os.clock() - started))
end

return TerrainGenerator
