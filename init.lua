rocket = {}
local MP = minetest.get_modpath("rocket").."/"

local random = math.random

local require_blueprint = minetest.settings:get_bool("rocket_require_blueprint")
local boost = tonumber(minetest.settings:get("rocket_boost")) or 50 -- velocity
local particle_amount = tonumber(minetest.settings:get("rocket_particle_amount") or 25) -- number of particles per rocket
local particle_amount_explode = tonumber(minetest.settings:get("rocket_particle_amount_explode") or 50) -- number of particles per rocket explosion

local hex = {"4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F"}

local spawn_explosion_particles = function(pos)
	local color = hex[random(1, 12)]..hex[random(1, 12)]..hex[random(1, 12)]
	local s = 5

	minetest.add_particlespawner({
		amount = particle_amount_explode,
		time = 0.01, -- seconds to spawn all particles
		minpos = {x=pos.x, y=pos.y, z=pos.z},
		maxpos = {x=pos.x, y=pos.y, z=pos.z},
		minvel = {x=-s, y=-s, z=-s},
		maxvel = {x=s, y=s, z=s},
		minacc = {x=0, y=0, z=0},
		maxacc = {x=0, y=0, z=0},
		minexptime = 3.0,
		maxexptime = 4.0,
		minsize = 2,
		maxsize = 5,
		collisiondetection = false,
		vertical = false,
		texture = "rocket-star.png^[multiply:#"..color,
		glow = 15
	})
end

local spawn_smoke_particles = function(pos, pct, dx, dy, dz, y_offset)
	minetest.add_particlespawner({
		amount = particle_amount*pct,
		time = 0.01, -- seconds to spawn all particles
		minpos = {x=pos.x-0.4, y=pos.y+y_offset-0.4, z=pos.z-0.4},
		maxpos = {x=pos.x+0.4, y=pos.y+y_offset+0.4, z=pos.z+0.4},
		minvel = {x=dx, y=dy, z=dz},
		maxvel = {x=dx, y=dy, z=dz},
		minacc = {x=0, y=0, z=0},
		maxacc = {x=0, y=0, z=0},
		minexptime = 2.0,
		maxexptime = 2.0,
		minsize = 0.5,
		maxsize = 2.0,
		collisiondetection = true,
		vertical = false,
		texture = "tnt_smoke.png",
		glow = 15
	})
end

local explode = function(pos, rocket)
	minetest.sound_play("tnt_explode", {pos = pos, gain = 10.0, max_hear_distance = 80})
	spawn_explosion_particles(pos)

	local objs = minetest.get_objects_inside_radius(pos, 2)
	if objs then
		for _,o in pairs(objs) do
			local e = o:get_luaentity()
			if o.punch and not o:get_armor_groups().immortal and (not e or not e.name or e.name ~= "rocket:entity") then
				-- damage entity, excluding other rockets
				o:punch(minetest.get_player_by_name(rocket.owner) or rocket.object, 1.0, {full_punch_interval = 1.0, damage_groups = {fleshy = 1}}, nil)
			end
		end
	end
end

minetest.register_entity("rocket:entity", {
	name = "rocket:entity",
	hp_max = 1,
	visual = "wielditem",
	visual_size = {x = 0.333, y = 0.333},
	textures = {"rocket:rocket"},
	collisionbox = {-0.15,-0.15,-0.15,0.15,0.15,0.15},
	physical = false,
	drop = false,

	timer = 0,
	on_step = function(self, dtime)
		self.timer = self.timer + dtime
		local pos = self.object:get_pos()

		if self.timer > 2.0 then
			-- timeout
			explode(pos, self)
			self.object:remove()
			return
		end

		local node = minetest.get_node(pos)
		if node then
			local ndef = minetest.registered_nodes[node.name]
			if ndef.drawtype == "liquid" then
				-- hit liquid
				self.object:remove()
				return
			elseif ndef.walkable then
				-- hit node
				explode(pos, self)
				self.object:remove()
				return
			end
		end

		local objs = minetest.get_objects_inside_radius(pos, 1.0)
		if objs and #objs > 1 then
			-- hit entity - must shoot player's legs
			explode(pos, self)
			self.object:remove()
			return
		end
	end,
})

minetest.register_craftitem("rocket:rocket", {
	description = "Rocket",
	inventory_image = "rocket-item.png",
	wield_image = "rocket-item.png",
	on_use = function(itemstack, user, pointed_thing)
		if user and user:is_player() then
			local pos = user:get_pos()
			local d = user:get_look_dir()
			local node = minetest.get_node(pos)

			if node and minetest.registered_nodes[node.name].drawtype ~= "liquid" then
				if user:get_player_control()["sneak"] or user.is_fake_player then
					-- launch rocket
					pos.y = pos.y + 1
					local rocket_pos = {x = pos.x + 2*d.x, y = pos.y + 2*d.y, z = pos.z + 2*d.z}

					local entity = minetest.add_entity(rocket_pos, "rocket:entity")
					entity:add_velocity({x = d.x * 10, y = d.y * 10, z = d.z * 10})
					entity:set_rotation({z = 0, x = -(user:get_look_vertical() + 3.1415926/2), y = user:get_look_horizontal()})
					if user.is_fake_player then
						-- pipeworks fake player
						local meta = minetest.get_meta(user:get_pos())
						entity:get_luaentity().owner = meta and meta:get_string("owner") or ""
					else
						entity:get_luaentity().owner = user:get_player_name()
					end
					minetest.sound_play("rocket_whistle", {object = entity, gain = 3.0, max_hear_distance = 15})

					spawn_smoke_particles(pos, 0.5, -d.x, -d.y, -d.z, 0.0)
				else
					-- boost player
					local v = user:get_player_velocity()
					v.x = d.x*boost - v.x
					v.y = d.y*boost - v.y
					v.z = d.z*boost - v.z
					user:add_player_velocity(v)

					minetest.sound_play("rocket_whistle", {object = user, gain = 3.0, max_hear_distance = 15})

					spawn_smoke_particles(pos, 1.0, -d.x, -d.y, -d.z, 1.0)
				end
			else
				-- in liquid
				minetest.sound_play("default_item_smoke", {pos = pos, gain = 3.0, max_hear_distance = 5})
				spawn_smoke_particles(pos, 1.0, d.x, d.y, d.z, 1.0)
			end

			itemstack:take_item(1)
		end
		return itemstack
	end,
})

if require_blueprint then
	minetest.register_craftitem("rocket:rocket_blueprint", {
		description = "Rocket Blueprint",
		inventory_image = "rocket-blueprint.png",
		stack_max = 1,
	})

	minetest.register_craft({
		output = "rocket:rocket",
		recipe = {
			{"default:paper", ""},
			{"tnt:gunpowder", "rocket:rocket_blueprint"},
			{"farming:string", ""},
		},
		replacements = {{"rocket:rocket_blueprint", "rocket:rocket_blueprint"}},
	})
else
	minetest.register_craft({
		output = "rocket:rocket",
		recipe = {
			{"default:paper"},
			{"tnt:gunpowder"},
			{"farming:string"},
		},
	})
end

print("[MOD] Rocket loaded")
