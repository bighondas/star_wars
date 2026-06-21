local function remove_self(self, pos)
    self.removing = true
    self.object:remove()
    if not self.returned then
        minetest.add_item(pos, "star_wars:darksaber_off")
    end
end

local function is_owner_at_pos(self, pos)
    for _, player in pairs(minetest.get_objects_inside_radius(pos, 1.5)) do
        if player:is_player() and player:get_player_name() == self.owner then
            return true, player
        end
    end
end

local function return_to_owner(self, pos)
    local owner = minetest.get_player_by_name(self.owner)
    if not owner or self.owner == nil then
        remove_self(self, pos)
        return
    end
    local owner_pos = owner:get_pos()
    owner_pos.y = owner_pos.y + 1
    local dir = vector.direction(pos, owner_pos)
    for _, entity in pairs(minetest.get_objects_inside_radius(pos, 2)) do
        if entity:is_player() and entity:get_player_name() ~= self.owner then
            entity:punch(self.object, 2.0, {full_punch_interval = 0.1, damage_groups = {fleshy = 6}}, nil)
        end
        local luaentity = entity:get_luaentity()
        if luaentity and not self.removing then
            if luaentity.name ~= self.object:get_luaentity().name then
                if entity:get_armor_groups().fleshy then
                    entity:punch(self.object, 2.0, {full_punch_interval = 0.1, damage_groups = {fleshy = 6}}, nil)
                end
            end
        end
    end
    self.returning_to_owner = true
    self.object:set_velocity(vector.multiply(dir, 15))
    local get_owner, player = is_owner_at_pos(self, pos)
    if get_owner then
        self.removing = true
        if player:get_wielded_item():get_name() == "" then
            player:set_wielded_item("star_wars:darksaber_on")
            self.returned = true
            self.object:remove()
        else
            remove_self(self, pos)
        end
    end
end

local function punch_entities(self, pos)
    for _, entity in pairs(minetest.get_objects_inside_radius(pos, 2)) do
        if entity:is_player() and entity:get_player_name() ~= self.owner then
            entity:punch(self.object, 2.0, {full_punch_interval = 0.1, damage_groups = {fleshy = 6}}, nil)
            return_to_owner(self, pos)
            return
        end
        local luaentity = entity:get_luaentity()
        if luaentity and not self.removing then
            if luaentity.name ~= self.object:get_luaentity().name then
                if entity:get_armor_groups().fleshy then
                    entity:punch(self.object, 2.0, {full_punch_interval = 0.1, damage_groups = {fleshy = 6}}, nil)
                    return_to_owner(self, pos)
                    return
                end
            end
        end
    end
end

minetest.register_entity("star_wars:darksaber_ent", {
    physical = false,
    visual = "wielditem",
    visual_size = {x = .25, y = .25, z = .25},
    textures = {"star_wars:darksaber_on"},
    collisionbox = {-0.125, -0.125, -0.125, 0.125, 0.125, 0.125},
    glow = 10,
    owner = "",
    timer = 0,
    on_activate = function(self)
        self.object:set_armor_groups({immortal = 1})
        local pos = self.object:get_pos()
        for _, player in pairs(minetest.get_objects_inside_radius(pos, 1.0)) do
            if player:is_player() then
                self.owner = player:get_player_name()
            end
        end
        local rot = self.object:get_rotation()
        self.object:set_rotation({x = rot.x, y = rot.y, z = -40})
        if self.owner == nil then
            remove_self(self, pos)
            return
        end
    end,
    on_step = function(self)
        local pos = self.object:get_pos()
        self.timer = self.timer + 1
        local rot = self.object:get_rotation()
        self.object:set_rotation({x = rot.x, y = self.timer, z = rot.z})
        if self.owner == nil then
            remove_self(self, pos)
            return
        end
        if self.timer >= 35 then
            return_to_owner(self, pos)
        end
        punch_entities(self, pos)
        local node = minetest.get_node_or_nil(pos)
        if node and minetest.registered_nodes[node.name].walkable then
            return_to_owner(self, pos)
        end
    end,
})

-- Idle hum
local t = 0
minetest.register_globalstep(function(dtime)
    t = t + dtime
    if t > 1.3 then
        for _, player in ipairs(minetest.get_connected_players()) do
            if player:get_wielded_item():get_name() == "star_wars:darksaber_on" then
                star_wars.play_sound(player, "star_wars_idle")
            end
        end
        t = 0
    end
end)

minetest.register_tool("star_wars:darksaber_off", {
    description = "Darksaber",
    inventory_image = "darksaber_hilt_inv.png",
    stack_max = 1,
    wield_scale = {x = 2, y = 2, z = 1},
    on_use = function(itemstack, player, pointed_thing)
        itemstack:replace("star_wars:darksaber_on")
        star_wars.play_sound(player, "star_wars_darksaber_on")
        return itemstack
    end,
})

minetest.register_tool("star_wars:darksaber_on", {
    description = "Darksaber",
    inventory_image = "darksaber_hilt_inv.png",
    wield_image = "blade_darksaber.png^darksaber_hilt.png",
    wield_scale = {x = 2, y = 2, z = 1},
    stack_max = 1,
    range = 4,
    light_source = 15,
    on_use = function(itemstack, player, pointed_thing)
        star_wars.lightsaber_attack(player, pointed_thing, "star_wars_swing", "star_wars_clash")
    end,
    on_secondary_use = function(itemstack, player, pointed_thing)
        local playername = player:get_player_name()
        if player:get_player_control().sneak == true then
            if force_ability[playername] == "Saber Throw" then
                -- Darksaber specific throw
                local pos = player:get_pos()
                pos.y = pos.y + 1
                local dir = player:get_look_dir()
                local saber = minetest.add_entity(pos, "star_wars:darksaber_ent")
                itemstack:take_item(1)
                saber:set_velocity(vector.multiply(dir, 20))
                return itemstack
            end
        else
            itemstack:replace("star_wars:darksaber_off")
            star_wars.play_sound(player, "star_wars_darksaber_off")
            return itemstack
        end
    end,
    on_place = function(itemstack, player, pointed_thing)
        itemstack:replace("star_wars:darksaber_off")
        star_wars.play_sound(player, "star_wars_darksaber_off")
        return itemstack
    end,
    groups = {not_in_creative_inventory = 1, lightsaber = 1},
})
