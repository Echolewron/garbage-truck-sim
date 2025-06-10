-- Chunk Provider - provides building/road chunks, or tiles, upon request
local module = {}

local sss = game:GetService("ServerScriptService")
local sstorage = game:GetService("ServerStorage")
local rStorage = game:GetService("ReplicatedStorage")

local remote = rStorage.Remote

local utils = require(rStorage.CodeUtils)
local ObjectKeyTable = require(rStorage.ObjectKeyTable)
local boolnum = utils.boolnum

local core_folder = workspace.GeneratedStructures

module.world_map = ObjectKeyTable.new()

module.seed = 5.5 -- Seed for RNG. Can be any arbitrary number
module.chunk_size = Vector3.new(50, 0, 50)
local block_length = workspace:GetAttribute("BlockLength") + 1

-- Library of available models
local models_root = sstorage.Models
local models = {
	houses = models_root.Houses:GetChildren(),
	road = {
		straight = models_root["Road-Straight"],
		junction = models_root["Road-3Junction"],
		intersection = models_root["Road-Intersection"],
	},
	fence = models_root.Fence,
}

local random = Random.new(module.seed)

--[[ Returns type of structure at that chunk
	1 : House
	2 : Horizontal Road
	3 : Vertical Road
	4 : Intersection
]]
local function GetStructureType(x : number, y : number) : number
	return boolnum(x % 3 == 0) + 2 * boolnum(y % block_length == 0) + 1
end

-- Places appropriate structure based on the x, y position of the chunk
function module.PlaceStructure(position : Vector2)
	local x = position.X
	local y = position.Y
	
	local structure_pos = CFrame.new(module.chunk_size * Vector3.new(x, 0, y))
	
	local build_functions = {
		function() -- House
			local house = models.houses[random:NextInteger(1, #models.houses)]:Clone()
			
			-- Names house model in "HouseX,Y" format
			house.Name = string.format("House%i,%i", x, y)
			
			if x % 3 == 1 then
				structure_pos *= CFrame.Angles(0, math.rad(180), 0)
			end
			
			for _, bin in pairs(house.GarbageBins:GetChildren()) do
				local click_detector : ClickDetector = bin.ClickDetector
				
				click_detector.MouseClick:Connect(function(player)
					remote:FireClient(player, "Bin PickUp", house.Name ,bin.Name)
				end)
			end

			return house
		end,

		function() -- Horizontal Road
			local road = models.road.straight:Clone()
			structure_pos *= CFrame.Angles(0, math.rad(90), 0)
			return road
		end,

		function() -- Vertical Road
			local road = models.road.straight:Clone()
			return road
		end,

		function() -- Intersection
			local intersection = models.road.intersection:Clone()
			return intersection
		end,
	}
	
	local structure_type = GetStructureType(x, y)
	local structure_model : Model = build_functions[structure_type]()
	structure_model:PivotTo(structure_pos)
	
	
	-- Adding Fence
	if x % 3 ~= 0 then
		local fence = models_root.Fence:Clone()
		fence:PivotTo(CFrame.new(structure_model.WorldPivot.Position))
		fence.Parent = structure_model
	end

	if x % 3 == 1 and y % block_length ~= 0 then
		local fence = models_root.Fence:Clone()
		fence:PivotTo(CFrame.new(structure_model.WorldPivot.Position) * CFrame.Angles(0, math.rad(-90), 0))
		fence.Parent = structure_model
	end
	
	
	structure_model:SetAttribute("pos", Vector2.new(x,y))--DEBUG
	
	module.world_map:Put(position, structure_model)
	
	structure_model.Parent = core_folder
end


-- Properly removes structure at chunk x,y
function module.RemoveChunk(position : Vector2)
	local chunk = module.world_map:Get(position)
	if chunk then
		chunk:Destroy()
		module.world_map:Remove(position)
	end
	
end


return module