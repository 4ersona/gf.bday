# Storm Chaser Simulator: Phase 2, Map Creation

Status: **Steps 1–5 done** (layout, WorldConfig, terrain, Hub, Bases). Next: Zones & Gates.

| Step | Deliverable | File (Explorer location) |
|---|---|---|
| 1 | Layout plan | this document |
| 2 | WorldConfig | `ReplicatedStorage > Shared > Config > WorldConfig` (ModuleScript) |
| 3 | Terrain generator | `ServerStorage > DevTools > TerrainGenerator` (ModuleScript, edit-time tool) |
| – | Shared build helpers | `ServerStorage > DevTools > BuildKit` (ModuleScript) |
| 4 | Hub build | `ServerStorage > DevTools > HubGenerator` (ModuleScript, edit-time tool) |
| 5 | Base template | `ServerStorage > DevTools > BaseTemplateBuilder` (ModuleScript, edit-time tool) |
| 5 | BaseService | `ServerScriptService > Services > BaseService` (ModuleScript) |
| 5 | TeleportPadService | `ServerScriptService > Services > TeleportPadService` (ModuleScript) |
| 5 | Service loader | `ServerScriptService > ServicesLoader` (Script), skip if Phase 1 has one |
| 6 | Zones / Gates / LaunchPad | *next* |
| 7 | Landmarks & props | *pending* |
| 8 | Navigation | *pending* |
| 9 | Streaming & audit | *pending* (budgets already in `WorldConfig.Budgets`) |

`src/` mirrors the Explorer tree, so you can copy and paste each file into Studio or sync it with Rojo (`default.project.json`).

---

## 1. World layout

### Design numbers
* The starter vehicle's reference speed is `WorldConfig.StarterVehicleSpeed = 36` studs/s.
* Each ground biome is **1200 × 1200** studs. The road meanders about **1260 studs** through each one, so crossing takes about **35 s** (the target was 30–45 s).
* Progression runs in a straight line to the east (+X): Hub → Plains → Desert → Tropical → Volcanic. Space floats **720 studs above Volcanic**. To bend the line into an arc, edit the biome `Center` values. Everything else follows because all positions are biome-local.
* Biome borders blend over **±80 studs** (`BlendWidth`).

### ASCII map (top-down. North = −Z is at the top, East = +X is to the right. 1 char ≈ 100 studs)

```
 Z
-720 ┌─────────┬────────────┬────────────┬────────────┬────────────┐  ~~ rim hills / sea (world edge, soft walls)
     │ ^ ^ ^ ^ │ ^ ^ ^ ^ ^ ^│ ^ ^ ^ ^ ^ ^│~~~~~~~~~~~~│ ^ ^ ^ ^ ^ ^│
-600 │         ├────────────┼────────────┼────────────┼────────────┤
     │         │ Z1    ▲Vane│ ▓Arch  ■M1 │ Z1  ≈≈≈≈   │ ✶Spk  ╱▲╲  │
-400 ├─────────┤      [SC]  │ Z1   Z2 [SC│ ≈≈L1≈≈ Z2  │      ╱ ◉ ╲ [SC]  ◉ = crater
     │P3  P2 P1│            │  ○basin2   │ ≈Temple≈ Z3│  Z3 ╱VOLCANO╲│
     │  ·HUB·  │            │            │ ═══════    │  ~~lava~~     │
   0 │P4 (◎)══>══MAIN ROAD═════════════════════════════════════════●PAD (launch)
     │  ·   ·  │ Z4  Z3 Barn│ ○basin1 Z4 │    ≈≈≈≈≈   │ Z1  Z2  ⌇   │
     │P5  P6 P7│ Mill   Z2  │ Z3  ■M2    │ [SC] ≈L2≈≈ │         bridge│
 400 ├─(P8)────┤            │Oasis Compass│Huts  Wreck │Station     │
     │         │            │■M3         │~~~~~~~~~~~~│            │
 600 │ ^ ^ ^ ^ ├────────────┼────────────┼────────────┼────────────┤
 720 └─────────┴────────────┴────────────┴────────────┴────────────┘
    -480   400(gate)   1600(gate)   2800(gate)   4000(gate)   5200  5280  X
      HUB       PLAINS       DESERT      TROPICAL     VOLCANIC
                                                    ↑ SPACE islands float above
                                                      Volcanic at Y≈720
```

The 8 plots sit in a ring at radius 300 around the Hub, at angles of 22.5° + 45°·k. That leaves a gap exactly at due east for the main road.

Space (Y ≈ 720, above Volcanic, local XZ offsets):

```
        (-190,400)③──②(40,300)
               │      \     \
 (-420,220)④───┘       \     ①(260,180) ← landing island (launch pad target)
        │               \
 (-360,-60)⑤───⑥(-120,-40)──⑦(120,-180)──⑨(380,-300)
               │
        (-160,-330)⑧──⑩(-440,-380)
```

### Coordinate table (world studs; Y = nominal ground height)

| Area | Center (X, Y, Z) | Size X × Z | Height range | Seed | Unlock | Gate (world) |
|---|---|---|---|---|---|---|
| Hub | (0, 0, 0) | 800 × 800 | 0 … 16 | 1001 | – | – |
| Plains | (1000, 0, 0) | 1200 × 1200 | 0 … 30 | 2002 | free | (400, 0, 0) |
| Desert | (2200, 0, 0) | 1200 × 1200 | 0 … 62 | 3003 | 2 500 Energy | (1600, 0, 0) |
| Tropical | (3400, 0, 0) | 1200 × 1200 | −6 … 16 (water Y=0) | 4004 | 25 000 Energy | (2800, 0, 0) |
| Volcanic | (4600, 0, 0) | 1200 × 1200 | −3 … 116 | 5005 | 1 Rebirth | (4000, 0, 0) |
| Space | (4600, 720, 0) | 1200 × 1200 | 640 … 760 | 6006 | 3 Rebirths | Launch pad (5040, 220) |
| World bounds | (-480,-200,-720) → (5280,1100,720) | 5760 × 1440 | | | | |

| Hub item | Hub-local XZ | | Hub item | Hub-local XZ |
|---|---|---|---|---|
| Spawn | (0, 0) | | Sell pad | (85, −85) |
| Upgrades shop | (−50, −120) | | Rebirth altar | (−160, 0) |
| Pets shop | (−120, −50) | | Event board | (110, 60) |
| Vehicles shop | (−120, 55) | | Daily chest | (35, −50) |
| Cosmetics shop | (−50, 125) | | Base teleport pad | (35, 50) |
| Leaderboards | Energy (40,140) · Rebirths (95,118) · StormsCaught (135,80) | | Plaza radius | 185 (flat) |

| Plot | Angle | Center (X, Z) | | Plot | Angle | Center (X, Z) |
|---|---|---|---|---|---|---|
| Plot1 | 22.5° | (277, 115) | | Plot5 | 202.5° | (−277, −115) |
| Plot2 | 67.5° | (115, 277) | | Plot6 | 247.5° | (−115, −277) |
| Plot3 | 112.5° | (−115, 277) | | Plot7 | 292.5° | (115, −277) |
| Plot4 | 157.5° | (−277, 115) | | Plot8 | 337.5° | (277, −115) |

Plots are 110 × 110 at Y = 0 and face the Hub centre. They come from `WorldConfig.GetPlots()`.

Per-biome landmarks, storm zones, supercell arenas, teleporters, lagoons, mesas, the volcano and lava rivers are all listed in `WorldConfig`, in biome-local coordinates.

---

## 2. WorldConfig

`ReplicatedStorage > Shared > Config > WorldConfig` is a ModuleScript and the only place world coordinates live. Its helpers:

| Function | Returns |
|---|---|
| `GetPlots()` | 8 plots `{Id, Name, Position, Angle, CFrame}` |
| `GetRoads()` | main road + 8 hub spokes `{Name, Width, Points}` |
| `ToWorld(biome, v2)` / `ToWorld3(biome, v2, y?)` | biome-local → world |
| `GetBiomeAt(pos)` | biome name, honouring `ZoneY` and `Priority` |
| `GetGroundBiomes()` | ground biomes in progression order |
| `GetSpaceIslands()` | `{Index, Center (top), Radius}` |
| `GetFlattenAreas()` / `GetNoDriveAreas()` | used by the terrain tool and audits |

### Setup
1. In Explorer, make sure `ReplicatedStorage > Shared > Config` exists.
2. Insert a **ModuleScript** named `WorldConfig` under `Config` and paste the file in.

### Test
Paste this in the Command Bar:
```lua
local W = require(game.ReplicatedStorage.Shared.Config.WorldConfig:Clone())
for _, p in W.GetPlots() do print(p.Name, p.Position) end
print(W.GetBiomeAt(Vector3.new(2200, 10, 0)), W.GetBiomeAt(Vector3.new(4600, 720, 0)))
```
You should see 8 plots, then `Desert  Space`.

---

## 3. Terrain generator

`ServerStorage > DevTools > TerrainGenerator` is a ModuleScript. It is an edit-time tool and never runs in a live game.

* Heights come from seeded `math.noise` fBm with layered octaves. Dunes and basalt use ridged noise, and the dunes are domain-warped. The output is reproducible for a given seed.
* Terrain is written with `Terrain:WriteVoxels` in 64 × 64 stud chunks. The tool calls `task.wait()` after every chunk and prints progress every 40 chunks.
* The shape passes run in this order: biome blend → world-edge rim hills (Tropical gets sea instead) → flattening (plots, gates, pads, teleporters) → roads (levelled to a smoothed centre-line height, never under water, with a noise-blended edge) → lava rivers.
* Materials come only from each biome's `Materials` table, which holds the Phase-1 approved list. Ground steeper than 32° switches to that biome's `Steep` material.
* Space gets 10 floating islands with flat Pavement tops, Glacier rims and domed undersides. The 10 bridges are parts in `Workspace > Map > Space > Bridges`: a violet deck with neon cyan rails.
* **Slope check:** the tool warns about any drivable, dry ground steeper than `MaxDriveSlopeDeg` (35°) and gives example coordinates. Mesas, the crater and lava channels are exempt on purpose. Pass `SlopeMarkers = true` to also place red neon pins at those spots.

### Offline verification (already run)
I ran the real config and generator code in the Luau CLI with Roblox stubs and a Perlin `math.noise`.
* The layout checks all pass. They cover zones inside their biome and clear of roads, landmarks, lagoons, mesas, the volcano and lava; zones not overlapping each other; plots clear of the road; hub props inside the plaza and off the road corridor; Space zones on their islands; islands not overlapping; and bridge slopes (max 9.9°).
* Slopes over 35° are 0% in Hub, Plains, Tropical and Volcanic, and **0.02 %** in Desert (two road cuts through a dune near (2454, 2)). The steepest point on the main road is **19.9°**, at the lava-bridge crossing. Studio's `math.noise` differs from the stub, so run the in-Studio report for the real figures.

### Setup
1. Create a Folder `ServerStorage > DevTools`.
2. Insert a ModuleScript named `TerrainGenerator` under it and paste the file in.
3. Make sure `Workspace > Map > Space` exists (the tool creates it if it's missing).
4. **Save the place first.** A full generate replaces **all** terrain via `Terrain:Clear()`.

### Run (Command Bar, Edit mode, not Play)
```lua
local m = game.ServerStorage.DevTools.TerrainGenerator:Clone(); m.Parent = game.ServerStorage.DevTools
local ok, err = pcall(function() require(m).Generate() end); m:Destroy(); if not ok then warn(err) end
```
Variants: replace `Generate()` with one of these.
* `Generate({ SlopeMarkers = true })`
* `Generate({ Only = "Desert" })`: rebuilds one biome plus its blend strips.
* `Generate({ SkipSpace = true })`
* `Clear()`: wipes all terrain, the bridges and the slope markers.

Cloning the module first gets around the Command Bar's `require` cache, so edits are always picked up. The tool re-requires WorldConfig the same way.

### Test in Studio
1. Run `Generate()`. The Output should show `Ground N/2184 (…%)`, then `Space island 1/10 … 10/10`, then `Built 10 Space bridges`, a slope report, and `Done in X s`. Expect about 1–2 minutes.
2. Fly the camera from (0, 200, 0) eastwards and check:
   * The Hub is a flat plaza with a cobblestone core, a ring and spokes to the 8 flat plot pads.
   * Plains has green rolling hills with a dirt road and dirt patches.
   * Desert has dunes, two flat Salt basins (the road crosses one) and three Sandstone mesas.
   * Tropical has LeafyGrass, Limestone beaches, two shallow lagoons and sea along the north and south edges.
   * Volcanic has Slate ash plains by the road, jagged Basalt to the south, the volcano with a CrackedLava crater, and two lava rivers. The east river crosses the road near (4890, 203), which is the lava-bridge spot.
   * Space: go to (4600, 800, 0) and look down. You should see 10 islands and glowing bridges.
3. Check there are no seams: at X = 400, 1600, 2800 and 4000 the height and material should blend smoothly.
4. Run the tool again. The result should be identical, because it is idempotent and seeded.
5. Change one biome's `Seed` in WorldConfig and run `Generate({ Only = "Plains" })`. Only Plains should change.
6. Run `Clear()`. All terrain and bridges should disappear.

---

## Shared: BuildKit

`ServerStorage > DevTools > BuildKit` (ModuleScript) is required by every generator. It provides:
* part defaults for mobile. Parts are anchored, and anything whose longest side is under 8 studs gets **CastShadow off**. **CanTouch is off** unless you ask for it, and **CanQuery follows CanCollide**.
* signs (SurfaceGui, FredokaOne font, outlined text, `LightInfluence = 0`) and billboards.
* ProximityPrompts built from `WorldConfig.Prompts`: `HoldDuration 0`, range 12, no line-of-sight check, tappable, E key / gamepad X.
* `groundY()` (raycasts terrain only), `tag()`, `reset()` (the idempotent container), and `freshRequire()`.

**Setup:** insert a ModuleScript named `BuildKit` into `ServerStorage > DevTools` and paste the file in. Nothing to test on its own.

---

## 4. Hub build

`ServerStorage > DevTools > HubGenerator` (ModuleScript). Its output goes to `Workspace > Map > Hub > Generated` and is rebuilt on every run.

| Piece | Tag / attributes | Interaction hook for Phase 3 |
|---|---|---|
| `Spawn` | SpawnLocation (Neutral, no forcefield) | – |
| `Shop_Upgrades/Pets/Vehicles/Cosmetics` | NPC model tagged **`ShopNPC`**, `Shop = "<name>"` | `ShopNPC.Body.Prompt` ("Open Pets") |
| `SellPad` | part `Pad` tagged **`SellPad`** (CanTouch on), green neon ring, PointLight | `.Touched` |
| `Leaderboard_<Stat>` ×3 | model tagged **`Leaderboard`**, `Stat = Energy/Rebirths/StormsCaught` | add rows to `Board.BoardGui.List` (UIListLayout) |
| `RebirthAltar` | model tagged **`RebirthAltar`** | `Top.Prompt` |
| `EventBoard` | model tagged **`EventBoard`** | set `Board.BoardGui.Status.Text` |
| `DailyChest` | model tagged **`DailyChest`** | `Base.Prompt`, animate `Lid` |
| `BaseTeleportPad` | part tagged **`TeleportPad`**, `Destination = "Base"` | handled by TeleportPadService |

Shops have a colour-coded chunky stepped roof, a big two-sided sign above the roof, an open front facing the plaza, a counter and a round friendly shopkeeper. The design is parts-only so you can swap each model for a mesh later.

### Setup
1. Steps 2–3 must be done first. The terrain gives the plaza height; without terrain the Hub falls back to Y = 0.
2. Insert a ModuleScript named `HubGenerator` into `ServerStorage > DevTools`.
3. Run it from the Command Bar in Edit mode:
```lua
local m = game.ServerStorage.DevTools.HubGenerator:Clone(); m.Parent = game.ServerStorage.DevTools
local ok, err = pcall(function() require(m).Build() end); m:Destroy(); if not ok then warn(err) end
```

### Test
1. The Output should show `[HubGenerator] Built Hub: N parts…` with N around 110, well under the Hub budget of 900.
2. Look down from above the plaza. The 4 shops should sit on the west half facing the centre. The east corridor (the road to Plains) should be clear, and the sell pad, chest, board and leaderboards should be on the east side.
3. Press **Play**, walk to a shopkeeper, and check that "Open Pets" etc. appears within about 12 studs. Use **Device Emulator → iPhone** and check the prompt can be tapped.
4. Paste `print(#game.CollectionService:GetTagged("ShopNPC"), #game.CollectionService:GetTagged("Leaderboard"))` in the Command Bar. It should print `4 3`.
5. Run the generator again. The part count should be identical and there should be no duplicates.

---

## 5. Base plots

### 5a. BaseTemplateBuilder
`ServerStorage > DevTools > BaseTemplateBuilder` (ModuleScript) builds **`ServerStorage > ServerAssets > BaseTemplate`**. The template is built at the origin with its entrance facing −Z. Everything in it is sized from `WorldConfig.Bases`.

| Child | What it is | Tag / attributes |
|---|---|---|
| `Floor` | 110×1×110 platform (PrimaryPart) | – |
| `ThemeRegion`, `ThemeAccent`×4 | recolourable base-theme region | attribute `ThemeRegion = true` |
| `CoreRack` | 3 stepped tiers, 24 pedestals | 24 Attachments **`CoreSlot`**: `SlotIndex` 1–24, `Unlocked` (first 8 = true) |
| `DefensePads` | 4 coral pads | Attachments **`DefenseSlot`**: `SlotIndex` 1–4 |
| `Entrance` | pillars + arch, 30-stud gap in the low wall | Attachment **`LaserGateSlot`** on `Floor`: `Width`, `Height` |
| `ClaimSign` | `Board.ClaimGui.Headshot` (ImageLabel) + `OwnerName` (TextLabel) | – |
| `HubTeleportPad` | pad inside the entrance | **`TeleportPad`**, `Destination = "Hub"` |
| `Floor.BaseSpawn` | Attachment where the owner arrives, facing the rack | – |
| `BaseZone` | invisible 110×80×110 volume (no collide/query/touch) | **`BaseZone`**, `PlotId` |

**Run:**
```lua
local m = game.ServerStorage.DevTools.BaseTemplateBuilder:Clone(); m.Parent = game.ServerStorage.DevTools
local ok, err = pcall(function() require(m).Build() end); m:Destroy(); if not ok then warn(err) end
```
The Output should show `Built … BaseTemplate (~55 parts, 24 CoreSlots, 4 DefenseSlots)`, well under the 250-part budget.

### 5b. BaseService + TeleportPadService + ServicesLoader
* **BaseService** `Init()` clones the template into `Workspace > Bases > PlotN > Base` at each plot's CFrame. The entrance faces the Hub and the model is set to `ModelStreamingMode = Atomic`. It sets `PlotId` on each plot and zone. `Start()` assigns the first free plot on join: it sets `OwnerUserId` and `OwnerName` on `PlotN`, sets `PlotId` on the Player, and updates the sign with the display name and a headshot (fetched asynchronously). On leave it releases the plot, resets the sign and relocks the extra core slots.
  API: `GetPlot`, `GetPlotById`, `GetOwnerUserId`, `GetBaseSpawnCFrame`, `GetCoreSlots`, `GetDefenseSlots`, `SetUnlockedCoreSlots(plotId, n)` (8 → 24, lights the pedestals), `IsInsideBase(plotId, pos)`, plus the events `PlotAssigned` and `PlotReleased`.
* **TeleportPadService** handles every **`TeleportPad`** based on its `Destination`: `"Hub"`, `"Base"` or `"Biome:<Name>"` (the last one is ready for the Navigation step). A seated player's whole vehicle under `Workspace.Vehicles` is moved. It calls `RequestStreamAroundAsync` before moving so the destination is loaded when you arrive. There is a 3 s per-player cooldown, and players arrive *beside* pads rather than on them, so they don't bounce back. API: `Teleport(player, destination)`, `TeleportToCFrame(player, cf)`.
* **ServicesLoader** (Script) requires every ModuleScript in `Services`, calls `Init` on all of them (BaseService first), then `Start` on all. If Phase 1 already has a loader, skip it.

### Setup
1. Run **BaseTemplateBuilder** (above). The template must exist before you press Play.
2. Check that `Workspace > Bases > Plot1…Plot8` exist. They're created if missing, and a Folder is converted to a Model.
3. Add ModuleScripts `BaseService` and `TeleportPadService` to `ServerScriptService > Services`.
4. Add the Script `ServicesLoader` to `ServerScriptService` (skip it if you already have a loader).
5. **Game Settings → Places → Max Players = 8** (one plot per player).

### Test
1. **Play Solo:** the Output shows `[BaseService] 8 plots ready` and `[ServicesLoader] Services started`. Walk to the plot east of the road (Plot1 or Plot8). One of them should show your name and headshot on the claim sign.
2. In the server Command Bar, run `print(game.Players:GetPlayers()[1]:GetAttribute("PlotId"))`. It should print a number from 1 to 8.
3. Step on **MY BASE** in the Hub. You should arrive inside your base facing the rack. Step on **TO HUB** in the base and you should arrive next to the spawn.
4. **Test → Clients and Servers → 3 players:** each player should get a different plot. Close one client and that plot's sign should go back to "Free Plot!".
5. In the server Command Bar, run `local BS = require(game.ServerScriptService.Services.BaseService); BS.SetUnlockedCoreSlots(1, 16)`. Plot1 should light 16 cyan pedestals.
6. Sit in any vehicle model placed under `Workspace.Vehicles` and drive onto a pad. The whole vehicle should teleport.
