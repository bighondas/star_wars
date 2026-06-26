local colors = {"green", "blue", "red", "purple", "yellow"}
local hilts = {"single", "cross", "double", "curved"}

--==========================
-- HILTS
--==========================

minetest.register_craft({
	output = "star_wars:single_hilt",
	recipe = {
		{"","",""},
		{"","default:steel_ingot",""},
		{"","default:steel_ingot",""}
	}
})

minetest.register_craft({
	output = "star_wars:darksaber_hilt",
	recipe = {
		{"","",""},
		{"","star_wars:beskar_ingot",""},
		{"","star_wars:beskar_ingot",""}
	}
})

minetest.register_craft({
	output = "star_wars:cross_hilt",
	recipe = {
		{"","",""},
		{"default:steel_ingot","default:steel_ingot","default:steel_ingot"},
		{"","default:steel_ingot",""}
	}
})

minetest.register_craft({
	output = "star_wars:double_hilt",
	recipe = {
		{"","",""},
		{"","star_wars:single_hilt",""},
		{"","star_wars:single_hilt",""}
	}
})

minetest.register_craft({
	output = "star_wars:curved_hilt",
	recipe = {
		{"","",""},
		{"","default:steel_ingot",""},
		{"","","default:steel_ingot"}
	}
})

minetest.register_craft({
	output = "star_wars:shoto_hilt",
	recipe = {
		{"","",""},
		{"","default:steel_ingot",""},
		{"","",""}
	}
})

--==========================
-- LIGHTSABERS
--==========================

for _, color in ipairs(colors) do
    minetest.register_craft({
        output = "star_wars:lightsaber_single_" .. color .. "_off",
        recipe = {
            {"", "", ""},
            {"star_wars:" ..color.. "_kyber_crystal", "", ""},
            {"star_wars:single_hilt", "", ""}
        }
    })

    minetest.register_craft({
        output = "star_wars:lightsaber_cross_" .. color .. "_off",
        recipe = {
            {"", "", ""},
            {"star_wars:" ..color.. "_kyber_crystal", "", ""},
            {"star_wars:cross_hilt", "", ""}
        }
    })

    minetest.register_craft({
        output = "star_wars:lightsaber_double_" .. color .. "_off",
        recipe = {
            {"", "", ""},
            {"star_wars:" ..color.. "_kyber_crystal", "", ""},
            {"star_wars:double_hilt", "", ""}
        }
    })

    minetest.register_craft({
        output = "star_wars:lightsaber_curved_" .. color .. "_off",
        recipe = {
            {"", "", ""},
            {"star_wars:" ..color.. "_kyber_crystal", "", ""},
            {"star_wars:curved_hilt", "", ""}
        }
    })

    minetest.register_craft({
        output = "star_wars:lightsaber_shoto_" .. color .. "_off",
        recipe = {
            {"", "", ""},
            {"star_wars:" ..color.. "_kyber_crystal", "", ""},
            {"star_wars:shoto_hilt", "", ""}
        }
    })
end

minetest.register_craft({
        output = "star_wars:lightsaber_single_white_off",
        recipe = {
            {"", "", ""},
            {"star_wars:kyber_crystal", "", ""},
            {"star_wars:single_hilt", "", ""}
        }
    })

    minetest.register_craft({
        output = "star_wars:lightsaber_cross_white_off",
        recipe = {
            {"", "", ""},
            {"star_wars:kyber_crystal", "", ""},
            {"star_wars:cross_hilt", "", ""}
        }
    })

    minetest.register_craft({
        output = "star_wars:lightsaber_double_white_off",
        recipe = {
            {"", "", ""},
            {"star_wars:kyber_crystal", "", ""},
            {"star_wars:double_hilt", "", ""}
        }
    })

    minetest.register_craft({
        output = "star_wars:lightsaber_curved_white_off",
        recipe = {
            {"", "", ""},
            {"star_wars:kyber_crystal", "", ""},
            {"star_wars:curved_hilt", "", ""}
        }
    })

    minetest.register_craft({
        output = "star_wars:lightsaber_shoto_white_off",
        recipe = {
            {"", "", ""},
            {"star_wars:kyber_crystal", "", ""},
            {"star_wars:shoto_hilt", "", ""}
        }
    })

minetest.register_craft({
    output = "star_wars:darksaber_off",
    recipe = {
        {"", "", ""},
        {"star_wars:black_kyber_crystal", "", ""},
        {"star_wars:darksaber_hilt", "", ""}
    }
})

--==========================
-- BLASTERS
--==========================

minetest.register_craft({
	output = "star_wars:blaster",
	recipe = {
		{"","",""},
		{"default:steel_ingot","star_wars:laser_core","default:steel_ingot"},
		{"","","default:steel_ingot"}
	}
})

minetest.register_craft({
	output = "star_wars:auto_blaster",
	recipe = {
		{"","",""},
		{"star_wars:beskar_ingot","star_wars:laser_core","star_wars:beskar_ingot"},
		{"","","star_wars:beskar_ingot"}
	}
})

--==========================
-- COOKING RECIPES
--==========================

minetest.register_craft({
       type = "cooking",
       output = "star_wars:beskar_ingot",
       recipe = "star_wars:raw_beskar",
})

minetest.register_craft({
       type = "cooking",
       output = "star_wars:cooked_arge_leg",
       recipe = "star_wars:arge_leg",
})

--==========================
-- ARMOR
--==========================

minetest.register_craft({
	output = "star_wars:helmet_beskar",
	recipe = {
		{"star_wars:beskar_ingot","star_wars:beskar_ingot","star_wars:beskar_ingot"},
		{"star_wars:beskar_ingot","","star_wars:beskar_ingot"},
		{"","",""}
	}
})

minetest.register_craft({
	output = "star_wars:chestplate_beskar",
	recipe = {
		{"star_wars:beskar_ingot","","star_wars:beskar_ingot"},
		{"star_wars:beskar_ingot","star_wars:beskar_ingot","star_wars:beskar_ingot"},
		{"star_wars:beskar_ingot","star_wars:beskar_ingot","star_wars:beskar_ingot"}
	}
})

minetest.register_craft({
	output = "star_wars:leggings_beskar",
	recipe = {
		{"star_wars:beskar_ingot","star_wars:beskar_ingot","star_wars:beskar_ingot"},
		{"star_wars:beskar_ingot","","star_wars:beskar_ingot"},
		{"star_wars:beskar_ingot","","star_wars:beskar_ingot"}
	}
})

minetest.register_craft({
	output = "star_wars:boots_beskar",
	recipe = {
		{"","",""},
		{"star_wars:beskar_ingot","","star_wars:beskar_ingot"},
		{"star_wars:beskar_ingot","","star_wars:beskar_ingot"}
	}
})


--==========================
-- BLOCKS
--==========================

minetest.register_craft({
	output = "star_wars:dagobah_planks 4",
	recipe = {
		{"","",""},
		{"","star_wars:dagobah_log",""},
		{"","",""}
	}
})

minetest.register_craft({
	output = "star_wars:beskar_ingot 9",
	recipe = {
		{"","",""},
		{"","star_wars:beskar_block",""},
		{"","",""}
	}
})

minetest.register_craft({
	output = "star_wars:beskar_block",
	recipe = {
		{"star_wars:beskar_ingot","star_wars:beskar_ingot","star_wars:beskar_ingot"},
		{"star_wars:beskar_ingot","star_wars:beskar_ingot","star_wars:beskar_ingot"},
		{"star_wars:beskar_ingot","star_wars:beskar_ingot","star_wars:beskar_ingot"}
	}
})

--==========================
-- VEHICLES
--==========================

minetest.register_craft({
	output = "star_wars:xwing_item",
	recipe = {
		{"star_wars:xwing_wing","","star_wars:xwing_wing"},
		{"","star_wars:engine", ""},
		{"star_wars:xwing_wing","","star_wars:xwing_wing"}
	}
})

minetest.register_craft({
	output = "star_wars:tie_advanced_item",
	recipe = {
		{"","",""},
		{"star_wars:tie_wing","star_wars:engine", "star_wars:tie_wing"},
		{"","",""}
	}
})

minetest.register_craft({
	output = "star_wars:speeder_item",
	recipe = {
		{"","",""},
		{"star_wars:propeller","star_wars:engine", ""},
		{"","",""}
	}
})

minetest.register_craft({
	output = "star_wars:propeller",
	recipe = {
		{"","default:steel_ingot",""},
		{"default:steel_ingot","", "default:steel_ingot"},
		{"","default:steel_ingot",""}
	}
})

minetest.register_craft({
	output = "star_wars:tie_wing",
	recipe = {
		{"star_wars:beskar_ingot","",""},
		{"default:steel_ingot","", ""},
		{"star_wars:beskar_ingot","",""}
	}
})

minetest.register_craft({
	output = "star_wars:xwing_wing",
	recipe = {
		{"","",""},
		{"default:steel_ingot","star_wars:beskar_ingot", "default:steel_ingot"},
		{"","",""}
	}
})

minetest.register_craft({
	output = "star_wars:engine",
	recipe = {
		{"star_wars:beskar_ingot","default:steel_ingot","star_wars:beskar_ingot"},
		{"default:steel_ingot","star_wars:laser_core", "default:steel_ingot"},
		{"star_wars:beskar_ingot","default:steel_ingot","star_wars:beskar_ingot"}
	}
})

minetest.register_craft({
	output = "star_wars:wrench",
	recipe = {
		{"default:steel_ingot","","default:steel_ingot"},
		{"","default:steel_ingot", ""},
		{"","default:steel_ingot",""}
	}
})

--==========================
-- DROIDS
--==========================

minetest.register_craft({
	output = "star_wars:r2d2_spawn_egg",
	recipe = {
		{"","default:steel_ingot",""},
		{"dye:blue","star_wars:engine", "dye:blue"},
		{"default:steel_ingot","default:steel_ingot","default:steel_ingot"}
	}
})

minetest.register_craft({
	output = "star_wars:r4p17_spawn_egg",
	recipe = {
		{"","default:steel_ingot",""},
		{"dye:red","star_wars:engine", "dye:red"},
		{"default:steel_ingot","default:steel_ingot","default:steel_ingot"}
	}
})













