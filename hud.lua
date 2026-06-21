star_wars = star_wars or {}
star_wars.hud = star_wars.hud or {}

-- PUBLIC API για clear_quest_hud και update_quest_hud
star_wars.clear_quest_hud = function(name)
    local player = minetest.get_player_by_name(name)
    local ids = star_wars.hud[name]
    if player and ids then
        for _, id in pairs(ids) do
            player:hud_remove(id)
        end
    end
    star_wars.hud[name] = nil
end

star_wars.update_quest_hud = function(name)
    -- ... όλο το υπόλοιπο περιεχόμενο της update_quest_hud function
end

-- ============================================================
-- HELPERS
-- ============================================================

local LINE_HEIGHT = 18
local MAX_CHARS = 28
local START_X = -215
local START_Y = 0.18

local function wrap_text(text, max_chars)
    local lines = {}
    for paragraph in (text .. "\n"):gmatch("(.-)\n") do
        if paragraph == "" then
            table.insert(lines, "")
        else
            local line = ""
            for word in paragraph:gmatch("%S+") do
                if line == "" then
                    line = word
                elseif #line + 1 + #word <= max_chars then
                    line = line .. " " .. word
                else
                    table.insert(lines, line)
                    line = word
                end
            end
            if line ~= "" then
                table.insert(lines, line)
            end
        end
    end
    return lines
end

-- ============================================================
-- QUEST HUD (πάνω δεξιά)
-- ============================================================

function star_wars.update_quest_hud(name)
    local player = minetest.get_player_by_name(name)
    if not player then return end
    if not star_wars.get_hud_text then return end

    local quest, state = star_wars.get_active_quest(name)
    local list = star_wars.get_faction_quest_list(name)

    -- Αν έχει τελειώσει όλα τα quests, καθάρισε το HUD
    if list and state and state.index >= #list and not state.accepted then
        star_wars.clear_quest_hud(name)
        return
    end

    if list and state and state.index > #list then
        star_wars.clear_quest_hud(name)
        return
    end

    if not quest or not state then
        star_wars.clear_quest_hud(name)
        return
    end
    local text = star_wars.get_hud_text(name)

    if not text or text == "" then
        star_wars.clear_quest_hud(name)
        return
    end

    -- Faction color
    local faction = star_wars.get_faction and star_wars.get_faction(name)
    local title_color = 0xFFE27A
    if faction == "jedi" then
        title_color = 0x4FC3F7
    elseif faction == "sith" then
        title_color = 0xFF4444
    end
    local title_text = faction == "jedi" and "[ JEDI QUEST ]"
        or (faction == "sith" and "[ SITH QUEST ]" or "[ QUEST ]")

    -- Σπάσε το text σε γραμμές
    local lines = wrap_text(text, MAX_CHARS)
    local total_lines = #lines
    local panel_height = 30 + total_lines * LINE_HEIGHT

    -- Καθάρισε παλιό HUD
    star_wars.clear_quest_hud(name)

    local ids = {}

    -- Φόντο panel
    ids.bg = player:hud_add({
        hud_elem_type = "image",
        position = {x = 1, y = START_Y},
        offset = {x = -230, y = 0},
        alignment = {x = 1, y = 1},
        scale = {x = 220, y = panel_height},
        text = "quest_hud_bg.png",
        z_index = -1,
    })

    -- Τίτλος
    ids.title = player:hud_add({
        hud_elem_type = "text",
        position = {x = 1, y = START_Y},
        offset = {x = START_X, y = 10},
        alignment = {x = 1, y = 1},
        number = title_color,
        text = title_text,
        scale = {x = 200, y = 16},
    })

    -- Γραμμές κειμένου
    for i, line in ipairs(lines) do
        local id = player:hud_add({
            hud_elem_type = "text",
            position = {x = 1, y = START_Y},
            offset = {x = START_X, y = 10 + 20 + (i - 1) * LINE_HEIGHT},
            alignment = {x = 1, y = 1},
            number = 0xFFFFFF,
            text = line,
            scale = {x = 200, y = 16},
        })
        ids["line_" .. i] = id
    end

    star_wars.hud[name] = ids
end

-- ============================================================
-- HOOKS
-- ============================================================

minetest.register_on_joinplayer(function(player)
    minetest.after(0.5, function()
        if player and player:is_player() then
            star_wars.update_quest_hud(player:get_player_name())
        end
    end)
end)

minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    star_wars.hud[name] = nil
end)
