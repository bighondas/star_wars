-- ============================================================
-- BLOCKS
-- ============================================================

minetest.register_node("star_wars:mud", {
    description = "Mud",
    tiles = {"mud.png"},
    paramtype = "light",
    groups = {crumbly = 3, soil = 1},
    sounds = default.node_sound_dirt_defaults(),
    light_source = 3,
})

minetest.register_node("star_wars:dagobah_log", {
    description = "Dagobah Logs",
    tiles = {"dagobah_log_top.png", "dagobah_log_top.png", "dagobah_log_side.png"},
    paramtype = "light",
    paramtype2 = "facedir",
    groups = {tree = 1, choppy = 2, oddly_breakable_by_hand = 1, flammable = 2},
    sounds = default.node_sound_wood_defaults(),
    light_source = 3,
    on_place = minetest.rotate_node
})

minetest.register_node("star_wars:dagobah_planks", {
    description = "Dagobah Planks",
    tiles = {"dagobah_planks.png"},
    paramtype = "light",
    paramtype2 = "facedir",
    groups = {choppy = 2, oddly_breakable_by_hand = 1, flammable = 2, wood = 1},
    sounds = default.node_sound_wood_defaults(),
    light_source = 3,
})

minetest.register_node("star_wars:dagobah_roots", {
    description = "Dagobah Roots",
    tiles = {"dagobah_roots.png"},
    drawtype = "allfaces_optional",
    waving = 1,
    paramtype = "light",
    groups = {snappy = 3, leafdecay = 3, flammable = 2, leaves = 1},
    sounds = default.node_sound_leaves_defaults(),
    light_source = 3,
})

minetest.register_node("star_wars:beskar_block", {
    description = "Beskar Block",
    tiles = {"beskar_block.png"},
    is_ground_content = false,
    groups = {cracky = 1, level = 2},
    sounds = default.node_sound_metal_defaults(),
})

minetest.register_node("star_wars:sorgan_grass", {
	description = "Sorgan Grass",
	tiles = {"sorgan_grass_top.png", "default_dirt.png",
		{name = "default_dirt.png^sorgan_grass_side.png",
			tileable_vertical = false}},
	groups = {crumbly = 3, soil = 1, spreading_dirt_type = 1},
	drop = "default:dirt",
	sounds = default.node_sound_dirt_defaults({
		footstep = {name = "default_grass_footstep", gain = 0.25},
	}),
})
