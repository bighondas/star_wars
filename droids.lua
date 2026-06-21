local modname = minetest.get_current_modname()

local DROID_MOVE_SPEED = 1.5
local DROID_WANDER_SPEED = 0.8

local function droid_pick_wander_yaw(pos)
    local base = math.random() * math.pi * 2
    for i = 0, 7 do
        local yaw = base + i * (math.pi / 4)
        local dir = minetest.yaw_to_dir(yaw)
        local check = {x = pos.x + dir.x * 1.5, y = pos.y + 0.5, z = pos.z + dir.z * 1.5}
        local node = minetest.get_node(check)
        if node and minetest.registered_nodes[node.name]
        and not minetest.registered_nodes[node.name].walkable then
            return yaw
        end
    end
    return base + math.pi
end

local VEHICLE_NAMES = {
    "star_wars:speeder",
    "star_wars:xwing",
    "star_wars:tie_advanced",
}

local function find_nearest_vehicle(pos)
    local nearest = nil
    local nearest_dist = math.huge
    for _, obj in ipairs(minetest.get_objects_inside_radius(pos, 50)) do
        local ent = obj:get_luaentity()
        if ent then
            for _, vname in ipairs(VEHICLE_NAMES) do
                if ent.name == vname then
                    local vpos = obj:get_pos()
                    if vpos then
                        local dist = vector.distance(pos, vpos)
                        if dist < nearest_dist then
                            nearest_dist = dist
                            nearest = obj
                        end
                    end
                    break
                end
            end
        end
    end
    return nearest, nearest_dist
end

local function droid_consume_ingot(self)
    local inv = self.inventory_slots
    if not inv then return false end
    for index, item_string in pairs(inv) do
        if item_string and item_string ~= "" then
            local stack = ItemStack(item_string)
            if stack:get_name() == "default:steel_ingot" and stack:get_count() > 0 then
                stack:take_item(1)
                if stack:is_empty() then
                    inv[index] = nil
                else
                    inv[index] = stack:to_string()
                end
                return true
            end
        end
    end
    return false
end

local function droid_ai_step(self, dtime)
    local pos = self.object:get_pos()
    if not pos then return end

    self.move_timer   = (self.move_timer   or 0) + dtime
    self.jump_timer   = (self.jump_timer   or 0) + dtime
    self.idle_timer   = (self.idle_timer   or 0) + dtime
    self.repair_timer = (self.repair_timer or 0) + dtime

    local target_vehicle, dist = find_nearest_vehicle(pos)

    -- Repair logic
    if target_vehicle and dist <= 2.5 then
        local ent = target_vehicle:get_luaentity()
        if ent and self.repair_timer >= 5.0 then
            self.repair_timer = 0
            if ent._vehicle_hp and ent._max_hp and ent._vehicle_hp < ent._max_hp then
                if droid_consume_ingot(self) then
                    ent._vehicle_hp = math.min(ent._vehicle_hp + 1, ent._max_hp)
                end
            end
        end
    end

    -- Jump over obstacles
    if self.jump_timer > 0.3 then
        self.jump_timer = 0
        local yaw = self.object:get_yaw() or 0
        local dir = minetest.yaw_to_dir(yaw)

        local from_low  = {x = pos.x, y = pos.y + 0.5, z = pos.z}
        local to_low    = {x = pos.x + dir.x * 1.2, y = pos.y + 0.5, z = pos.z + dir.z * 1.2}
        local hit_low   = minetest.raycast(from_low, to_low, false, false):next()

        local from_high = {x = pos.x, y = pos.y + 1.5, z = pos.z}
        local to_high   = {x = pos.x + dir.x * 1.2, y = pos.y + 1.5, z = pos.z + dir.z * 1.2}
        local hit_high  = minetest.raycast(from_high, to_high, false, false):next()

        if hit_low and hit_low.type == "node" and not hit_high then
            self.object:set_velocity({
                x = dir.x * DROID_MOVE_SPEED,
                y = 5,
                z = dir.z * DROID_MOVE_SPEED,
            })
        end
    end

    if self.move_timer > 0.4 then
        self.move_timer = 0
        pos = self.object:get_pos()
        if not pos then return end

        local vel = self.object:get_velocity()

        if target_vehicle and dist > 2.5 then
            local vpos = target_vehicle:get_pos()
            if vpos then
                local dir_to = vector.normalize({
                    x = vpos.x - pos.x,
                    y = 0,
                    z = vpos.z - pos.z,
                })
                local yaw = minetest.dir_to_yaw(dir_to)
                self.object:set_yaw(yaw)
                self.object:set_velocity({
                    x = dir_to.x * DROID_MOVE_SPEED,
                    y = vel and vel.y or 0,
                    z = dir_to.z * DROID_MOVE_SPEED,
                })
                self.idle_timer = 0
                self.wander_yaw = nil
            end
        else
            local yaw = self.object:get_yaw() or 0
            local dir = minetest.yaw_to_dir(yaw)
            local ahead = {x = pos.x + dir.x * 1.2, y = pos.y + 0.5, z = pos.z + dir.z * 1.2}
            local ahead_node = minetest.get_node(ahead)
            local blocked = ahead_node
                and minetest.registered_nodes[ahead_node.name]
                and minetest.registered_nodes[ahead_node.name].walkable

            if not self.wander_yaw or self.idle_timer > 4.0 or blocked then
                self.idle_timer = 0
                self.wander_yaw = droid_pick_wander_yaw(pos)
                self.object:set_yaw(self.wander_yaw)
                yaw = self.wander_yaw
                dir = minetest.yaw_to_dir(yaw)
            end

            self.object:set_velocity({
                x = dir.x * DROID_WANDER_SPEED,
                y = vel and vel.y or 0,
                z = dir.z * DROID_WANDER_SPEED,
            })
        end
    end
end

-- ============================================================
-- DROID MOBS
-- ============================================================

--R2-D2

minetest.register_entity("star_wars:r2d2", {
    initial_properties = {
        physical             = true,
        visual               = "mesh",
        mesh                 = "droid.obj",
        textures             = {"r2d2.png"},
        visual_size          = {x = 6, y = 6, z = 6},
        collisionbox = {-0.3, -0.3, -0.3, 0.3, 1.0, 0.3},
        makes_footstep_sound = true,
        hp_max               = 15,
    },
    is_npc    = true,
    move_timer = 0,
    idle_timer = 0,
    physical = true,
    sound_death = "star_wars_droid_death",
    on_activate = function(self, staticdata, dtime_s)
        self.inventory_slots = {}
        self.msg_cooldown = 0
        if staticdata and staticdata ~= "" then
            local data = minetest.deserialize(staticdata)
            if data and data.inventory_slots then
                self.inventory_slots = data.inventory_slots
            end
        end
        self.object:set_acceleration({x = 0, y = -10, z = 0})
    end,

    get_staticdata = function(self)
        return minetest.serialize({
            inventory_slots = self.inventory_slots
        })
    end,
     
    on_rightclick = function(self, clicker)
        if not clicker or not clicker:is_player() then return end
        
        local player_name = clicker:get_player_name()
        
        local inv_name = "r2d2_tmp_" .. player_name
        local detached_inv = minetest.create_detached_inventory(inv_name, {
            allow_move = function(inv, from_list, from_index, to_list, to_index, count, player)
                return count
            end,
            allow_put = function(inv, listname, index, stack, player)
                if stack:get_name() ~= "default:steel_ingot" then
                    if (self.msg_cooldown or 0) <= 0 then
                        self.msg_cooldown = 2.0
                        minetest.chat_send_player(player:get_player_name(), "Only steel ingots are allowed.")
                    end
                    return 0
                end
                return stack:get_count()
            end,
            allow_take = function(inv, listname, index, stack, player)
                return stack:get_count()
            end,
            on_put = function(inv, listname, index, stack, player)
                self.inventory_slots[index] = stack:to_string()
            end,
            on_take = function(inv, listname, index, stack, player)
                local remaining = inv:get_stack(listname, index)
                if remaining:is_empty() then
                    self.inventory_slots[index] = nil
                else
                    self.inventory_slots[index] = remaining:to_string()
                end
            end,
            on_move = function(inv, from_list, from_index, to_list, to_index, count, player)
                self.inventory_slots[from_index] = inv:get_stack(from_list, from_index):to_string()
                self.inventory_slots[to_index] = inv:get_stack(to_list, to_index):to_string()
            end,
        })

        detached_inv:set_size("main", 8)
        for index, item_string in pairs(self.inventory_slots) do
            detached_inv:set_stack("main", index, ItemStack(item_string))
        end

        local formspec = "size[8,9]" ..
            "list[detached:" .. inv_name .. ";main;0,0.3;8,4;]" .. 
            "list[current_player;main;0,4.85;8,4;]" ..             
            "listring[detached:" .. inv_name .. ";main]" ..          
            "listring[current_player;main]"

        minetest.show_formspec(player_name, "star_wars:r2d2_inventory", formspec)
    end,

    on_death = function(self, killer)
        minetest.sound_play(self.sound_death, {pos = self.object:get_pos(), gain = 1.0, max_hear_distance = 10})
        local pos = self.object:get_pos()
        if pos then
           minetest.add_item(pos, "star_wars:r2d2_spawn_egg")
            if self.inventory_slots then
                for _, item_string in pairs(self.inventory_slots) do
                    if item_string and item_string ~= "" then
                        minetest.add_item(pos, ItemStack(item_string))
                    end
                end
            end
        end
    end,
    on_step = function(self, dtime)
        self.msg_cooldown = (self.msg_cooldown or 0) - dtime
        droid_ai_step(self, dtime)
    end,
})

--R4-P17

minetest.register_entity("star_wars:r4p17", {
    initial_properties = {
        physical             = true,
        visual               = "mesh",
        mesh                 = "droid.obj",
        textures             = {"r4p17.png"},
        visual_size          = {x = 6, y = 6, z = 6},
        collisionbox = {-0.3, -0.3, -0.3, 0.3, 1.0, 0.3},
        makes_footstep_sound = true,
        hp_max               = 15,
    },
    is_npc    = true,
    move_timer = 0,
    idle_timer = 0,
    physical = true,
    sound_death = "star_wars_droid_death",
    on_activate = function(self, staticdata, dtime_s)
        self.inventory_slots = {}
        self.msg_cooldown = 0
        if staticdata and staticdata ~= "" then
            local data = minetest.deserialize(staticdata)
            if data and data.inventory_slots then
                self.inventory_slots = data.inventory_slots
            end
        end
        self.object:set_acceleration({x = 0, y = -10, z = 0})
    end,

    get_staticdata = function(self)
        return minetest.serialize({
            inventory_slots = self.inventory_slots
        })
    end,

    on_rightclick = function(self, clicker)
        if not clicker or not clicker:is_player() then return end
        
        local player_name = clicker:get_player_name()
        
        local inv_name = "r2d2_tmp_" .. player_name
        local detached_inv = minetest.create_detached_inventory(inv_name, {
            allow_move = function(inv, from_list, from_index, to_list, to_index, count, player)
                return count
            end,
            allow_put = function(inv, listname, index, stack, player)
                if stack:get_name() ~= "default:steel_ingot" then
                    if (self.msg_cooldown or 0) <= 0 then
                        self.msg_cooldown = 2.0
                        minetest.chat_send_player(player:get_player_name(), "Only steel ingots are allowed.")
                    end
                    return 0
                end
                return stack:get_count()
            end,
            allow_take = function(inv, listname, index, stack, player)
                return stack:get_count()
            end,
            on_put = function(inv, listname, index, stack, player)
                self.inventory_slots[index] = stack:to_string()
            end,
            on_take = function(inv, listname, index, stack, player)
                local remaining = inv:get_stack(listname, index)
                if remaining:is_empty() then
                    self.inventory_slots[index] = nil
                else
                    self.inventory_slots[index] = remaining:to_string()
                end
            end,
            on_move = function(inv, from_list, from_index, to_list, to_index, count, player)
                self.inventory_slots[from_index] = inv:get_stack(from_list, from_index):to_string()
                self.inventory_slots[to_index] = inv:get_stack(to_list, to_index):to_string()
            end,
        })

        detached_inv:set_size("main", 8)
        for index, item_string in pairs(self.inventory_slots) do
            detached_inv:set_stack("main", index, ItemStack(item_string))
        end

        local formspec = "size[8,9]" ..
            "list[detached:" .. inv_name .. ";main;0,0.3;8,4;]" .. 
            "list[current_player;main;0,4.85;8,4;]" ..             
            "listring[detached:" .. inv_name .. ";main]" ..          
            "listring[current_player;main]"

        minetest.show_formspec(player_name, "star_wars:r4p17_inventory", formspec)
    end,

    on_death = function(self, killer)
        minetest.sound_play(self.sound_death, {pos = self.object:get_pos(), gain = 1.0, max_hear_distance = 10})
        local pos = self.object:get_pos()
        if pos then
           minetest.add_item(pos, "star_wars:r4p17_spawn_egg")
            if self.inventory_slots then
                for _, item_string in pairs(self.inventory_slots) do
                    if item_string and item_string ~= "" then
                        minetest.add_item(pos, ItemStack(item_string))
                    end
                end
            end
        end
    end,
    on_step = function(self, dtime)
        self.msg_cooldown = (self.msg_cooldown or 0) - dtime
        droid_ai_step(self, dtime)
    end,
})

-- ============================================================
-- SPAWN EGGS
-- ============================================================

--R2-D2

minetest.register_craftitem(modname .. ":r2d2_spawn_egg", {
    description     = "R2-D2",
    inventory_image = "r2d2_egg.png",
    on_place = function(itemstack, placer, pointed_thing)
        if pointed_thing.type ~= "node" then return itemstack end
        local pos = pointed_thing.above
        minetest.add_entity(pos, "star_wars:r2d2")
        if not minetest.is_creative_enabled(placer:get_player_name()) then
            itemstack:take_item()
        end
        return itemstack
    end,
})

--R4-P17

minetest.register_craftitem(modname .. ":r4p17_spawn_egg", {
    description     = "R4-P17",
    inventory_image = "r4p17_egg.png",
    on_place = function(itemstack, placer, pointed_thing)
        if pointed_thing.type ~= "node" then return itemstack end
        local pos = pointed_thing.above
        minetest.add_entity(pos, "star_wars:r4p17")
        if not minetest.is_creative_enabled(placer:get_player_name()) then
            itemstack:take_item()
        end
        return itemstack
    end,
})



















