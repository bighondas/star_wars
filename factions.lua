star_wars = star_wars or {}
star_wars.faction = star_wars.faction or {}
star_wars.rank = star_wars.rank or {}

local storage = minetest.get_mod_storage()

-- ============================================================
-- RANKS
-- ============================================================

local jedi_ranks = {
    "Force Sensitive",
    "Youngling",
    "Padawan",
    "Knight",
    "Master",
    "Grand Master"
}

local sith_ranks = {
    "Force Sensitive",
    "Servant",
    "Warrior",
    "Killer",
    "Lord",
    "Dark Lord"
}

local jedi_rank_abilities = {
    ["Force Sensitive"] = {},
    ["Youngling"] = {"Dash", "Jump"},
    ["Padawan"] = {"Push", "Saber Throw", "Crystal Bond"},
    ["Knight"] = {"Heal", "Force Sense"},
    ["Master"] = {},
    ["Grand Master"] = {},
}

local sith_rank_abilities = {
    ["Force Sensitive"] = {},
    ["Servant"] = {"Dash", "Jump"},
    ["Warrior"] = {"Pull", "Saber Throw", "Crystal Bleed"},
    ["Killer"] = {"Choke"},
    ["Lord"] = {"Force Lightning"},
    ["Dark Lord"] = {},
}

local jedi_ability_order = {
    "None",
    "Dash",
    "Jump",
    "Push",
    "Saber Throw",
    "Heal",
    "Force Sense",
    "Crystal Bond"
}

local sith_ability_order = {
    "None",
    "Dash",
    "Jump",
    "Pull",
    "Saber Throw",
    "Choke",
    "Force Lightning",
    "Crystal Bleed"
}

local jedi_rank_hp = {
    ["Force Sensitive"] = 20,
    ["Youngling"] = 20,
    ["Padawan"] = 20,
    ["Knight"] = 20,
    ["Master"] = 30,
    ["Grand Master"] = 40,
}

local sith_rank_hp = {
    ["Force Sensitive"] = 20,
    ["Servant"] = 20,
    ["Warrior"] = 20,
    ["Killer"] = 20,
    ["Lord"] = 30,
    ["Dark Lord"] = 40,
}

local function get_rank_list(faction)
    if faction == "jedi" then
        return jedi_ranks
    end
    if faction == "sith" then
        return sith_ranks
    end
    return {}
end

local function get_rank_ability_map(faction)
    if faction == "jedi" then
        return jedi_rank_abilities
    end
    if faction == "sith" then
        return sith_rank_abilities
    end
    return {}
end

local function build_ability_list(faction, rank_index)
    local ranks = get_rank_list(faction)
    local ability_map = get_rank_ability_map(faction)
    local order = faction == "jedi" and jedi_ability_order or sith_ability_order
    local unlocked = {["None"] = true}

    for i = 1, rank_index do
        local rank_name = ranks[i]
        for _, ab in ipairs(ability_map[rank_name] or {}) do
            unlocked[ab] = true
        end
    end

    local result = {}
    for _, ab in ipairs(order) do
        if unlocked[ab] then
            table.insert(result, ab)
        end
    end
    return result
end

local function save_rank(name)
    local faction = star_wars.faction[name]
    if not faction then
        return
    end
    local rank = star_wars.rank[name] or 1
    storage:set_int("rank_" .. faction .. "_" .. name, rank)
end

local function load_rank(name, faction)
    local saved = storage:get_int("rank_" .. faction .. "_" .. name)
    if saved and saved >= 1 then
        star_wars.rank[name] = saved
    else
        star_wars.rank[name] = 1
    end
end

local function get_rank_name(name)
    local faction = star_wars.faction[name]
    if not faction then
        return "None"
    end
    local ranks = get_rank_list(faction)
    local rank = star_wars.rank[name] or 1
    return ranks[rank] or "Force Sensitive"
end

function star_wars.apply_rank_hp(player)
    local name = player:get_player_name()
    local faction = star_wars.faction[name]
    if not faction then
        return
    end

    local rank_name = get_rank_name(name)
    local hp_map = faction == "jedi" and jedi_rank_hp or sith_rank_hp
    local max_hp = hp_map[rank_name] or 20

    player:set_properties({hp_max = max_hp})
    if player:get_hp() > max_hp then
        player:set_hp(max_hp)
    end
end

-- ============================================================
-- TRAINING HINTS
-- ============================================================

local function send_training_hint(name, faction)
    if faction == "jedi" then
        minetest.chat_send_player(name, "To begin your Jedi training, find Yoda's Hut in a Dagobah biome.")
    elseif faction == "sith" then
        minetest.chat_send_player(name, "To begin your Sith training, find a Sith Cave in a Grasslands biome.")
    end
end

-- ============================================================
-- PUBLIC API
-- ============================================================

function star_wars.get_rank(name)
    return get_rank_name(name)
end

function star_wars.save_rank(name)
    save_rank(name)
end

function star_wars.get_ability_order(name)
    local faction = star_wars.faction[name]
    if not faction then
        return {"None"}
    end
    local rank = star_wars.rank[name] or 1
    return build_ability_list(faction, rank)
end

function star_wars.get_faction(name)
    return star_wars.faction[name]
end

-- ============================================================
-- FACTION
-- ============================================================

local function set_faction(player, faction)
    local name = player:get_player_name()

    if star_wars.faction[name] then
        save_rank(name)
    end

    star_wars.faction[name] = faction
    storage:set_string("faction_" .. name, faction)
    load_rank(name, faction)

    -- Fix #1: έλεγχος ύπαρξης πριν χρήση των globals από force_abilities.lua
    if force_ability then
        force_ability[name] = "None"
    end
    if update_force_hud then
        update_force_hud(player)
    end
    star_wars.apply_rank_hp(player)

    minetest.chat_send_player(name, "You have joined the " .. faction:gsub("^%l", string.upper) .. ".")
    minetest.chat_send_player(name, "Rank: " .. get_rank_name(name))
    send_training_hint(name, faction)
end

function star_wars.show_faction_prompt(player)
    local name = player:get_player_name()
    minetest.chat_send_player(name, "Choose your team:")
    minetest.chat_send_player(name, "  /team jedi")
    minetest.chat_send_player(name, "  /team sith")
end

-- ============================================================
-- COMMANDS
-- ============================================================

minetest.register_privilege("rank", {
	description = "Allows player use /rank command.",
	give_to_singleplayer = false
})

minetest.register_chatcommand("team", {
	description = "Choose your faction: /team jedi | /team sith",
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if not player then
			return false, "Player not found."
		end

		param = param:lower():gsub("%s+", "")

		if param == "jedi" or param == "sith" then
			set_faction(player, param)
            star_wars.reset_player_quests(name)
            star_wars.update_quest_hud(name)
			return true, "Faction set to " .. param
		elseif param == "" then
			local faction = star_wars.faction[name]
			if faction then
				return true, "You are a " .. faction:gsub("^%l", string.upper) .. " — " .. get_rank_name(name)
			else
				return true, "You have not chosen a faction yet."
			end
		else
			return false, "Usage: /team jedi | /team sith"
		end
	end
})

minetest.register_chatcommand("rank", {
	description = "Set your rank: /rank <rank> | /rank max",
	privs = { rank = true },
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if not player then
			return false, "Player not found."
		end

		local faction = star_wars.faction[name]
		if not faction then
			return false, "You have not chosen a faction yet."
		end

		param = param:lower():gsub("^%s*(.-)%s*$", "%1")
		local ranks = get_rank_list(faction)

		if not ranks or #ranks == 0 then
			return false, "No ranks found for faction: " .. faction
		end

		if param == "max" then
			star_wars.rank[name] = #ranks
			save_rank(name)
            -- Fix #1: έλεγχος ύπαρξης
            if force_ability then
                force_ability[name] = "None"
            end
            if update_force_hud then
                update_force_hud(player)
            end
			star_wars.apply_rank_hp(player)
            star_wars.reset_player_quests(name)
            star_wars.update_quest_hud(name)
			return true, "Rank: " .. ranks[#ranks]
		end

		local found = nil
		for i, r in ipairs(ranks) do
			if r:lower() == param then
				found = i
				break
			end
		end

		if found then
			star_wars.rank[name] = found
			save_rank(name)
            -- Fix #1: έλεγχος ύπαρξης
            if force_ability then
                force_ability[name] = "None"
            end
            if update_force_hud then
                update_force_hud(player)
            end
			star_wars.apply_rank_hp(player)
            star_wars.reset_player_quests(name)
            star_wars.update_quest_hud(name)
			return true, "Rank: " .. ranks[found]
		else
			return false, "Available ranks: " .. table.concat(ranks, ", ")
		end
	end
})

-- ============================================================
-- JOIN / LEAVE
-- ============================================================

minetest.register_on_joinplayer(function(player)
    local name = player:get_player_name()
    local saved = storage:get_string("faction_" .. name)

    if saved and (saved == "jedi" or saved == "sith") then
        star_wars.faction[name] = saved
        load_rank(name, saved)

        minetest.after(1.0, function()
            local p = minetest.get_player_by_name(name)
            if p then
                star_wars.apply_rank_hp(p)
                minetest.chat_send_player(name, "Welcome back, " .. saved:gsub("^%l", string.upper) .. ".")
                minetest.chat_send_player(name, "Rank: " .. get_rank_name(name))
                send_training_hint(name, saved)
            end
        end)
    else
        minetest.after(1.0, function()
            local p = minetest.get_player_by_name(name)
            if p then
                star_wars.show_faction_prompt(p)
            end
        end)
    end
end)

minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    save_rank(name)
    star_wars.faction[name] = nil
    star_wars.rank[name] = nil
end)
