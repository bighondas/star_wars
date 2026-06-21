--=========================
-- ORE BLOCKS
--=========================

minetest.register_node("star_wars:kyber_ore", {
	description = "Kyber Crystal Ore",
	tiles = {"default_stone.png^kyber_crystal_ore.png"},
	paramtype = "light",
	groups = {cracky = 1,level = 2},
	drop = "star_wars:kyber_crystal",
	sounds = default.node_sound_stone_defaults(),
})

minetest.register_node("star_wars:black_kyber_crystal_ore", {
	description = "Black Kyber Crystal Ore",
	tiles = {"default_stone.png^black_kyber_crystal_ore.png"},
	paramtype = "light",
	groups = {cracky = 1,level = 2},
	drop = "star_wars:black_kyber_crystal",
	sounds = default.node_sound_stone_defaults(),
})

minetest.register_node("star_wars:laser_core_ore", {
	description = "Laser Core Ore",
	tiles = {"default_stone.png^laser_core_ore.png"},
	paramtype = "light",
	groups = {cracky = 1,level = 2},
	drop = "star_wars:laser_core",
	sounds = default.node_sound_stone_defaults(),
})

minetest.register_node("star_wars:beskar_ore", {
	description = "Beskar Ore",
	tiles = {"default_stone.png^beskar_ore.png"},
	paramtype = "light",
	groups = {cracky = 1,level = 2},
	drop = "star_wars:raw_beskar",
	sounds = default.node_sound_stone_defaults(),
})

--=========================
-- SPAWN ORES
--=========================

minetest.register_ore({
    ore_type       = "scatter",
    ore            = "star_wars:kyber_ore",
    wherein        = "default:stone",
    clust_scarcity = 9 * 9 * 9,   
    clust_num_ores = 14,
    clust_size     = 3,
    y_max          = 31000,
    y_min          = 1025,
})

minetest.register_ore({
    ore_type       = "scatter",
    ore            = "star_wars:laser_core_ore",
    wherein        = "default:stone",
    clust_scarcity = 9 * 9 * 9,
    clust_num_ores = 10,
    clust_size     = 3,
    y_max          = 31000,
    y_min          = 800,
})

minetest.register_ore({
    ore_type       = "scatter",
    ore            = "star_wars:beskar_ore",
    wherein        = "default:stone",
    clust_scarcity = 13 * 13 * 13,  
    clust_num_ores = 5,
    clust_size     = 4,
    y_max          = 31000,
    y_min          = 1025,
})

minetest.register_ore({
    ore_type       = "scatter",
    ore            = "star_wars:black_kyber_crystal_ore",
    wherein        = "default:stone",
    clust_scarcity = 36 * 36 * 36,
    clust_num_ores = 2,
    clust_size     = 2,
    y_max          = 31000,
    y_min          = 1025,
})

