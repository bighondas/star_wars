-- ============================================================
-- DECORATION SPAWN HELPERS
-- ============================================================

star_wars = star_wars or {}

local function add_entity_once(pos, entity_name)
    minetest.after(0, function()
        local objs = minetest.get_objects_inside_radius(pos, 2)
        for _, obj in ipairs(objs) do
            local ent = obj:get_luaentity()
            if ent and ent.name == entity_name then
                return
            end
        end
        minetest.add_entity(pos, entity_name)
    end)
end

function star_wars.spawn_yoda_at(pos)
    add_entity_once({x = pos.x, y = pos.y + 4, z = pos.z}, "star_wars:yoda")
end

function star_wars.spawn_sidious_at(pos)
    add_entity_once({x = pos.x, y = pos.y + 4, z = pos.z}, "star_wars:darth_sidious")
end

-- ============================================================
-- ON PUNCH
-- ============================================================

-- on_punch helper για Yoda/Sidious
local function combat_on_punch(self, puncher, msg)
    if not puncher or not puncher:get_pos() then return end
    if msg and puncher:is_player() then
        minetest.chat_send_player(puncher:get_player_name(), msg)
    end
    self._aggro_target = puncher
end

local function default_on_punch(self, puncher)
    if puncher and puncher:get_pos() then
        self._aggro_target = puncher
    end
end

-- ============================================================
-- WEAPON CONFIGS PER NPC
-- ============================================================

local NPC_WEAPON = {
    ["star_wars:yoda"]             = {type = "lightsaber", color = "green",  hilt = "shoto"},
    ["star_wars:luke_skywalker"]   = {type = "lightsaber", color = "green",  hilt = "single"},
    ["star_wars:anakin_skywalker"] = {type = "lightsaber", color = "blue",   hilt = "single"},
    ["star_wars:obi_wan_kenobi"]   = {type = "lightsaber", color = "blue",   hilt = "single"},
    ["star_wars:qui_gon_jinn"]     = {type = "lightsaber", color = "green",  hilt = "single"},
    ["star_wars:darth_sidious"]    = {type = "lightsaber", color = "red",    hilt = "single"},
    ["star_wars:darth_vader"]      = {type = "lightsaber", color = "red",    hilt = "single"},
    ["star_wars:darth_maul"]       = {type = "lightsaber", color = "red",    hilt = "double"},
    ["star_wars:count_dooku"]      = {type = "lightsaber", color = "red",    hilt = "curved"},
    ["star_wars:darth_revan"]      = {type = "lightsaber", color = "red",    hilt = "cross"},
    ["star_wars:mandalorian"]      = {type = "darksaber"},
    ["star_wars:stormtrooper"]     = {type = "blaster"},
    ["star_wars:wookee"]           = {type = "auto_blaster"},
}

-- ============================================================
-- WEAPON VISUAL (attached entity)
-- ============================================================

local function attach_weapon(self)
    local weapon = NPC_WEAPON[self.name]
    if not weapon then return end

    local item_name
    local pos_offset = {x=0, y=5, z=3}
    local rot_offset = {x=90, y=315, z=270}

    if weapon.type == "lightsaber" then
        item_name = "star_wars:lightsaber_" .. weapon.hilt .. "_" .. weapon.color .. "_on"
        if weapon.hilt == "double" then
            pos_offset = {x=0, y=5, z=1.5}
            rot_offset = {x=90, y=315, z=270}
        end
    elseif weapon.type == "darksaber" then
        item_name = "star_wars:darksaber_on"
        pos_offset = {x=0, y=5, z=3}
        rot_offset = {x=90, y=315, z=270}
    elseif weapon.type == "blaster" then
        item_name = "star_wars:blaster"
        pos_offset = {x=0, y=5, z=1.4}
        rot_offset = {x=90, y=350, z=270}
    elseif weapon.type == "auto_blaster" then
    item_name = "star_wars:auto_blaster"
    pos_offset = {x=0, y=5, z=2}
    rot_offset = {x=90, y=315, z=270}
    end


    if not item_name then return end

    local ent = minetest.add_entity(self.object:get_pos(), "star_wars:npc_weapon_visual")
    if not ent then return end
    ent:set_attach(self.object, "Arm_Right", pos_offset, rot_offset)
    local lua = ent:get_luaentity()
    if lua then
        lua.parent = self.object
        ent:set_properties({textures = {item_name}})
    end
end

minetest.register_entity("star_wars:npc_weapon_visual", {
    initial_properties = {
        physical = false,
        collisionbox = {0, 0, 0, 0, 0, 0},
        visual = "wielditem",
        visual_size = {x = 0.25, y = 0.25, z = 0.25},
        textures = {""},
        static_save = false,
        pointable = false,
    },
    parent = nil,
    on_activate = function(self)
        self.object:set_armor_groups({immortal = 1})
    end,
    on_step = function(self)
        if not self.parent or not self.parent:get_pos() then
            self.object:remove()
        end
    end,
})

-- ============================================================
-- DEFLECT STEP
-- ============================================================

local DEFLECT_RADIUS = 3.5

local function npc_deflect_step(self)
    local pos = self.object:get_pos()
    if not pos then return end

    local nearby = minetest.get_objects_inside_radius(pos, DEFLECT_RADIUS)
    for _, obj in ipairs(nearby) do
        local ent = obj:get_luaentity()
        if ent and ent.name == "star_wars:laser" and obj ~= self.object then
            -- έλεγχος ότι δεν είναι δικό μας laser (shooter = self.object)
            if ent.shooter ~= self.object then
                local now = minetest.get_us_time()
                if not ent._last_deflect or (now - ent._last_deflect) > 100000 then
                    ent._last_deflect = now

                    -- ανάκλαση πίσω προς τον shooter
                    local laser_pos = obj:get_pos()
                    if not laser_pos then goto continue end

                    local reflect_dir
                    if ent.shooter and ent.shooter:get_pos() then
                        reflect_dir = vector.normalize(
                            vector.subtract(ent.shooter:get_pos(), laser_pos)
                        )
                    else
                        local vel = obj:get_velocity()
                        if vel and vector.length(vel) > 0.001 then
                            reflect_dir = vector.normalize(vector.multiply(vel, -1))
                        else
                            reflect_dir = vector.new(0, 0, 1)
                        end
                    end

                    ent.shooter = self.object
                    obj:set_velocity(vector.multiply(reflect_dir, ent.speed or 40))

                    -- rotation
                    local rot = reflect_dir:dir_to_rotation()
                    rot.y = rot.y - math.rad(360)
                    rot.z = 0
                    obj:set_rotation(rot)

                    minetest.sound_play("star_wars_clash", {
                        pos = laser_pos,
                        gain = 1.0,
                        max_hear_distance = 24,
                    })
                end
            end
            ::continue::
        end
    end
end

-- ============================================================
-- STORMTROOPER SHOOT STEP
-- ============================================================

local BLASTER_RANGE    = 14
local BLASTER_COOLDOWN = 1.2

local function npc_shoot_step(self, dtime)
    self._shoot_timer = (self._shoot_timer or 0) + dtime
    local cooldown = (self.name == "star_wars:wookee") and 0.3 or BLASTER_COOLDOWN
    if self._shoot_timer < cooldown then return end

    if not self.target then return end
    local tpos = self.target:get_pos()
    if not tpos then return end

    local pos = self.object:get_pos()
    if not pos then return end

    local dist = vector.distance(pos, tpos)
    if dist > BLASTER_RANGE then return end
  
    if not minetest.line_of_sight(
    {x = pos.x, y = pos.y + 1.0, z = pos.z},
    {x = tpos.x, y = tpos.y + 1.0, z = tpos.z}
    ) then return end

    self._shoot_timer = 0

    local shoot_pos = {x = pos.x, y = pos.y + 1.4, z = pos.z}
    local target_center = {x = tpos.x, y = tpos.y + 1.0, z = tpos.z}
    local dir = vector.normalize(vector.subtract(target_center, shoot_pos))

    local obj = minetest.add_entity(shoot_pos, "star_wars:laser")
    if obj then
        local lua = obj:get_luaentity()
        if lua then
            lua.shooter       = self.object
            lua.last_pos      = vector.new(shoot_pos)
            lua.damage        = 2
            lua.vehicle_damage = 2
            lua.speed         = 40
        end
        obj:set_velocity(vector.multiply(dir, 40))
        obj:set_acceleration({x = 0, y = 0, z = 0})

        -- rotation
        local rot = dir:dir_to_rotation()
        rot.y = rot.y - math.rad(360)
        rot.z = 0
        obj:set_rotation(rot)
    end

    minetest.sound_play("star_wars_blaster_shot", {
        pos = shoot_pos,
        gain = 1.0,
        max_hear_distance = 24,
    })
end

-- ============================================================
-- LIGHTSABER MELEE ATTACK
-- ============================================================

local function npc_saber_attack(self, target, weapon)
    if not target or not target:get_pos() then return end

    target:punch(self.object, 1.0, {
        full_punch_interval = 1.5,
        damage_groups = {fleshy = 8},
    }, nil)

    local sound = "star_wars_swing"
    if weapon and weapon.hilt == "cross" then
        sound = "star_wars_swing_cross"
    end
    minetest.sound_play(sound, {
        pos = self.object:get_pos(),
        gain = 1.0,
        max_hear_distance = 16,
    })
end

-- ============================================================
-- AI HELPERS
-- ============================================================

local DETECT_RADIUS = 15
local ATTACK_RADIUS = 1.5
local MOVE_SPEED    = 2.2
local WANDER_SPEED  = 2.2

local NPC_FACTION = {
    ["star_wars:yoda"]            = "jedi",
    ["star_wars:luke_skywalker"]  = "jedi",
    ["star_wars:anakin_skywalker"]= "jedi",
    ["star_wars:obi_wan_kenobi"]  = "jedi",
    ["star_wars:qui_gon_jinn"]    = "jedi",
    ["star_wars:darth_sidious"]   = "sith",
    ["star_wars:darth_vader"]     = "sith",
    ["star_wars:darth_maul"]      = "sith",
    ["star_wars:count_dooku"]     = "sith",
    ["star_wars:darth_revan"]     = "sith",
    ["star_wars:stormtrooper"]    = "sith",
}

local function get_ground_y(pos)
    for y = pos.y, pos.y - 5, -1 do
        local node = minetest.get_node({x = pos.x, y = y, z = pos.z})
        if node and minetest.registered_nodes[node.name]
        and minetest.registered_nodes[node.name].walkable then
            return y + 1
        end
    end
    return pos.y
end

local function has_clear_path(pos1, pos2)
    local a = {x = pos1.x, y = pos1.y + 1.0, z = pos1.z}
    local b = {x = pos2.x, y = pos2.y + 1.0, z = pos2.z}
    return minetest.line_of_sight(a, b)
end

local function set_anim(self, anim)
    if self.current_anim == anim then return end
    self.current_anim = anim
    if anim == "idle" then
        self.object:set_animation({x = 0,   y = 79},  15, 0, true)
    elseif anim == "walk" then
        self.object:set_animation({x = 168, y = 187}, 15, 0, true)
    elseif anim == "attack" then
        self.object:set_animation({x = 200, y = 219}, 15, 0, false)
    end
end

local function face_pos(self, from_pos, to_pos)
    local dir = vector.direction(from_pos, to_pos)
    local yaw = minetest.dir_to_yaw(dir)
    self.object:set_yaw(yaw)
    return yaw
end

local function set_forward_velocity(self, speed)
    local yaw = self.object:get_yaw() or 0
    local dir = minetest.yaw_to_dir(yaw)
    local vel = self.object:get_velocity()
    self.object:set_velocity({x = dir.x * speed, y = vel.y, z = dir.z * speed})
end

local function stop_horizontal(self)
    local vel = self.object:get_velocity()
    self.object:set_velocity({x = 0, y = vel.y, z = 0})
end

local function path_blocked_ahead(pos, yaw, dist)
    local dir  = minetest.yaw_to_dir(yaw)
    local from = {x = pos.x, y = pos.y + 1.0, z = pos.z}
    local to   = vector.add(from, vector.multiply(dir, dist or 1.5))
    return not minetest.line_of_sight(from, to)
end

local function pick_wander_yaw(pos)
    local base = math.random() * math.pi * 2
    for i = 0, 7 do
        local yaw = base + i * (math.pi / 4)
        if not path_blocked_ahead(pos, yaw, 2.0) then
            return yaw
        end
    end
    return base + math.pi
end

-- Ελέγχει αν ένα object είναι εχθρός βάσει faction
local function is_enemy_of(obj, enemy_faction)
    if obj:is_player() then
        return star_wars.get_faction(obj:get_player_name()) == enemy_faction
    else
        local ent = obj:get_luaentity()
        if ent and NPC_FACTION[ent.name] then
            return NPC_FACTION[ent.name] == enemy_faction
        end
    end
    return false
end

local function find_target(pos, enemy_faction, self_obj)
    local nearby       = minetest.get_objects_inside_radius(pos, DETECT_RADIUS)
    local target       = nil
    local nearest_dist = DETECT_RADIUS + 0.1

    for _, obj in ipairs(nearby) do
        if obj == self_obj then goto continue end
        if is_enemy_of(obj, enemy_faction) then
            local opos = obj:get_pos()
            local d    = vector.distance(pos, opos)
            if d < nearest_dist and has_clear_path(pos, opos) then
                nearest_dist = d
                target = obj
            end
        end
        ::continue::
    end

    return target, nearest_dist
end

-- ============================================================
-- AI STEP
-- ============================================================

local function ai_step(self, dtime, enemy_faction, aggro_any)
    local pos = self.object:get_pos()
    if not pos then return end

    local weapon = NPC_WEAPON[self.name]

    self.move_timer   = (self.move_timer   or 0) + dtime
    self.attack_timer = (self.attack_timer or 0) + dtime
    self.idle_timer   = (self.idle_timer   or 0) + dtime
    self.target_timer = (self.target_timer or 0) + dtime
    self.jump_timer   = (self.jump_timer   or 0) + dtime

    -- aggro από punch
    if self._aggro_target then
        local aobj = self._aggro_target
        self._aggro_target = nil
        if aobj and aobj:get_pos() then
            self.target = aobj
            self._aggro_from_punch = true
        end
    end

    -- αναζήτηση target
    if self.target_timer > 0.5 then
        self.target_timer = 0
        if enemy_faction and (not self.target or not self.target:get_pos()) then
            self.target, _ = find_target(pos, enemy_faction, self.object)
            self._aggro_from_punch = false
        end
    end

    -- χάνει target
    if self.target then
        local tpos = self.target:get_pos()
        if not tpos or vector.distance(pos, tpos) > DETECT_RADIUS then
            self.target = nil
            self._aggro_from_punch = false
        elseif self.target:is_player() and self.target:get_hp() <= 0 then
            self.target = nil
            self._aggro_from_punch = false
        elseif not self._aggro_from_punch and enemy_faction
        and not is_enemy_of(self.target, enemy_faction) then
            self.target = nil
        end
    end

    -- ATTACK
    if self.attack_timer > 1.5 then
        self.attack_timer = 0
        if self.target then
            local tpos = self.target:get_pos()
            if tpos then
                local dist = vector.distance(pos, tpos)
                local do_attack = self._aggro_from_punch
                    or (enemy_faction and is_enemy_of(self.target, enemy_faction))

                if do_attack then
                    -- stormtrooper: δεν κάνει melee εδώ, το handle-άρει npc_shoot_step
                    if weapon and weapon.type ~= "blaster"
                    and dist <= ATTACK_RADIUS
                    and has_clear_path(pos, tpos) then
                        npc_saber_attack(self, self.target, weapon)
                        set_anim(self, "attack")
                        local self_obj = self.object
                        local self_ref = self
                        minetest.after(0.6, function()
                            if not self_obj or not self_obj:get_pos() then return end
                            local t = self_ref.target
                            if t and t:get_pos() then
                                local mypos = self_obj:get_pos()
                                if vector.distance(mypos, t:get_pos()) > ATTACK_RADIUS then
                                    set_anim(self_ref, "walk")
                                else
                                    set_anim(self_ref, "idle")
                                end
                            else
                                set_anim(self_ref, "walk")
                            end
                        end)
                    end
                else
                    self.target = nil
                end
            end
        end
    end

    -- STORMTROOPER SHOOT
    if weapon and (weapon.type == "blaster" or weapon.type == "auto_blaster") then
        npc_shoot_step(self, dtime)
    end

    -- LIGHTSABER/DARKSABER DEFLECT
    if weapon and (weapon.type == "lightsaber" or weapon.type == "darksaber") then
        npc_deflect_step(self)
    end

    -- MOVE
    if self.move_timer > 0.35 then
        self.move_timer = 0
        pos = self.object:get_pos()
        if not pos then return end

        local moving = false

        if self.target and self.target:get_pos() then
            local tpos = self.target:get_pos()
            local dist = vector.distance(pos, tpos)

            -- stormtrooper: κρατά απόσταση για να πυροβολεί
            local keep_dist = (weapon and weapon.type == "blaster") and 15 or ATTACK_RADIUS

            if dist > keep_dist then
                local yaw = face_pos(self, pos, tpos)
                if path_blocked_ahead(pos, yaw, 1.2) then
                    self.object:set_yaw(pick_wander_yaw(pos))
                end
                set_forward_velocity(self, MOVE_SPEED)
                set_anim(self, "walk")
                moving = true
            else
                stop_horizontal(self)
                face_pos(self, pos, tpos)
                set_anim(self, "idle")
            end
        end

        if not self.target then
            if (not self.wander_yaw)
            or self.idle_timer > 3.0
            or path_blocked_ahead(pos, self.wander_yaw, 1.5) then
                self.idle_timer = 0
                self.wander_yaw = pick_wander_yaw(pos)
                self.object:set_yaw(self.wander_yaw)
            end
            set_forward_velocity(self, WANDER_SPEED)
            set_anim(self, "walk")
            moving = true
        end

        if not moving then
            stop_horizontal(self)
            set_anim(self, "idle")
        end

        local ground_y = get_ground_y(pos)
        local vel = self.object:get_velocity()
        if pos.y < ground_y and vel and vel.y < 0 then
            self.object:set_velocity({x = vel.x, y = 0, z = vel.z})
            self.object:set_pos({x = pos.x, y = ground_y, z = pos.z})
        end
    end

    -- JUMP (αμετάβλητο)
    if self.jump_timer > 0.1 then
        self.jump_timer = 0
        pos = self.object:get_pos()
        if not pos then return end
        local vel = self.object:get_velocity()
        if self._is_jumping then
            if vel and math.abs(vel.y) < 0.1 then self._is_jumping = false end
        elseif vel then
            local yaw   = self.object:get_yaw() or 0
            local dir   = minetest.yaw_to_dir(yaw)
            local check = {x = pos.x + dir.x * 0.8, y = pos.y + 0.5, z = pos.z + dir.z * 0.8}
            local node  = minetest.get_node(check)
            if node and minetest.registered_nodes[node.name]
            and minetest.registered_nodes[node.name].walkable then
                self._is_jumping = true
                self.object:set_velocity({x = dir.x * MOVE_SPEED, y = 4.5, z = dir.z * MOVE_SPEED})
            end
        end
    end
end

-- ============================================================
-- YODA
-- ============================================================

minetest.register_entity("star_wars:yoda", {
    initial_properties = {
        physical = true,
        collisionbox = {-0.3, 0, -0.3, 0.3, 1.8, 0.3},
        visual = "mesh", mesh = "character.b3d",
        textures = {"yoda.png"},
        visual_size = {x = 1.1, y = 1.1, z = 1.1},
        makes_footstep_sound = true,
        hp_max = 30,
    },
    is_npc = true,
    move_timer = 0, attack_timer = 0, idle_timer = 0, jump_timer = 0,
    on_activate = function(self)
        self.object:set_armor_groups({immortal = 1})
        self.object:set_acceleration({x = 0, y = -10, z = 0})
        self.object:set_animation({x = 0, y = 79}, 15, 0, true)
        attach_weapon(self)
    end,
    on_step = function(self, dtime) ai_step(self, dtime, "sith", true) end,

    on_rightclick = function(self, clicker)
        if not clicker or not clicker:is_player() then return end
        local name = clicker:get_player_name()
        if star_wars.get_faction(name) ~= "jedi" then
            minetest.chat_send_player(name, "Yoda: Only Jedi may train with me.")
            return
        end
        star_wars.show_master_formspec(name, "Yoda")
    end,
    on_punch = function(self, puncher)
        combat_on_punch(self, puncher, "Yoda: You attack me, may not.")
    end,
})

-- ============================================================
-- DARTH SIDIOUS
-- ============================================================

minetest.register_entity("star_wars:darth_sidious", {
    initial_properties = {
        physical = true,
        collisionbox = {-0.3, 0, -0.3, 0.3, 1.8, 0.3},
        visual = "mesh", mesh = "character.b3d",
        textures = {"darth_sidious.png"},
        visual_size = {x = 1.1, y = 1.1, z = 1.1},
        makes_footstep_sound = true,
        hp_max = 30,
    },
    is_npc = true,
    move_timer = 0, attack_timer = 0, idle_timer = 0, jump_timer = 0,
    on_activate = function(self)
        self.object:set_armor_groups({immortal = 1})
        self.object:set_acceleration({x = 0, y = -10, z = 0})
        self.object:set_animation({x = 0, y = 79}, 15, 0, true)
        attach_weapon(self)
    end,

    on_step = function(self, dtime) ai_step(self, dtime, "jedi", true) end,

    on_rightclick = function(self, clicker)
        if not clicker or not clicker:is_player() then return end
        local name = clicker:get_player_name()
        if star_wars.get_faction(name) ~= "sith" then
            minetest.chat_send_player(name, "Darth Sidious: Leave.")
            return
        end
        star_wars.show_master_formspec(name, "Darth Sidious")
    end,
    on_punch = function(self, puncher)
        combat_on_punch(self, puncher, "Darth Sidious: Foolish.")
    end,
})

-- ============================================================
-- LUKE SKYWALKER
-- ============================================================

minetest.register_entity("star_wars:luke_skywalker", {
    initial_properties = {
        physical = true,
        collisionbox = {-0.3, 0, -0.3, 0.3, 1.8, 0.3},
        visual = "mesh", mesh = "character.b3d",
        textures = {"luke_skywalker.png"},
        visual_size = {x = 1.1, y = 1.1, z = 1.1},
        makes_footstep_sound = true,
        hp_max = 40,
    },
    is_npc = true,
    move_timer = 0, attack_timer = 0, idle_timer = 0, jump_timer = 0,
    on_activate = function(self)
        self.object:set_acceleration({x = 0, y = -10, z = 0})
        self.object:set_animation({x = 0, y = 79}, 15, 0, true)
        attach_weapon(self)
    end,
    on_step = function(self, dtime)
        ai_step(self, dtime, "sith", true)
    end,
    on_punch = function(self, puncher) default_on_punch(self, puncher) end,
on_death = function(self, killer)
    local pos = self.object:get_pos()
    
    if pos then
        if math.random(1, 100) <= 15 then
            minetest.add_item(pos, "star_wars:lightsaber_single_green_off")
        end
        
        if self.inventory_slots then
            for _, item_string in pairs(self.inventory_slots) do
                if item_string and item_string ~= "" then
                    if math.random(1, 100) <= 50 then
                        minetest.add_item(pos, ItemStack(item_string))
                    end
                end
            end
        end
    end
end,
})

-- ============================================================
-- ANAKIN SKYWALKER
-- ============================================================

minetest.register_entity("star_wars:anakin_skywalker", {
    initial_properties = {
        physical = true,
        collisionbox = {-0.3, 0, -0.3, 0.3, 1.8, 0.3},
        visual = "mesh", mesh = "character.b3d",
        textures = {"anakin_skywalker.png"},
        visual_size = {x = 1.1, y = 1.1, z = 1.1},
        makes_footstep_sound = true,
        hp_max = 40,
    },
    is_npc = true,
    move_timer = 0, attack_timer = 0, idle_timer = 0, jump_timer = 0,
    on_activate = function(self)
        self.object:set_acceleration({x = 0, y = -10, z = 0})
        self.object:set_animation({x = 0, y = 79}, 15, 0, true)
        attach_weapon(self)
    end,
    on_step = function(self, dtime)
        ai_step(self, dtime, "sith", true)
    end,
    on_punch = function(self, puncher) default_on_punch(self, puncher) end,
on_death = function(self, killer)
    local pos = self.object:get_pos()
    
    if pos then
        if math.random(1, 100) <= 15 then
            minetest.add_item(pos, "star_wars:lightsaber_single_blue_off")
        end
        
        if self.inventory_slots then
            for _, item_string in pairs(self.inventory_slots) do
                if item_string and item_string ~= "" then
                    if math.random(1, 100) <= 50 then
                        minetest.add_item(pos, ItemStack(item_string))
                    end
                end
            end
        end
    end
end,
})

-- ============================================================
-- OBI WAN KENOBI
-- ============================================================

minetest.register_entity("star_wars:obi_wan_kenobi", {
    initial_properties = {
        physical = true,
        collisionbox = {-0.3, 0, -0.3, 0.3, 1.8, 0.3},
        visual = "mesh", mesh = "character.b3d",
        textures = {"obi_wan_kenobi.png"},
        visual_size = {x = 1.1, y = 1.1, z = 1.1},
        makes_footstep_sound = true,
        hp_max = 40,
    },
    is_npc = true,
    move_timer = 0, attack_timer = 0, idle_timer = 0, jump_timer = 0,
    on_activate = function(self)
        self.object:set_acceleration({x = 0, y = -10, z = 0})
        self.object:set_animation({x = 0, y = 79}, 15, 0, true)
        attach_weapon(self)
    end,
    on_step = function(self, dtime)
        ai_step(self, dtime, "sith", true)
    end,
    on_punch = function(self, puncher) default_on_punch(self, puncher) end,
on_death = function(self, killer)
    local pos = self.object:get_pos()
    
    if pos then
        if math.random(1, 100) <= 15 then
            minetest.add_item(pos, "star_wars:lightsaber_single_blue_off")
        end
        
        if self.inventory_slots then
            for _, item_string in pairs(self.inventory_slots) do
                if item_string and item_string ~= "" then
                    if math.random(1, 100) <= 50 then
                        minetest.add_item(pos, ItemStack(item_string))
                    end
                end
            end
        end
    end
end,
})

-- ============================================================
-- QUI GON JINN
-- ============================================================

minetest.register_entity("star_wars:qui_gon_jinn", {
    initial_properties = {
        physical = true,
        collisionbox = {-0.3, 0, -0.3, 0.3, 1.8, 0.3},
        visual = "mesh", mesh = "character.b3d",
        textures = {"qui_gon_jinn.png"},
        visual_size = {x = 1.1, y = 1.1, z = 1.1},
        makes_footstep_sound = true,
        hp_max = 40,
    },
    is_npc = true,
    move_timer = 0, attack_timer = 0, idle_timer = 0, jump_timer = 0,
    on_activate = function(self)
        self.object:set_acceleration({x = 0, y = -10, z = 0})
        self.object:set_animation({x = 0, y = 79}, 15, 0, true)
        attach_weapon(self)
    end,
    on_step = function(self, dtime)
        ai_step(self, dtime, "sith", true)
    end,
    on_punch = function(self, puncher) default_on_punch(self, puncher) end,
on_death = function(self, killer)
    local pos = self.object:get_pos()
    
    if pos then
        if math.random(1, 100) <= 15 then
            minetest.add_item(pos, "star_wars:lightsaber_single_green_off")
        end
        
        if self.inventory_slots then
            for _, item_string in pairs(self.inventory_slots) do
                if item_string and item_string ~= "" then
                    if math.random(1, 100) <= 50 then
                        minetest.add_item(pos, ItemStack(item_string))
                    end
                end
            end
        end
    end
end,
})

-- ============================================================
-- DARTH VADER
-- ============================================================

minetest.register_entity("star_wars:darth_vader", {
    initial_properties = {
        physical = true,
        collisionbox = {-0.3, 0, -0.3, 0.3, 1.8, 0.3},
        visual = "mesh", mesh = "character.b3d",
        textures = {"darth_vader.png"},
        visual_size = {x = 1.1, y = 1.1, z = 1.1},
        makes_footstep_sound = true,
        hp_max = 40,
    },
    is_npc = true,
    move_timer = 0, attack_timer = 0, idle_timer = 0, jump_timer = 0,
    on_activate = function(self)
        self.object:set_acceleration({x = 0, y = -10, z = 0})
        self.object:set_animation({x = 0, y = 79}, 15, 0, true)
        attach_weapon(self)
    end,
    on_step = function(self, dtime)
        ai_step(self, dtime, "jedi", true)
    end,
    on_punch = function(self, puncher) default_on_punch(self, puncher) end,
on_death = function(self, killer)
    local pos = self.object:get_pos()
    
    if pos then
        if math.random(1, 100) <= 15 then
            minetest.add_item(pos, "star_wars:lightsaber_single_red_off")
        end
        
        if self.inventory_slots then
            for _, item_string in pairs(self.inventory_slots) do
                if item_string and item_string ~= "" then
                    if math.random(1, 100) <= 50 then
                        minetest.add_item(pos, ItemStack(item_string))
                    end
                end
            end
        end
    end
end,
})

-- ============================================================
-- DARTH MAUL
-- ============================================================

minetest.register_entity("star_wars:darth_maul", {
    initial_properties = {
        physical = true,
        collisionbox = {-0.3, 0, -0.3, 0.3, 1.8, 0.3},
        visual = "mesh", mesh = "character.b3d",
        textures = {"darth_maul.png"},
        visual_size = {x = 1.1, y = 1.1, z = 1.1},
        makes_footstep_sound = true,
        hp_max = 40,
    },
    is_npc = true,
    move_timer = 0, attack_timer = 0, idle_timer = 0, jump_timer = 0,
    on_activate = function(self)
        self.object:set_acceleration({x = 0, y = -10, z = 0})
        self.object:set_animation({x = 0, y = 79}, 15, 0, true)
        attach_weapon(self)
    end,
    on_step = function(self, dtime)
        ai_step(self, dtime, "jedi", true)
    end,
    on_punch = function(self, puncher) default_on_punch(self, puncher) end,
on_death = function(self, killer)
    local pos = self.object:get_pos()
    
    if pos then
        if math.random(1, 100) <= 15 then
            minetest.add_item(pos, "star_wars:lightsaber_double_red_off")
        end
        
        if self.inventory_slots then
            for _, item_string in pairs(self.inventory_slots) do
                if item_string and item_string ~= "" then
                    if math.random(1, 100) <= 50 then
                        minetest.add_item(pos, ItemStack(item_string))
                    end
                end
            end
        end
    end
end,
})

-- ============================================================
-- COUNT DOOKU
-- ============================================================

minetest.register_entity("star_wars:count_dooku", {
    initial_properties = {
        physical = true,
        collisionbox = {-0.3, 0, -0.3, 0.3, 1.8, 0.3},
        visual = "mesh", mesh = "character.b3d",
        textures = {"count_dooku.png"},
        visual_size = {x = 1.1, y = 1.1, z = 1.1},
        makes_footstep_sound = true,
        hp_max = 40,
    },
    is_npc = true,
    move_timer = 0, attack_timer = 0, idle_timer = 0, jump_timer = 0,
    on_activate = function(self)
        self.object:set_acceleration({x = 0, y = -10, z = 0})
        self.object:set_animation({x = 0, y = 79}, 15, 0, true)
        attach_weapon(self)
    end,
    on_step = function(self, dtime)
        ai_step(self, dtime, "jedi", true)
    end,
    on_punch = function(self, puncher) default_on_punch(self, puncher) end,
on_death = function(self, killer)
    local pos = self.object:get_pos()
    
    if pos then
        if math.random(1, 100) <= 15 then
            minetest.add_item(pos, "star_wars:lightsaber_curved_red_off")
        end
        
        if self.inventory_slots then
            for _, item_string in pairs(self.inventory_slots) do
                if item_string and item_string ~= "" then
                    if math.random(1, 100) <= 50 then
                        minetest.add_item(pos, ItemStack(item_string))
                    end
                end
            end
        end
    end
end,
})

-- ============================================================
-- DARTH REVAN
-- ============================================================

minetest.register_entity("star_wars:darth_revan", {
    initial_properties = {
        physical = true,
        collisionbox = {-0.3, 0, -0.3, 0.3, 1.8, 0.3},
        visual = "mesh", mesh = "character.b3d",
        textures = {"darth_revan.png"},
        visual_size = {x = 1.1, y = 1.1, z = 1.1},
        makes_footstep_sound = true,
        hp_max = 40,
    },
    is_npc = true,
    move_timer = 0, attack_timer = 0, idle_timer = 0, jump_timer = 0,
    on_activate = function(self)
        self.object:set_acceleration({x = 0, y = -10, z = 0})
        self.object:set_animation({x = 0, y = 79}, 15, 0, true)
        attach_weapon(self)
    end,
    on_step = function(self, dtime)
        ai_step(self, dtime, "jedi", true)
    end,
    on_punch = function(self, puncher) default_on_punch(self, puncher) end,
on_death = function(self, killer)
    local pos = self.object:get_pos()
    
    if pos then
        if math.random(1, 100) <= 30 then
            minetest.add_item(pos, "star_wars:lightsaber_cross_red_off")
        end
        
        if self.inventory_slots then
            for _, item_string in pairs(self.inventory_slots) do
                if item_string and item_string ~= "" then
                    if math.random(1, 100) <= 50 then
                        minetest.add_item(pos, ItemStack(item_string))
                    end
                end
            end
        end
    end
end,
})

-- ============================================================
-- STORMTROOPER
-- ============================================================

minetest.register_entity("star_wars:stormtrooper", {
    initial_properties = {
        physical = true,
        collisionbox = {-0.3, 0, -0.3, 0.3, 1.8, 0.3},
        visual = "mesh", mesh = "character.b3d",
        textures = {"stormtrooper.png"},
        visual_size = {x = 1.1, y = 1.1, z = 1.1},
        makes_footstep_sound = true,
        hp_max = 20,
    },
    is_npc = true,
    move_timer = 0, attack_timer = 0, idle_timer = 0, jump_timer = 0,
    on_activate = function(self)
        self.object:set_acceleration({x = 0, y = -10, z = 0})
        self.object:set_animation({x = 0, y = 79}, 15, 0, true)
        attach_weapon(self)
    end,
    on_step = function(self, dtime)
        ai_step(self, dtime, "jedi", false)
    end,
on_death = function(self, killer)
    local pos = self.object:get_pos()
    
    if pos then
        if math.random(1, 100) <= 30 then
            minetest.add_item(pos, "star_wars:blaster")
        end
        
        if self.inventory_slots then
            for _, item_string in pairs(self.inventory_slots) do
                if item_string and item_string ~= "" then
                    if math.random(1, 100) <= 50 then
                        minetest.add_item(pos, ItemStack(item_string))
                    end
                end
            end
        end
    end
end,
})

-- ============================================================
-- JAR JAR BINKS
-- ============================================================

minetest.register_entity("star_wars:jar_jar_binks", {
    initial_properties = {
        physical = true,
        collisionbox = {-0.3, 0, -0.3, 0.3, 1.8, 0.3},
        visual = "mesh", mesh = "character.b3d",
        textures = {"jar_jar_binks.png"},
        visual_size = {x = 1.1, y = 1.1, z = 1.1},
        makes_footstep_sound = true,
        hp_max = 20,
    },
    is_npc = true,
    move_timer = 0, idle_timer = 0, jump_timer = 0,
    on_activate = function(self)
        self.object:set_acceleration({x = 0, y = -10, z = 0})
        self.object:set_animation({x = 0, y = 79}, 15, 0, true)
    end,
    on_step = function(self, dtime)
        ai_step(self, dtime, nil, false)
    end,
})

-- ============================================================
-- MANDALORIAN
-- ============================================================

minetest.register_entity("star_wars:mandalorian", {
    initial_properties = {
        physical = true,
        collisionbox = {-0.3, 0, -0.3, 0.3, 1.8, 0.3},
        visual = "mesh", mesh = "character.b3d",
        textures = {"mandalorian.png"},
        visual_size = {x = 1.1, y = 1.1, z = 1.1},
        makes_footstep_sound = true,
        hp_max = 40,
    },
    is_npc = true,
    move_timer = 0, attack_timer = 0, idle_timer = 0, jump_timer = 0,
    on_activate = function(self)
        self.object:set_acceleration({x = 0, y = -10, z = 0})
        self.object:set_animation({x = 0, y = 79}, 15, 0, true)
        attach_weapon(self)
    end,
    on_step = function(self, dtime)
        ai_step(self, dtime, nil, true)
    end,
    on_punch = function(self, puncher) default_on_punch(self, puncher) end,
on_death = function(self, killer)
    local pos = self.object:get_pos()
    
    if pos then
        if math.random(1, 100) <= 100 then
            minetest.add_item(pos, "star_wars:darksaber_off")
        end
        
        if self.inventory_slots then
            for _, item_string in pairs(self.inventory_slots) do
                if item_string and item_string ~= "" then
                    if math.random(1, 100) <= 50 then
                        minetest.add_item(pos, ItemStack(item_string))
                    end
                end
            end
        end
    end
end,
})

-- ============================================================
-- WOOKEE
-- ============================================================

minetest.register_entity("star_wars:wookee", {
    initial_properties = {
        physical = true,
        collisionbox = {-0.3, 0, -0.3, 0.3, 1.8, 0.3},
        visual = "mesh", mesh = "character.b3d",
        textures = {"wookee.png"},
        visual_size = {x = 1.1, y = 1.1, z = 1.1},
        makes_footstep_sound = true,
        hp_max = 40,
    },
    is_npc = true,
    move_timer = 0, attack_timer = 0, idle_timer = 0, jump_timer = 0,
    on_activate = function(self)
        self.object:set_acceleration({x = 0, y = -10, z = 0})
        self.object:set_animation({x = 0, y = 79}, 15, 0, true)
        attach_weapon(self)
    end,
    on_step = function(self, dtime)
        ai_step(self, dtime, nil, true)
    end,
    on_punch = function(self, puncher) default_on_punch(self, puncher) end,

on_death = function(self, killer)
    local pos = self.object:get_pos()
    
    if pos then
        if math.random(1, 100) <= 30 then
            minetest.add_item(pos, "star_wars:auto_blaster")
        end
        
        if self.inventory_slots then
            for _, item_string in pairs(self.inventory_slots) do
                if item_string and item_string ~= "" then
                    if math.random(1, 100) <= 50 then
                        minetest.add_item(pos, ItemStack(item_string))
                    end
                end
            end
        end
    end
end,
})
