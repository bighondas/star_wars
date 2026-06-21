local modname = minetest.get_current_modname()

star_wars = star_wars or {}
star_wars.flash_damage = flash_damage
star_wars.vehicle_explode = vehicle_explode
star_wars.apply_vehicle_hit = apply_vehicle_hit

--------------------------------------------------------------------------------
-- Vehicle health / combat defaults
--------------------------------------------------------------------------------

local BLASTER_SPEED    = 40
local BLASTER_COOLDOWN = 0.15
local BLASTER_DAMAGE   = 15

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function get_vehicle_hit_zone(self, hit_pos)
    local obj_pos = self.object and self.object:get_pos()
    if not obj_pos or not hit_pos then
        return nil
    end

    local yaw = self.object:get_yaw() or 0
    local dir = minetest.yaw_to_dir(yaw)
    local right = {x = -dir.z, y = 0, z = dir.x}

    local rel = vector.subtract(hit_pos, obj_pos)

    local forward = rel.x * dir.x + rel.z * dir.z
    local side = rel.x * right.x + rel.z * right.z
    local up = rel.y

    if up < -0.2 or up > 2.8 then
        return nil
    end

    if forward > 1.5 then
        return "front"
    elseif forward < -1.5 then
        return "rear"
    elseif side > 1.0 then
        return "right"
    elseif side < -1.0 then
        return "left"
    else
        return "core"
    end
end

local function apply_vehicle_hit(self, hit_pos, dmg)
    if not self or not self._vehicle_hp then
        return false
    end

    local zone = get_vehicle_hit_zone(self, hit_pos)
    if not zone then
        return false
    end

    if zone ~= "front" and zone ~= "core" then
        return false
    end

    self._vehicle_hp = (self._vehicle_hp or self._max_hp or 0) - (dmg or 0)

    if self.flash_damage then
        self:flash_damage()
    elseif flash_damage then
        flash_damage(self)
    end

    if self._vehicle_hp <= 0 then
        if is_valid_player(puncher) and is_wrench(puncher) then
            vehicle_break_no_explosion(self)
        else
            vehicle_explode(self)
        end
    end

    return true
end

local function is_valid_player(player)
    return player and player:is_player()
end

local function table_has_player(seats, name)
    for seat_name, player_name in pairs(seats or {}) do
        if player_name == name then
            return seat_name
        end
    end
    return nil
end

local function first_free_seat(seats, order)
    for _, seat_name in ipairs(order) do
        if seats[seat_name] == nil then
            return seat_name
        end
    end
    return nil
end

local function set_player_stand_animation(player)
    if not is_valid_player(player) then return end
    if rawget(_G, "player_api") and player_api.set_animation then
        local name = player:get_player_name()
        if player_api.player_attached then
            player_api.player_attached[name] = false
        end
        player_api.set_animation(player, "stand", 30)
    end
end

local function set_player_sit_animation(player)
    if not is_valid_player(player) then return end
    if rawget(_G, "player_api") and player_api.set_animation then
        local name = player:get_player_name()
        if player_api.player_attached then
            player_api.player_attached[name] = true
        end
        minetest.after(0.2, function()
            local p = minetest.get_player_by_name(name)
            if p then
                player_api.set_animation(p, "sit", 30)
            end
        end)
    end
end

local function reset_player_mount_state(player)
    if not is_valid_player(player) then return end
    player:set_detach()
    player:set_eye_offset({x=0, y=0, z=0}, {x=0, y=0, z=0})
    player:set_properties({
        visual_size          = {x=1, y=1},
        pointable            = true,
        makes_footstep_sound = true,
        is_visible           = true,
    })
    set_player_stand_animation(player)
end

local function set_player_mounted_state(player, seat)
    if not is_valid_player(player) then return end
    player:set_attach(seat.parent, "", seat.pos, seat.rot)
    player:set_eye_offset(seat.eye_offset_first, seat.eye_offset_third)
    player:set_properties({
        visual_size          = seat.player_visual_size or {x=0.01, y=0.01},
        pointable            = false,
        makes_footstep_sound = false,
        is_visible           = true,
    })

    if seat.animation == "sit" then
        set_player_sit_animation(player)
    else
        set_player_stand_animation(player)
    end
end

local function get_exit_pos(self, side_sign)
    local pos  = self.object:get_pos()
    local yaw  = self.object:get_yaw() or 0
    local dir  = minetest.yaw_to_dir(yaw)
    local side = {x = -dir.z, y = 0, z = dir.x}
    local dist = self.exit_distance or 2.0
    return {
        x = pos.x + side.x * dist * side_sign,
        y = pos.y + (self.exit_height or 0.5),
        z = pos.z + side.z * dist * side_sign,
    }
end

local function detach_player_from_vehicle(self, player)
    if not is_valid_player(player) then return end
    local name      = player:get_player_name()
    local seat_name = table_has_player(self.seats, name)
    if not seat_name then return end

    local sign = 1
    if seat_name == "p3" or seat_name == "p4" then sign = -1 end

    local exit_pos = get_exit_pos(self, sign)
    self.seats[seat_name] = nil
    reset_player_mount_state(player)

    if self.stop_on_exit then
        self.speed = 0
        if self.object and self.object:get_luaentity() then
            self.object:set_velocity({x=0, y=0, z=0})
            self.object:set_acceleration({x=0, y=0, z=0})
        end
    end

    local pname = name
    minetest.after(0.05, function()
        local p = minetest.get_player_by_name(pname)
        if not p then return end
        p:add_velocity({x=0, y=0, z=0})
        if exit_pos then
            p:set_pos(exit_pos)
        end
    end)
end

local function detach_all(self)
    for seat_name, player_name in pairs(self.seats or {}) do
        if player_name then
            local player = minetest.get_player_by_name(player_name)
            if player then
                reset_player_mount_state(player)
            end
        end
        self.seats[seat_name] = nil
    end
end

local function attach_player_to_seat(self, player, seat_name)
    local def = self.seat_def[seat_name]
    if not def or self.seats[seat_name] ~= nil then return false end

    local name = player:get_player_name()
    self.seats[seat_name] = name
    set_player_mounted_state(player, {
        parent             = self.object,
        pos                = def.pos,
        rot                = def.rot,
        eye_offset_first   = def.eye_offset_first or {x=0, y=0, z=0},
        eye_offset_third   = def.eye_offset_third or {x=0, y=0, z=0},
        player_visual_size = def.player_visual_size or {x=0.01, y=0.01},
        animation          = def.animation,
    })
    return true
end

local function cleanup_missing_players(self)
    for seat_name, player_name in pairs(self.seats or {}) do
        if player_name and not minetest.get_player_by_name(player_name) then
            self.seats[seat_name] = nil
        end
    end
end

local function get_driver(self)
    local driver_name = self.seats.driver
    if not driver_name then return nil end
    return minetest.get_player_by_name(driver_name)
end

local function is_walkable_node(pos)
    local node = minetest.get_node_or_nil(pos)
    if not node then return false end
    local def = minetest.registered_nodes[node.name]
    return def and def.walkable or false
end

local function maybe_drop_vehicle_item(self)
    local pos = self.object:get_pos()
    if not pos or not self.drop_item then return end
    minetest.add_item(pos, ItemStack(self.drop_item))
end

local function is_wrench(player)
    if not is_valid_player(player) then return false end
    local stack = player:get_wielded_item()
    return stack and stack:get_name() == "star_wars:wrench"
end

--------------------------------------------------------------------------------
-- Flash damage effect
--------------------------------------------------------------------------------

local function flash_damage(self)
    local obj = self.object
    if not obj then return end
    local base = self._base_texture
    obj:set_properties({textures = {"red.png"}})
    minetest.after(0.15, function()
        if obj and obj:get_luaentity() then
            obj:set_properties({textures = {base}})
        end
    end)
end

--------------------------------------------------------------------------------
-- Explosion helper
--------------------------------------------------------------------------------

local function vehicle_break_no_explosion(self)
    local pos = self.object:get_pos()
    if not pos then return end

    detach_all(self)
    maybe_drop_vehicle_item(self)
    self.object:remove()
end

local function vehicle_explode(self)
    local pos = self.object:get_pos()
    if not pos then return end

    detach_all(self)
    -- maybe_drop_vehicle_item αφαιρέθηκε, δεν πετάει item στην έκρηξη

    minetest.sound_play("tnt_explode", {
        pos               = pos,
        gain              = 1.5,
        max_hear_distance = 64,
    })

    for _, obj in ipairs(minetest.get_objects_inside_radius(pos, 5)) do
        if obj:is_player() then
            local hp = obj:get_hp()
            obj:set_hp(math.max(0, hp - 40))
        else
            local ent = obj:get_luaentity()
            if ent and ent ~= self then
                obj:punch(self.object, 1.0, {
                    full_punch_interval = 1.0,
                    damage_groups       = {fleshy = 30},
                }, nil)
            end
        end
    end

    minetest.add_particlespawner({
        amount     = 60,
        time       = 0.4,
        minpos     = {x=pos.x-0.5, y=pos.y,     z=pos.z-0.5},
        maxpos     = {x=pos.x+0.5, y=pos.y+0.5, z=pos.z+0.5},
        minvel     = {x=-6, y=2,  z=-6},
        maxvel     = {x=6,  y=10, z=6},
        minacc     = {x=0,  y=-10, z=0},
        maxacc     = {x=0,  y=-10, z=0},
        minexptime = 0.5,
        maxexptime = 1.5,
        minsize    = 1.5,
        maxsize    = 4.0,
        texture    = "tnt_smoke.png",
    })

    self.object:remove()
end

--------------------------------------------------------------------------------
-- Blaster firing
--------------------------------------------------------------------------------

local function fire_blaster(self, driver)
    local pos = self.object:get_pos()
    if not pos then return end

    local dir   = vector.normalize(driver:get_look_dir())
    local right = vector.normalize({x = -dir.z, y = 0, z = dir.x})

    local side = self._shot_side or 1
    self._shot_side = -side

    local forward_offset = self.blaster_forward_offset or 3.5
    local up_offset      = self.blaster_up_offset or 0.8
    local side_offset    = self.blaster_side_offset or 0.8

    local spawn = {
        x = pos.x + dir.x * forward_offset + right.x * side_offset * side,
        y = pos.y + dir.y * forward_offset + up_offset,
        z = pos.z + dir.z * forward_offset + right.z * side_offset * side,
    }

    minetest.sound_play("star_wars_blaster_shot", {
        pos               = spawn,
        gain              = 1.0,
        max_hear_distance = 48,
    })

    local bolt = minetest.add_entity(spawn, "star_wars:laser")
    if bolt then
        local ent = bolt:get_luaentity()
        if ent then
            ent.shooter = driver
            ent.speed   = BLASTER_SPEED
            ent.damage  = BLASTER_DAMAGE
        end

        if self.blaster_texture then
            bolt:set_properties({textures = {self.blaster_texture}})
        end

        bolt:set_velocity({
            x = dir.x * BLASTER_SPEED,
            y = dir.y * BLASTER_SPEED,
            z = dir.z * BLASTER_SPEED,
        })

        minetest.sound_play("star_wars_blaster", {
            pos               = spawn,
            gain              = 0.9,
            max_hear_distance = 48,
        })
    end
end

--------------------------------------------------------------------------------
-- Seat / interact callbacks
--------------------------------------------------------------------------------

local function vehicle_rightclick(self, clicker)
    if not is_valid_player(clicker) then return end
    local name          = clicker:get_player_name()
    local existing_seat = table_has_player(self.seats, name)

    if existing_seat then
        detach_player_from_vehicle(self, clicker)
        return
    end

    local seat_name = first_free_seat(self.seats, self.seat_order)
    if not seat_name then
        minetest.chat_send_player(name, "The vehicle is full.")
        return
    end

    attach_player_to_seat(self, clicker, seat_name)
end

local function vehicle_on_punch(self, puncher, time_from_last_punch, tool_capabilities, dir)
    local dmg = 10

    if is_valid_player(puncher) then
        local wield = puncher:get_wielded_item()
        local caps = wield and wield:get_tool_capabilities() or nil
        if caps and caps.damage_groups then
            dmg = caps.damage_groups.fleshy
                or caps.damage_groups.vehicle
                or dmg
        end
    elseif tool_capabilities and tool_capabilities.damage_groups then
        dmg = tool_capabilities.damage_groups.fleshy
            or tool_capabilities.damage_groups.vehicle
            or dmg
    end

    if is_valid_player(puncher) then
        local seat_name = table_has_player(self.seats, puncher:get_player_name())
        if seat_name then
            detach_player_from_vehicle(self, puncher)
            return
        end
    end

    self._vehicle_hp = (self._vehicle_hp or self._max_hp) - dmg
    flash_damage(self)

    if self._vehicle_hp <= 0 then
        if is_valid_player(puncher) and is_wrench(puncher) then
            vehicle_break_no_explosion(self)
        else
            vehicle_explode(self)
        end
    end
end

local function handle_passenger_exit(self)
    for seat_name, player_name in pairs(self.seats or {}) do
        if player_name then
            local player = minetest.get_player_by_name(player_name)
            if player then
                local ctrl = player:get_player_control()
                if ctrl.sneak then
                    detach_player_from_vehicle(self, player)
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Activate / staticdata
--------------------------------------------------------------------------------

local function default_activate(self, staticdata, dtime_s)
    if staticdata and staticdata ~= "" then
        local data = minetest.deserialize(staticdata)
        if data then
            self.speed       = data.speed or 0
            self._vehicle_hp = data.hp or self._max_hp
        end
    end

    self.speed           = self.speed or 0
    self._vehicle_hp     = self._vehicle_hp or self._max_hp or 100
    self.max_speed       = self.max_speed or 10
    self.accel           = self.accel or 5
    self.brake           = self.brake or 8
    self.friction        = self.friction or 2
    self.turn_speed      = self.turn_speed or 1.5
    self.vertical_speed  = self.vertical_speed or 8
    self.max_pitch       = self.max_pitch or 0.45
    self._shoot_timer    = 0
    self._hover_timer    = 0
    self._shot_side      = 1
    self._prev_vel_y     = 0
    self._last_safe_pos  = self.object:get_pos()
    self.seats           = {}

    if self.object and self.object.set_armor_groups then
        self.object:set_armor_groups({immortal = 1})
    end

    for _, seat_name in ipairs(self.seat_order or {}) do
        self.seats[seat_name] = nil
    end
end

local function default_staticdata(self)
    return minetest.serialize({
        speed = self.speed or 0,
        hp    = self._vehicle_hp or self._max_hp,
    })
end

--------------------------------------------------------------------------------
-- Crash detection
--------------------------------------------------------------------------------

local function check_vehicle_crash(self, vel)
    local pos = self.object:get_pos()
    if not pos or not vel then return false end

    local speed_total = vector.length(vel)
    local horiz_speed = math.sqrt(vel.x * vel.x + vel.z * vel.z)
    local fall_speed  = -vel.y

    if speed_total < 4.0 then return false end

    if horiz_speed >= (self.min_collision_speed or 20) then
        local dir = vector.normalize({x = vel.x, y = 0, z = vel.z})
        if not vector.equals(dir, {x=0, y=0, z=0}) then
            local front_probe = vector.add(pos, vector.multiply(dir, self.crash_forward_probe or 1.8))
            local low_front   = {x=front_probe.x, y=front_probe.y-(self.crash_low_probe_drop or 0.8), z=front_probe.z}
            if is_walkable_node(front_probe) or is_walkable_node(low_front) then
                return true
            end
        end
    end

    if fall_speed >= (self.crash_speed or 20) then
        local below_probe = {x=pos.x, y=pos.y-(self.crash_probe_depth or 1.5), z=pos.z}
        if is_walkable_node(below_probe) then
            return true
        end
    end

    return false
end

--------------------------------------------------------------------------------
-- Main step
--------------------------------------------------------------------------------

local function vehicle_step(self, dtime)
    cleanup_missing_players(self)
    handle_passenger_exit(self)

    self._shoot_timer = (self._shoot_timer or 0) + dtime

    local vel = self.object:get_velocity()
    if vel and check_vehicle_crash(self, vel) then
        vehicle_explode(self)
        return
    end

    local yaw_offset   = self.model_yaw_offset or 0
    local pitch_offset = self.model_pitch_offset or 0
    local roll_offset  = self.model_roll_offset or 0

    local driver = get_driver(self)
    if driver then
        local ctrl       = driver:get_player_control()
        local player_yaw = driver:get_look_horizontal()
        local move_yaw   = player_yaw

        if ctrl.up then
            self.speed = math.min(self.speed + self.accel * dtime, self.max_speed)
        elseif ctrl.down then
            self.speed = math.max(self.speed - self.brake * dtime, 0)
        else
            self.speed = math.max(self.speed - self.friction * dtime, 0)
        end

        if self.has_blasters and ctrl.aux1 and self._shoot_timer >= BLASTER_COOLDOWN then
            self._shoot_timer = 0
            fire_blaster(self, driver)
        end

        if self.can_fly then
            self.object:set_acceleration({x = 0, y = 0, z = 0})

            local look_dir = driver:get_look_dir()
            local climb    = 0

            if look_dir.y > 0.2 then
                climb = look_dir.y * self.vertical_speed
            elseif look_dir.y < -0.2 then
                climb = look_dir.y * self.vertical_speed
            end

            local forward = minetest.yaw_to_dir(move_yaw)

            self.object:set_velocity({
                x = forward.x * self.speed,
                y = climb,
                z = forward.z * self.speed,
            })

            local pitch = -look_dir.y * self.max_pitch + pitch_offset
            self.object:set_rotation({
                x = pitch,
                y = move_yaw + yaw_offset,
                z = roll_offset,
            })
        else
            local hover_y = self.hover_height or 0.5
            local forward = minetest.yaw_to_dir(move_yaw)

            self.object:set_acceleration({x = 0, y = 0, z = 0})
            self.object:set_velocity({
                x = forward.x * self.speed,
                y = 0,
                z = forward.z * self.speed,
            })

            local pos = self.object:get_pos()
            if pos then
                self.object:set_pos({
                    x = pos.x,
                    y = self._spawn_base_y + hover_y,
                    z = pos.z,
                })
            end

            self.object:set_rotation({
                x = pitch_offset,
                y = move_yaw + yaw_offset,
                z = 0,
            })
        end
    else
        local yaw = self.object:get_yaw() or 0

        if self.can_fly then
            local gravity = tonumber(minetest.settings:get("movement_gravity")) or 9.81
            self.speed    = 0

            self.object:set_acceleration({x = 0, y = -gravity, z = 0})

            local vel2 = self.object:get_velocity()
            self.object:set_velocity({
                x = vel2.x * 0.15,
                y = vel2.y,
                z = vel2.z * 0.15,
            })

            self.object:set_rotation({x = pitch_offset, y = yaw, z = roll_offset})
        else
            self.speed = math.max((self.speed or 0) - self.friction * dtime, 0)
            local forward = minetest.yaw_to_dir(yaw)

            self.object:set_acceleration({x = 0, y = 0, z = 0})
            self.object:set_velocity({
                x = forward.x * self.speed,
                y = 0,
                z = forward.z * self.speed,
            })

            local pos = self.object:get_pos()
            if pos then
                self.object:set_pos({
                    x = pos.x,
                    y = self._spawn_base_y + (self.hover_height or 0.5),
                    z = pos.z,
                })
            end

            self.object:set_rotation({
                x = pitch_offset,
                y = yaw,
                z = 0,
            })
        end
    end
end

--------------------------------------------------------------------------------
-- Factory
--------------------------------------------------------------------------------

local function make_vehicle_def(data)
    return {
        initial_properties = {
            visual               = "mesh",
            mesh                 = data.mesh,
            textures             = {data.texture},
            visual_size          = data.visual_size or {x=1, y=1},
            physical             = true,
            collide_with_objects = false,
            pointable            = true,
            collisionbox         = data.collisionbox or {-1.0, -0.5, -1.0, 1.0, 1.0, 1.0},
            selectionbox         = data.selectionbox  or {-1.0, -0.5, -1.0, 1.0, 1.0, 1.0},
            stepheight           = data.stepheight or 1.0,
            hp_max               = 9999,
            armor_groups         = {immortal = 1},
        },
        

        _base_texture           = data.texture,

        can_fly                 = data.can_fly or false,
        has_blasters            = data.has_blasters or false,
        blaster_texture         = data.blaster_texture or nil,
        blaster_forward_offset  = data.blaster_forward_offset or 3.5,
        blaster_up_offset       = data.blaster_up_offset or 0.8,
        blaster_side_offset     = data.blaster_side_offset or 0.8,

        model_yaw_offset        = data.model_yaw_offset or 0,
        model_pitch_offset      = data.model_pitch_offset or 0,
        model_roll_offset       = data.model_roll_offset or 0,

        vertical_speed          = data.vertical_speed or 8,
        max_pitch               = data.max_pitch or 0.5,

        seat_def                = data.seat_def,
        seat_order              = data.seat_order,
        seats                   = nil,

        _max_hp                 = data.hp or 100,
        _vehicle_hp             = nil,
        _shoot_timer            = 0,
        _hover_timer            = 0,

        speed                   = 0,
        max_speed               = data.max_speed,
        accel                   = data.accel,
        brake                   = data.brake,
        friction                = data.friction,
        turn_speed              = data.turn_speed,
        exit_distance           = data.exit_distance or 2.0,
        exit_height             = data.exit_height or 0.5,

        hover_height            = data.hover_height or 0,
        stop_on_exit            = data.stop_on_exit ~= false,

        crash_speed             = data.crash_speed or 20,
        crash_probe_depth       = data.crash_probe_depth or 1.5,
        crash_forward_probe     = data.crash_forward_probe or 1.8,
        crash_low_probe_drop    = data.crash_low_probe_drop or 0.8,
        min_collision_speed     = data.min_collision_speed or 20,
        driver_crash_speed      = data.driver_crash_speed or 20,

        drop_item               = data.drop_item,

        on_activate             = function(self, staticdata, dtime_s)
            default_activate(self, staticdata, dtime_s)
            local pos = self.object:get_pos()
            if pos then
                self._spawn_base_y = pos.y - (self.hover_height or 0)
            else
                self._spawn_base_y = 0
            end
        end,
        get_staticdata          = default_staticdata,
        on_rightclick           = vehicle_rightclick,
        on_punch                = vehicle_on_punch,
        on_step                 = vehicle_step,
        on_deactivate           = function(self)
            detach_all(self)
        end,
    }
end

--------------------------------------------------------------------------------
-- Seat definitions
--------------------------------------------------------------------------------

local SPEEDER_SEATS = {
    driver = {
        pos                = {x=0, y=0.001, z=0.4},
        rot                = {x=0, y=180, z=0},
        eye_offset_first   ={x=0, y=1, z=0},
        eye_offset_third   ={x=0, y=8, z=-12},
        player_visual_size = {x=0.1, y=0.1},
        animation          = "sit",
    },
}

local XWING_SEATS = {
    driver = {
        pos                = {x=0, y=2, z=0},
        rot                = {x=0, y=0, z=0},
        eye_offset_first   ={x=0, y=2, z=0},
        eye_offset_third   ={x=0, y=12, z=-18},
        player_visual_size = {x=0.01, y=0.01},
    },
}

local TIE_SEATS = {
    driver = {
        pos                = {x=0, y=4.5, z=0},
        rot                = {x=0, y=0, z=0},
        eye_offset_first   = {x=0, y=21, z=10},
        eye_offset_third   = {x=0, y=30,  z=-16},
        player_visual_size = {x=0.01, y=0.01},
    },
}

--------------------------------------------------------------------------------
-- Register entities
--------------------------------------------------------------------------------

minetest.register_entity(modname .. ":speeder", make_vehicle_def({
    mesh                = "star_wars_speeder.obj",
    texture             = "star_wars_speeder.png",
    visual_size         = {x=10, y=10},
    selectionbox        = {-2.5, -0.5, -4.0, 2.5, 1.5, 4.0},
    collisionbox        = {-2.5, -0.5, -4.0, 2.5, 1.5, 4.0},
    seat_def            = SPEEDER_SEATS,
    seat_order          = {"driver"},
    hp                  = 100,
    max_speed           = 14,
    accel               = 8,
    brake               = 10,
    model_yaw_offset    = math.pi,
    can_fly             = false,
    has_blasters        = false,
    friction            = 3,
    turn_speed          = 1.8,
    stepheight          = 1.1,
    exit_distance       = 2.5,
    exit_height         = 0.5,
    hover_height        = 0.3,
    stop_on_exit        = true,
    min_collision_speed = 20,
    crash_speed         = 20,
    crash_probe_depth   = 1.2,
    crash_forward_probe = 1.6,
    driver_crash_speed  = 20,
    drop_item           = modname .. ":speeder_item",
}))

minetest.register_entity(modname .. ":xwing", make_vehicle_def({
    mesh                   = "star_wars_xwing.obj",
    texture                = "star_wars_xwing.png",
    visual_size            = {x=10, y=10},
    selectionbox           = {-4.0, -0.5, -3.0, 4.0, 2.0, 3.0},
    collisionbox           = {-3.0, -0.5, -3.0, 3.0, 2.0, 3.0},
    seat_def               = XWING_SEATS,
    seat_order             = {"driver"},
    hp                     = 100,
    max_speed              = 22,
    accel                  = 11,
    brake                  = 9,
    friction               = 2,
    turn_speed             = 1.4,
    can_fly                = true,
    has_blasters           = true,
    blaster_texture        = "laser.png",
    blaster_forward_offset = 5.5,
    blaster_up_offset      = 1.0,
    blaster_side_offset    = 1.2,
    model_yaw_offset       = math.pi,
    model_pitch_offset     = 0.0,
    model_roll_offset      = 0.0,
    vertical_speed         = 7,
    max_pitch              = 0.45,
    stepheight             = 1.0,
    exit_distance          = 3.0,
    exit_height            = 2.0,
    min_collision_speed    = 20,
    crash_speed            = 20,
    crash_probe_depth      = 2.0,
    crash_forward_probe    = 2.2,
    crash_low_probe_drop   = 1.0,
    driver_crash_speed     = 20,
    drop_item              = modname .. ":xwing_item",
}))

minetest.register_entity(modname .. ":tie_advanced", make_vehicle_def({
    mesh                   = "star_wars_tie_advanced.obj",
    texture                = "star_wars_tie_advanced.png",
    visual_size            = {x=10, y=10},
    selectionbox           = {-3.5, 0.0, -2.0, 3.5, 3.0, 2.0},
    collisionbox           = {-3.5, 0.0, -2.0, 3.5, 3.0, 2.0},
    seat_def               = TIE_SEATS,
    seat_order             = {"driver"},
    hp                     = 100,
    max_speed              = 24,
    accel                  = 12,
    brake                  = 10,
    friction               = 2,
    turn_speed             = 1.7,
    can_fly                = true,
    has_blasters           = true,
    blaster_texture        = "laser_green.png",
    blaster_forward_offset = 4.0,
    blaster_up_offset      = 0.8,
    blaster_side_offset    = 0.9,
    model_yaw_offset       = math.pi,
    model_pitch_offset     = 0,
    model_roll_offset      = 0,
    vertical_speed         = 7,
    max_pitch              = 0.45,
    stepheight             = 1.0,
    exit_distance          = 3.0,
    exit_height            = 2.0,
    min_collision_speed    = 20,
    crash_speed            = 20,
    crash_probe_depth      = 1.6,
    crash_forward_probe    = 1.7,
    crash_low_probe_drop   = 0.8,
    driver_crash_speed     = 20,
    drop_item              = modname .. ":tie_advanced_item",
}))

--------------------------------------------------------------------------------
-- Spawner items
--------------------------------------------------------------------------------

local function place_vehicle(itemstack, placer, pointed_thing, entity_name, height_offset)
    if pointed_thing.type ~= "node" then return itemstack end
    local pos = vector.new(pointed_thing.above)
    pos.y = pos.y + (height_offset or 1.0)

    local obj = minetest.add_entity(pos, entity_name)
    if obj and placer then
        obj:set_yaw(placer:get_look_horizontal() or 0)
    end

    if placer and not minetest.is_creative_enabled(placer:get_player_name()) then
        itemstack:take_item()
    end
    return itemstack
end

minetest.register_craftitem(modname .. ":speeder_item", {
    description     = "Speeder",
    inventory_image = "star_wars_speeder_item.png",
    stack_max       = 1,
    on_place = function(itemstack, placer, pointed_thing)
        return place_vehicle(itemstack, placer, pointed_thing, modname .. ":speeder", 1.0)
    end,
})

minetest.register_craftitem(modname .. ":xwing_item", {
    description     = "X-Wing",
    inventory_image = "star_wars_xwing_item.png",
    stack_max       = 1,
    on_place = function(itemstack, placer, pointed_thing)
        return place_vehicle(itemstack, placer, pointed_thing, modname .. ":xwing", 6.5)
    end,
})

minetest.register_craftitem(modname .. ":tie_advanced_item", {
    description     = "TIE Fighter",
    inventory_image = "star_wars_tie_item.png",
    stack_max       = 1,
    on_place = function(itemstack, placer, pointed_thing)
        return place_vehicle(itemstack, placer, pointed_thing, modname .. ":tie_advanced", 3.5)
    end,
})

--------------------------------------------------------------------------------
-- Cleanup on leave
--------------------------------------------------------------------------------

minetest.register_on_leaveplayer(function(player)
    if player then
        reset_player_mount_state(player)
    end
end)
