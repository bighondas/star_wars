star_wars = star_wars or {}
star_wars.hud = star_wars.hud or {}
star_wars.form_contexts = star_wars.form_contexts or {}

-- ============================================================
-- QUEST DEFINITIONS
-- ============================================================

star_wars.quest_defs = {
    jedi = {
        {
            rank = "Youngling",
            title = "Find Yoda",
            desc = "Find Yoda and speak with him.",
            objective = "talk_to_master",
            need = 1,
            master = "Yoda",
        },
        {
            rank = "Padawan",
            title = "Force Dash",
            desc = "Use Dash 3 times.",
            objective = "dash",
            need = 3,
            master = "Yoda",
        },
        {
            rank = "Knight",
            title = "Your First Lightsaber",
            desc = "Return to Yoda while holding an open lightsaber.",
            objective = "talk_with_open_lightsaber",
            need = 1,
            master = "Yoda",
        },
        {
            rank = "Master",
            title = "Sense",
            desc = "Use Force Sense on a Jedi player.",
            objective = "sense_jedi",
            need = 1,
            master = "Yoda",
        },
        {
            rank = "Grand Master",
            title = "Final Trial",
            desc = "Sense a Sith player then kill them.",
            objective = "grandmaster_jedi",
            need = 2,
            master = "Yoda",
        },
    },

    sith = {
        {
            rank = "Servant",
            title = "Find Darth Sidious",
            desc = "Find Darth Sidious and speak with him.",
            objective = "talk_to_master",
            need = 1,
            master = "Darth Sidious",
        },
        {
            rank = "Warrior",
            title = "Force Dash",
            desc = "Use Dash 3 times.",
            objective = "dash",
            need = 3,
            master = "Darth Sidious",
        },
        {
            rank = "Killer",
            title = "Open Saber Discipline",
            desc = "Return to Darth Sidious while holding an open lightsaber.",
            objective = "talk_with_open_lightsaber",
            need = 1,
            master = "Darth Sidious",
        },
        {
            rank = "Lord",
            title = "Defeat a Jedi",
            desc = "Kill 1 Jedi player.",
            objective = "kill_enemy",
            need = 1,
            master = "Darth Sidious",
        },
        {
            rank = "Dark Lord",
            title = "Final Trial",
            desc = "Kill 3 Jedi players using Force Lightning.",
            objective = "lightning_kill",
            need = 3,
            master = "Darth Sidious",
        },
    }
}

-- ============================================================
-- DIALOGUE (εύκολα customizable)
-- ============================================================

star_wars.quest_dialogue = {
    Yoda = {
        [1] = "Strong in the Force, you are. Found me, you have. Begin your training, we shall.",
        [2] = "Fast you must be. Use Dash three times, you will.",
        [3] = "Crystal Bond, you have earned. A Blank Kyber Crystal, hold you must. Color it, then a hilt combine. Return to me with it opened, you will.",
        [4] = "Growing stronger, your connection with the Force is. Sense a fellow Jedi, you must. A Master, you shall become.",
        [5] = "Your final trial, this is. Sense a Sith, then defeat them. Taught you everything, I have.",
    },

    ["Darth Sidious"] = {
        [1] = "So, you found me. Good. Your training in the dark side begins.",
        [2] = "Speed is power. Use Dash three times.",
        [3] = "Use your new earned Crystal Bleed ability while holding a Blank Kyber Crystal. Then combine it with a hilt. Return to me with it opened.",
        [4] = "Destroy a Jedi. Prove your worth.",
        [5] = "Your final trial. Annihilate three Jedi with Force Lightning. Then you will be the same level as me...",
    }
}

-- ============================================================
-- RANK ORDERS
-- ============================================================

local jedi_rank_order = {
    "Force Sensitive",
    "Youngling",
    "Padawan",
    "Knight",
    "Master",
    "Grand Master"
}

local sith_rank_order = {
    "Force Sensitive",
    "Servant",
    "Warrior",
    "Killer",
    "Lord",
    "Dark Lord"
}

-- ============================================================
-- HELPERS
-- ============================================================

local function get_player(name)
    return minetest.get_player_by_name(name)
end

local function get_meta(name)
    local player = get_player(name)
    if not player then return nil end
    return player:get_meta()
end

local function get_rank_order_for_faction(faction)
    if faction == "jedi" then return jedi_rank_order end
    if faction == "sith" then return sith_rank_order end
    return nil
end

function star_wars.is_open_lightsaber(itemname)
    if not itemname or itemname == "" then return false end
    if itemname:match("^star_wars:lightsaber_single_.+_on$") then return true end
    if itemname:match("^star_wars:lightsaber_double_.+_on$") then return true end
    if itemname:match("^star_wars:lightsaber_cross_.+_on$") then return true end
    return false
end

function star_wars.player_has_open_lightsaber(player)
    if not player then return false end
    local wielded = player:get_wielded_item()
    if wielded and star_wars.is_open_lightsaber(wielded:get_name()) then
        return true
    end
    return false
end

function star_wars.get_faction_quest_list(name)
    local faction = star_wars.get_faction(name)
    if not faction then return nil, nil end
    return star_wars.quest_defs[faction], faction
end

-- ============================================================
-- QUEST STATE
-- ============================================================

function star_wars.get_quest_state(name)
    local meta = get_meta(name)
    if not meta then return nil end

    local index = meta:get_int("star_wars:quest_index")

    if index <= 0 then
        local state = {
            index = 1,
            progress = 0,
            accepted = false,
            master = "",
            sensed_sith_target = "",
            choke_kills = 0,
            lightning_kills = 0,
        }
        star_wars.save_quest_state(name, state)
        return state
    end

    return {
        index = index,
        progress = meta:get_int("star_wars:quest_progress"),
        accepted = meta:get_int("star_wars:quest_accepted") == 1,
        master = meta:get_string("star_wars:quest_master"),
        sensed_sith_target = meta:get_string("star_wars:sensed_sith_target"),
        choke_kills = meta:get_int("star_wars:choke_kills"),
        lightning_kills = meta:get_int("star_wars:lightning_kills"),
    }
end

function star_wars.save_quest_state(name, state)
    local meta = get_meta(name)
    if not meta then return end

    meta:set_int("star_wars:quest_index", state.index or 1)
    meta:set_int("star_wars:quest_progress", state.progress or 0)
    meta:set_int("star_wars:quest_accepted", state.accepted and 1 or 0)
    meta:set_string("star_wars:quest_master", state.master or "")
    meta:set_string("star_wars:sensed_sith_target", state.sensed_sith_target or "")
    meta:set_int("star_wars:choke_kills", state.choke_kills or 0)
    meta:set_int("star_wars:lightning_kills", state.lightning_kills or 0)
end

function star_wars.reset_quest_flags(state)
    state.sensed_sith_target = ""
    state.choke_kills = 0
    state.lightning_kills = 0
end

function star_wars.reset_player_quests(name)
    local state = {
        index = 1,
        progress = 0,
        accepted = false,
        master = "",
        sensed_sith_target = "",
        choke_kills = 0,
        lightning_kills = 0,
    }
    star_wars.save_quest_state(name, state)
    if star_wars.clear_quest_hud then
        star_wars.clear_quest_hud(name)
    end
end

function star_wars.get_active_quest(name)
    local list = star_wars.get_faction_quest_list(name)
    local state = star_wars.get_quest_state(name)
    if not list or not state then return nil, nil end
    return list[state.index], state
end

-- ============================================================
-- RANK SYNC
-- ============================================================

function star_wars.sync_rank_to_current_quest(name)
    local faction = star_wars.get_faction(name)
    if not faction then return end

    local quest, state = star_wars.get_active_quest(name)
    if not quest or not state then return end

    local target_rank = quest.rank
    if not target_rank then return end

    local rank_order = get_rank_order_for_faction(faction)
    if not rank_order then return end

    for i, rank_name in ipairs(rank_order) do
        if rank_name == target_rank then
            if star_wars.rank then
                star_wars.rank[name] = i
            end
            if star_wars.save_rank then
                star_wars.save_rank(name)
            end
            local player = minetest.get_player_by_name(name)
            if player then
                if force_ability then force_ability[name] = "None" end
                if update_force_hud then update_force_hud(player) end
                if star_wars.apply_rank_hp then star_wars.apply_rank_hp(player) end
            end
            return
        end
    end
end

-- ============================================================
-- QUEST FLOW
-- ============================================================

function star_wars.accept_current_quest(name, master_name)
    local quest, state = star_wars.get_active_quest(name)
    if not quest or not state then return end

    if state.accepted then
        star_wars.update_quest_hud(name)
        return
    end

    state.accepted = true
    state.master = master_name or quest.master
    state.progress = 0
    star_wars.reset_quest_flags(state)
    star_wars.save_quest_state(name, state)
    star_wars.update_quest_hud(name)
end

function star_wars.complete_current_quest(name)
    local list = star_wars.get_faction_quest_list(name)
    local state = star_wars.get_quest_state(name)
    if not list or not state then return end

    -- Δώσε το rank του quest που μόλις ολοκληρώθηκε
    local completed_quest = list[state.index]
    if completed_quest then
        local faction = star_wars.get_faction(name)
        local rank_order = faction == "jedi" and {
            "Force Sensitive", "Youngling", "Padawan", "Knight", "Master", "Grand Master"
        } or {
            "Force Sensitive", "Servant", "Warrior", "Killer", "Lord", "Dark Lord"
        }
        for i, rank_name in ipairs(rank_order) do
            if rank_name == completed_quest.rank then
                if star_wars.rank then star_wars.rank[name] = i end
                if star_wars.save_rank then star_wars.save_rank(name) end
                local player = minetest.get_player_by_name(name)
                if player then
                    if force_ability then force_ability[name] = "None" end
                    if update_force_hud then update_force_hud(player) end
                    if star_wars.apply_rank_hp then star_wars.apply_rank_hp(player) end
                end
                minetest.chat_send_player(name, "You are now a " .. completed_quest.rank .. ".")
                break
            end
        end
    end

    if state.index < #list then
        state.index = state.index + 1
        state.progress = 0
        state.accepted = false
        state.master = ""
        star_wars.reset_quest_flags(state)
        star_wars.save_quest_state(name, state)
    else
        state.progress = 0
        state.accepted = false
        state.master = ""
        star_wars.reset_quest_flags(state)
        star_wars.save_quest_state(name, state)
    end

    star_wars.update_quest_hud(name)
end

function star_wars.add_progress(name, amount)
    local quest, state = star_wars.get_active_quest(name)
    if not quest or not state then return false end
    if not state.accepted then return false end

    state.progress = math.min((state.progress or 0) + (amount or 1), quest.need)
    star_wars.save_quest_state(name, state)

    if state.progress >= quest.need then
        minetest.chat_send_player(name, "Quest complete: " .. quest.title)

        minetest.sound_play("star_wars_quest_complete", {
            to_player = name,
            gain = 1.0,
        }, true)

        star_wars.complete_current_quest(name)
        return true
    end

    star_wars.update_quest_hud(name)
    return false
end

-- ============================================================
-- OBJECTIVE HANDLERS
-- ============================================================

function star_wars.try_complete_talk_to_master(name, master_name)
    local quest, state = star_wars.get_active_quest(name)
    if not quest or not state then return false end
    if quest.objective ~= "talk_to_master" then return false end
    if quest.master ~= master_name then return false end

    state.accepted = true
    state.master = master_name
    state.progress = quest.need
    star_wars.save_quest_state(name, state)

    minetest.chat_send_player(name, "Quest complete: " .. quest.title)
    star_wars.complete_current_quest(name)
    return true
end

function star_wars.try_complete_open_lightsaber_talk(name, player, master_name)
    local quest, state = star_wars.get_active_quest(name)
    if not quest or not state then return false end
    if quest.objective ~= "talk_with_open_lightsaber" then return false end
    if quest.master ~= master_name then return false end

    if not star_wars.player_has_open_lightsaber(player) then
        return false
    end

    if not state.accepted then
        state.accepted = true
        state.master = master_name
    end

    state.progress = quest.need
    star_wars.save_quest_state(name, state)

    minetest.chat_send_player(name, "Quest complete: " .. quest.title)
    star_wars.complete_current_quest(name)
    return true
end

-- Καλείται από force_abilities.lua όταν κάνει Dash
function star_wars.on_dash(name)
    local quest, state = star_wars.get_active_quest(name)
    if not quest or not state then return end
    if not state.accepted then return end
    if quest.objective ~= "dash" then return end

    star_wars.add_progress(name, 1)
end

-- Καλείται από force_abilities.lua όταν κάνει Force Sense
function star_wars.on_force_sense(name, sensed_players)
    local quest, state = star_wars.get_active_quest(name)
    if not quest or not state then return end
    if not state.accepted then return end

    if quest.objective == "sense_jedi" then
        for _, sensed_name in ipairs(sensed_players) do
            if star_wars.get_faction(sensed_name) == "jedi" then
                star_wars.add_progress(name, 1)
                return
            end
        end
        return
    end

    if quest.objective == "grandmaster_jedi" then
        -- Αποθήκευσε τον πρώτο sith που εντοπίστηκε ως target
        if (state.sensed_sith_target or "") ~= "" then return end
        for _, sensed_name in ipairs(sensed_players) do
            if star_wars.get_faction(sensed_name) == "sith" then
                state.sensed_sith_target = sensed_name
                state.progress = 1
                star_wars.save_quest_state(name, state)
                minetest.chat_send_player(name, "You sensed " .. sensed_name .. ". Now defeat him.")
                star_wars.update_quest_hud(name)
                return
            end
        end
    end
end

-- Καλείται από kill handler
function star_wars.on_kill_enemy(name, victim_name)
    local quest, state = star_wars.get_active_quest(name)
    if not quest or not state then return end
    if not state.accepted then return end

    local victim_faction = star_wars.get_faction(victim_name)
    local my_faction = star_wars.get_faction(name)

    if quest.objective == "kill_enemy" then
        local target_faction = my_faction == "jedi" and "sith" or "jedi"
        if victim_faction == target_faction then
            star_wars.add_progress(name, 1)
        end
        return
    end

    if quest.objective == "grandmaster_jedi" then
        if (state.sensed_sith_target or "") == "" then
            minetest.chat_send_player(name, "Sense a Sith player first.")
            return
        end
        if victim_name == state.sensed_sith_target then
            state.progress = quest.need
            star_wars.save_quest_state(name, state)
            minetest.chat_send_player(name, "Quest complete: " .. quest.title)
            star_wars.complete_current_quest(name)
        else
            minetest.chat_send_player(name, "You must kill the Sith you sensed: " .. state.sensed_sith_target)
        end
        return
    end
end

-- Καλείται από force_abilities.lua όταν παίκτης πεθαίνει υπό choke
function star_wars.on_choke_kill(name, victim_name)
    local quest, state = star_wars.get_active_quest(name)
    if not quest or not state then return end
    if not state.accepted then return end
    if quest.objective ~= "choke_kill" then return end

    if star_wars.get_faction(victim_name) == "jedi" then
        star_wars.add_progress(name, 1)
    end
end

-- Καλείται από force_abilities.lua όταν παίκτης πεθαίνει υπό lightning
function star_wars.on_lightning_kill(name, victim_name)
    local quest, state = star_wars.get_active_quest(name)
    if not quest or not state then return end
    if not state.accepted then return end
    if quest.objective ~= "lightning_kill" then return end

    if star_wars.get_faction(victim_name) == "jedi" then
        star_wars.add_progress(name, 1)
    end
end

-- ============================================================
-- HUD TEXT
-- ============================================================

function star_wars.get_hud_text(name)
    local quest, state = star_wars.get_active_quest(name)
    if not quest or not state then return nil end

    if not state.accepted then
        return "Return to " .. (quest.master or "your master") .. "."
    end

    local obj = quest.objective

    if obj == "grandmaster_jedi" then
        if (state.sensed_sith_target or "") == "" then
            return quest.rank .. ": " .. quest.title .. "\nSense a Sith player."
        else
            return quest.rank .. ": " .. quest.title .. "\nKill " .. state.sensed_sith_target .. "."
        end
    elseif obj == "lightning_kill" then
        return quest.rank .. ": " .. quest.title .. "\nLightning kills: " .. state.progress .. "/" .. quest.need
    elseif obj == "choke_kill" then
        return quest.rank .. ": " .. quest.title .. "\nChoke kills: " .. state.progress .. "/" .. quest.need
    elseif obj == "dash" then
        return quest.rank .. ": " .. quest.title .. "\nDash uses: " .. state.progress .. "/" .. quest.need
    else
        return quest.rank .. ": " .. quest.title .. "\nProgress: " .. state.progress .. "/" .. quest.need
    end
end

function star_wars.get_dialogue(master_name, index, fallback)
    if star_wars.quest_dialogue[master_name] and star_wars.quest_dialogue[master_name][index] then
        return star_wars.quest_dialogue[master_name][index]
    end
    return fallback or ""
end
