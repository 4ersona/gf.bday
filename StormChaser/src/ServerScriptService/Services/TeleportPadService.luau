--[[
	TeleportPadService  (ModuleScript)
	Location: ServerScriptService > Services > TeleportPadService

	Handles every part tagged "TeleportPad". Its attribute Destination says where to go:
		"Hub"             -> WorldConfig.Teleport.HubArrival (next to the Hub spawn)
		"Base"            -> the toucher's own base (BaseService.GetBaseSpawnCFrame)
		"Biome:<Name>"    -> that biome's Teleporter point (used by Navigation step)

	Works on foot and in vehicles: if the player is seated, the whole vehicle
	model (a child of Workspace.Vehicles) is moved.

	Public API
		TeleportPadService.Teleport(player, destination: string) -> boolean
		TeleportPadService.TeleportToCFrame(player, cf: CFrame)
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WorldConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("WorldConfig"))
local BaseService = require(script.Parent:WaitForChild("BaseService"))

local TeleportPadService = {}

local lastTeleport: { [Player]: number } = {}

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { Workspace.Terrain }

-- Drop point on terrain at a world XZ, facing `lookDir` (optional).
local function groundCFrame(xz: Vector2, fallbackY: number): CFrame
	local hit = Workspace:Raycast(Vector3.new(xz.X, fallbackY + 400, xz.Y), Vector3.new(0, -800, 0), groundParams)
	local y = if hit then hit.Position.Y else fallbackY
	return CFrame.new(xz.X, y + WorldConfig.Teleport.ArrivalHeight, xz.Y)
end

local function resolve(player: Player, destination: string): CFrame?
	if destination == "Hub" then
		local hub = WorldConfig.Biomes.Hub
		return groundCFrame(WorldConfig.ToWorld("Hub", WorldConfig.Teleport.HubArrival), hub.Center.Y)
	elseif destination == "Base" then
		local cf = BaseService.GetBaseSpawnCFrame(player)
		return cf and cf + Vector3.new(0, WorldConfig.Teleport.ArrivalHeight, 0)
	end
	local biomeName = string.match(destination, "^Biome:(%w+)$")
	if biomeName then
		local biome = WorldConfig.Biomes[biomeName]
		if biome and biome.Teleporter then
			-- Arrive a little beside the pad so it doesn't bounce you straight back.
			local xz = WorldConfig.ToWorld(biomeName, biome.Teleporter + Vector2.new(0, 16))
			return groundCFrame(xz, biome.Center.Y)
		end
	end
	warn("[TeleportPadService] Unknown destination: " .. tostring(destination))
	return nil
end

-- Moves the player (or their vehicle) to `cf`.
function TeleportPadService.TeleportToCFrame(player: Player, cf: CFrame)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	-- Ask the client to stream the destination first (StreamingEnabled).
	pcall(function()
		player:RequestStreamAroundAsync(cf.Position, 5)
	end)

	local seat = humanoid.SeatPart
	local vehiclesFolder = Workspace:FindFirstChild("Vehicles")
	if seat and vehiclesFolder and seat:IsDescendantOf(vehiclesFolder) then
		-- Walk up to the top-level vehicle model directly under Workspace.Vehicles
		local vehicle: Instance = seat
		while vehicle.Parent and vehicle.Parent ~= vehiclesFolder do
			vehicle = vehicle.Parent
		end
		if vehicle:IsA("Model") then
			vehicle:PivotTo(cf)
			for _, part in vehicle:GetDescendants() do
				if part:IsA("BasePart") then
					part.AssemblyLinearVelocity = Vector3.zero
					part.AssemblyAngularVelocity = Vector3.zero
				end
			end
			return
		end
	end
	if seat then
		humanoid.Sit = false
	end
	character:PivotTo(cf)
end

function TeleportPadService.Teleport(player: Player, destination: string): boolean
	local now = os.clock()
	if (lastTeleport[player] or 0) + WorldConfig.Teleport.Cooldown > now then
		return false
	end
	local cf = resolve(player, destination)
	if not cf then
		return false
	end
	lastTeleport[player] = now
	TeleportPadService.TeleportToCFrame(player, cf)
	return true
end

-- Which player (if any) does this touching part belong to? Characters and vehicles.
local function playerFromHit(hit: BasePart): Player?
	-- On foot: walk up models (accessories are nested) until one is a character.
	local model = hit:FindFirstAncestorOfClass("Model")
	while model do
		local p = Players:GetPlayerFromCharacter(model)
		if p then
			return p
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	-- In a vehicle: only parts under Workspace.Vehicles are considered.
	local vehiclesFolder = Workspace:FindFirstChild("Vehicles")
	if vehiclesFolder and hit:IsDescendantOf(vehiclesFolder) then
		local vehicle: Instance = hit
		while vehicle.Parent and vehicle.Parent ~= vehiclesFolder do
			vehicle = vehicle.Parent
		end
		local seat = vehicle:FindFirstChildWhichIsA("VehicleSeat", true) :: VehicleSeat?
		if seat and seat.Occupant then
			return Players:GetPlayerFromCharacter(seat.Occupant.Parent)
		end
	end
	return nil
end

local function bindPad(pad: Instance)
	if not pad:IsA("BasePart") then
		return
	end
	pad.CanTouch = true
	pad.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if player then
			TeleportPadService.Teleport(player, pad:GetAttribute("Destination") or "Hub")
		end
	end)
end

function TeleportPadService.Start()
	for _, pad in CollectionService:GetTagged("TeleportPad") do
		bindPad(pad)
	end
	-- Pads inside bases are cloned at runtime and may stream/appear later.
	CollectionService:GetInstanceAddedSignal("TeleportPad"):Connect(bindPad)
	Players.PlayerRemoving:Connect(function(player)
		lastTeleport[player] = nil
	end)
end

return TeleportPadService
