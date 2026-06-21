star_wars = star_wars or {}
star_wars.form_contexts = star_wars.form_contexts or {}

local function split_lines(text, max_len)
    local lines = {}
    max_len = max_len or 46

    for paragraph in (text .. "\n"):gmatch("(.-)\n") do
        local line = ""
        for word in paragraph:gmatch("%S+") do
            if line == "" then
                line = word
            elseif #line + #word + 1 <= max_len then
                line = line .. " " .. word
            else
                table.insert(lines, line)
                line = word
            end
        end
        if line ~= "" then
            table.insert(lines, line)
        end
        if paragraph == "" then
            table.insert(lines, "")
        end
    end

    return lines
end

function star_wars.show_master_formspec(name, entity_name)
    local player = minetest.get_player_by_name(name)
    if not player then return end

    local quest, state = star_wars.get_active_quest(name)
    if not quest or not state then return end
    
        local list, faction = star_wars.get_faction_quest_list(name)
        if list and state.index >= #list and not state.accepted then
            local final_text = ""
            local current_rank = star_wars.get_rank(name)

            if entity_name == "Yoda" and faction == "jedi" and current_rank == "Grand Master" then
                final_text = "Everything I know, learned you have. More for you, there is not."
            elseif entity_name == "Darth Sidious" and faction == "sith" and current_rank == "Dark Lord" then
                final_text = "You now know everything I do..."
            end

        if final_text ~= "" then
            local lines = split_lines(final_text, 44)
            local y = 2.15
            local parts = {
                "formspec_version[4]",
                "size[10,7.5]",
                "position[0.5,0.5]",
                "anchor[0.5,0.5]",
                "bgcolor[#111111EE;true]",
                "box[0.25,0.25;9.5,0.85;#222222]",
                "label[0.55,0.58;" .. minetest.formspec_escape(entity_name) .. "]",
                "box[0.45,1.3;9.1,4.2;#181818]",
            }

            for _, line in ipairs(lines) do
                table.insert(parts, "label[0.65," .. y .. ";" .. minetest.formspec_escape(line) .. "]")
                y = y + 0.34
            end

            table.insert(parts, "button[3.5,6.55;3.0,0.8;close_form;Close]")

            minetest.show_formspec(name, "star_wars:quest_master", table.concat(parts, ""))

            star_wars.form_contexts[name] = {
                entity_name = entity_name,
                quest_index = state.index,
                ctx_mode = "final_dialogue",
            }
            return
        end
    end

    if quest.master ~= entity_name then
        minetest.chat_send_player(name, entity_name .. ": I have nothing for you right now.")
        return
    end

    local is_talk_quest = quest.objective == "talk_to_master"
    local is_open_saber_quest = quest.objective == "talk_with_open_lightsaber"
    local has_open_saber = star_wars.player_has_open_lightsaber(player)

    local dialogue = star_wars.get_dialogue(entity_name, state.index, quest.desc)
    local lines = split_lines(dialogue, 44)
    local y = 2.15

    local parts = {
        "formspec_version[4]",
        "size[10,7.5]",
        "position[0.5,0.5]",
        "anchor[0.5,0.5]",
        "bgcolor[#111111EE;true]",
        "box[0.25,0.25;9.5,0.85;#222222]",
        "label[0.55,0.58;" .. minetest.formspec_escape(entity_name) .. "]",
        "box[0.45,1.3;9.1,4.2;#181818]",
        "label[0.65,1.55;Quest: " .. minetest.formspec_escape(quest.title) .. "]",
        "label[0.65,1.9;Rank: " .. minetest.formspec_escape(quest.rank) .. "]",
    }

    for _, line in ipairs(lines) do
        table.insert(parts, "label[0.65," .. y .. ";" .. minetest.formspec_escape(line) .. "]")
        y = y + 0.34
    end

    local ctx_mode = "info"

    if is_talk_quest then
        -- Quest 1: πάντα δείχνει Continue, ολοκλήρωση μόνο με αυτό
        table.insert(parts, "label[0.65,5.8;Speak to your master to begin your training.]")
        table.insert(parts, "button[3.5,6.55;3.0,0.8;complete_talk;Continue]")
        ctx_mode = "talk"

    elseif is_open_saber_quest then
        if not state.accepted then
            -- Δεν έχει γίνει accept ακόμα: δείχνει Accept/Close
            table.insert(parts, "label[0.65,5.8;Accept this quest to continue your training.]")
            table.insert(parts, "button[2.1,6.55;2.5,0.8;accept;Accept]")
            table.insert(parts, "button[5.2,6.55;2.5,0.8;close_form;Close]")
            ctx_mode = "accept"
        elseif has_open_saber then
            -- Έχει accepted ΚΑΙ κρατάει open lightsaber: complete
            table.insert(parts, "label[0.65,5.8;You are holding an open lightsaber. Well done.]")
            table.insert(parts, "button[3.5,6.55;3.0,0.8;complete_saber;Continue]")
            ctx_mode = "complete_saber"
        else
            -- Έχει accepted αλλά ΔΕΝ κρατάει open lightsaber: reminder
            table.insert(parts, "label[0.65,5.8;You must hold an open lightsaber to proceed.]")
            table.insert(parts, "button[3.5,6.55;3.0,0.8;close_form;Close]")
            ctx_mode = "reminder"
        end

    else
        -- Υπόλοιπα quests
        table.insert(parts, "label[0.65,5.8;Progress: " .. tostring(state.progress) .. "/" .. tostring(quest.need) .. "]")
        if not state.accepted then
            table.insert(parts, "button[2.1,6.55;2.5,0.8;accept;Accept]")
            table.insert(parts, "button[5.2,6.55;2.5,0.8;close_form;Close]")
            ctx_mode = "accept"
        else
            table.insert(parts, "button[3.5,6.55;3.0,0.8;close_form;Close]")
            ctx_mode = "info"
        end
    end

    minetest.show_formspec(name, "star_wars:quest_master", table.concat(parts, ""))

    star_wars.form_contexts[name] = {
        entity_name = entity_name,
        quest_index = state.index,
        ctx_mode = ctx_mode,
    }
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= "star_wars:quest_master" then return end

    local name = player:get_player_name()
    local ctx = star_wars.form_contexts[name]
    if not ctx then return end

    if fields.complete_talk then
        star_wars.try_complete_talk_to_master(name, ctx.entity_name)
        star_wars.form_contexts[name] = nil
        minetest.close_formspec(name, "star_wars:quest_master")
        return
    end

    if fields.complete_saber then
        if not star_wars.try_complete_open_lightsaber_talk(name, player, ctx.entity_name) then
            minetest.chat_send_player(name, ctx.entity_name .. ": You must hold an open lightsaber.")
        end
        star_wars.form_contexts[name] = nil
        minetest.close_formspec(name, "star_wars:quest_master")
        return
    end

    if fields.accept then
        star_wars.accept_current_quest(name, ctx.entity_name)
        minetest.chat_send_player(name, "Quest accepted.")
        star_wars.form_contexts[name] = nil
        minetest.close_formspec(name, "star_wars:quest_master")
        return
    end

    if fields.close_form then
        star_wars.form_contexts[name] = nil
        minetest.close_formspec(name, "star_wars:quest_master")
        return
    end

    if fields.quit then
        star_wars.form_contexts[name] = nil
        return
    end
end)

minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    star_wars.form_contexts[name] = nil
end)
