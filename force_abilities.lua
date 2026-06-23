star_wars = star_wars or {}

force_ability = {}
ability_cooldown = {}
stunned = {}
floating = {}
player_physics = {}
last_controls = {}
force_hud = {}
force_disabled = {}
active_choke = {}
active_lightning = {}

local cooldowns = {
    Jump = 5, Dash = 5, Push = 6, Choke = 10,
    ["Crystal Bond"] = 0, ["Crystal Bleed"] = 0,
    ["Saber Throw"] = 0,
    ["Force Lightning"] = 15,
    ["Heal"] = 10, ["Force Sense"] = 15,
    ["Pull"] = 8,
}

-- ============================================================
-- HUD & UTILITIES
-- ============================================================

local function get_next_ability(name)
    local order = star_wars.get_ability_order(name)
    local current = force_ability[name] or "None"
    local index = 1
    for i, n in ipairs(order) do
        if n == current then index = i; break end
    end
    index = index + 1
    if index > #order then index = 1 end
    return order[index]
end

function update_force_hud(player)
    local name = player:get_player_name()
    local faction = star_wars.get_faction(name)
    local faction_label = faction and (" [" .. faction:gsub("^%l", string.upper) .. "]") or " [No Faction]"
    local selected = force_ability[name] or "None"
    local text = "Force Ability: " .. selected .. faction_label
    if not force_hud[name] then
        force_hud[name] = player:hud_add({
            hud_elem_type = "text",
            position = {x = 0, y = 1},
            offset = {x = 20, y = -100},
            alignment = {x = 1, y = 1},
            number = 0xFFFFFF,
            text = text,
            scale = {x = 100, y = 20},
        })
    else
        player:hud_change(force_hud[name], "text", text)
    end
end

local function reset_player_physics(player)
    player:set_physics_override({speed = 1, gravity = 1, jump = 1})
end

-- ============================================================
-- JOIN / LEAVE / DIE / RESPAWN
-- ============================================================

minetest.register_on_joinplayer(function(player)
    local name = player:get_player_name()
    force_ability[name] = "None"
    ability_cooldown[name] = {}
    last_controls[name] = {aux1 = false, jump = false, RMB = false}
    minetest.after(0.2, function()
        local p = minetest.get_player_by_name(name)
        if p then
            update_force_hud(p)
        end
    end)
end)

minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    force_ability[name] = nil
    ability_cooldown[name] = nil
    last_controls[name] = nil
    force_hud[name] = nil
    stunned[name] = nil
    floating[name] = nil
    player_physics[name] = nil
    force_disabled[name] = nil
    active_choke[name] = nil
    active_lightning[name] = nil
end)

minetest.register_on_dieplayer(function(player)
    local name = player:get_player_name()

    -- Αν πέθανε κάποιος που ήταν υπό choke
    for caster_name, data in pairs(active_choke) do
        if data.target_name == name then
            -- Ενημέρωσε το quest του caster για choke kill
            star_wars.on_choke_kill(caster_name, name)
            active_choke[caster_name] = nil
            force_disabled[name] = nil
            break
        end
    end
    if active_choke[name] then
        local target = minetest.get_player_by_name(active_choke[name].target_name)
        if target then reset_player_physics(target) end
        force_disabled[active_choke[name].target_name] = nil
        active_choke[name] = nil
    end

    -- Αν πέθανε κάποιος που ήταν υπό lightning
    for caster_name, data in pairs(active_lightning) do
        if data.target_name == name then
            -- Ενημέρωσε το quest του caster για lightning kill
            star_wars.on_lightning_kill(caster_name, name)
            active_lightning[caster_name] = nil
            force_disabled[name] = nil
            break
        end
    end
    if active_lightning[name] then
        local target = minetest.get_player_by_name(active_lightning[name].target_name)
        if target then
            reset_player_physics(target)
            force_disabled[active_lightning[name].target_name] = nil
        end
        active_lightning[name] = nil
    end
end)

minetest.register_on_respawnplayer(function(player)
    reset_player_physics(player)
    local name = player:get_player_name()
    force_disabled[name] = nil
end)

-- ============================================================
-- KILL DETECTION (για kill_enemy και grandmaster_jedi quests)
-- ============================================================

minetest.register_on_dieplayer(function(player)
    local victim_name = player:get_player_name()
    local victim_faction = star_wars.get_faction(victim_name)
    if not victim_faction then return end

    local meta = player:get_meta()
    local killer_name = meta:get_string("star_wars:last_puncher")
    if killer_name and killer_name ~= "" then
        star_wars.on_kill_enemy(killer_name, victim_name)
    end
end)

-- ============================================================
-- COOLDOWN & TARGETING
-- ============================================================

local function can_use_ability(player, key, duration)
    local name = player:get_player_name()
    ability_cooldown[name] = ability_cooldown[name] or {}
    local now = minetest.get_gametime()
    local expires = ability_cooldown[name][key] or 0
    if now < expires then
        minetest.chat_send_player(name, key .. " cooldown: " .. math.ceil(expires - now) .. "s")
        return false
    end
    if duration > 0 then
        ability_cooldown[name][key] = now + duration
    end
    return true
end

local function ray_pointed_thing(player)
    local dir = player:get_look_dir()
    local pos = player:get_pos()
    pos.y = pos.y + (player:get_properties().eye_height or 1.625)
    local dest = vector.add(pos, vector.multiply(dir, 20))
    local ray = minetest.raycast(pos, dest, true, false)
    for pointed_thing in ray do
        if pointed_thing.type == "object" then
            local obj = pointed_thing.ref
            if obj and obj:is_player() and obj:get_player_name() ~= player:get_player_name() then
                return obj
            end
        end
    end
end

-- ============================================================
-- TRACK LAST PUNCHER (για kill detection)
-- ============================================================

minetest.register_on_punchplayer(function(player, hitter, time_from_last_punch, tool_capabilities, dir, damage)
    if hitter and hitter:is_player() then
        player:get_meta():set_string("star_wars:last_puncher", hitter:get_player_name())
    end
end)

-- ============================================================
-- FORCE JUMP (Both)
-- ============================================================

local function do_force_jump(player)
    if not can_use_ability(player, "Jump", cooldowns.Jump) then return end
    player:add_player_velocity({x = 0, y = 5, z = 0})
end

-- ============================================================
-- DASH (Both)
-- ============================================================

local function do_dash(player)
    if not can_use_ability(player, "Dash", cooldowns["Dash"]) then return end
    local dir = player:get_look_dir()
    local dash_dir = vector.normalize({x = dir.x, y = 0, z = dir.z})
    player:add_player_velocity(vector.multiply(dash_dir, 20))
    star_wars.on_dash(player:get_player_name())
end

-- ============================================================
-- FORCE PUSH (Jedi only)
-- ============================================================

local function do_force_push(player)
    local target = ray_pointed_thing(player)
    if not target then
        minetest.chat_send_player(player:get_player_name(), "No target for Force Push")
        return
    end
    if not can_use_ability(player, "Push", cooldowns.Push) then return end
    local dir = player:get_look_dir()
    target:add_player_velocity(vector.multiply(dir, 17))
end

-- ============================================================
-- FORCE PULL (Sith only)
-- ============================================================

local function do_force_pull(player)
    local name = player:get_player_name()
    if star_wars.get_faction(name) ~= "sith" then
        minetest.chat_send_player(name, "Only Sith can use Force Pull")
        return
    end
    local target = ray_pointed_thing(player)
    if not target then
        minetest.chat_send_player(name, "No target for Force Pull")
        return
    end
    if not can_use_ability(player, "Pull", cooldowns["Pull"]) then return end
    local dir = player:get_look_dir()
    target:add_player_velocity(vector.multiply(dir, -17))
end

-- ============================================================
-- FORCE SENSE (Jedi only)
-- ============================================================

local sense_active = {}

local function stop_force_sense(name)
    sense_active[name] = nil
end

local function do_force_sense(player)
    local name = player:get_player_name()
    if star_wars.get_faction(name) ~= "jedi" then
        minetest.chat_send_player(name, "Only Jedi can use Force Sense")
        return
    end
    if not can_use_ability(player, "Force Sense", cooldowns["Force Sense"]) then return end

    stop_force_sense(name)

    local pos = player:get_pos()
    local nearby = minetest.get_objects_inside_radius(pos, 100)
    local targets = {}
    local sensed_names = {}

    for _, obj in ipairs(nearby) do
        if obj:is_player() and obj:get_player_name() ~= name then
            local target_name = obj:get_player_name()
            local target_faction = star_wars.get_faction(target_name)
            local color
            if target_faction == "jedi" then
                color = "blue.png"
            elseif target_faction == "sith" then
                color = "red.png"
            else
                color = "white.png"
            end
            table.insert(targets, {obj = obj, color = color})
            table.insert(sensed_names, target_name)
        end
    end

    if #targets == 0 then
        minetest.chat_send_player(name, "No presence detected")
        return
    end

    minetest.chat_send_player(name, "Detected " .. #targets .. " presence(s)")

    sense_active[name] = {
        targets = targets,
        timer = 10,
    }

    -- Ενημέρωσε το quest system με τους παίκτες που εντοπίστηκαν
    star_wars.on_force_sense(name, sensed_names)
end

local function update_force_sense(dtime)
    for caster_name, data in pairs(sense_active) do
        local caster = minetest.get_player_by_name(caster_name)
        if not caster then
            stop_force_sense(caster_name)
        else
            data.timer = data.timer - dtime
            if data.timer <= 0 then
                stop_force_sense(caster_name)
            else
                for _, entry in ipairs(data.targets) do
                    local target = entry.obj
                    if target and target:get_pos() then
                        local tpos = target:get_pos()
                        tpos.y = tpos.y + 2.5
                        minetest.add_particlespawner({
                            amount = 1,
                            time = 0.2,
                            minpos = {x = tpos.x - 0.1, y = tpos.y - 0.1, z = tpos.z - 0.1},
                            maxpos = {x = tpos.x + 0.1, y = tpos.y + 0.1, z = tpos.z + 0.1},
                            minvel = {x = 0, y = 0, z = 0},
                            maxvel = {x = 0, y = 0, z = 0},
                            minacc = {x = 0, y = 0, z = 0},
                            maxacc = {x = 0, y = 0, z = 0},
                            minexptime = 0.25,
                            maxexptime = 0.25,
                            minsize = 3,
                            maxsize = 3,
                            texture = entry.color,
                            glow = 14,
                            playername = caster_name,
                        })
                    end
                end
            end
        end
    end
end

-- ============================================================
-- FORCE CHOKE (Sith only)
-- ============================================================

local function stop_force_choke(caster_name)
    local data = active_choke[caster_name]
    if not data then return end
    local target = minetest.get_player_by_name(data.target_name)
    if target then
        target:set_physics_override({speed = 1, gravity = 1, jump = 1})
    end
    local caster = minetest.get_player_by_name(caster_name)
    if caster then
        ability_cooldown[caster_name] = ability_cooldown[caster_name] or {}
        ability_cooldown[caster_name]["Choke"] = minetest.get_gametime() + cooldowns.Choke
    end
    force_disabled[data.target_name] = nil
    active_choke[caster_name] = nil
end

local function start_force_choke(player)
    local caster_name = player:get_player_name()
    if active_choke[caster_name] then return end

    local now = minetest.get_gametime()
    ability_cooldown[caster_name] = ability_cooldown[caster_name] or {}
    local expires = ability_cooldown[caster_name]["Choke"] or 0
    if now < expires then
        minetest.chat_send_player(caster_name, "Choke cooldown: " .. math.ceil(expires - now) .. "s")
        return
    end

    local target = ray_pointed_thing(player)
    if not target then
        minetest.chat_send_player(caster_name, "No target for Force Choke")
        return
    end
    local target_name = target:get_player_name()
    active_choke[caster_name] = {
        target_name = target_name,
        old_physics = {speed = 1, gravity = 1, jump = 1},
        time_left = 7,
        damage_timer = 0,
        lifted = false,
    }
    force_disabled[target_name] = true
    target:set_physics_override({speed = 0.1, gravity = 0.0, jump = 0})
    target:set_velocity({x = 0, y = 0, z = 0})
    minetest.after(0.05, function()
        local t = minetest.get_player_by_name(target_name)
        if t then
            t:set_velocity({x = 0, y = 0, z = 0})
            t:set_physics_override({speed = 0.1, gravity = 0.0, jump = 0})
        end
    end)
end

-- ============================================================
-- FORCE LIGHTNING (Sith only)
-- ============================================================

local function stop_force_lightning(caster_name)
    local data = active_lightning[caster_name]
    if not data then return end
    local target = minetest.get_player_by_name(data.target_name)
    if target then
        reset_player_physics(target)
        force_disabled[data.target_name] = nil
    end
    active_lightning[caster_name] = nil
end

local function start_force_lightning(player)
    local caster_name = player:get_player_name()
    if star_wars.get_faction(caster_name) ~= "sith" then
        minetest.chat_send_player(caster_name, "Only Sith can use Force Lightning")
        return
    end
    local item = player:get_wielded_item():get_name()
    if minetest.registered_items[item]
    and minetest.registered_items[item].groups
    and minetest.registered_items[item].groups.lightsaber == 1 then
        minetest.chat_send_player(caster_name, "You cannot use Force Lightning while wielding a lightsaber")
        return
    end
    if active_lightning[caster_name] then return end
    local target = ray_pointed_thing(player)
    if not target then
        minetest.chat_send_player(caster_name, "No target for Force Lightning")
        return
    end
    if not can_use_ability(player, "Force Lightning", cooldowns["Force Lightning"]) then return end
    local target_name = target:get_player_name()
    active_lightning[caster_name] = {
        target_name = target_name,
        damage_timer = 0,
        time_left = 10,
    }
    force_disabled[target_name] = true
    target:set_physics_override({speed = 0.3, gravity = 1, jump = 0})
end

-- ============================================================
-- FORCE HEAL (Jedi only)
-- ============================================================

local function do_heal(player)
    local name = player:get_player_name()
    if star_wars.get_faction(name) ~= "jedi" then return end
    if not can_use_ability(player, "Heal", cooldowns["Heal"]) then return end
    local hp = player:get_hp()
    local max_hp = player:get_properties().hp_max or 20
    player:set_hp(math.min(hp + 15, max_hp))
end

-- ============================================================
-- CRYSTAL BOND (Jedi only)
-- ============================================================

local function do_crystal_bond(player)
    if not can_use_ability(player, "Crystal Bond", cooldowns["Crystal Bond"]) then return end
    local item = player:get_wielded_item()
    if item:get_name() ~= "star_wars:kyber_crystal" then
        minetest.chat_send_player(player:get_player_name(), "You need to hold a Blank Kyber Crystal")
        return
    end
    local crystals = {
        "star_wars:blue_kyber_crystal",
        "star_wars:green_kyber_crystal",
        "star_wars:purple_kyber_crystal",
        "star_wars:yellow_kyber_crystal"
    }
    player:set_wielded_item(crystals[math.random(1, #crystals)])
end

-- ============================================================
-- CRYSTAL BLEED (Sith only)
-- ============================================================

local function do_crystal_bleed(player)
    if not can_use_ability(player, "Crystal Bleed", cooldowns["Crystal Bleed"]) then return end
    local item = player:get_wielded_item()
    if item:get_name() ~= "star_wars:kyber_crystal" then
        minetest.chat_send_player(player:get_player_name(), "You need to hold a Blank Kyber Crystal")
        return
    end
    if math.random(1, 2) == 1 then
        player:set_wielded_item("star_wars:purple_kyber_crystal")
    else
        player:set_wielded_item("star_wars:red_kyber_crystal")
    end
end

-- ============================================================
-- SABER THROW (Both)
-- ============================================================

local function do_saber_throw(player)
    local name = player:get_player_name()
    local item = player:get_wielded_item()
    local itemname = item:get_name()
    if not (minetest.registered_items[itemname]
    and minetest.registered_items[itemname].groups
    and minetest.registered_items[itemname].groups.lightsaber == 1) then
        minetest.chat_send_player(name, "You need to hold an active lightsaber")
        return
    end
    if not can_use_ability(player, "Saber Throw", cooldowns["Saber Throw"]) then return end
    local hilt, color = itemname:match("star_wars:lightsaber_(.-)_(.-)_on$")
    if not hilt or not color then
        minetest.chat_send_player(name, "Could not identify lightsaber type")
        return
    end
    star_wars:saber_throw(item, player, hilt, color)
    player:set_wielded_item(item)
end

-- ============================================================
-- RMB DISPATCHER
-- ============================================================

local function activate_rmb_ability(player)
    local name = player:get_player_name()
    if not star_wars.get_faction(name) then
        return
    end
    if force_disabled[name] then
        minetest.chat_send_player(name, "You cannot use Force abilities while being choked or stunned")
        return
    end
    local selected = force_ability[name] or "None"
    if selected == "Push" then
        do_force_push(player)
    elseif selected == "Choke" then
        start_force_choke(player)
    elseif selected == "Crystal Bond" then
        do_crystal_bond(player)
    elseif selected == "Crystal Bleed" then
        do_crystal_bleed(player)
    elseif selected == "Saber Throw" then
        do_saber_throw(player)
    elseif selected == "Force Lightning" then
        start_force_lightning(player)
    elseif selected == "Heal" then
        do_heal(player)
    elseif selected == "Force Sense" then
        do_force_sense(player)
    elseif selected == "Pull" then
        do_force_pull(player)
    end
end

-- ============================================================
-- CHOKE / LIGHTNING RESTRICTIONS
-- ============================================================

minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)
    if not (placer and placer:is_player()) then return end
    local name = placer:get_player_name()
    if force_disabled[name] then
        minetest.remove_node(pos)
        minetest.set_node(pos, oldnode)
        minetest.chat_send_player(name, "You cannot place blocks while being choked or stunned")
        return itemstack
    end
end)

minetest.register_on_player_hpchange(function(player, hp_change, reason)
    if hp_change < 0 and reason and reason.type == "punch" then
        local attacker = reason.object
        if attacker and attacker:is_player() then
            if force_disabled[attacker:get_player_name()] then
                return 0
            end
        end
    end
    return hp_change
end, true)

-- ============================================================
-- GLOBALSTEP
-- ============================================================

minetest.register_globalstep(function(dtime)

    -- Choke tick
    for caster_name, data in pairs(active_choke) do
        local caster = minetest.get_player_by_name(caster_name)
        local target = minetest.get_player_by_name(data.target_name)
        if not caster or not target then
            stop_force_choke(caster_name)
        else
            local ctrl = caster:get_player_control()
            if not ctrl.sneak or not ctrl.RMB or (force_ability[caster_name] or "None") ~= "Choke" then
                stop_force_choke(caster_name)
            else
                data.time_left = data.time_left - dtime
                data.damage_timer = (data.damage_timer or 0) + dtime
                if data.time_left <= 0 then
                    stop_force_choke(caster_name)
                else
                    if not data.lifted then
                        data.lifted = true
                        local pos = target:get_pos()
                        target:set_pos({x = pos.x, y = pos.y + 2, z = pos.z})
                        target:set_velocity({x = 0, y = 0, z = 0})
                        target:set_physics_override({speed = 0.1, gravity = 0.0, jump = 0})
                    end
                    target:set_physics_override({speed = 0.1, gravity = 0.0, jump = 0})
                    target:set_velocity({x = 0, y = 0, z = 0})
                    target:set_physics_override({speed = 0.1, gravity = 0.0, jump = 0})
                    target:set_velocity({x = 0, y = 0, z = 0})
                    if data.damage_timer >= 1 then
                        data.damage_timer = data.damage_timer - 1
                        local hp = target:get_hp()
                        target:set_hp(math.max(0, hp - 1))
                        if target:get_hp() <= 0 then
                            -- Το kill event θα πυροδοτηθεί από on_dieplayer
                            active_choke[caster_name] = nil
                            force_disabled[data.target_name] = nil
                            break
                        end
                    end
                end
            end
        end
    end

    -- Force Lightning tick
    for caster_name, data in pairs(active_lightning) do
        local caster = minetest.get_player_by_name(caster_name)
        local target = minetest.get_player_by_name(data.target_name)
        if not caster or not target then
            stop_force_lightning(caster_name)
        else
            local ctrl = caster:get_player_control()
            local item = caster:get_wielded_item():get_name()
            local has_saber = minetest.registered_items[item]
                and minetest.registered_items[item].groups
                and minetest.registered_items[item].groups.lightsaber == 1

            if not ctrl.sneak or not ctrl.RMB
            or (force_ability[caster_name] or "None") ~= "Force Lightning"
            or has_saber then
                stop_force_lightning(caster_name)
            else
                data.time_left = data.time_left - dtime
                data.damage_timer = (data.damage_timer or 0) + dtime
                if data.time_left <= 0 then
                    stop_force_lightning(caster_name)
                else
                    if data.damage_timer >= 0.5 then
                        data.damage_timer = data.damage_timer - 0.5
                        local hp = target:get_hp()
                        target:set_hp(math.max(0, hp - 2))
                        if target:get_hp() <= 0 then
                            -- Το kill event θα πυροδοτηθεί από on_dieplayer
                            active_lightning[caster_name] = nil
                            force_disabled[data.target_name] = nil
                            break
                        end
                    end
                    target:set_physics_override({speed = 0.3, gravity = 1, jump = 0})
                    if math.random(1, 5) == 1 then
                        target:add_player_velocity({
                            x = (math.random() - 0.5) * 2,
                            y = 0.5,
                            z = (math.random() - 0.5) * 2
                        })
                    end
                end
            end
        end
    end

    update_force_sense(dtime)

    -- Player input handling
    for _, player in ipairs(minetest.get_connected_players()) do
        local name = player:get_player_name()
        local ctrl = player:get_player_control()
        local prev = last_controls[name] or {}

        local cycle_pressed = ctrl.aux1 and not prev.aux1
        local jump_pressed  = ctrl.jump and not prev.jump
        local rmb_pressed   = ctrl.RMB  and not prev.RMB
        local up_pressed    = ctrl.up   and not prev.up
            
        if cycle_pressed or (rmb_pressed and not ctrl.sneak) then
            if force_disabled[name] then
                minetest.chat_send_player(name, "You cannot use Force abilities while being choked or stunned")
            elseif not star_wars.get_faction(name) then
                -- no faction
            else
                force_ability[name] = get_next_ability(name)
                update_force_hud(player)
            end
        end

        if ctrl.sneak and up_pressed then
            if force_disabled[name] then
                minetest.chat_send_player(name, "You cannot use Force abilities while being choked or stunned")
            elseif (force_ability[name] or "None") == "Dash" then
                do_dash(player)
            end
        end

        if ctrl.sneak and jump_pressed then
            if (force_ability[name] or "None") == "Jump" then
                if force_disabled[name] then
                    minetest.chat_send_player(name, "You cannot use Force abilities while being choked or stunned")
                else
                    do_force_jump(player)
                end
            end
        end

        if ctrl.sneak and rmb_pressed then
            activate_rmb_ability(player)
        end

        last_controls[name] = {
            aux1 = ctrl.aux1,
            jump = ctrl.jump,
            RMB  = ctrl.RMB,
            up   = ctrl.up,
        }
    end
end)
