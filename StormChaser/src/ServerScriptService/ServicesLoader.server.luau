--[[
	ServicesLoader  (Script)
	Location: ServerScriptService > ServicesLoader

	Requires every ModuleScript in ServerScriptService > Services, then calls
	Init() on all of them (setup, no cross-service calls), then Start() on all
	(connect events, may call other services).

	If Phase 1 already has a service loader, do NOT add this Script: make sure
	your loader calls BaseService.Init() before TeleportPadService.Start().
]]

local ServerScriptService = game:GetService("ServerScriptService")

local servicesFolder = ServerScriptService:WaitForChild("Services")

-- Init order matters only for services that build world state others read.
local INIT_FIRST = { BaseService = 1 }

local modules = {}
for _, child in servicesFolder:GetChildren() do
	if child:IsA("ModuleScript") then
		table.insert(modules, child)
	end
end
table.sort(modules, function(a, b)
	local pa, pb = INIT_FIRST[a.Name] or 100, INIT_FIRST[b.Name] or 100
	if pa ~= pb then
		return pa < pb
	end
	return a.Name < b.Name
end)

local services = {}
for _, module in modules do
	local ok, service = pcall(require, module)
	if ok then
		services[module.Name] = service
	else
		warn(("[ServicesLoader] Failed to require %s: %s"):format(module.Name, tostring(service)))
	end
end

for _, module in modules do
	local service = services[module.Name]
	if service and type(service.Init) == "function" then
		local ok, err = pcall(service.Init)
		if not ok then
			warn(("[ServicesLoader] %s.Init failed: %s"):format(module.Name, tostring(err)))
		end
	end
end

for _, module in modules do
	local service = services[module.Name]
	if service and type(service.Start) == "function" then
		task.spawn(function()
			local ok, err = pcall(service.Start)
			if not ok then
				warn(("[ServicesLoader] %s.Start failed: %s"):format(module.Name, tostring(err)))
			end
		end)
	end
end

print("[ServicesLoader] Services started")
