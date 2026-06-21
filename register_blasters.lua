--==========================
-- HELPERS
--==========================

local function laser_set_rotation_from_velocity(object, vel)
    if not object or not vel then return end
    if vector.length(vel) < 0.001 then return end

    local dir = vector.normalize(vel)
    local rot = dir:dir_to_rotation()
    rot.y = rot.y - math.rad(360)
    rot.z = 0
    object:set_rotation(rot)
end

local function is_lightsaber_blocking(player)
    if not player or not player:is_player() then
        return false
    end

    local wielded = player:get_wielded_item():get_name()
    if wielded == "" then
        return false
    end

    if minetest.get_item_group(wielded, "lightsaber") <= 0 then
        return false
    end

    local ctrl = player:get_player_control()
    return ctrl and ctrl.LMB == true
end

local function try_deflect(self, obj, pos)
    if not obj or not obj:is_player() then
        return false
    end

    if not is_lightsaber_blocking(obj) then
        return false
    end

    local now = minetest.get_us_time()
    if self._last_deflect and (now - self._last_deflect) < 100000 then
        return false
    end
    self._last_deflect = now

    local look_dir = obj:get_look_dir()
    if not look_dir or vector.length(look_dir) < 0.001 then
        return false
    end

    local new_dir = vector.normalize(look_dir)
    self.object:set_velocity(vector.multiply(new_dir, self.speed))
    self.shooter = obj
    self.last_pos = vector.copy(self.object:get_pos())

    laser_set_rotation_from_velocity(self.object, new_dir)

    minetest.sound_play("star_wars_clash", {
        pos = self.object:get_pos(),
        gain = 1.0,
        max_hear_distance = 24,
    })

    return true
end

--==========================
-- LASER ENTITY
--==========================

minetest.register_entity("star_wars:laser", {
    initial_properties = {
        physical = true,
        collide_with_objects = true,
        collisionbox = {-0.15, -0.15, -0.15, 0.15, 0.15, 0.15},
        selectionbox = {-0.15, -0.15, -0.15, 0.15, 0.15, 0.15},

        visual = "mesh",
        mesh = "laser.obj",
        textures = {"laser.png"},
        visual_size = {x = 7.7, y = 7.7, z = 7.7},

        pointable = true,
        static_save = false,
        glow = 10,
    },

    timer = 0,
    shooter = nil,
    damage = 2,
    vehicle_damage = 2,
    speed = 40,
    last_pos = nil,
    _last_deflect = 0,

    on_activate = function(self)
        self.object:set_armor_groups({immortal = 1})
        self.object:set_acceleration({x = 0, y = 0, z = 0})
        self.last_pos = self.object:get_pos()
    end,

    on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir)
        if not puncher or not puncher:is_player() then
            return
        end

        local wielded = puncher:get_wielded_item():get_name()
        if wielded == "" then
            return
        end

        if minetest.get_item_group(wielded, "lightsaber") <= 0 then
            return
        end

        local now = minetest.get_us_time()
        if self._last_deflect and (now - self._last_deflect) < 100000 then
            return
        end
        self._last_deflect = now

        local vel = self.object:get_velocity()
        if not vel or vector.length(vel) < 0.001 then
            return
        end

        local look_dir = puncher:get_look_dir()
        if not look_dir or vector.length(look_dir) < 0.001 then
            return
        end

        local new_dir = vector.normalize(look_dir)

        self.object:set_velocity(vector.multiply(new_dir, self.speed))
        self.shooter = puncher
        self.last_pos = vector.copy(self.object:get_pos())

        laser_set_rotation_from_velocity(self.object, new_dir)

        minetest.sound_play("star_wars_clash", {
            pos = self.object:get_pos(),
            gain = 1.0,
            max_hear_distance = 24,
        })
    end,

    on_step = function(self, dtime, moveresult)
        self.timer = self.timer + dtime
        if self.timer > 3 then
            self.object:remove()
            return
        end

        local pos = self.object:get_pos()
        if not pos then return end

        local vel = self.object:get_velocity()
        if not vel then return end

        if vector.length(vel) > 0.001 then
            local dir = vector.normalize(vel)
            self.object:set_velocity(vector.multiply(dir, self.speed))
            laser_set_rotation_from_velocity(self.object, dir)
        end

        local function damage_vehicle_from_hit(obj, hit_pos)
            if not obj then
                return false
            end

            local ent = obj:get_luaentity()
            if not ent or not ent._vehicle_hp then
                return false
            end

            if star_wars and star_wars.apply_vehicle_hit then
                return star_wars.apply_vehicle_hit(ent, hit_pos, self.vehicle_damage or self.damage or 2)
            end

            return false
        end

        if self.last_pos then
            local ray = minetest.raycast(self.last_pos, pos, true, false)

            for pointed in ray do
                if pointed.type == "object" then
                    local obj = pointed.ref
                    if obj and obj ~= self.object and obj ~= self.shooter then
                        local ent = obj:get_luaentity()
                        local hit_pos = pointed.intersection_point or pos

                        if ent and ent._vehicle_hp then
                            if damage_vehicle_from_hit(obj, hit_pos) then
                                self.object:remove()
                                return
                            end
                        end

                        if try_deflect(self, obj, pos) then
                            return
                        end

                        obj:punch(self.object, 1.0, {
                            full_punch_interval = 0.1,
                            damage_groups = {fleshy = self.damage},
                        }, vector.normalize(vel))

                        self.object:remove()
                        return
                    end

                elseif pointed.type == "node" then
                    self.object:remove()
                    return
                end
            end
        end

        self.last_pos = vector.copy(pos)

        if moveresult and moveresult.collisions then
            for _, c in ipairs(moveresult.collisions) do
                if c.type == "object" and c.object then
                    local obj = c.object
                    if obj ~= self.object and obj ~= self.shooter then
                        local ent = obj:get_luaentity()

                        if ent and ent._vehicle_hp then
                            local hit_pos = obj:get_pos() or pos
                            if damage_vehicle_from_hit(obj, hit_pos) then
                                self.object:remove()
                                return
                            end
                        end

                        if try_deflect(self, obj, pos) then
                            return
                        end

                        obj:punch(self.object, 1.0, {
                            full_punch_interval = 0.1,
                            damage_groups = {fleshy = self.damage},
                        }, vector.normalize(vel))

                        self.object:remove()
                        return
                    end
                elseif c.type == "node" then
                    self.object:remove()
                    return
                end
            end
        end
    end,
})

--==========================
-- BLASTER
--==========================

local BLASTER_COOLDOWN = 0.5

minetest.register_tool("star_wars:blaster", {
    stack_max = 1,
    description = "Blaster",
    inventory_image = "blaster.png",
    range = 0,
    _damage = 2,
    _vehicle_damage = 2,
    _speed = 40,

    on_use = function(itemstack, user, pointed_thing)
        if not user then
            return itemstack
        end

        local now = minetest.get_us_time() / 1000000
        local meta = itemstack:get_meta()
        local last_shot = meta:get_float("last_shot")

        if now - last_shot < BLASTER_COOLDOWN then
            return itemstack
        end
        meta:set_float("last_shot", now)

        local pos = vector.copy(user:get_pos())
        local dir = user:get_look_dir()

        pos.y = pos.y + 1.5
        pos = vector.add(pos, vector.multiply(dir, 1.2))

        local obj = minetest.add_entity(pos, "star_wars:laser")
               if obj then
            local lua = obj:get_luaentity()
            if lua then
                lua.shooter = user
                lua.last_pos = vector.new(pos)
                lua.damage = 2
                lua.vehicle_damage = 2
                lua.speed = 40
            end

            obj:set_velocity(vector.multiply(dir, 40))
            obj:set_acceleration({x = 0, y = 0, z = 0})
        end

        minetest.sound_play("star_wars_blaster_shot", {
            object = user,
            gain = 1.0,
            max_hear_distance = 24,
        })

        return itemstack
    end,
})

--==========================
-- AUTO BLASTER
--==========================

local AUTO_BLASTER_COOLDOWN = 0.1

minetest.register_tool("star_wars:auto_blaster", {
    stack_max = 1,
    description = "Auto Blaster",
    inventory_image = "auto_blaster.png",
    range = 0,
    _damage = 2,
    _vehicle_damage = 2,
    _speed = 40,

    on_use = function(itemstack, user, pointed_thing)
        if not user then
            return itemstack
        end

        local now = minetest.get_us_time() / 1000000
        local meta = itemstack:get_meta()
        local last_shot = meta:get_float("last_shot")

        if now - last_shot < AUTO_BLASTER_COOLDOWN then
            return itemstack
        end
        meta:set_float("last_shot", now)

        local pos = vector.copy(user:get_pos())
        local dir = user:get_look_dir()

        pos.y = pos.y + 1.5
        pos = vector.add(pos, vector.multiply(dir, 1.2))

        local obj = minetest.add_entity(pos, "star_wars:laser")
        if obj then
            local lua = obj:get_luaentity()
            if lua then
                lua.shooter = user
                lua.last_pos = vector.new(pos)
                lua.damage = 2
                lua.vehicle_damage = 2
                lua.speed = 40
            end

            obj:set_velocity(vector.multiply(dir, 40))
            obj:set_acceleration({x = 0, y = 0, z = 0})
        end

        minetest.sound_play("star_wars_blaster_shot", {
            object = user,
            gain = 1.0,
            max_hear_distance = 24,
        })

        return itemstack
    end,
})
