local modpath = minetest.get_modpath("star_wars")

minetest.register_decoration({
    name = "star_wars:yoda_hut",
    deco_type = "schematic",
    place_on = {"star_wars:mud"},
    sidelen = 16,
    fill_ratio = 0.00001,
    biomes = {"dagobah"},
    y_min = 1,
    y_max = 30,
    schematic = modpath .. "/schematics/yoda_hut.mts",
    place_offset_y = 1,
    flags = "place_center_x, place_center_z",
    rotation = "random",
})

minetest.register_decoration({
    name = "star_wars:sith_cave",
    deco_type = "schematic",
    place_on = {"default:dirt_with_grass"},
    sidelen = 16,
    fill_ratio = 0.00001,
    biomes = {"grassland"},
    y_min = 1,
    y_max = 30,
    schematic = modpath .. "/schematics/sith_cave.mts",
    place_offset_y = 1,
    flags = "place_center_x, place_center_z",
    rotation = "random",
})

local yoda_hut_id = minetest.get_decoration_id("star_wars:yoda_hut")
local sith_cave_id = minetest.get_decoration_id("star_wars:sith_cave")

minetest.set_gen_notify("decoration", {
    yoda_hut_id,
    sith_cave_id,
})

minetest.register_on_generated(function(minp, maxp, blockseed)
    local gennotify = minetest.get_mapgen_object("gennotify")
    if not gennotify then
        return
    end

    local yoda_positions = gennotify["decoration#" .. yoda_hut_id] or {}
    for _, pos in ipairs(yoda_positions) do
        star_wars.spawn_yoda_at(pos)
    end

    local sith_positions = gennotify["decoration#" .. sith_cave_id] or {}
    for _, pos in ipairs(sith_positions) do
        star_wars.spawn_sidious_at(pos)
    end
end)
