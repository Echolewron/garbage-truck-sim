local sss = game:GetService("ServerScriptService")
local sstorage = game:GetService("ServerStorage")
local rStorage = game:GetService("ReplicatedStorage")

local ChunkProvider = require(sss.ChunkProvider)        -- Module handling chunk placement/removal
local ObjectKeyTable = require(rStorage.ObjectKeyTable) -- Module with object keys (not used here)

local remote = rStorage.Remote
local rFunction = rStorage.rFunction

local old_pos : Vector2 = Vector2.one * math.huge       -- Last known center position
local world_gen_radius = script:GetAttribute("WorldGenRaduis") -- Radius around player to generate chunks

ChunkProvider.seed = script:GetAttribute("Seed")        -- Seed for procedural generation


-- Updates chunks around a new center position
local function UpdateWorld(new_pos : Vector2)
	
	if new_pos == old_pos then
		return  -- No change in position, skip update
	end
	
	local delta = new_pos - old_pos                     -- Vector difference between new and old positions
	local x_step : number = delta.X ~= 0 and -math.sign(delta.X) or 1 -- Direction for x-axis iteration
	local pos_sum = new_pos + old_pos                   -- Sum of positions, used in chunk removal
	
	for iy = new_pos.Y - world_gen_radius, new_pos.Y + world_gen_radius do
		local x_length : number
		local x_pos : number
		
		-- Determine number of chunks to add in this row (Y line)
		if math.abs(old_pos.Y - iy) <= world_gen_radius then
			
			-- If no horizontal movement, skip this Y line
			if delta.X == 0 then
				continue
			end
			
			x_length = math.abs(delta.X)  -- Number of new chunks horizontally
		else
			x_length = 2 * world_gen_radius + 1  -- Full width of chunks for new row
		end
		
		-- Loop through chunks to add/remove on the X axis
		for ix = new_pos.X - x_step * world_gen_radius, new_pos.X + x_step * (x_length - 1 - world_gen_radius), x_step do
			ChunkProvider.PlaceStructure(Vector2.new(ix, iy))             -- Place new chunk
			ChunkProvider.RemoveChunk(pos_sum - Vector2.new(ix, iy))      -- Remove old chunk no longer in range
		end
	end
	
	old_pos = new_pos  -- Update the last known center position
	
end

-- Remote function called by clients to update the world based on their position
function rFunction.OnServerInvoke(player, context, new_pos)
	if context == "Update World" and new_pos then
		UpdateWorld(new_pos)
		return ChunkProvider.world_map  -- Return current world map to client
	end
end
