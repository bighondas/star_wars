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
-- AI HELPERS
-- ============================================================

local DETECT_RADIUS = 10
local ATTACK_RADIUS = 2.5
local MOVE_SPEED = 2.2
local WANDER_SPEED = 1.2

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
        self.object:set_animation({x = 0, y = 79}, 15, 0, true)
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

    self.object:set_velocity({
        x = dir.x * speed,
        y = vel.y,
        z = dir.z * speed
    })
end

local function stop_horizontal(self)
    local vel = self.object:get_velocity()
    self.object:set_velocity({x = 0, y = vel.y, z = 0})
end

local function path_blocked_ahead(pos, yaw, dist)
    local dir = minetest.yaw_to_dir(yaw)
    local from = {x = pos.x, y = pos.y + 1.0, z = pos.z}
    local to = vector.add(from, vector.multiply(dir, dist or 1.5))
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

local function find_target(pos, enemy_faction)
    local nearby = minetest.get_objects_inside_radius(pos, DETECT_RADIUS)
    local target = nil
    local nearest_dist = DETECT_RADIUS + 0.1

    for _, obj in ipairs(nearby) do
        if obj:is_player() then
            local name = obj:get_player_name()
            local faction = star_wars.get_faction(name)

            if faction == enemy_faction then
                local opos = obj:get_pos()
                local d = vector.distance(pos, opos)

                if d < nearest_dist and has_clear_path(pos, opos) then
                    nearest_dist = d
                    target = obj
                end
            end
        end
    end

    return target, nearest_dist
end

local function ai_step(self, dtime, enemy_faction)
    local pos = self.object:get_pos()
    if not pos then return end

    self.move_timer = (self.move_timer or 0) + dtime
    self.attack_timer = (self.attack_timer or 0) + dtime
    self.idle_timer = (self.idle_timer or 0) + dtime
    self.target_timer = (self.target_timer or 0) + dtime

    if self.target_timer > 0.5 then
        self.target_timer = 0
        self.target, self.target_dist = find_target(pos, enemy_faction)
    end

    if self.attack_timer > 1.5 then
        self.attack_timer = 0
        local nearby = minetest.get_objects_inside_radius(pos, ATTACK_RADIUS)

        for _, obj in ipairs(nearby) do
            if obj:is_player() then
                local name = obj:get_player_name()
                local faction = star_wars.get_faction(name)

                if faction == enemy_faction then
                    local opos = obj:get_pos()
                    if opos and has_clear_path(pos, opos) then
                        obj:punch(self.object, 1.0, {
                            full_punch_interval = 1.5,
                            damage_groups = {fleshy = 4}
                        }, nil)
                        set_anim(self, "attack")

                        local self_obj = self.object
                        local self_ref = self
                        minetest.after(0.6, function()
                            if not self_obj or not self_obj:get_pos() then return end
                            local t = self_ref.target
                            if t and t:get_pos() then
                                local mypos = self_obj:get_pos()
                                local tpos = t:get_pos()
                                if vector.distance(mypos, tpos) > ATTACK_RADIUS then
                                    set_anim(self_ref, "walk")
                                else
                                    set_anim(self_ref, "idle")
                                end
                            else
                                set_anim(self_ref, "walk")
                            end
                        end)
                    end
                end
            end
        end
    end

    if self.move_timer > 0.35 then
        self.move_timer = 0
        pos = self.object:get_pos()
        if not pos then return end

        local moving = false

        if self.target and self.target:get_pos() then
            local tpos = self.target:get_pos()
            local dist = vector.distance(pos, tpos)

            if dist <= DETECT_RADIUS and has_clear_path(pos, tpos) then
                if dist > ATTACK_RADIUS then
                    local yaw = face_pos(self, pos, tpos)

                    if path_blocked_ahead(pos, yaw, 1.2) then
                        local new_yaw = pick_wander_yaw(pos)
                        self.object:set_yaw(new_yaw)
                    end

                    set_forward_velocity(self, MOVE_SPEED)
                    set_anim(self, "walk")
                    moving = true
                else
                    stop_horizontal(self)
                    face_pos(self, pos, tpos)
                    set_anim(self, "idle")
                    moving = false
                end
            else
                self.target = nil
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

    -- Jump over obstacles
    self.jump_timer = (self.jump_timer or 0) + dtime
    if self.jump_timer > 0.1 then
        self.jump_timer = 0
        local vel = self.object:get_velocity()
        if vel and vel.y > -1 and vel.y < 1 then
            local yaw = self.object:get_yaw() or 0
            local dir = minetest.yaw_to_dir(yaw)
            local check = {x = pos.x + dir.x * 0.8, y = pos.y + 0.5, z = pos.z + dir.z * 0.8}
            local node = minetest.get_node(check)
            if node and minetest.registered_nodes[node.name]
            and minetest.registered_nodes[node.name].walkable then
                self.object:set_velocity({
                    x = dir.x * MOVE_SPEED,
                    y = 4.5,
                    z = dir.z * MOVE_SPEED,
                })
            else
                self.jump_timer = 0.09
            end
        end
    end
end 

-- ============================================================
-- YODA MOB
-- ============================================================

minetest.register_entity("star_wars:yoda", {
    initial_properties = {
        physical = true,
        collisionbox = {-0.3, 0, -0.3, 0.3, 1.8, 0.3},
        visual = "mesh",
        mesh = "character.b3d",
        textures = {"yoda.png"},
        visual_size = {x = 1.1, y = 1.1, z = 1.1},
        makes_footstep_sound = true,
        hp_max = 30,
    },
    is_npc = true,
    move_timer = 0,
    attack_timer = 0,
    idle_timer = 0,
    on_activate = function(self, staticdata)
        self.object:set_armor_groups({immortal = 1})
        self.object:set_acceleration({x = 0, y = -10, z = 0})
        self.object:set_animation({x = 0, y = 79}, 15, 0, true)
        self.jump_timer = 0
    end,
    on_step = function(self, dtime)
        ai_step(self, dtime, "sith")
    end,

    on_rightclick = function(self, clicker)
        if not clicker or not clicker:is_player() then
            return
        end

        local name = clicker:get_player_name()
        if star_wars.get_faction(name) ~= "jedi" then
            minetest.chat_send_player(name, "Yoda: Only Jedi may train with me.")
            return
        end

        star_wars.show_master_formspec(name, "Yoda")
    end,

    on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir)
        if puncher and puncher:is_player() then
            minetest.chat_send_player(puncher:get_player_name(), "Yoda: You attack me, may not.")
        end
    end,
})

-- ============================================================
-- DARTH SIDIOUS MOB
-- ============================================================

minetest.register_entity("star_wars:darth_sidious", {
    initial_properties = {
        physical = true,
        collisionbox = {-0.3, 0, -0.3, 0.3, 1.8, 0.3},
        visual = "mesh",
        mesh = "character.b3d",
        textures = {"darth_sidious.png"},
        visual_size = {x = 1.1, y = 1.1, z = 1.1},
        makes_footstep_sound = true,
        hp_max = 30,
    },
    is_npc = true,
    move_timer = 0,
    attack_timer = 0,
    idle_timer = 0,
    on_activate = function(self, staticdata)
        self.object:set_armor_groups({immortal = 1})
        self.object:set_acceleration({x = 0, y = -10, z = 0})
        self.object:set_animation({x = 0, y = 79}, 15, 0, true)
    end,
    on_step = function(self, dtime)
        ai_step(self, dtime, "jedi")
    end,

    on_rightclick = function(self, clicker)
        if not clicker or not clicker:is_player() then
            return
        end

        local name = clicker:get_player_name()
        if star_wars.get_faction(name) ~= "sith" then
            minetest.chat_send_player(name, "Darth Sidious: Leave.")
            return
        end

        star_wars.show_master_formspec(name, "Darth Sidious")
    end,

    on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir)
        if puncher and puncher:is_player() then
            minetest.chat_send_player(puncher:get_player_name(), "Darth Sidious: Foolish.")
        end
    end,
})
