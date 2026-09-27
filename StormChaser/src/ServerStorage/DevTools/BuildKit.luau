--[[
	BuildKit  (ModuleScript)
	Location: ServerStorage > DevTools > BuildKit

	Shared helpers for every edit-time generator (Hub, BaseTemplate, Zones,
	Props, Navigation). Keeps part defaults, signs, prompts and tagging
	consistent so Phase 3 code can rely on them.

	Performance defaults baked into BuildKit.part():
	  * Anchored = true
	  * CastShadow = false for anything whose largest side is < 8 studs
	  * Smooth surfaces, SmoothPlastic unless a material is given
	  * CanTouch = false unless explicitly enabled (touch events cost CPU)
	  * CanQuery stays true only for things that should block raycasts/camera
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BuildKit = {}

--------------------------------------------------------------------------------
-- MODULE LOADING
--------------------------------------------------------------------------------
-- In Edit mode the Command Bar caches require() results; cloning the module
-- first guarantees the latest source is used.
function BuildKit.freshRequire(module: ModuleScript): any
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

function BuildKit.config(): any
	return BuildKit.freshRequire(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("WorldConfig"))
end

--------------------------------------------------------------------------------
-- HIERARCHY
--------------------------------------------------------------------------------
function BuildKit.ensure(parent: Instance, name: string, className: string?): Instance
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local inst = Instance.new(className or "Folder")
	inst.Name = name
	inst.Parent = parent
	return inst
end

-- Destroys parent[name] (if any) and creates a fresh empty container.
-- This is how every generator stays idempotent: it only ever owns one
-- container and rebuilds it from scratch.
function BuildKit.reset(parent: Instance, name: string, className: string?): Instance
	local old = parent:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local inst = Instance.new(className or "Folder")
	inst.Name = name
	inst.Parent = parent
	return inst
end

function BuildKit.model(name: string, parent: Instance?): Model
	local m = Instance.new("Model")
	m.Name = name
	if parent then
		m.Parent = parent
	end
	return m
end

--------------------------------------------------------------------------------
-- PARTS
--------------------------------------------------------------------------------
--[[
	BuildKit.part({
		Name, Size, CFrame, Color (Color3 or hex string), Material, Shape,
		Transparency, CanCollide, CanTouch, CanQuery, CastShadow, Parent, ClassName
	})
]]
function BuildKit.part(props: { [string]: any }): BasePart
	local p = Instance.new(props.ClassName or "Part") :: any
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Size = props.Size or Vector3.new(4, 4, 4)
	if props.Shape and p:IsA("Part") then
		p.Shape = props.Shape
	end
	if props.CFrame then
		p.CFrame = props.CFrame
	end
	local color = props.Color
	if typeof(color) == "string" then
		color = Color3.fromHex(color)
	end
	if color then
		p.Color = color
	end
	if props.MaterialVariant then
		p.MaterialVariant = props.MaterialVariant
	end
	p.Transparency = props.Transparency or 0
	p.CanCollide = if props.CanCollide == nil then true else props.CanCollide
	p.CanTouch = props.CanTouch == true
	p.CanQuery = if props.CanQuery == nil then p.CanCollide else props.CanQuery
	local largest = math.max(p.Size.X, p.Size.Y, p.Size.Z)
	p.CastShadow = if props.CastShadow == nil then largest >= 8 else props.CastShadow
	p.Name = props.Name or "Part"
	if props.Parent then
		p.Parent = props.Parent
	end
	return p
end

-- A vertical cylinder (Roblox cylinders run along X, so we rotate 90 deg).
-- `base` is the CFrame of the cylinder's BOTTOM centre.
function BuildKit.disc(props: { [string]: any }, base: CFrame, radius: number, height: number): BasePart
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(height, radius * 2, radius * 2)
	props.CFrame = base * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
	return BuildKit.part(props)
end

--------------------------------------------------------------------------------
-- GROUND
--------------------------------------------------------------------------------
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { Workspace.Terrain }
groundParams.IgnoreWater = false

-- Terrain height at (x, z). Falls back to `fallbackY` if nothing is hit
-- (e.g. terrain not generated yet).
function BuildKit.groundY(x: number, z: number, fallbackY: number?, fromY: number?): number
	local origin = Vector3.new(x, fromY or 1200, z)
	local hit = Workspace:Raycast(origin, Vector3.new(0, -2000, 0), groundParams)
	if hit then
		return hit.Position.Y
	end
	return fallbackY or 0
end

-- Like groundY but also returns the surface normal and material.
function BuildKit.groundHit(x: number, z: number, fromY: number?): RaycastResult?
	return Workspace:Raycast(Vector3.new(x, fromY or 1200, z), Vector3.new(0, -2000, 0), groundParams)
end

--------------------------------------------------------------------------------
-- TAGS / ATTRIBUTES
--------------------------------------------------------------------------------
function BuildKit.tag(inst: Instance, tag: string, attributes: { [string]: any }?): Instance
	CollectionService:AddTag(inst, tag)
	if attributes then
		for k, v in attributes do
			inst:SetAttribute(k, v)
		end
	end
	return inst
end

--------------------------------------------------------------------------------
-- TEXT: signs and billboards (chunky, readable on phones)
--------------------------------------------------------------------------------
local FONT = Enum.Font.FredokaOne

-- SurfaceGui with one big TextLabel on `part`'s `face`.
function BuildKit.sign(part: BasePart, text: string, opts: { [string]: any }?): SurfaceGui
	local o = opts or {}
	local gui = Instance.new("SurfaceGui")
	gui.Name = o.Name or "SignGui"
	gui.Face = o.Face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = o.PixelsPerStud or 20
	gui.LightInfluence = 0 -- always bright and readable
	gui.MaxDistance = o.MaxDistance or 250
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = o.TextColor or Color3.new(1, 1, 1)
	label.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = o.StrokeThickness or 4
	stroke.Color = o.StrokeColor or Color3.fromRGB(40, 30, 60)
	stroke.Parent = label

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0.06, 0), UDim.new(0.06, 0)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0.1, 0), UDim.new(0.1, 0)
	pad.Parent = label
	return gui
end

-- Floating label above a part (visible from far away; fades by distance).
function BuildKit.billboard(adornee: BasePart, text: string, opts: { [string]: any }?): BillboardGui
	local o = opts or {}
	local gui = Instance.new("BillboardGui")
	gui.Name = o.Name or "Label"
	gui.Size = o.Size or UDim2.fromScale(10, 3) -- studs (scale units on billboards)
	gui.StudsOffsetWorldSpace = o.Offset or Vector3.new(0, 6, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = o.MaxDistance or 160
	gui.AlwaysOnTop = o.AlwaysOnTop == true
	gui.Adornee = adornee
	gui.Parent = adornee

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = o.TextColor or Color3.new(1, 1, 1)
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = o.StrokeColor or Color3.fromRGB(40, 30, 60)
	stroke.Parent = label
	return gui
end

--------------------------------------------------------------------------------
-- PROMPTS (mobile-friendly defaults from WorldConfig.Prompts)
--------------------------------------------------------------------------------
function BuildKit.prompt(parent: Instance, config: any, actionText: string, objectText: string?): ProximityPrompt
	local d = config.Prompts
	local p = Instance.new("ProximityPrompt")
	p.Name = "Prompt"
	p.ActionText = actionText
	p.ObjectText = objectText or ""
	p.HoldDuration = d.HoldDuration
	p.MaxActivationDistance = d.MaxActivationDistance
	p.RequiresLineOfSight = d.RequiresLineOfSight
	p.KeyboardKeyCode = d.KeyboardKeyCode
	p.GamepadKeyCode = d.GamepadKeyCode
	p.ClickablePrompt = true -- tap on phones, click on PC
	p.Style = Enum.ProximityPromptStyle.Default
	p.Parent = parent
	return p
end

return BuildKit
